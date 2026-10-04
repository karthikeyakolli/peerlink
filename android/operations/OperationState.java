package org.peerlink.core.operation;

/**
 * PeerLink Operation Lifecycle states.
 * Transitions follow: INTENT -> EXECUTE -> VERIFY -> COMMIT -> FINALIZE
 */
public enum OperationState {
    CREATED,
    VALIDATED,
    AUTHORIZED,
    EXECUTING,
    WAITING,
    COMMITTED,
    FAILED,
    CANCELLED,
    OUTCOME_UNKNOWN,
    RECOVERY_REQUIRED;

    public boolean isTerminal() {
        return this == COMMITTED || this == FAILED || this == CANCELLED || this == OUTCOME_UNKNOWN || this == RECOVERY_REQUIRED;
    }
}
