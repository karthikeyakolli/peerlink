package org.peerlink.core.transport;

import java.io.IOException;
import java.net.Socket;

/**
 * Platform-neutral hook invoked on an unconnected client socket immediately before
 * {@link java.net.Socket#connect(java.net.SocketAddress)} or
 * {@link java.nio.channels.SocketChannel#connect(java.net.SocketAddress)}.
 *
 * Used by mobile operating systems (e.g. Android ConnectivityManager.bindSocket)
 * to bind outgoing TCP sockets to specific physical or virtual network interfaces
 * (e.g. Wi-Fi Direct P2P networks) without exposing OS-specific classes to the generic transport layer.
 */
@FunctionalInterface
public interface PreConnectSocketBinder {
    /**
     * Binds or configures the unconnected socket prior to connection initiation.
     *
     * @param socket the unconnected client socket
     * @throws IOException if network or interface binding fails
     */
    void bind(Socket socket) throws IOException;
}
