package org.peerlink.desktop.storage;

import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.nio.file.Files;
import java.nio.file.Path;
import java.io.IOException;
import java.security.MessageDigest;

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
 * <p>Design rules:
 * <ul>
 *   <li>A destructive operation must NEVER be replayed if its outcome is
 *       uncertain without first querying the counterparty and/or filesystem.</li>
 *   <li>Reconciliation produces a decision per operation — it does not
 *       automatically apply that decision. The engine applies it under policy.</li>
 *   <li>Database transactions CANNOT span filesystem operations. Multi-stage journal
 *       reconciliation bridges the SQLite-filesystem consistency boundary.</li>
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
         * but not the other, or content hash mismatch. Requires explicit conflict resolution.
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
     * decisions.
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
     * Reconciles the boundary between SQLite and the filesystem for a specific operation.
     * Never relies on SQLite transaction boundaries to assume filesystem atomicity.
     *
     * @param operationId The operation under evaluation.
     * @param targetPath The destination filesystem path that should have been modified/created.
     * @param expectedSha256 Expected SHA-256 hash of the committed file content.
     * @return ReconciliationResult containing evidence-based decision and explanation.
     */
    public ReconciliationResult reconcileFilesystemBoundary(String operationId, Path targetPath, String expectedSha256) {
        if (targetPath == null || !Files.exists(targetPath)) {
            return new ReconciliationResult(
                    operationId,
                    ReconciliationDecision.CONFIRMED_NOT_COMMITTED,
                    "Target filesystem path does not exist: " + targetPath + ". Mutation was never completed."
            );
        }

        try {
            byte[] fileBytes = Files.readAllBytes(targetPath);
            String actualSha256 = sha256Hex(fileBytes);
            if (expectedSha256 != null && !expectedSha256.isBlank()) {
                if (actualSha256.equalsIgnoreCase(expectedSha256)) {
                    return new ReconciliationResult(
                            operationId,
                            ReconciliationDecision.CONFIRMED_COMMITTED,
                            "Filesystem target exists and matches expected content hash (" + actualSha256 + ")."
                    );
                } else {
                    return new ReconciliationResult(
                            operationId,
                            ReconciliationDecision.CONFLICT_DETECTED,
                            "Filesystem content mismatch: found hash " + actualSha256 + ", expected " + expectedSha256
                    );
                }
            } else {
                return new ReconciliationResult(
                        operationId,
                        ReconciliationDecision.CONFIRMED_COMMITTED,
                        "Filesystem target exists and is readable (" + fileBytes.length + " bytes)."
                );
            }
        } catch (IOException e) {
            return new ReconciliationResult(
                    operationId,
                    ReconciliationDecision.CONFLICT_DETECTED,
                    "I/O error reading filesystem target during reconciliation: " + e.getMessage()
            );
        }
    }

    /**
     * Apply a reconciliation decision to the journal. This is the only place
     * where OUTCOME_UNKNOWN → COMMITTED or OUTCOME_UNKNOWN → CANCELLED
     * transitions are permitted.
     */
    public void applyDecision(String operationId, ReconciliationDecision decision, String note) {
        String recoveryId = "rec-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8);
        switch (decision) {
            case CONFIRMED_COMMITTED -> {
                storage.updateState(operationId, OperationState.COMMITTED);
                storage.recordRecoveryEntry(recoveryId, operationId, decision.name(), null, null,
                        System.currentTimeMillis(), note);
            }

            case CONFIRMED_NOT_COMMITTED -> {
                storage.updateState(operationId, OperationState.CANCELLED);
                storage.recordRecoveryEntry(recoveryId, operationId, decision.name(), null, null,
                        System.currentTimeMillis(), note);
            }

            case ORPHANED, CONFLICT_DETECTED -> {
                storage.updateState(operationId, OperationState.RECOVERY_REQUIRED);
                storage.recordRecoveryEntry(recoveryId, operationId, decision.name(), null, null,
                        System.currentTimeMillis(), note);
            }

            case RECONCILIATION_PENDING -> {
                // No state change — leave in OUTCOME_UNKNOWN, append a note
                log.warn("Operation {} remains OUTCOME_UNKNOWN: {}", operationId, decision);
            }
        }
        storage.appendNote(operationId, "Reconciliation decision: " + decision + " — " + note);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ──────────────────────────────────────────────────────────────────────────

    private ReconciliationResult classifyUnknownOperation(OperationRecord op) {
        return new ReconciliationResult(
                op.getOperationId(),
                ReconciliationDecision.RECONCILIATION_PENDING,
                "Awaiting counterparty query or filesystem boundary probe for operation " + op.getOperationId());
    }

    private static String sha256Hex(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(data);
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }
}
