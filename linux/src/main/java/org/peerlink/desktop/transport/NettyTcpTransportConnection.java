package org.peerlink.desktop.transport;

import io.netty.channel.Channel;
import io.netty.channel.ChannelFutureListener;
import org.peerlink.core.transport.ConnectionLifecycleListener;
import org.peerlink.core.transport.ConnectionState;
import org.peerlink.core.transport.TransportConnection;
import org.peerlink.core.transport.TransportFrameHandler;
import org.peerlink.protocol.v1.ConnectionId;
import org.peerlink.protocol.v1.TransportFrame;
import org.peerlink.protocol.v1.TransportType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicReference;

public class NettyTcpTransportConnection implements TransportConnection {

    private static final Logger log = LoggerFactory.getLogger(NettyTcpTransportConnection.class);

    private final ConnectionId connectionId;
    private final Channel channel;
    private final AtomicReference<ConnectionState> state = new AtomicReference<>(ConnectionState.CONNECTED);
    private final AtomicReference<TransportFrameHandler> frameHandler = new AtomicReference<>();
    private final List<ConnectionLifecycleListener> lifecycleListeners = new CopyOnWriteArrayList<>();

    public NettyTcpTransportConnection(Channel channel) {
        this.connectionId = ConnectionId.newBuilder().setValue("conn_tcp_" + UUID.randomUUID()).build();
        this.channel = channel;

        // Monitor channel close
        this.channel.closeFuture().addListener((ChannelFutureListener) future -> {
            ConnectionState oldState = state.getAndSet(ConnectionState.CLOSED);
            if (oldState != ConnectionState.CLOSED) {
                notifyStateChanged(oldState, ConnectionState.CLOSED);
            }
        });
    }

    public void onInboundFrame(TransportFrame frame) {
        TransportFrameHandler handler = frameHandler.get();
        if (handler != null) {
            handler.handleFrame(this, frame);
        } else {
            log.debug("Frame received without registered handler on conn {}", connectionId.getValue());
        }
    }

    public void onInboundError(Throwable cause) {
        for (ConnectionLifecycleListener l : lifecycleListeners) {
            try {
                l.onError(this, cause);
            } catch (Exception ignored) {
            }
        }
    }

    @Override
    public ConnectionId getConnectionId() {
        return connectionId;
    }

    @Override
    public TransportType getTransportType() {
        return TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS;
    }

    @Override
    public ConnectionState getState() {
        return state.get();
    }

    @Override
    public InetSocketAddress getRemoteAddress() {
        return (InetSocketAddress) channel.remoteAddress();
    }

    @Override
    public InetSocketAddress getLocalAddress() {
        return (InetSocketAddress) channel.localAddress();
    }

    @Override
    public CompletableFuture<Void> sendFrameAsync(TransportFrame frame) {
        if (state.get() != ConnectionState.CONNECTED) {
            return CompletableFuture.failedFuture(new IOException("Connection is not connected: " + state.get()));
        }

        CompletableFuture<Void> future = new CompletableFuture<>();
        channel.writeAndFlush(frame).addListener((ChannelFutureListener) f -> {
            if (f.isSuccess()) {
                future.complete(null);
            } else {
                future.completeExceptionally(f.cause());
            }
        });
        return future;
    }

    @Override
    public void setFrameHandler(TransportFrameHandler handler) {
        this.frameHandler.set(handler);
    }

    @Override
    public void addLifecycleListener(ConnectionLifecycleListener listener) {
        this.lifecycleListeners.add(listener);
    }

    @Override
    public CompletableFuture<Void> closeAsync() {
        ConnectionState oldState = state.getAndSet(ConnectionState.CLOSING);
        if (oldState == ConnectionState.CLOSED) {
            return CompletableFuture.completedFuture(null);
        }

        CompletableFuture<Void> future = new CompletableFuture<>();
        channel.close().addListener((ChannelFutureListener) f -> {
            state.set(ConnectionState.CLOSED);
            notifyStateChanged(oldState, ConnectionState.CLOSED);
            future.complete(null);
        });
        return future;
    }

    private void notifyStateChanged(ConnectionState oldState, ConnectionState newState) {
        for (ConnectionLifecycleListener l : lifecycleListeners) {
            try {
                l.onStateChanged(this, oldState, newState);
            } catch (Exception ignored) {
            }
        }
    }

    @Override
    public void close() throws IOException {
        try {
            closeAsync().get();
        } catch (Exception e) {
            throw new IOException("Failed to close transport connection cleanly", e);
        }
    }
}
