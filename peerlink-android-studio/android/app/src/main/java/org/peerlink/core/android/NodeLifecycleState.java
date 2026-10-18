package org.peerlink.core.android;

/**
 * Authoritative node lifecycle state machine distinguishing operational readiness
 * from peer discovery, authenticated connection, and active transfer execution.
 *
 * Implements Phase 1 requirements:
 * - STOPPED: Node is inactive; listeners and discovery loops are closed.
 * - STARTING: Node initialization has begun; persistent identity is loading.
 * - CHECKING_CAPABILITIES: Reconciling permissions, network interfaces, and keystore.
 * - RECOVERING: Reconciling operation journal and incomplete staging files (Rule 9).
 * - DISCOVERING: Active discovery adapters (NSD, Wi-Fi Direct) are scanning/advertising.
 * - READY: Active transfer listener is bound and ready for verified sharing routes.
 * - CONNECTED: Authenticated 3-way cryptographic session established with a peer.
 * - TRANSFERRING: Active chunked payload streaming with bounded memory backpressure.
 * - DEGRADED: Partial capability loss (e.g., mDNS failed but Wi-Fi Direct available, or Doze mode active).
 * - UNAVAILABLE: Fatal prerequisite failure (e.g. no network interfaces or missing storage permissions).
 * - STOPPING: Tear-down in progress; active transfers paused, discovery stopped, sockets closing.
 */
public enum NodeLifecycleState {
    STOPPED,
    STARTING,
    CHECKING_CAPABILITIES,
    RECOVERING,
    DISCOVERING,
    READY,
    CONNECTED,
    TRANSFERRING,
    DEGRADED,
    UNAVAILABLE,
    STOPPING;

    public boolean isOperational() {
        return this == READY || this == CONNECTED || this == TRANSFERRING || this == DISCOVERING || this == DEGRADED;
    }

    public boolean canAcceptTransfers() {
        return this == READY || this == CONNECTED || this == DISCOVERING;
    }

    public boolean isTransferring() {
        return this == TRANSFERRING;
    }

    public boolean isTerminalOrStopped() {
        return this == STOPPED || this == UNAVAILABLE;
    }
}
