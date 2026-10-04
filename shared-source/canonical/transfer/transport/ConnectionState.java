package org.peerlink.core.transport;

/**
 * Lifecycle states of a physical or virtual transport connection.
 */
public enum ConnectionState {
    CONNECTING,
    CONNECTED,
    CLOSING,
    CLOSED
}
