package org.peerlink.core.transport;

import org.peerlink.protocol.v1.PeerIdentity;
import org.peerlink.protocol.v1.SessionDescriptor;
import org.peerlink.protocol.v1.SessionId;
import org.peerlink.protocol.v1.SessionState;
import org.peerlink.protocol.v1.TransportType;

import java.io.Closeable;
import java.util.concurrent.CompletableFuture;

/**
 * Authenticated end-to-end session between two verified peers.
 */
public interface PeerSession extends Closeable {
    SessionId getSessionId();
    PeerIdentity getLocalPeer();
    PeerIdentity getRemotePeer();
    SessionState getState();
    TransportType getActiveTransportType();
    TransportConnection getConnection();
    SessionDescriptor getDescriptor();

    CompletableFuture<Void> sendPayloadAsync(byte[] payload);
    void setPayloadHandler(SessionPayloadHandler handler);
    default SessionPayloadHandler getPayloadHandler() { return null; }

    /**
     * Sends keepalive ping and returns measured round-trip time in milliseconds.
     */
    CompletableFuture<Long> sendPingAsync();

    CompletableFuture<Void> closeAsync(int reasonCode, String reason);
}
