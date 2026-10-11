package org.peerlink.desktop.transport;

import org.peerlink.core.transport.TransportConnection;
import org.peerlink.core.transport.TransportConnectionListener;
import org.peerlink.core.transport.TransportProvider;
import org.peerlink.protocol.v1.ConnectionId;
import org.peerlink.protocol.v1.TransportType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Desktop QUIC Transport Provider prototype.
 * Uses UDP datagrams with QUIC Connection IDs and multiplexed frame semantics.
 */
public class DesktopQuicTransportProvider implements TransportProvider {

    private static final Logger log = LoggerFactory.getLogger(DesktopQuicTransportProvider.class);

    private DatagramSocket socket;
    private int listeningPort = 0;
    private final AtomicBoolean isListening = new AtomicBoolean(false);
    private volatile boolean isAvailable = true;

    private TransportConnectionListener connectionListener;
    private final Map<Long, DesktopQuicTransportConnection> connectionsByDcid = new ConcurrentHashMap<>();
    private final Random random = new Random();

    private ExecutorService receiverExecutor;

    public DesktopQuicTransportProvider() {
    }

    public void setAvailable(boolean available) {
        this.isAvailable = available;
    }

    @Override
    public TransportType getTransportType() {
        return TransportType.TRANSPORT_TYPE_DIRECT_QUIC;
    }

    @Override
    public boolean isAvailable() {
        return isAvailable;
    }

    @Override
    public int getPriority() {
        return 1; // Highest priority candidate (preferred over TCP)
    }

    @Override
    public synchronized void startListening(int port, TransportConnectionListener listener) throws IOException {
        if (!isListening.compareAndSet(false, true)) {
            throw new IllegalStateException("QUIC transport already listening on port " + listeningPort);
        }

        this.connectionListener = listener;
        this.socket = new DatagramSocket(port);
        this.listeningPort = socket.getLocalPort();
        this.receiverExecutor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "peerlink-quic-receiver-" + listeningPort);
            t.setDaemon(true);
            return t;
        });

        receiverExecutor.submit(this::listenLoop);
        log.info("Desktop QUIC prototype listening on UDP port {}", listeningPort);
    }

    private void listenLoop() {
        byte[] buffer = new byte[65535];
        while (isListening.get() && !socket.isClosed()) {
            try {
                DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                socket.receive(packet);

                if (packet.getLength() < 29) { // 1 + 8 + 8 + 8 + 4 = 29 min header
                    continue;
                }

                byte[] data = new byte[packet.getLength()];
                System.arraycopy(packet.getData(), packet.getOffset(), data, 0, packet.getLength());

                ByteBuffer buf = ByteBuffer.wrap(data);
                buf.get(); // flags
                long dcid = buf.getLong();
                long scid = buf.getLong();

                InetSocketAddress senderAddress = new InetSocketAddress(packet.getAddress(), packet.getPort());

                DesktopQuicTransportConnection conn = connectionsByDcid.computeIfAbsent(dcid, id -> {
                    ConnectionId connId = ConnectionId.newBuilder().setValue("conn_quic_" + UUID.randomUUID()).build();
                    DesktopQuicTransportConnection newConn = new DesktopQuicTransportConnection(
                            connId,
                            dcid, // local SCID is the inbound DCID
                            scid, // local DCID is the inbound SCID
                            new InetSocketAddress(socket.getLocalAddress(), socket.getLocalPort()),
                            senderAddress,
                            this::sendDatagram
                    );

                    if (connectionListener != null) {
                        connectionListener.onConnectionAccepted(newConn);
                    }
                    return newConn;
                });

                conn.onInboundDatagram(data);
            } catch (Exception e) {
                if (!isListening.get()) {
                    break;
                }
                log.debug("QUIC socket receive exception: {}", e.getMessage());
            }
        }
    }

    private void sendDatagram(byte[] data, InetSocketAddress destination) {
        try {
            DatagramPacket packet = new DatagramPacket(data, data.length, destination);
            socket.send(packet);
        } catch (Exception e) {
            log.warn("Failed to send QUIC datagram to {}: {}", destination, e.getMessage());
        }
    }

    @Override
    public int getListeningPort() {
        return listeningPort;
    }

    @Override
    public CompletableFuture<TransportConnection> connectAsync(InetSocketAddress remoteAddress) {
        if (!isAvailable) {
            return CompletableFuture.failedFuture(new IOException("QUIC transport is disabled/unavailable on this platform"));
        }

        try {
            if (socket == null || socket.isClosed()) {
                startListening(0, null);
            }

            long scid = random.nextLong() & Long.MAX_VALUE;
            long dcid = random.nextLong() & Long.MAX_VALUE;
            ConnectionId connId = ConnectionId.newBuilder().setValue("conn_quic_" + UUID.randomUUID()).build();

            DesktopQuicTransportConnection conn = new DesktopQuicTransportConnection(
                    connId,
                    scid,
                    dcid,
                    new InetSocketAddress(socket.getLocalAddress(), socket.getLocalPort()),
                    remoteAddress,
                    this::sendDatagram
            );

            // Register so inbound packets on this SCID route to this connection
            connectionsByDcid.put(scid, conn);

            return CompletableFuture.completedFuture(conn);
        } catch (Exception e) {
            return CompletableFuture.failedFuture(e);
        }
    }

    @Override
    public synchronized void stopListening() {
        if (isListening.compareAndSet(true, false)) {
            if (socket != null && !socket.isClosed()) {
                socket.close();
            }
            if (receiverExecutor != null) {
                receiverExecutor.shutdownNow();
            }
            connectionsByDcid.clear();
        }
    }

    @Override
    public void close() {
        stopListening();
    }
}
