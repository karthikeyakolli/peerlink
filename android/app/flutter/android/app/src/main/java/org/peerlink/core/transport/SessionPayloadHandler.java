package org.peerlink.core.transport;

@FunctionalInterface
public interface SessionPayloadHandler {
    void handlePayload(PeerSession session, byte[] payload);
}
