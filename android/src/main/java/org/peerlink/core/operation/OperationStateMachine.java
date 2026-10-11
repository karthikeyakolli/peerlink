package org.peerlink.core.operation;

import java.util.*;

/**
 * Validates and enforces operation lifecycle transitions.
 * Strict lifecycle sequence:
 * CREATED -> VALIDATED -> AUTHORIZED -> EXECUTING -> WAITING -> COMMITTED
 *
 * Terminal states: COMMITTED, FAILED, CANCELLED, OUTCOME_UNKNOWN, RECOVERY_REQUIRED.
 * Destructive operations cannot jump to COMMITTED without prior execution and verification.
 */
public final class OperationStateMachine {

    private static final Map<OperationState, Set<OperationState>> ALLOWED_TRANSITIONS = Map.of(
            OperationState.CREATED, Set.of(OperationState.VALIDATED, OperationState.CANCELLED, OperationState.FAILED),
            OperationState.VALIDATED, Set.of(OperationState.AUTHORIZED, OperationState.CANCELLED, OperationState.FAILED),
            OperationState.AUTHORIZED, Set.of(OperationState.EXECUTING, OperationState.CANCELLED, OperationState.FAILED),
            OperationState.EXECUTING, Set.of(OperationState.WAITING, OperationState.COMMITTED, OperationState.FAILED, OperationState.CANCELLED, OperationState.OUTCOME_UNKNOWN, OperationState.RECOVERY_REQUIRED),
            OperationState.WAITING, Set.of(OperationState.EXECUTING, OperationState.COMMITTED, OperationState.FAILED, OperationState.CANCELLED, OperationState.OUTCOME_UNKNOWN, OperationState.RECOVERY_REQUIRED),
            OperationState.COMMITTED, Collections.emptySet(),
            OperationState.FAILED, Collections.emptySet(),
            OperationState.CANCELLED, Collections.emptySet(),
            OperationState.OUTCOME_UNKNOWN, Set.of(OperationState.RECOVERY_REQUIRED, OperationState.FAILED, OperationState.COMMITTED),
            OperationState.RECOVERY_REQUIRED, Set.of(OperationState.EXECUTING, OperationState.FAILED, OperationState.CANCELLED)
    );

    private OperationStateMachine() {}

    public static boolean canTransition(OperationState from, OperationState to) {
        if (from == to) return true;
        Set<OperationState> targets = ALLOWED_TRANSITIONS.get(from);
        return targets != null && targets.contains(to);
    }

    public static void validateTransition(OperationState from, OperationState to) {
        if (!canTransition(from, to)) {
            throw new IllegalStateException("Illegal operation lifecycle transition from " + from + " to " + to);
        }
    }
}
