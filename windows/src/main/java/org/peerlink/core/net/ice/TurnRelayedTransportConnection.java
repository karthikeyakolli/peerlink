package org.peerlink.core.net.ice;

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
import java.nio.channels.SocketChannel;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

/**
 * TransportConnection forwarding frames through a coturn TURN relay.
 * Implements RFC 5766 ChannelData framing:
 * [2 bytes Channel Number (0x4000..0x7FFF)] [2 bytes Payload Length] [Application Frame Bytes]
 *
 * CRITICAL SECURITY INVARIANT:
 * 1. The TURN relay is an UNTRUSTED dumb pipe; it never sees application plaintext.
 * 2. Relay success DOES NOT bypass PeerLink mutual cryptographic authentication
 *    or authorization. Every node must prove ownership of its Ed25519 identity key.
 */
public class TurnRelayedTransportConnection implements TransportConnection {

    private static final Logger log = LoggerFactory.getLogger(TurnRelayedTransportConnection.class);

    public static final short DEFAULT_CHANNEL_NUMBER = 0x4000;
    private static final int MAX_RELAY_FRAME_SIZE = 16 * 1024 * 1024; // 16 MB

    private final ConnectionId connectionId;
    private final InetSocketAddress localAddress;
    private final InetSocketAddress remoteAddress;
    private final InetSocketAddress relayAddress;
    private final TransportProtocol transportProtocol;
    private final short channelNumber;

    private final AtomicReference<ConnectionState> state = new AtomicReference<>(ConnectionState.CONNECTED);
    private final AtomicBoolean isPeerAuthenticated = new AtomicBoolean(false);
    private final AtomicReference<String> authenticatedPeerId = new AtomicReference<>(null);

    private SocketChannel socketChannel;
    private Consumer<byte[]> relayDataSender;
    private TransportFrameHandler frameHandler;
    private final List<ConnectionLifecycleListener> lifecycleListeners = new CopyOnWriteArrayList<>();

    private final AtomicBoolean readerStarted = new AtomicBoolean(false);
    private Thread socketReaderThread;

    public TurnRelayedTransportConnection(ConnectionId connectionId,
                                          InetSocketAddress localAddress,
                                          InetSocketAddress remoteAddress,
                                          InetSocketAddress relayAddress,
                                          TransportProtocol transportProtocol) {
        this(connectionId, localAddress, remoteAddress, relayAddress, transportProtocol, DEFAULT_CHANNEL_NUMBER, null, null);
    }

    public TurnRelayedTransportConnection(ConnectionId connectionId,
                                          InetSocketAddress localAddress,
                                          InetSocketAddress remoteAddress,
                                          InetSocketAddress relayAddress,
                                          TransportProtocol transportProtocol,
                                          short channelNumber,
                                          SocketChannel socketChannel,
                                          Consumer<byte[]> relayDataSender) {
        this.connectionId = Objects.requireNonNull(connectionId, "connectionId must not be null");
        this.localAddress = localAddress;
        this.remoteAddress = remoteAddress;
        this.relayAddress = Objects.requireNonNull(relayAddress, "relayAddress must not be null");
        this.transportProtocol = transportProtocol != null ? transportProtocol : TransportProtocol.UDP;
        this.channelNumber = channelNumber;
        this.socketChannel = socketChannel;
        this.relayDataSender = relayDataSender;

        if (this.socketChannel != null) {
            this.socketReaderThread = new Thread(this::runSocketReaderLoop, "peerlink-turn-reader-" + connectionId.getValue());
            this.socketReaderThread.setDaemon(true);
        }
    }

    public InetSocketAddress getRelayAddress() {
        return relayAddress;
    }

    public TransportProtocol getRelayTransportProtocol() {
        return transportProtocol;
    }

    public short getChannelNumber() {
        return channelNumber;
    }

    public boolean isPeerAuthenticated() {
        return isPeerAuthenticated.get();
    }

    public String getAuthenticatedPeerId() {
        return authenticatedPeerId.get();
    }

    /**
     * Mark that mutual cryptographic identity verification has succeeded over this relayed connection.
     */
    public void markPeerAuthenticated(String peerId) {
        this.authenticatedPeerId.set(Objects.requireNonNull(peerId, "peerId must not be null"));
        this.isPeerAuthenticated.set(true);
    }

    public boolean isDirect() {
        return false;
    }

    public ConnectionDiagnostics.Outcome getDiagnosticsOutcome() {
        return ConnectionDiagnostics.Outcome.RELAY_USED;
    }

    /**
     * Enforces that relay success does not bypass PeerLink authentication or application authorization.
     */
    public void checkApplicationTransferAuthorization() {
        if (!isPeerAuthenticated.get()) {
            throw new SecurityException("Cannot transfer application payload over relayed connection: peer is not authenticated");
        }
    }

    public void setRelayDataSender(Consumer<byte[]> sender) {
        this.relayDataSender = sender;
    }

    public void startReading() {
        if (socketReaderThread != null && readerStarted.compareAndSet(false, true)) {
            socketReaderThread.start();
        }
    }

    @Override
    public ConnectionId getConnectionId() {
        return connectionId;
    }

    @Override
    public TransportType getTransportType() {
        return TransportType.TRANSPORT_TYPE_RELAY_TURN;
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
            return CompletableFuture.failedFuture(new IOException("Cannot send frame: connection is " + state.get()));
        }

        try {
            byte[] frameBytes = frame.toByteArray();
            byte[] channelData = encapsulateChannelData(channelNumber, frameBytes);

            if (socketChannel != null && socketChannel.isOpen()) {
                ByteBuffer buf = ByteBuffer.wrap(channelData);
                while (buf.hasRemaining()) {
                    socketChannel.write(buf);
                }
            } else if (relayDataSender != null) {
                relayDataSender.accept(channelData);
            }

            return CompletableFuture.completedFuture(null);
        } catch (Exception e) {
            return CompletableFuture.failedFuture(new IOException("Failed to send relayed frame: " + e.getMessage(), e));
        }
    }

    @Override
    public void setFrameHandler(TransportFrameHandler handler) {
        this.frameHandler = handler;
    }

    @Override
    public void addLifecycleListener(ConnectionLifecycleListener listener) {
        if (listener != null) {
            lifecycleListeners.add(listener);
        }
    }

    /**
     * Decapsulates incoming raw bytes from the TURN relay and dispatches to frame handler.
     */
    public void deliverIncomingRelayedBytes(byte[] data) throws IOException {
        if (state.get() != ConnectionState.CONNECTED) return;
        if (data.length < 4) {
            throw new IOException("Malformed TURN ChannelData packet: too short (" + data.length + " bytes)");
        }

        ByteBuffer buf = ByteBuffer.wrap(data);
        short ch = buf.getShort();
        int len = buf.getShort() & 0xFFFF;

        if (len > data.length - 4) {
            throw new IOException("Malformed TURN ChannelData: declared length " + len + " exceeds remaining data " + (data.length - 4));
        }

        byte[] payload = new byte[len];
        buf.get(payload);

        TransportFrame frame = TransportFrame.parseFrom(payload);
        deliverIncomingFrame(frame);
    }

    public void deliverIncomingFrame(TransportFrame frame) {
        if (frameHandler != null && state.get() == ConnectionState.CONNECTED) {
            frameHandler.handleFrame(this, frame);
        }
    }

    private void runSocketReaderLoop() {
        try {
            ByteBuffer headerBuf = ByteBuffer.allocate(4);
            while (state.get() == ConnectionState.CONNECTED && socketChannel.isOpen()) {
                headerBuf.clear();
                readFully(socketChannel, headerBuf);
                headerBuf.flip();

                short ch = headerBuf.getShort();
                int len = headerBuf.getShort() & 0xFFFF;

                if (len <= 0 || len > MAX_RELAY_FRAME_SIZE) {
                    throw new IOException("Invalid TURN ChannelData payload length: " + len);
                }

                ByteBuffer bodyBuf = ByteBuffer.allocate(len);
                readFully(socketChannel, bodyBuf);
                bodyBuf.flip();
                byte[] payload = new byte[len];
                bodyBuf.get(payload);

                TransportFrame frame = TransportFrame.parseFrom(payload);
                deliverIncomingFrame(frame);
            }
        } catch (Exception e) {
            log.debug("TURN relay socket reader closed on {}: {}", connectionId.getValue(), e.getMessage());
            closeLocally();
        }
    }

    private static void readFully(SocketChannel ch, ByteBuffer buf) throws IOException {
        while (buf.hasRemaining()) {
            int read = ch.read(buf);
            if (read < 0) {
                throw new IOException("End of stream reached on TURN relay socket");
            }
        }
    }

    /**
     * Encapsulates raw payload with RFC 5766 ChannelData header:
     * 2-byte channel number (0x4000..0x7FFF), 2-byte length (big-endian), payload.
     */
    public static byte[] encapsulateChannelData(short channelNumber, byte[] payload) {
        ByteBuffer buf = ByteBuffer.allocate(4 + payload.length);
        buf.putShort(channelNumber);
        buf.putShort((short) (payload.length & 0xFFFF));
        buf.put(payload);
        return buf.array();
    }

    private void closeLocally() {
        ConnectionState old = state.getAndSet(ConnectionState.CLOSED);
        if (old != ConnectionState.CLOSED) {
            if (socketChannel != null) {
                try { socketChannel.close(); } catch (Exception ignored) {}
            }
            for (ConnectionLifecycleListener l : lifecycleListeners) {
                try {
                    l.onStateChanged(this, old, ConnectionState.CLOSED);
                } catch (Exception ignored) {}
            }
        }
    }

    @Override
    public CompletableFuture<Void> closeAsync() {
        closeLocally();
        return CompletableFuture.completedFuture(null);
    }

    @Override
    public void close() throws IOException {
        closeAsync().join();
    }
}
