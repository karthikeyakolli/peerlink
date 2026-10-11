package org.peerlink.core.transport;

import com.google.protobuf.ByteString;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicReference;

public class PeerSessionImpl implements PeerSession {

    private static final Logger log = LoggerFactory.getLogger(PeerSessionImpl.class);

    private final SessionId sessionId;
    private final PeerIdentity localPeer;
    private final PeerIdentity remotePeer;
    private final TransportType transportType;
    private final TransportConnection connection;
    private final ProtocolVersion protocolVersion;
    private final long establishedAtUtcMs;

    private final AtomicReference<SessionState> state = new AtomicReference<>(SessionState.SESSION_STATE_ESTABLISHED);
    private final AtomicReference<SessionPayloadHandler> payloadHandler = new AtomicReference<>();
    private final Map<String, PendingPing> pendingPings = new ConcurrentHashMap<>();

    private static class PendingPing {
        final long sentTimestampMs;
        final CompletableFuture<Long> future;

        PendingPing(long sentTimestampMs, CompletableFuture<Long> future) {
            this.sentTimestampMs = sentTimestampMs;
            this.future = future;
        }
    }

    public PeerSessionImpl(SessionId sessionId,
                           PeerIdentity localPeer,
                           PeerIdentity remotePeer,
                           TransportType transportType,
                           TransportConnection connection,
                           ProtocolVersion protocolVersion,
                           long establishedAtUtcMs) {
        this.sessionId = sessionId;
        this.localPeer = localPeer;
        this.remotePeer = remotePeer;
        this.transportType = transportType;
        this.connection = connection;
        this.protocolVersion = protocolVersion;
        this.establishedAtUtcMs = establishedAtUtcMs;

        this.connection.setFrameHandler(this::onFrameReceived);
        this.connection.addLifecycleListener(new ConnectionLifecycleListener() {
            @Override
            public void onStateChanged(TransportConnection c, ConnectionState oldState, ConnectionState newState) {
                if (newState == ConnectionState.CLOSED) {
                    state.set(SessionState.SESSION_STATE_CLOSED);
                    failPendingPings("Connection closed");
                }
            }

            @Override
            public void onError(TransportConnection c, Throwable throwable) {
                log.warn("Session [{}] transport error: {}", sessionId.getValue(), throwable.getMessage());
            }
        });
    }

    private void onFrameReceived(TransportConnection c, TransportFrame frame) {
        if (state.get() == SessionState.SESSION_STATE_CLOSED) {
            return;
        }

        switch (frame.getFrameCase()) {
            case PAYLOAD -> {
                SessionPayloadHandler handler = payloadHandler.get();
                if (handler != null) {
                    handler.handlePayload(this, frame.getPayload().toByteArray());
                }
            }
            case PING -> {
                KeepalivePing ping = frame.getPing();
                KeepalivePong pong = KeepalivePong.newBuilder()
                        .setPingId(ping.getPingId())
                        .setEchoTimestampUtcMs(ping.getTimestampUtcMs())
                        .setResponderTimestampUtcMs(System.currentTimeMillis())
                        .build();
                connection.sendFrameAsync(TransportFrame.newBuilder().setPong(pong).build());
            }
            case PONG -> {
                KeepalivePong pong = frame.getPong();
                PendingPing pending = pendingPings.remove(pong.getPingId());
                if (pending != null) {
                    long rtt = Math.max(0, System.currentTimeMillis() - pending.sentTimestampMs);
                    pending.future.complete(rtt);
                }
            }
            case CLOSE -> {
                SessionCloseFrame close = frame.getClose();
                log.info("Remote peer closed session [{}]: {} ({})",
                        sessionId.getValue(), close.getReasonMessage(), close.getReasonCode());
                state.set(SessionState.SESSION_STATE_CLOSED);
                failPendingPings("Session closed by remote peer");
                connection.closeAsync();
            }
            default -> log.debug("Unhandled frame case: {}", frame.getFrameCase());
        }
    }

    private void failPendingPings(String reason) {
        for (PendingPing p : pendingPings.values()) {
            p.future.completeExceptionally(new IOException(reason));
        }
        pendingPings.clear();
    }

    @Override
    public SessionId getSessionId() {
        return sessionId;
    }

    @Override
    public PeerIdentity getLocalPeer() {
        return localPeer;
    }

    @Override
    public PeerIdentity getRemotePeer() {
        return remotePeer;
    }

    @Override
    public SessionState getState() {
        return state.get();
    }

    @Override
    public TransportType getActiveTransportType() {
        return transportType;
    }

    @Override
    public TransportConnection getConnection() {
        return connection;
    }

    @Override
    public SessionDescriptor getDescriptor() {
        return SessionDescriptor.newBuilder()
                .setSessionId(sessionId)
                .setInitiatorPeerId(localPeer.getPeerId())
                .setResponderPeerId(remotePeer.getPeerId())
                .setState(state.get())
                .setTransportType(transportType)
                .setEstablishedAtUtcMs(establishedAtUtcMs)
                .setExpiresAtUtcMs(establishedAtUtcMs + 3600_000L)
                .setProtocolVersion(protocolVersion)
                .build();
    }

    @Override
    public CompletableFuture<Void> sendPayloadAsync(byte[] payload) {
        if (state.get() != SessionState.SESSION_STATE_ESTABLISHED) {
            return CompletableFuture.failedFuture(new IllegalStateException("Session is not established: " + state.get()));
        }
        TransportFrame frame = TransportFrame.newBuilder()
                .setPayload(ByteString.copyFrom(payload))
                .build();
        return connection.sendFrameAsync(frame);
    }

    @Override
    public void setPayloadHandler(SessionPayloadHandler handler) {
        this.payloadHandler.set(handler);
    }

    @Override
    public CompletableFuture<Long> sendPingAsync() {
        if (state.get() != SessionState.SESSION_STATE_ESTABLISHED) {
            return CompletableFuture.failedFuture(new IllegalStateException("Session is not established"));
        }
        String pingId = UUID.randomUUID().toString();
        long now = System.currentTimeMillis();
        CompletableFuture<Long> future = new CompletableFuture<>();
        pendingPings.put(pingId, new PendingPing(now, future));

        KeepalivePing ping = KeepalivePing.newBuilder()
                .setPingId(pingId)
                .setTimestampUtcMs(now)
                .build();

        connection.sendFrameAsync(TransportFrame.newBuilder().setPing(ping).build())
                .exceptionally(ex -> {
                    pendingPings.remove(pingId);
                    future.completeExceptionally(ex);
                    return null;
                });

        return future;
    }

    @Override
    public CompletableFuture<Void> closeAsync(int reasonCode, String reason) {
        if (state.getAndSet(SessionState.SESSION_STATE_CLOSING) == SessionState.SESSION_STATE_CLOSED) {
            return CompletableFuture.completedFuture(null);
        }

        SessionCloseFrame close = SessionCloseFrame.newBuilder()
                .setSessionId(sessionId)
                .setReasonCode(reasonCode)
                .setReasonMessage(reason != null ? reason : "Normal closure")
                .build();

        return connection.sendFrameAsync(TransportFrame.newBuilder().setClose(close).build())
                .thenCompose(v -> connection.closeAsync())
                .thenRun(() -> {
                    state.set(SessionState.SESSION_STATE_CLOSED);
                    failPendingPings("Session closed locally");
                });
    }

    @Override
    public void close() throws IOException {
        try {
            closeAsync(0, "Close invoked").get();
        } catch (Exception e) {
            throw new IOException("Failed to close session cleanly", e);
        }
    }
}
