package org.peerlink.core.operation;

/**
 * The durable sequence of stages within a single operation execution.
 *
 * <p>The journal stage tracks progress through the commit model so crash recovery
 * can determine exactly where work was interrupted:
 * <pre>
 *   INTENT → EXECUTE → VERIFY → COMMIT → FINALIZE
 * </pre>
 *
 * <p>These are orthogonal to {@link OperationState}: state captures the
 * authoritative lifecycle state (CREATED, EXECUTING, COMMITTED, …), while
 * stage tracks what step of the work pipeline was last durably recorded.
 */
public enum JournalStage {
    /**
     * The operation intent has been recorded. No real work has started yet.
     * Safe to cancel or discard without side effects.
     */
    INTENT,

    /**
     * Execution has begun. Resources may have been allocated or partially
     * written. A crash at this stage leaves partial state that must be
     * reconciled on recovery.
     */
    EXECUTE,

    /**
     * Execution complete; verification (hash checks, policy checks, etc.)
     * is in progress or complete. Side effects are complete but not yet
     * durably committed.
     */
    VERIFY,

    /**
     * The operation outcome has been atomically committed. Object mappings,
     * indexes and state are updated. This is the point of no return for
     * target-side state.
     */
    COMMIT,

    /**
     * Post-commit cleanup complete: temporary files removed, events fired,
     * history updated. The operation is fully resolved.
     */
    FINALIZE;

    /** True if this stage indicates that side-effects have begun. */
    public boolean hasSideEffects() {
        return this == EXECUTE || this == VERIFY || this == COMMIT || this == FINALIZE;
    }

    /** True if the operation is past the point-of-no-return. */
    public boolean isPastCommit() {
        return this == COMMIT || this == FINALIZE;
    }
}
