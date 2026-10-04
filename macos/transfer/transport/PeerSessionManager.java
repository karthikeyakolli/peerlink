package org.peerlink.core.transport;

import com.google.protobuf.ByteString;
import org.peerlink.core.security.PeerCryptoSigner;
import org.peerlink.core.security.TrustStore;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Orchestrates mutual cryptographic handshakes, session lifecycle,
 * replay protection, duplicate session prevention, and reconnects.
 */
public class PeerSessionManager implements Closeable {

    private static final Logger log = LoggerFactory.getLogger(PeerSessionManager.class);

    private static final long MAX_ALLOWED_TIMESTAMP_SKEW_MS = 30_000L;
    private static final int HANDSHAKE_TIMEOUT_SECONDS = 5;
    private static final int MAX_CONCURRENT_HANDSHAKES = 50;

    private final PeerIdentity localPeer;
    private final DeviceIdentity localDevice;
    private final PeerCryptoSigner localSigner;
    private final TrustStore trustStore;
    private final ProtocolVersion localProtocolVersion;
    private final ProtocolVersion minSupportedVersion;
    private final TransportCapabilityNegotiator capabilityNegotiator;

    private final Map<String, PeerSession> activeSessionsByPeerId = new ConcurrentHashMap<>();
    private final Map<String, PeerSession> activeSessionsBySessionId = new ConcurrentHashMap<>();
    private final Set<String> seenNonces = Collections.newSetFromMap(new ConcurrentHashMap<>());
    private final AtomicInteger currentHandshakes = new AtomicInteger(0);

    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "peerlink-session-manager");
        t.setDaemon(true);
        return t;
    });

    public PeerSessionManager(PeerIdentity localPeer,
                              DeviceIdentity localDevice,
                              PeerCryptoSigner localSigner,
                              TrustStore trustStore,
                              ProtocolVersion localProtocolVersion,
                              ProtocolVersion minSupportedVersion,
                              TransportCapabilityNegotiator capabilityNegotiator) {
        this.localPeer = localPeer;
        this.localDevice = localDevice;
        this.localSigner = localSigner;
        this.trustStore = trustStore;
        this.localProtocolVersion = localProtocolVersion;
        this.minSupportedVersion = minSupportedVersion;
        this.capabilityNegotiator = capabilityNegotiator;
    }

    public PeerIdentity getLocalPeer() {
        return localPeer;
    }

    public Optional<PeerSession> getSessionByPeerId(String peerId) {
        return Optional.ofNullable(activeSessionsByPeerId.get(peerId));
    }

    public Optional<PeerSession> getSessionBySessionId(String sessionId) {
        return Optional.ofNullable(activeSessionsBySessionId.get(sessionId));
    }

    public Collection<PeerSession> getActiveSessions() {
        return Collections.unmodifiableCollection(activeSessionsByPeerId.values());
    }

    /**
     * Initiates an outbound secure mutual handshake over an established TransportConnection.
     */
    public CompletableFuture<PeerSession> initiateSessionAsync(TransportConnection connection) {
        if (currentHandshakes.incrementAndGet() > MAX_CONCURRENT_HANDSHAKES) {
            currentHandshakes.decrementAndGet();
            return CompletableFuture.failedFuture(new IllegalStateException("Max concurrent handshakes exceeded"));
        }

        CompletableFuture<PeerSession> sessionFuture = new CompletableFuture<>();
        String sessionIdStr = "sess_" + UUID.randomUUID();
        SessionId sessionId = SessionId.newBuilder().setValue(sessionIdStr).build();
        ConnectionId connectionId = connection.getConnectionId();
        byte[] nonce = PeerCryptoSigner.generateNonce(32);
        long now = System.currentTimeMillis();

        byte[] signature = localSigner.signChallenge(
                localPeer.getPeerId().getValue(),
                connectionId.getValue(),
                sessionIdStr,
                nonce,
                now
        );

        HandshakeFrame synFrame = HandshakeFrame.newBuilder()
                .setPhase(HandshakePhase.HANDSHAKE_PHASE_SYN)
                .setProtocolVersion(localProtocolVersion)
                .setMinSupportedVersion(minSupportedVersion)
                .setConnectionId(connectionId)
                .setSessionId(sessionId)
                .setPeerIdentity(localPeer)
                .setDeviceIdentity(localDevice)
                .setNonce(ByteString.copyFrom(nonce))
                .setTimestampUtcMs(now)
                .setSignature(ByteString.copyFrom(signature))
                .addAllSupportedTransports(capabilityNegotiator.getSupportedTransports())
                .setSelectedTransport(connection.getTransportType())
                .build();

        // Register temporary frame handler for handshake response
        connection.setFrameHandler((c, frame) -> {
            if (!frame.hasHandshake()) {
                return;
            }
            HandshakeFrame resp = frame.getHandshake();
            if (resp.getPhase() == HandshakePhase.HANDSHAKE_PHASE_REJECT) {
                currentHandshakes.decrementAndGet();
                sessionFuture.completeExceptionally(new IOException("Handshake rejected by remote peer: " +
                        resp.getError().getHumanSummary() + " [" + resp.getError().getCode() + "]"));
                return;
            }

            if (resp.getPhase() == HandshakePhase.HANDSHAKE_PHASE_SYN_ACK) {
                try {
                    validateHandshakeResponse(resp, sessionIdStr, connectionId.getValue());

                    // Check duplicate session
                    String remotePeerId = resp.getPeerIdentity().getPeerId().getValue();
                    if (activeSessionsByPeerId.containsKey(remotePeerId)) {
                        throw new IllegalStateException("Duplicate active session for peer: " + remotePeerId);
                    }

                    // Send ACK
                    HandshakeFrame ackFrame = HandshakeFrame.newBuilder()
                            .setPhase(HandshakePhase.HANDSHAKE_PHASE_ACK)
                            .setSessionId(sessionId)
                            .setConnectionId(connectionId)
                            .build();

                    c.sendFrameAsync(TransportFrame.newBuilder().setHandshake(ackFrame).build());

                    PeerSession session = new PeerSessionImpl(
                            sessionId,
                            localPeer,
                            resp.getPeerIdentity(),
                            connection.getTransportType(),
                            c,
                            resp.getProtocolVersion(),
                            System.currentTimeMillis()
                    );

                    registerSession(session);
                    currentHandshakes.decrementAndGet();
                    sessionFuture.complete(session);
                } catch (Exception e) {
                    currentHandshakes.decrementAndGet();
                    sessionFuture.completeExceptionally(e);
                    c.closeAsync();
                }
            }
        });

        // Set timeout
        scheduler.schedule(() -> {
            if (!sessionFuture.isDone()) {
                currentHandshakes.decrementAndGet();
                sessionFuture.completeExceptionally(new TimeoutException("Handshake timed out after " + HANDSHAKE_TIMEOUT_SECONDS + "s"));
                connection.closeAsync();
            }
        }, HANDSHAKE_TIMEOUT_SECONDS, TimeUnit.SECONDS);

        // Send SYN
        connection.sendFrameAsync(TransportFrame.newBuilder().setHandshake(synFrame).build())
                .exceptionally(ex -> {
                    currentHandshakes.decrementAndGet();
                    sessionFuture.completeExceptionally(ex);
                    return null;
                });

        return sessionFuture;
    }

    /**
     * Handles inbound connection and acts as responder in the 3-way handshake.
     */
    public void handleInboundConnection(TransportConnection connection) {
        if (currentHandshakes.incrementAndGet() > MAX_CONCURRENT_HANDSHAKES) {
            currentHandshakes.decrementAndGet();
            rejectHandshake(connection, null, null, ErrorCode.ERROR_CODE_RESOURCE_EXHAUSTED, "Handshake concurrency limit reached");
            return;
        }

        connection.setFrameHandler((c, frame) -> {
            if (!frame.hasHandshake()) {
                return;
            }
            HandshakeFrame handshake = frame.getHandshake();
            if (handshake.getPhase() == HandshakePhase.HANDSHAKE_PHASE_SYN) {
                handleInboundSyn(c, handshake);
            }
        });
    }

    private void handleInboundSyn(TransportConnection connection, HandshakeFrame syn) {
        SessionId sessionId = syn.getSessionId();
        ConnectionId connectionId = syn.getConnectionId();

        try {
            // 1. Protocol Version Compatibility
            if (!isVersionCompatible(syn.getProtocolVersion(), syn.getMinSupportedVersion())) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION,
                        "Incompatible protocol version: remote=" + syn.getProtocolVersion().getMajor() +
                                ", local=" + localProtocolVersion.getMajor());
                return;
            }

            // 2. Malformed Checks
            if (!syn.hasPeerIdentity() || syn.getNonce().isEmpty() || syn.getSignature().isEmpty()
                    || !syn.hasSessionId() || !syn.hasConnectionId()) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_UNAUTHENTICATED,
                        "Malformed handshake: missing required cryptographic identity or signature");
                return;
            }

            // 3. Time Skew & Replay Protection
            long now = System.currentTimeMillis();
            if (Math.abs(now - syn.getTimestampUtcMs()) > MAX_ALLOWED_TIMESTAMP_SKEW_MS) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_UNAUTHENTICATED,
                        "Handshake timestamp outside freshness window (skew > 30s)");
                return;
            }

            String nonceHex = HexFormat.of().formatHex(syn.getNonce().toByteArray());
            if (!seenNonces.add(nonceHex)) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_UNAUTHENTICATED,
                        "Replay attack detected: nonce already consumed");
                return;
            }

            // 4. Cryptographic Signature Verification
            byte[] remotePubKey = syn.getPeerIdentity().getIdentityKey().getPublicKeyBytes().toByteArray();
            boolean validSig = PeerCryptoSigner.verifyChallenge(
                    remotePubKey,
                    syn.getPeerIdentity().getPeerId().getValue(),
                    connectionId.getValue(),
                    sessionId.getValue(),
                    syn.getNonce().toByteArray(),
                    syn.getTimestampUtcMs(),
                    syn.getSignature().toByteArray()
            );

            if (!validSig) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_UNAUTHENTICATED,
                        "Invalid cryptographic signature: peer identity cannot be proven");
                return;
            }

            // 5. Trust Store Verification (Discovery is NOT trust)
            String remotePeerId = syn.getPeerIdentity().getPeerId().getValue();
            if (!trustStore.isTrusted(remotePeerId)) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_UNAUTHORIZED,
                        "Peer identity [" + remotePeerId + "] is not in trusted paired store");
                return;
            }

            // 6. Duplicate Active Session Prevention
            if (activeSessionsByPeerId.containsKey(remotePeerId)) {
                rejectHandshake(connection, sessionId, connectionId,
                        ErrorCode.ERROR_CODE_CONFLICT_DETECTED,
                        "Duplicate session attempt: an active session is already established for peer " + remotePeerId);
                return;
            }

            // 7. Negotiate Transport
            TransportType selectedTransport = capabilityNegotiator.negotiateTransport(syn.getSupportedTransportsList());

            // 8. Sign and return SYN_ACK
            byte[] responderNonce = PeerCryptoSigner.generateNonce(32);
            byte[] responderSig = localSigner.signChallenge(
                    localPeer.getPeerId().getValue(),
                    connectionId.getValue(),
                    sessionId.getValue(),
                    responderNonce,
                    now
            );

            HandshakeFrame synAck = HandshakeFrame.newBuilder()
                    .setPhase(HandshakePhase.HANDSHAKE_PHASE_SYN_ACK)
                    .setProtocolVersion(localProtocolVersion)
                    .setMinSupportedVersion(minSupportedVersion)
                    .setConnectionId(connectionId)
                    .setSessionId(sessionId)
                    .setPeerIdentity(localPeer)
                    .setDeviceIdentity(localDevice)
                    .setNonce(ByteString.copyFrom(responderNonce))
                    .setTimestampUtcMs(now)
                    .setSignature(ByteString.copyFrom(responderSig))
                    .setSelectedTransport(selectedTransport)
                    .build();

            // Await final ACK
            connection.setFrameHandler((c, frame) -> {
                if (frame.hasHandshake() && frame.getHandshake().getPhase() == HandshakePhase.HANDSHAKE_PHASE_ACK) {
                    PeerSession session = new PeerSessionImpl(
                            sessionId,
                            localPeer,
                            syn.getPeerIdentity(),
                            connection.getTransportType(),
                            c,
                            syn.getProtocolVersion(),
                            System.currentTimeMillis()
                    );
                    registerSession(session);
                    currentHandshakes.decrementAndGet();
                    log.info("Secure session [{}] established with peer [{}] via [{}]",
                            sessionId.getValue(), remotePeerId, connection.getTransportType());
                }
            });

            connection.sendFrameAsync(TransportFrame.newBuilder().setHandshake(synAck).build());
        } catch (Exception e) {
            currentHandshakes.decrementAndGet();
            rejectHandshake(connection, sessionId, connectionId, ErrorCode.ERROR_CODE_INTERNAL_ERROR, e.getMessage());
        }
    }

    private void validateHandshakeResponse(HandshakeFrame resp, String expectedSessionId, String expectedConnectionId) {
        if (!resp.hasPeerIdentity() || resp.getNonce().isEmpty() || resp.getSignature().isEmpty()) {
            throw new IllegalArgumentException("Malformed SYN_ACK: missing required identity or signature");
        }

        if (!resp.getSessionId().getValue().equals(expectedSessionId)) {
            throw new IllegalArgumentException("Session ID mismatch in SYN_ACK");
        }

        byte[] remotePubKey = resp.getPeerIdentity().getIdentityKey().getPublicKeyBytes().toByteArray();
        boolean valid = PeerCryptoSigner.verifyChallenge(
                remotePubKey,
                resp.getPeerIdentity().getPeerId().getValue(),
                expectedConnectionId,
                expectedSessionId,
                resp.getNonce().toByteArray(),
                resp.getTimestampUtcMs(),
                resp.getSignature().toByteArray()
        );

        if (!valid) {
            throw new SecurityException("Invalid cryptographic signature in SYN_ACK from remote peer");
        }

        String remotePeerId = resp.getPeerIdentity().getPeerId().getValue();
        if (!trustStore.isTrusted(remotePeerId)) {
            throw new SecurityException("Peer [" + remotePeerId + "] is not trusted in local TrustStore");
        }
    }

    private void rejectHandshake(TransportConnection connection, SessionId sessionId, ConnectionId connectionId,
                                 ErrorCode code, String explanation) {
        currentHandshakes.decrementAndGet();
        ErrorDetail error = ErrorDetail.newBuilder()
                .setCode(code)
                .setErrorName(code.name())
                .setHumanSummary("Handshake rejected")
                .setHumanExplanation(explanation)
                .setIsRetryable(false)
                .setTimestampUtcMs(System.currentTimeMillis())
                .build();

        HandshakeFrame.Builder builder = HandshakeFrame.newBuilder()
                .setPhase(HandshakePhase.HANDSHAKE_PHASE_REJECT)
                .setError(error);

        if (sessionId != null) builder.setSessionId(sessionId);
        if (connectionId != null) builder.setConnectionId(connectionId);

        connection.sendFrameAsync(TransportFrame.newBuilder().setHandshake(builder.build()).build())
                .thenCompose(v -> connection.closeAsync());
    }

    private boolean isVersionCompatible(ProtocolVersion remote, ProtocolVersion remoteMin) {
        // Enforce major version match
        return remote.getMajor() == localProtocolVersion.getMajor();
    }

    private void registerSession(PeerSession session) {
        String peerId = session.getRemotePeer().getPeerId().getValue();
        String sessId = session.getSessionId().getValue();
        activeSessionsByPeerId.put(peerId, session);
        activeSessionsBySessionId.put(sessId, session);

        session.getConnection().addLifecycleListener(new ConnectionLifecycleListener() {
            @Override
            public void onStateChanged(TransportConnection connection, ConnectionState oldState, ConnectionState newState) {
                if (newState == ConnectionState.CLOSED) {
                    activeSessionsByPeerId.remove(peerId, session);
                    activeSessionsBySessionId.remove(sessId, session);
                    log.info("Session [{}] deregistered following connection close", sessId);
                }
            }

            @Override
            public void onError(TransportConnection connection, Throwable throwable) {
            }
        });
    }

    /**
     * Immediately terminates active sessions for a revoked peer.
     */
    public void onPeerRevoked(String peerId) {
        if (peerId == null) return;
        PeerSession session = activeSessionsByPeerId.get(peerId);
        if (session != null) {
            log.warn("Peer [{}] revoked. Terminating active session [{}] immediately",
                    peerId, session.getSessionId().getValue());
            try {
                session.close();
            } catch (Exception ignored) {
            }
            activeSessionsByPeerId.remove(peerId, session);
            activeSessionsBySessionId.remove(session.getSessionId().getValue(), session);
        }
    }

    /**
     * Reconnect skeleton with exponential backoff.
     */
    public CompletableFuture<PeerSession> reconnectAsync(TransportProvider provider,
                                                         InetSocketAddress remoteAddress,
                                                         int maxAttempts) {
        CompletableFuture<PeerSession> future = new CompletableFuture<>();
        attemptReconnect(provider, remoteAddress, 1, maxAttempts, 50, future);
        return future;
    }

    private void attemptReconnect(TransportProvider provider,
                                  InetSocketAddress remoteAddress,
                                  int attempt,
                                  int maxAttempts,
                                  long delayMs,
                                  CompletableFuture<PeerSession> future) {
        provider.connectAsync(remoteAddress)
                .thenCompose(this::initiateSessionAsync)
                .thenAccept(future::complete)
                .exceptionally(ex -> {
                    if (attempt >= maxAttempts) {
                        future.completeExceptionally(new IOException("Reconnect failed after " + maxAttempts + " attempts", ex));
                    } else {
                        long nextDelay = Math.min(delayMs * 2, 2000L);
                        scheduler.schedule(() -> attemptReconnect(provider, remoteAddress, attempt + 1, maxAttempts, nextDelay, future),
                                delayMs, TimeUnit.MILLISECONDS);
                    }
                    return null;
                });
    }

    @Override
    public void close() {
        scheduler.shutdownNow();
        for (PeerSession session : activeSessionsBySessionId.values()) {
            try {
                session.close();
            } catch (Exception ignored) {
            }
        }
        activeSessionsByPeerId.clear();
        activeSessionsBySessionId.clear();
    }
}
