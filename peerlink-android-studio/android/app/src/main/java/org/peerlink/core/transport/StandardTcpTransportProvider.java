package org.peerlink.core.transport;

import org.peerlink.protocol.v1.TransportType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.StandardSocketOptions;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Real Java NIO TCP Transport Provider.
 * Requires no external native libraries or shaded frameworks; operates over standard OS TCP sockets.
 */
public class StandardTcpTransportProvider implements TransportProvider {

    private static final Logger log = LoggerFactory.getLogger(StandardTcpTransportProvider.class);

    private final String bindHost;
    private ServerSocketChannel serverChannel;
    private int listeningPort = 0;
    private final AtomicBoolean isListening = new AtomicBoolean(false);
    private Thread acceptThread;

    public StandardTcpTransportProvider() {
        this("127.0.0.1");
    }

    public StandardTcpTransportProvider(String bindHost) {
        this.bindHost = (bindHost != null && !bindHost.isBlank()) ? bindHost : "127.0.0.1";
    }

    @Override
    public TransportType getTransportType() {
        return TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS;
    }

    @Override
    public boolean isAvailable() {
        return true;
    }

    @Override
    public int getPriority() {
        return 2; // Priority 2 (Direct TCP/TLS fallback if QUIC is unavailable)
    }

    @Override
    public synchronized void startListening(int port, TransportConnectionListener listener) throws IOException {
        if (!isListening.compareAndSet(false, true)) {
            throw new IllegalStateException("TCP transport already listening on port " + listeningPort);
        }

        try {
            serverChannel = ServerSocketChannel.open();
            serverChannel.setOption(StandardSocketOptions.SO_REUSEADDR, true);
            serverChannel.bind(new InetSocketAddress(bindHost, port));
            this.listeningPort = ((InetSocketAddress) serverChannel.getLocalAddress()).getPort();

            log.info("Standard TCP transport listening on {}:{}", bindHost, listeningPort);

            acceptThread = new Thread(() -> runAcceptLoop(listener), "peerlink-tcp-acceptor-" + listeningPort);
            acceptThread.setDaemon(true);
            acceptThread.start();
        } catch (IOException e) {
            isListening.set(false);
            if (serverChannel != null && serverChannel.isOpen()) {
                serverChannel.close();
            }
            throw e;
        }
    }

    private void runAcceptLoop(TransportConnectionListener listener) {
        while (isListening.get() && serverChannel.isOpen()) {
            try {
                SocketChannel clientChannel = serverChannel.accept();
                if (clientChannel != null) {
                    clientChannel.setOption(StandardSocketOptions.TCP_NODELAY, true);
                    clientChannel.setOption(StandardSocketOptions.SO_RCVBUF, 256 * 1024);
                    clientChannel.setOption(StandardSocketOptions.SO_SNDBUF, 256 * 1024);
                    StandardTcpTransportConnection connection = new StandardTcpTransportConnection(
                            clientChannel, TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS);
                    connection.startReading();
                    try {
                        listener.onConnectionAccepted(connection);
                    } catch (Exception e) {
                        log.error("Error in connection listener on accepted connection: {}", e.getMessage(), e);
                    }
                }
            } catch (Exception e) {
                if (isListening.get()) {
                    log.debug("Accept loop terminated or interrupted: {}", e.getMessage());
                }
                break;
            }
        }
    }

    @Override
    public int getListeningPort() {
        return listeningPort;
    }

    @Override
    public CompletableFuture<TransportConnection> connectAsync(InetSocketAddress remoteAddress) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                SocketChannel channel = SocketChannel.open();
                channel.setOption(StandardSocketOptions.TCP_NODELAY, true);
                channel.setOption(StandardSocketOptions.SO_RCVBUF, 256 * 1024);
                channel.setOption(StandardSocketOptions.SO_SNDBUF, 256 * 1024);
                channel.connect(remoteAddress);
                StandardTcpTransportConnection connection = new StandardTcpTransportConnection(
                        channel, TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS);
                connection.startReading();
                return connection;
            } catch (IOException e) {
                throw new RuntimeException("Failed to connect to " + remoteAddress + ": " + e.getMessage(), e);
            }
        });
    }

    @Override
    public synchronized void stopListening() {
        if (isListening.compareAndSet(true, false)) {
            log.info("Stopping Standard TCP transport on port {}", listeningPort);
            try {
                if (serverChannel != null && serverChannel.isOpen()) {
                    serverChannel.close();
                }
            } catch (IOException e) {
                log.warn("Error closing server channel: {}", e.getMessage());
            }
            if (acceptThread != null) {
                acceptThread.interrupt();
            }
        }
    }

    @Override
    public void close() throws IOException {
        stopListening();
    }
}
