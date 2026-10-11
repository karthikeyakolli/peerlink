package org.peerlink.desktop.storage;

import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;

/**
 * Reconciliation framework for the Desktop Local Node.
 *
 * <p>Reconciliation is how the engine resolves uncertain operational states
 * without performing blind replay. It is invoked:
 * <ul>
 *   <li>During startup recovery for OUTCOME_UNKNOWN operations.</li>
 *   <li>After a peer reconnects, to reconcile in-flight work interrupted by
 *       a network disconnect.</li>
 *   <li>Periodically, to detect stale or orphaned journal entries.</li>
 * </ul>
 *
 * <p>Phase 05 scope: this framework establishes the structure and contract.
 * The actual peer-query and filesystem-check reconciliation logic is
 * implemented in Phase 06 (transfer reliability). All unknown operations
 * currently receive RECONCILIATION_PENDING classification pending that work.
 *
 * <p>Design rules:
 * <ul>
 *   <li>A destructive operation must NEVER be replayed if its outcome is
 *       uncertain without first querying the counterparty and/or filesystem.</li>
 *   <li>Reconciliation produces a decision per operation — it does not
 *       automatically apply that decision. The engine applies it under policy.</li>
 * </ul>
 */
public final class ReconciliationFramework {
    private static final Logger log = LoggerFactory.getLogger(ReconciliationFramework.class);

    /** The decision produced for each operation during reconciliation. */
    public enum ReconciliationDecision {
        /**
         * The operation was confirmed committed on both sides.
         * Can be finalized and removed from active tracking.
         */
        CONFIRMED_COMMITTED,

        /**
         * The operation was confirmed as not committed on either side.
         * It is safe to retry or cancel.
         */
        CONFIRMED_NOT_COMMITTED,

        /**
         * Outcome could not be determined (peer offline, no filesystem evidence).
         * Must remain in OUTCOME_UNKNOWN state until a future reconciliation pass.
         */
        RECONCILIATION_PENDING,

        /**
         * The operation's outcome is conflicted — partial state found on one side
         * but not the other. Requires explicit conflict resolution before retry.
         */
        CONFLICT_DETECTED,

        /**
         * The operation is orphaned — no active context, peer unreachable,
         * and no filesystem evidence. Safe to mark RECOVERY_REQUIRED.
         */
        ORPHANED
    }

    /**
     * A reconciliation result for a single operation.
     */
    public record ReconciliationResult(
            String operationId,
            ReconciliationDecision decision,
            String explanation
    ) {}

    private final LocalSqliteStorage storage;

    public ReconciliationFramework(LocalSqliteStorage storage) {
        this.storage = storage;
    }

    /**
     * Evaluate all OUTCOME_UNKNOWN operations and produce reconciliation
     * decisions. In Phase 05, all unknown operations are classified as
     * RECONCILIATION_PENDING because peer-query and filesystem-check
     * infrastructure is not yet available.
     *
     * <p>Phase 06 will replace this with actual peer-query logic.
     */
    public List<ReconciliationResult> reconcileUnknownOperations() {
        List<OperationRecord> unknown = storage.listUnknownOutcomeOperations();
        List<ReconciliationResult> results = new ArrayList<>();

        for (OperationRecord op : unknown) {
            ReconciliationResult result = classifyUnknownOperation(op);
            results.add(result);
            log.info("Reconciliation [{}]: {} — {}", op.getOperationId(), result.decision(), result.explanation());
        }

        if (unknown.isEmpty()) {
            log.debug("No OUTCOME_UNKNOWN operations to reconcile");
        }
        return results;
    }

    /**
     * Apply a reconciliation decision to the journal. This is the only place
     * where OUTCOME_UNKNOWN → COMMITTED or OUTCOME_UNKNOWN → CANCELLED
     * transitions are permitted.
     */
    public void applyDecision(String operationId, ReconciliationDecision decision, String note) {
        switch (decision) {
            case CONFIRMED_COMMITTED ->
                storage.updateState(operationId, OperationState.COMMITTED);

            case CONFIRMED_NOT_COMMITTED ->
                storage.updateState(operationId, OperationState.CANCELLED);

            case ORPHANED ->
                storage.updateState(operationId, OperationState.RECOVERY_REQUIRED);

            case CONFLICT_DETECTED, RECONCILIATION_PENDING -> {
                // No state change — leave in OUTCOME_UNKNOWN, append a note
                log.warn("Operation {} remains OUTCOME_UNKNOWN: {}", operationId, decision);
            }
        }
        storage.appendNote(operationId, "Reconciliation decision: " + decision + " — " + note);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Private — classification logic (Phase 05: all PENDING)
    // ──────────────────────────────────────────────────────────────────────────

    private ReconciliationResult classifyUnknownOperation(OperationRecord op) {
        // Phase 05: no peer connectivity or filesystem probe available.
        // All unknown operations are pending until Phase 06 provides the infrastructure.
        return new ReconciliationResult(
                op.getOperationId(),
                ReconciliationDecision.RECONCILIATION_PENDING,
                "Peer-query and filesystem-check not yet available (Phase 05 scope). " +
                "Operation will be reconciled when peer reconnects in Phase 06.");
    }
}
