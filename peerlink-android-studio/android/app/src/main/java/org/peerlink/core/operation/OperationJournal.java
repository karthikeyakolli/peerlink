package org.peerlink.core.operation;

import java.util.List;
import java.util.Optional;

/**
 * Authoritative operation journal contract.
 *
 * <p>The journal is the durable record of all in-flight and completed operations.
 * It is the authority for recovering interrupted state after a crash or restart.
 *
 * <p>Invariants:
 * <ul>
 *   <li>An operation_id is globally unique and immutable once created.</li>
 *   <li>Duplicate submissions are detected via idempotency_key. Implementations
 *       must reject or deduplicate a second submission for the same key.</li>
 *   <li>A terminal state (COMMITTED, FAILED, CANCELLED, OUTCOME_UNKNOWN,
 *       RECOVERY_REQUIRED) cannot be overwritten by a non-terminal state.</li>
 *   <li>Unknown outcome must never result in blind replay — the caller must
 *       explicitly query and reconcile before retrying destructive operations.</li>
 * </ul>
 */
public interface OperationJournal {

    /**
     * Persist a new operation record. Must be idempotent for the same operationId.
     *
     * @throws DuplicateOperationException if a different operation already occupies
     *         the same idempotency_key.
     */
    void recordOperation(OperationRecord record);

    /**
     * Advance an operation to a new state. The transition must be valid per the
     * operation state machine.
     *
     * @throws IllegalStateTransitionException if the transition is forbidden.
     */
    void updateState(String operationId, OperationState newState);

    /**
     * Update a journal stage marker (INTENT, EXECUTE, VERIFY, COMMIT, FINALIZE).
     * Used to track progress through the durable operation sequence so that crash
     * recovery can identify exactly where work was interrupted.
     */
    void recordJournalStage(String operationId, JournalStage stage);

    /** Retrieve a single operation by its durable ID. */
    Optional<OperationRecord> getOperation(String operationId);

    /**
     * Return all operations not in a terminal state. Used during startup recovery
     * to find work interrupted by a crash or abrupt shutdown.
     */
    List<OperationRecord> listIncompleteOperations();

    /**
     * Return all operations currently in EXECUTING state — these were actively
     * running when the process died and require specific crash-recovery handling.
     */
    List<OperationRecord> listInterruptedOperations();

    /**
     * Return all operations in OUTCOME_UNKNOWN state — these require reconciliation
     * before any retry is permitted.
     */
    List<OperationRecord> listUnknownOutcomeOperations();

    /**
     * Check whether an idempotency key is already registered for a different
     * operation_id (duplicate submission detection).
     */
    Optional<String> findOperationByIdempotencyKey(String idempotencyKey);

    /**
     * Append a human-readable diagnostic note to a journal entry without changing
     * state. Used for crash markers, reconciliation notes, etc.
     */
    void appendNote(String operationId, String note);

    /**
     * Mark all currently EXECUTING operations as OUTCOME_UNKNOWN. Called during
     * startup to prevent blind replay of operations whose outcome is uncertain.
     */
    void markInterruptedOperationsUnknown(String reason);
}
