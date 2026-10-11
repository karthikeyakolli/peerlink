package org.peerlink.core.event;

import org.peerlink.core.operation.OperationState;

import java.time.Instant;

/**
 * A typed node-internal event.
 *
 * <p>Events are produced by the Local Node engine and consumed by subscribers
 * (IPC adapters, index updaters, diagnostics, etc.). Events are informational:
 * they do not grant authority or bypass policy.
 *
 * <p>Events are published after state changes are durable — never speculatively.
 */
public sealed interface NodeEvent permits
        NodeEvent.OperationStateChanged,
        NodeEvent.NodeLifecycleChanged,
        NodeEvent.RecoveryCompleted,
        NodeEvent.IntegrityCheckFailed,
        NodeEvent.ResourceLimitWarning {

    /** Unique sequential event number within this node session. */
    long sequenceNumber();

    /** UTC timestamp when the event was produced. */
    Instant timestamp();

    // ──────────────────────────────────────────────────────────────────────
    // Event subtypes
    // ──────────────────────────────────────────────────────────────────────

    /**
     * An operation transitioned to a new state.
     */
    record OperationStateChanged(
            long sequenceNumber,
            Instant timestamp,
            String operationId,
            OperationState previousState,
            OperationState newState,
            String note
    ) implements NodeEvent {}

    /**
     * The local node itself changed lifecycle state.
     */
    record NodeLifecycleChanged(
            long sequenceNumber,
            Instant timestamp,
            NodeLifecycleState lifecycleState,
            String reason
    ) implements NodeEvent {}

    /**
     * Startup recovery has completed. Reports the count of operations that
     * were found interrupted and what action was taken.
     */
    record RecoveryCompleted(
            long sequenceNumber,
            Instant timestamp,
            int interruptedOpsFound,
            int markedUnknown,
            int resumed,
            String summary
    ) implements NodeEvent {}

    /**
     * An SQLite integrity check found problems. The node has not self-repaired;
     * manual intervention or recovery may be required.
     */
    record IntegrityCheckFailed(
            long sequenceNumber,
            Instant timestamp,
            String databasePath,
            String details
    ) implements NodeEvent {}

    /**
     * A resource limit has been approached or exceeded.
     */
    record ResourceLimitWarning(
            long sequenceNumber,
            Instant timestamp,
            ResourceKind resourceKind,
            long currentValue,
            long limitValue,
            String details
    ) implements NodeEvent {}

    // ──────────────────────────────────────────────────────────────────────
    // Supporting enums
    // ──────────────────────────────────────────────────────────────────────

    enum NodeLifecycleState {
        STARTING,
        RECOVERY_IN_PROGRESS,
        RUNNING,
        STOPPING,
        STOPPED,
        FAULTED
    }

    enum ResourceKind {
        DATABASE_SIZE_BYTES,
        OPEN_OPERATIONS_COUNT,
        JOURNAL_ENTRIES_COUNT
    }
}
