package org.peerlink.desktop.storage;

import org.peerlink.core.event.NodeEvent;
import org.peerlink.core.event.NodeEventBus;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.SQLException;
import java.time.Instant;
import java.util.List;

/**
 * Executes startup recovery for the Desktop Local Node.
 *
 * <p>Recovery runs during every node start, after the database is open but before
 * accepting any new operations. The sequence follows the architecture document:
 *
 * <ol>
 *   <li>Open and verify SQLite (done by {@link LocalSqliteStorage} constructor).</li>
 *   <li>Run integrity check — if it fails, publish an event and abort startup.</li>
 *   <li>Inspect incomplete (non-terminal) operations.</li>
 *   <li>Mark all EXECUTING operations as OUTCOME_UNKNOWN to prevent blind replay.</li>
 *   <li>Log RECOVERY_REQUIRED operations (human intervention needed).</li>
 *   <li>Mark CREATED/VALIDATED operations as CANCELLED (never started — safe to discard).</li>
 *   <li>Record the last-startup timestamp in node metadata.</li>
 *   <li>Publish a {@link NodeEvent.RecoveryCompleted} event.</li>
 * </ol>
 *
 * <p>Design invariants enforced here:
 * <ul>
 *   <li>OUTCOME_UNKNOWN operations are never automatically replayed. The caller
 *       (or a future reconciliation pass) must explicitly reconcile each one.</li>
 *   <li>No destructive filesystem operations happen during recovery — only journal
 *       state is updated.</li>
 * </ul>
 */
public final class StartupRecoveryManager {
    private static final Logger log = LoggerFactory.getLogger(StartupRecoveryManager.class);

    private final LocalSqliteStorage storage;
    private final NodeEventBus eventBus;

    public StartupRecoveryManager(LocalSqliteStorage storage, NodeEventBus eventBus) {
        this.storage = storage;
        this.eventBus = eventBus;
    }

    /**
     * Run full startup recovery. Returns a {@link RecoveryReport} describing
     * what was found and what actions were taken.
     *
     * @param startupReason Human-readable reason for this startup (e.g., "clean start", "restart").
     * @throws StartupRecoveryException if a fatal condition is detected (integrity failure).
     */
    public RecoveryReport runRecovery(String startupReason) throws StartupRecoveryException {
        log.info("=== Startup recovery beginning: {} ===", startupReason);

        // Step 1: Integrity check
        boolean integrityOk;
        try {
            integrityOk = storage.checkIntegrity();
        } catch (SQLException e) {
            throw new StartupRecoveryException("Integrity check failed with SQL error", e);
        }

        if (!integrityOk) {
            long seq = eventBus.nextSequence();
            eventBus.publish(new NodeEvent.IntegrityCheckFailed(
                    seq, Instant.now(), storage.databasePath().toString(),
                    "SQLite integrity_check returned errors on startup"));
            throw new StartupRecoveryException("Database integrity check failed — node cannot start safely");
        }

        // Step 2: Find all interrupted (EXECUTING) operations
        List<OperationRecord> interrupted = storage.listInterruptedOperations();
        int markedUnknown = 0;

        if (!interrupted.isEmpty()) {
            log.warn("Found {} EXECUTING operation(s) at startup — marking OUTCOME_UNKNOWN", interrupted.size());
            storage.markInterruptedOperationsUnknown("Startup: " + startupReason);
            markedUnknown = interrupted.size();
            for (OperationRecord op : interrupted) {
                log.warn("  OUTCOME_UNKNOWN: {} [intent={}, idempotencyKey={}]",
                        op.getOperationId(), op.getIntent(), op.getIdempotencyKey());
            }
        }

        // Step 3: Count OUTCOME_UNKNOWN operations (may include ones from previous starts)
        List<OperationRecord> unknown = storage.listUnknownOutcomeOperations();
        if (!unknown.isEmpty()) {
            log.warn("{} operation(s) in OUTCOME_UNKNOWN state — require reconciliation before retry:", unknown.size());
            for (OperationRecord op : unknown) {
                log.warn("  OUTCOME_UNKNOWN: {} [intent={}]", op.getOperationId(), op.getIntent());
            }
        }

        // Step 4: Cancel pre-execution operations that were never started
        List<OperationRecord> preExecution = storage.listIncompleteOperations().stream()
                .filter(op -> op.getState() == OperationState.CREATED
                        || op.getState() == OperationState.VALIDATED
                        || op.getState() == OperationState.AUTHORIZED)
                .toList();

        int cancelled = 0;
        for (OperationRecord op : preExecution) {
            storage.updateState(op.getOperationId(), OperationState.CANCELLED);
            storage.appendNote(op.getOperationId(),
                    "Cancelled on startup — operation never reached EXECUTING stage. Reason: " + startupReason);
            cancelled++;
            log.info("Cancelled pre-execution operation: {} [intent={}]", op.getOperationId(), op.getIntent());
        }

        // Step 5: Log RECOVERY_REQUIRED operations
        List<OperationRecord> recoveryRequired = storage.listIncompleteOperations().stream()
                .filter(op -> op.getState() == OperationState.RECOVERY_REQUIRED)
                .toList();
        if (!recoveryRequired.isEmpty()) {
            log.error("{} operation(s) in RECOVERY_REQUIRED state — manual intervention may be needed:",
                    recoveryRequired.size());
            for (OperationRecord op : recoveryRequired) {
                log.error("  RECOVERY_REQUIRED: {} [intent={}]", op.getOperationId(), op.getIntent());
            }
        }

        // Step 6: Record startup timestamp in metadata
        storage.setMetadata("last_startup_utc_ms", String.valueOf(System.currentTimeMillis()));
        storage.setMetadata("last_startup_reason", startupReason);

        // Step 7: Publish recovery completed event
        String summary = String.format(
                "interrupted=%d markedUnknown=%d cancelled=%d recoveryRequired=%d unknownTotal=%d",
                interrupted.size(), markedUnknown, cancelled, recoveryRequired.size(), unknown.size());

        RecoveryReport report = new RecoveryReport(
                interrupted.size(), markedUnknown, cancelled,
                recoveryRequired.size(), unknown.size(), summary);

        eventBus.publish(new NodeEvent.RecoveryCompleted(
                eventBus.nextSequence(),
                Instant.now(),
                interrupted.size(),
                markedUnknown,
                0, // resumed — not yet implemented; placeholder for Phase 06
                summary));

        log.info("=== Startup recovery complete: {} ===", summary);
        return report;
    }

    /**
     * Immutable report produced by a recovery run.
     */
    public record RecoveryReport(
            int interruptedFound,
            int markedUnknown,
            int cancelledPreExecution,
            int recoveryRequiredCount,
            int totalUnknownOutcome,
            String summary
    ) {
        public boolean hasInterruptedWork() {
            return interruptedFound > 0 || totalUnknownOutcome > 0 || recoveryRequiredCount > 0;
        }
    }

    /**
     * Thrown when a fatal condition prevents safe node startup.
     */
    public static final class StartupRecoveryException extends Exception {
        public StartupRecoveryException(String message) { super(message); }
        public StartupRecoveryException(String message, Throwable cause) { super(message, cause); }
    }
}
