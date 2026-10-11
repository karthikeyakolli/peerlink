package org.peerlink.core.transport;

import org.peerlink.protocol.v1.TransportType;
import java.io.Closeable;
import java.io.IOException;

/**
 * Active P2P transport session between two authenticated peers.
 */
public interface TransportSession extends Closeable {
    String getSessionId();
    String getRemotePeerId();
    TransportType getTransportType();
    boolean isDirect();
    void sendPayload(byte[] payload) throws IOException;
    byte[] receivePayload() throws IOException;
}
