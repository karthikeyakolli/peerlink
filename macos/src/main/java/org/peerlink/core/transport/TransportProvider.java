package org.peerlink.core.transport;

import org.peerlink.protocol.v1.TransportType;

import java.io.Closeable;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.concurrent.CompletableFuture;

/**
 * Pluggable provider for a physical or virtual P2P transport mechanism.
 * The architecture does NOT require Netty or QUIC on every future platform.
 */
public interface TransportProvider extends Closeable {
    TransportType getTransportType();
    boolean isAvailable();
    int getPriority(); // lower value = higher preference (e.g. QUIC = 1, TCP = 2)
    void startListening(int port, TransportConnectionListener listener) throws IOException;
    int getListeningPort();
    CompletableFuture<TransportConnection> connectAsync(InetSocketAddress remoteAddress);
    void stopListening();
}
