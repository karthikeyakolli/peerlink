package org.peerlink.core.transport;

import org.peerlink.protocol.v1.TransportType;
import java.io.Closeable;
import java.io.IOException;

/**
 * Universal transport abstraction.
 * Allows Desktop to use Netty/QUIC/TCP-TLS while other platforms (e.g. Android)
 * can use native transport adapters without changing protocol semantics.
 */
public interface PeerLinkTransport extends Closeable {
    TransportType getTransportType();
    boolean isAvailable();
    void startListening(int port) throws IOException;
    TransportSession connect(String remoteAddress, int port) throws IOException;
}
