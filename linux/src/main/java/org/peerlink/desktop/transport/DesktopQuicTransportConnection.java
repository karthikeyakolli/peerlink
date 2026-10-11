package org.peerlink.desktop.transport;

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
import java.nio.ByteBuffer;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.BiConsumer;

/**
 * Desktop QUIC Transport Connection prototype.
 * Carries multiplexed frames with 64-bit QUIC Connection IDs and monotonic packet numbers over UDP datagrams.
 */
public class DesktopQuicTransportConnection implements TransportConnection {

    private static final Logger log = LoggerFactory.getLogger(DesktopQuicTransportConnection.class);

    private final ConnectionId connectionId;
    private final long scid;
    private final long dcid;
    private final InetSocketAddress localAddress;
    private final InetSocketAddress remoteAddress;
    private final BiConsumer<byte[], InetSocketAddress> datagramSender;

    private final AtomicLong packetNumberGenerator = new AtomicLong(1);
    private final AtomicReference<ConnectionState> state = new AtomicReference<>(ConnectionState.CONNECTED);
    private final AtomicReference<TransportFrameHandler> frameHandler = new AtomicReference<>();
    private final List<ConnectionLifecycleListener> lifecycleListeners = new CopyOnWriteArrayList<>();

    public DesktopQuicTransportConnection(ConnectionId connectionId,
                                          long scid,
                                          long dcid,
                                          InetSocketAddress localAddress,
                                          InetSocketAddress remoteAddress,
                                          BiConsumer<byte[], InetSocketAddress> datagramSender) {
        this.connectionId = connectionId;
        this.scid = scid;
        this.dcid = dcid;
        this.localAddress = localAddress;
        this.remoteAddress = remoteAddress;
        this.datagramSender = datagramSender;
    }

    public long getScid() {
        return scid;
    }

    public long getDcid() {
        return dcid;
    }

    public void onInboundDatagram(byte[] packetBytes) {
        try {
            ByteBuffer buf = ByteBuffer.wrap(packetBytes);
            byte flags = buf.get(); // QUIC header flags
            long inDcid = buf.getLong();
            long inScid = buf.getLong();
            long packetNumber = buf.getLong();
            int frameLen = buf.getInt();

            if (frameLen < 0 || buf.remaining() < frameLen) {
                log.warn("Malformed QUIC datagram frame length: {}", frameLen);
                return;
            }

            byte[] frameBytes = new byte[frameLen];
            buf.get(frameBytes);
            TransportFrame frame = TransportFrame.parseFrom(frameBytes);

            TransportFrameHandler handler = frameHandler.get();
            if (handler != null) {
                handler.handleFrame(this, frame);
            }
        } catch (Exception e) {
            log.warn("Failed to parse inbound QUIC packet: {}", e.getMessage());
            for (ConnectionLifecycleListener l : lifecycleListeners) {
                l.onError(this, e);
            }
        }
    }

    @Override
    public ConnectionId getConnectionId() {
        return connectionId;
    }

    @Override
    public TransportType getTransportType() {
        return TransportType.TRANSPORT_TYPE_DIRECT_QUIC;
    }

    @Override
    public ConnectionState getState() {
        return state.get();
    }

    @Override
    public InetSocketAddress getRemoteAddress() {
        return remoteAddress;
    }

    @Override
    public InetSocketAddress getLocalAddress() {
        return localAddress;
    }

    @Override
    public CompletableFuture<Void> sendFrameAsync(TransportFrame frame) {
        if (state.get() != ConnectionState.CONNECTED) {
            return CompletableFuture.failedFuture(new IOException("QUIC connection not connected: " + state.get()));
        }

        try {
            byte[] frameBytes = frame.toByteArray();
            long pktNum = packetNumberGenerator.getAndIncrement();

            // Header: 1 byte flags (0xC0), 8 bytes DCID, 8 bytes SCID, 8 bytes PktNum, 4 bytes len
            ByteBuffer buf = ByteBuffer.allocate(1 + 8 + 8 + 8 + 4 + frameBytes.length);
            buf.put((byte) 0xC0); // QUIC 1-RTT short header flag
            buf.putLong(dcid);
            buf.putLong(scid);
            buf.putLong(pktNum);
            buf.putInt(frameBytes.length);
            buf.put(frameBytes);

            datagramSender.accept(buf.array(), remoteAddress);
            return CompletableFuture.completedFuture(null);
        } catch (Exception e) {
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
        ConnectionState old = state.getAndSet(ConnectionState.CLOSED);
        if (old != ConnectionState.CLOSED) {
            for (ConnectionLifecycleListener l : lifecycleListeners) {
                l.onStateChanged(this, old, ConnectionState.CLOSED);
            }
        }
        return CompletableFuture.completedFuture(null);
    }

    @Override
    public void close() throws IOException {
        closeAsync();
    }
}
