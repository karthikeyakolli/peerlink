package org.peerlink.core.transport;

import org.peerlink.protocol.v1.ConnectionId;
import org.peerlink.protocol.v1.TransportFrame;
import org.peerlink.protocol.v1.TransportType;

import java.io.Closeable;
import java.net.InetSocketAddress;
import java.util.concurrent.CompletableFuture;

/**
 * Low-level duplex transport channel carrying serialized Protobuf TransportFrames.
 */
public interface TransportConnection extends Closeable {
    ConnectionId getConnectionId();
    TransportType getTransportType();
    ConnectionState getState();
    InetSocketAddress getRemoteAddress();
    InetSocketAddress getLocalAddress();
    CompletableFuture<Void> sendFrameAsync(TransportFrame frame);
    void setFrameHandler(TransportFrameHandler handler);
    void addLifecycleListener(ConnectionLifecycleListener listener);
    CompletableFuture<Void> closeAsync();
}
