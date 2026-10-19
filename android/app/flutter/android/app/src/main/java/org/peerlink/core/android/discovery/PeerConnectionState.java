package org.peerlink.core.android.discovery;

/**
 * State of a peer relative to the local node.
 * Distinguishes an unauthenticated discovered advertisement from an active,
 * cryptographically authenticated connection.
 */
public enum PeerConnectionState {
    /**
     * Peer was discovered via advertising/beaconing (mDNS, Wi-Fi Direct, Wi-Fi Aware),
     * but no authenticated cryptographic session is established.
     */
    DISCOVERED,

    /**
     * Handshake or connection attempt in progress.
     */
    CONNECTING,

    /**
     * Authenticated mutual Ed25519 cryptographic session established.
     */
    AUTHENTICATED_CONNECTED,

    /**
     * Peer was previously discovered or connected but has walked away or timed out.
     */
    LOST
}
