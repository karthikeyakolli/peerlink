package org.peerlink.core.transport;

import org.peerlink.protocol.v1.ConnectionId;
import org.peerlink.protocol.v1.TransportFrame;
import org.peerlink.protocol.v1.TransportType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.EOFException;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.ClosedChannelException;
import java.nio.channels.SocketChannel;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Real duplex TCP socket transport connection backed by Java NIO {@link SocketChannel}.
 * Framing format: [4 bytes length header (big-endian)] [Protobuf wire bytes].
 * Enforces frame size boundaries (max 16 MB) and handles partial channel writes safely.
 */
public class StandardTcpTransportConnection implements TransportConnection {

    private static final Logger log = LoggerFactory.getLogger(StandardTcpTransportConnection.class);
    private static final int MAX_FRAME_SIZE = 16 * 1024 * 1024; // 16 MB

    private final ConnectionId connectionId;
    private final SocketChannel channel;
    private final TransportType transportType;
    private final AtomicReference<ConnectionState> state = new AtomicReference<>(ConnectionState.CONNECTED);
    private final AtomicReference<TransportFrameHandler> frameHandler = new AtomicReference<>();
    private final List<ConnectionLifecycleListener> lifecycleListeners = new CopyOnWriteArrayList<>();
    private final AtomicBoolean readerStarted = new AtomicBoolean(false);
    private final Thread readerThread;

    public StandardTcpTransportConnection(SocketChannel channel, TransportType transportType) {
        this.connectionId = ConnectionId.newBuilder()
                .setValue("conn_tcp_" + UUID.randomUUID().toString().replace("-", ""))
                .build();
        this.channel = channel;
        this.transportType = transportType != null ? transportType : TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS;

        this.readerThread = new Thread(this::runFrameReaderLoop, "peerlink-tcp-reader-" + connectionId.getValue());
        this.readerThread.setDaemon(true);
    }

    /**
     * Start the background frame reader thread.
     */
    public void startReading() {
        if (readerStarted.compareAndSet(false, true)) {
            readerThread.start();
        }
    }

    private void runFrameReaderLoop() {
        try {
            while (state.get() == ConnectionState.CONNECTED && channel.isOpen()) {
                // 1. Read 4-byte length prefix
                ByteBuffer lengthBuf = ByteBuffer.allocate(4);
                readFully(channel, lengthBuf);
                lengthBuf.flip();
                int length = lengthBuf.getInt();

                if (length <= 0 || length > MAX_FRAME_SIZE) {
                    throw new IllegalArgumentException("Invalid frame length header: " + length +
                            " (must be between 1 and " + MAX_FRAME_SIZE + " bytes)");
                }

                // 2. Read full frame bytes
                ByteBuffer bodyBuf = ByteBuffer.allocate(length);
                readFully(channel, bodyBuf);
                bodyBuf.flip();
                byte[] payload = new byte[length];
                bodyBuf.get(payload);

                // 3. Parse Protobuf TransportFrame
                TransportFrame frame = TransportFrame.parseFrom(payload);

                // 4. Dispatch to frame handler
                TransportFrameHandler handler = frameHandler.get();
                if (handler != null) {
                    try {
                        handler.handleFrame(this, frame);
                    } catch (Exception e) {
                        log.error("Error in frame handler on conn {}: {}", connectionId.getValue(), e.getMessage(), e);
                    }
                } else {
                    log.debug("Frame received without registered handler on conn {}", connectionId.getValue());
                }
            }
        } catch (EOFException | ClosedChannelException e) {
            log.info("TCP connection closed by peer on conn {}", connectionId.getValue());
            closeLocally();
        } catch (Exception e) {
            if (state.get() == ConnectionState.CONNECTED) {
                log.warn("TCP read loop error on conn {}: {}", connectionId.getValue(), e.getMessage());
                notifyError(e);
                closeLocally();
            }
        }
    }

    private static void readFully(SocketChannel ch, ByteBuffer buf) throws IOException {
        while (buf.hasRemaining()) {
            int read = ch.read(buf);
            if (read < 0) {
                throw new EOFException("End of stream reached on socket channel");
            }
        }
    }

    @Override
    public ConnectionId getConnectionId() {
        return connectionId;
    }

    @Override
    public TransportType getTransportType() {
        return transportType;
    }

    @Override
    public ConnectionState getState() {
        return state.get();
    }

    @Override
    public InetSocketAddress getRemoteAddress() {
        try {
            return (InetSocketAddress) channel.getRemoteAddress();
        } catch (IOException e) {
            return null;
        }
    }

    @Override
    public InetSocketAddress getLocalAddress() {
        try {
            return (InetSocketAddress) channel.getLocalAddress();
        } catch (IOException e) {
            return null;
        }
    }

    @Override
    public synchronized CompletableFuture<Void> sendFrameAsync(TransportFrame frame) {
        if (state.get() != ConnectionState.CONNECTED || !channel.isOpen()) {
            return CompletableFuture.failedFuture(new IOException("Connection is closed: " + state.get()));
        }

        try {
            byte[] frameBytes = frame.toByteArray();
            if (frameBytes.length > MAX_FRAME_SIZE) {
                return CompletableFuture.failedFuture(new IllegalArgumentException(
                        "Frame size " + frameBytes.length + " exceeds maximum permitted " + MAX_FRAME_SIZE));
            }

            ByteBuffer buf = ByteBuffer.allocate(4 + frameBytes.length);
            buf.putInt(frameBytes.length);
            buf.put(frameBytes);
            buf.flip();

            // Safe loop write to handle partial FileChannel / SocketChannel writes
            while (buf.hasRemaining()) {
                int written = channel.write(buf);
                if (written < 0) {
                    throw new EOFException("Channel closed during write");
                }
            }
            return CompletableFuture.completedFuture(null);
        } catch (Exception e) {
            closeLocally();
            return CompletableFuture.failedFuture(e);
        }
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
        closeLocally();
        return CompletableFuture.completedFuture(null);
    }

    private void closeLocally() {
        ConnectionState oldState = state.getAndSet(ConnectionState.CLOSED);
        if (oldState != ConnectionState.CLOSED) {
            try {
                if (channel.isOpen()) {
                    channel.close();
                }
            } catch (IOException ignored) {
            }
            notifyStateChanged(oldState, ConnectionState.CLOSED);
        }
    }

    private void notifyStateChanged(ConnectionState oldState, ConnectionState newState) {
        for (ConnectionLifecycleListener l : lifecycleListeners) {
            try {
                l.onStateChanged(this, oldState, newState);
            } catch (Exception ignored) {
            }
        }
    }

    private void notifyError(Throwable t) {
        for (ConnectionLifecycleListener l : lifecycleListeners) {
            try {
                l.onError(this, t);
            } catch (Exception ignored) {
            }
        }
    }

    @Override
    public void close() throws IOException {
        closeLocally();
    }
}
