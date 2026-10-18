package org.peerlink.core.android.discovery;

import org.peerlink.core.transport.TransportConnection;
import org.peerlink.core.transport.TransportProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

/**
 * Universal transport abstraction and route selection engine.
 * Selects, evaluates, and falls back across available network routes for a target peer
 * without exposing radio-specific logic to the transfer layer.
 */
public class TransportRouteSelector {
    private static final Logger log = LoggerFactory.getLogger(TransportRouteSelector.class);

    private final TransportProvider transportProvider;
    private final long perRouteTimeoutMs;

    public TransportRouteSelector(TransportProvider transportProvider) {
        this(transportProvider, 3000L);
    }

    public TransportRouteSelector(TransportProvider transportProvider, long perRouteTimeoutMs) {
        this.transportProvider = Objects.requireNonNull(transportProvider, "transportProvider is required");
        this.perRouteTimeoutMs = perRouteTimeoutMs;
    }

    /**
     * Attempts to connect to the target peer using the best available route,
     * falling back to lower-priority routes if earlier attempts fail.
     */
    public CompletableFuture<TransportConnectionResult> connectWithFallbackAsync(DiscoveredPeerRecord peer) {
        Objects.requireNonNull(peer, "peer must not be null");
        List<PeerTransportRoute> candidateRoutes = new ArrayList<>(peer.getAvailableRoutes());

        if (candidateRoutes.isEmpty()) {
            return CompletableFuture.failedFuture(
                    new IOException("No available routes found for peer: " + peer.getPeerId().getValue())
            );
        }

        CompletableFuture<TransportConnectionResult> resultFuture = new CompletableFuture<>();
        tryRouteAtIndex(peer, candidateRoutes, 0, new ArrayList<>(), resultFuture);
        return resultFuture;
    }

    private void tryRouteAtIndex(DiscoveredPeerRecord peer,
                                 List<PeerTransportRoute> routes,
                                 int index,
                                 List<String> failureReasons,
                                 CompletableFuture<TransportConnectionResult> resultFuture) {
        if (index >= routes.size()) {
            String combinedReasons = String.join("; ", failureReasons);
            resultFuture.completeExceptionally(
                    new IOException("All " + routes.size() + " route(s) failed for peer " +
                            peer.getDisplayName() + " [" + peer.getPeerId().getValue() + "]: " + combinedReasons)
            );
            return;
        }

        PeerTransportRoute route = routes.get(index);
        log.info("Attempting route [{}/{}] for {}: {} ({}:{})",
                index + 1, routes.size(), peer.getDisplayName(),
                route.getDiscoveryTechnology(), route.getHostAddress(), route.getPort());

        InetSocketAddress socketAddress = new InetSocketAddress(route.getHostAddress(), route.getPort());

        CompletableFuture<TransportConnection> connectFuture = transportProvider.connectAsync(socketAddress);

        // Bounded per-route timeout
        CompletableFuture<TransportConnection> timedFuture = connectFuture.orTimeout(perRouteTimeoutMs, TimeUnit.MILLISECONDS);

        timedFuture.thenAccept(connection -> {
            log.info("Successfully connected to {} via route: {}", peer.getDisplayName(), route);
            route.markSuccess();
            resultFuture.complete(new TransportConnectionResult(connection, route, index > 0));
        }).exceptionally(ex -> {
            String reason = route.getDiscoveryTechnology() + "@" + route.getHostAddress() + ":" + route.getPort() +
                    " failed: " + (ex.getCause() != null ? ex.getCause().getMessage() : ex.getMessage());
            log.warn("Route attempt failed: {}. Falling back to next candidate...", reason);
            route.markFailure();
            failureReasons.add(reason);

            // Sequential fallback to next candidate route
            tryRouteAtIndex(peer, routes, index + 1, failureReasons, resultFuture);
            return null;
        });
    }

    /**
     * Encapsulates the successful connection and metadata about the chosen route.
     */
    public record TransportConnectionResult(
            TransportConnection connection,
            PeerTransportRoute chosenRoute,
            boolean didFallback
    ) {}
}
