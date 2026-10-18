package org.peerlink.core.android.discovery;

import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.*;

/**
 * Discovery engine coordinating multiple platform discovery adapters
 * (NSD/mDNS, Wi-Fi Direct, Wi-Fi Aware, Nearby RF).
 * Aggregates, deduplicates, health-evaluates, and expires discovered peers across network technologies.
 */
public class AndroidDiscoveryEngine implements DiscoveryAdapter.DiscoveryCallback {
    private static final Logger log = LoggerFactory.getLogger(AndroidDiscoveryEngine.class);

    public static final long DEFAULT_PEER_TTL_MS = 30_000L; // 30 seconds TTL for stale peer pruning

    public interface EngineListener {
        void onPeerDiscovered(DiscoveredPeerRecord peer);
        void onPeerLost(PeerId peerId);
    }

    private final List<DiscoveryAdapter> adapters = new CopyOnWriteArrayList<>();
    private final List<EngineListener> listeners = new CopyOnWriteArrayList<>();
    private final ConcurrentMap<PeerId, DiscoveredPeerRecord> activePeers = new ConcurrentHashMap<>();
    private volatile PeerId localPeerId;
    private volatile boolean isRunning = false;

    private ScheduledExecutorService stalePruneScheduler;

    public AndroidDiscoveryEngine(List<DiscoveryAdapter> adapters) {
        if (adapters != null) {
            this.adapters.addAll(adapters);
        }
    }

    public void setLocalPeerId(PeerId localPeerId) {
        this.localPeerId = localPeerId;
    }

    public PeerId getLocalPeerId() {
        return localPeerId;
    }

    public void addAdapter(DiscoveryAdapter adapter) {
        this.adapters.add(Objects.requireNonNull(adapter));
        if (isRunning && adapter.isAvailable()) {
            adapter.startDiscovery(this);
        }
    }

    public List<DiscoveryAdapter> getAdapters() {
        return Collections.unmodifiableList(adapters);
    }

    public void addListener(EngineListener listener) {
        this.listeners.add(Objects.requireNonNull(listener));
    }

    public void removeListener(EngineListener listener) {
        this.listeners.remove(listener);
    }

    public synchronized void startAll() {
        if (isRunning) return;
        isRunning = true;
        log.info("Starting AndroidDiscoveryEngine with {} adapters", adapters.size());

        startStalePruneScheduler();

        for (DiscoveryAdapter adapter : adapters) {
            if (adapter.isAvailable()) {
                try {
                    adapter.startDiscovery(this);
                } catch (Exception e) {
                    log.error("Failed to start discovery adapter: " + adapter.getTechnologyName(), e);
                }
            } else {
                log.info("Adapter {} is unavailable on this device/network", adapter.getTechnologyName());
            }
        }
    }

    private synchronized void startStalePruneScheduler() {
        if (stalePruneScheduler == null || stalePruneScheduler.isShutdown()) {
            stalePruneScheduler = Executors.newSingleThreadScheduledExecutor(r -> {
                Thread t = new Thread(r, "peerlink-discovery-pruner");
                t.setDaemon(true);
                return t;
            });
            stalePruneScheduler.scheduleWithFixedDelay(
                    () -> sweepStalePeers(DEFAULT_PEER_TTL_MS),
                    10, 10, TimeUnit.SECONDS
            );
        }
    }

    public synchronized void stopAll() {
        if (!isRunning) return;
        isRunning = false;
        log.info("Stopping AndroidDiscoveryEngine");

        if (stalePruneScheduler != null) {
            stalePruneScheduler.shutdownNow();
            stalePruneScheduler = null;
        }

        for (DiscoveryAdapter adapter : adapters) {
            try {
                adapter.stopDiscovery();
                adapter.stopAdvertising();
            } catch (Exception e) {
                log.error("Error stopping adapter: " + adapter.getTechnologyName(), e);
            }
        }
        activePeers.clear();
    }

    public synchronized void startAdvertisingAll(PeerId localPeerId, String displayName, int port) {
        this.localPeerId = localPeerId;
        for (DiscoveryAdapter adapter : adapters) {
            if (adapter.isAvailable()) {
                try {
                    adapter.startAdvertising(localPeerId, displayName, port);
                } catch (Exception e) {
                    log.error("Failed to start advertising on: " + adapter.getTechnologyName(), e);
                }
            }
        }
    }

    @Override
    public void onPeerFound(DiscoveredPeerRecord peer) {
        if (peer == null || peer.getPeerId() == null || peer.getPeerId().getValue().isBlank()) {
            return;
        }

        // Self-filtering: never show the local device as a remote peer
        if (localPeerId != null && localPeerId.equals(peer.getPeerId())) {
            log.debug("Self-filtering: dropped discovery record matching local peerId {}", localPeerId.getValue());
            return;
        }

        DiscoveredPeerRecord authoritative = activePeers.compute(peer.getPeerId(), (id, existing) -> {
            if (existing == null) {
                return peer;
            } else {
                existing.mergeFrom(peer);
                return existing;
            }
        });

        log.info("Peer deduplicated & active via {}: {} ({}:{}) - total routes: {}",
                authoritative.getDiscoveryTechnology(), authoritative.getDisplayName(),
                authoritative.getHostAddress(), authoritative.getPort(), authoritative.getAvailableRoutes().size());

        for (EngineListener listener : listeners) {
            try {
                listener.onPeerDiscovered(authoritative);
            } catch (Exception e) {
                log.error("Error notifying listener of discovered peer", e);
            }
        }
    }

    @Override
    public void onPeerLost(PeerId peerId) {
        if (peerId == null) return;
        DiscoveredPeerRecord removed = activePeers.remove(peerId);
        if (removed != null) {
            log.info("Peer lost from discovery: {}", peerId.getValue());
            for (EngineListener listener : listeners) {
                try {
                    listener.onPeerLost(peerId);
                } catch (Exception e) {
                    log.error("Error notifying listener of lost peer", e);
                }
            }
        }
    }

    @Override
    public void onDiscoveryError(String technology, String errorMessage) {
        log.warn("Discovery error on {}: {}", technology, errorMessage);
    }

    /**
     * Periodically sweeps stale peers whose routes have not been seen within maxAgeMs.
     * Fires onPeerLost for any pruned peer.
     * Returns the list of pruned peer IDs.
     */
    public List<PeerId> sweepStalePeers(long maxAgeMs) {
        List<PeerId> pruned = new ArrayList<>();
        Iterator<Map.Entry<PeerId, DiscoveredPeerRecord>> it = activePeers.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<PeerId, DiscoveredPeerRecord> entry = it.next();
            DiscoveredPeerRecord record = entry.getValue();
            boolean allRoutesExpired = record.pruneExpiredRoutes(maxAgeMs);
            if (allRoutesExpired || record.isExpired(maxAgeMs)) {
                it.remove();
                pruned.add(entry.getKey());
                log.info("Peer expired due to inactivity (>{}ms): {}", maxAgeMs, entry.getKey().getValue());
                for (EngineListener listener : listeners) {
                    try {
                        listener.onPeerLost(entry.getKey());
                    } catch (Exception e) {
                        log.error("Error notifying listener of expired peer", e);
                    }
                }
            }
        }
        return pruned;
    }

    /**
     * Adds an explicit manual endpoint as a fallback route.
     * Useful when mDNS or Wi-Fi Direct multicast is blocked by network infrastructure.
     */
    public DiscoveredPeerRecord addManualPeer(PeerId peerId, String displayName, String hostAddress, int port) {
        Objects.requireNonNull(peerId, "peerId is required");
        Objects.requireNonNull(hostAddress, "hostAddress is required");
        if (localPeerId != null && localPeerId.equals(peerId)) {
            throw new IllegalArgumentException("Cannot add local peer as manual remote endpoint");
        }
        DiscoveredPeerRecord record = new DiscoveredPeerRecord(
                peerId, displayName, hostAddress, port, "MANUAL", List.of("TCP_TLS")
        );
        onPeerFound(record);
        return activePeers.get(peerId);
    }

    /**
     * Updates peer connection state, distinguishing a discovered advertisement from an
     * active, authenticated cryptographic session.
     */
    public void updatePeerConnectionState(PeerId peerId, PeerConnectionState state) {
        DiscoveredPeerRecord record = activePeers.get(peerId);
        if (record != null) {
            record.setConnectionState(state);
            for (EngineListener listener : listeners) {
                try {
                    listener.onPeerDiscovered(record);
                } catch (Exception e) {
                    log.error("Error notifying listener of peer state update", e);
                }
            }
        }
    }

    public Map<PeerId, DiscoveredPeerRecord> getActivePeers() {
        return Collections.unmodifiableMap(activePeers);
    }

    public List<DiscoveredPeerRecord> getDiscoveredPeers() {
        return new ArrayList<>(activePeers.values());
    }

    public List<DiscoveredPeerRecord> getConnectedPeers() {
        List<DiscoveredPeerRecord> connected = new ArrayList<>();
        for (DiscoveredPeerRecord p : activePeers.values()) {
            if (p.getConnectionState() == PeerConnectionState.AUTHENTICATED_CONNECTED) {
                connected.add(p);
            }
        }
        return connected;
    }

    public boolean isRunning() {
        return isRunning;
    }
}
