package org.peerlink.core.net.ice;

/**
 * Standard ICE candidate types as defined in RFC 8445.
 */
public enum CandidateType {
    /**
     * Local network interface candidate (e.g. LAN IP).
     */
    HOST(126),

    /**
     * Peer-reflexive candidate discovered during connectivity checks.
     */
    PRFLX(110),

    /**
     * Server-reflexive candidate allocated via STUN (public NAT mapping).
     */
    SRFLX(100),

    /**
     * Relayed candidate allocated via TURN server.
     */
    RELAY(0);

    private final int defaultPreference;

    CandidateType(int defaultPreference) {
        this.defaultPreference = defaultPreference;
    }

    public int getDefaultPreference() {
        return defaultPreference;
    }
}
