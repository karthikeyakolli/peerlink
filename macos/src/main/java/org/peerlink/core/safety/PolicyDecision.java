package org.peerlink.core.safety;

public enum PolicyDecision {
    PERMIT_COMMIT,
    REJECT_AND_DELETE,
    HOLD_IN_QUARANTINE_FOR_DECISION
}