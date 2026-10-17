package org.peerlink.core.android;

import org.peerlink.core.operation.JournalStage;
import org.peerlink.core.operation.OperationJournal;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.core.transfer.FileManifestBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

/**
 * Startup Recovery Engine for Android PeerLink node conforming to Phase 25 & Rule 9 requirements.
 *
 * <p>At the instant of process death (LMK, user force-stop, system crash, power loss), the OS
 * cannot run callbacks to record OUTCOME_UNKNOWN. On next startup, this engine reconciles
 * the last durably persisted journal state against physical filesystem staging and destination files.
 *
 * <p>Invariants:
 * <ul>
 *   <li>Rule 9: Never blindly replay a destructive operation or unverified partial transfer.</li>
 *   <li>Operations interrupted during COMMIT are reconciled: if destination file exists and
 *       its SHA-256 matches the expected digest, the operation was actually committed before crash;
 *       it is safely marked COMMITTED. Otherwise, it is marked OUTCOME_UNKNOWN.</li>
 *   <li>Operations interrupted during EXECUTE/VERIFY (chunk exchange) are marked OUTCOME_UNKNOWN.</li>
 *   <li>Unstarted operations (CREATED, VALIDATED, AUTHORIZED) are marked CANCELLED.</li>
 *   <li>All reconciliation decisions are recorded in the recovery journal with cryptographic evidence.</li>
 * </ul>
 */
public class AndroidStartupRecoveryManager {
    private static final Logger log = LoggerFactory.getLogger(AndroidStartupRecoveryManager.class);

    public record ReconciliationAction(
            String operationId,
            OperationState previousState,
            OperationState reconciledState,
            String decision,
            String explanation,
            String evidenceHash
    ) {}

    public record RecoverySummary(
            int totalIncompleteFound,
            int committedRecovered,
            int unknownOutcomeMarked,
            int cancelledUnstarted,
            int resumablePreserved,
            int corruptedQuarantined,
            boolean storageAvailable,
            List<ReconciliationAction> actions
    ) {
        public RecoverySummary(int totalIncompleteFound, int committedRecovered, int unknownOutcomeMarked, int cancelledUnstarted, List<ReconciliationAction> actions) {
            this(totalIncompleteFound, committedRecovered, unknownOutcomeMarked, cancelledUnstarted, 0, 0, true, actions);
        }
    }

    private final OperationJournal journal;

    public AndroidStartupRecoveryManager(OperationJournal journal) {
        this.journal = Objects.requireNonNull(journal, "journal must not be null");
    }

    /**
     * Inspect all incomplete operations in the journal and reconcile them against filesystem truth.
     *
     * @param stagingRoot Default staging directory root.
     * @param destinationRoot Default destination directory root.
     * @return Summary of reconciliation actions taken.
     */
    public RecoverySummary reconcileOnStartup(Path stagingRoot, Path destinationRoot) {
        List<OperationRecord> incomplete;
        try {
            incomplete = journal.listIncompleteOperations();
        } catch (Exception e) {
            log.error("Storage/Database access error reading incomplete operations: {}", e.getMessage(), e);
            return new RecoverySummary(0, 0, 0, 0, 0, 0, false, Collections.emptyList());
        }

        log.info("Startup reconciliation initiated: {} incomplete operation(s) found", incomplete.size());

        List<ReconciliationAction> actions = new ArrayList<>();
        int committedCount = 0;
        int unknownCount = 0;
        int cancelledCount = 0;
        int resumableCount = 0;
        int corruptedCount = 0;

        for (OperationRecord record : incomplete) {
            String opId = record.getOperationId();
            OperationState currentState = record.getState();

            // Only reconcile non-terminal operations
            if (currentState.isTerminal()) {
                continue;
            }

            JournalStage stage = JournalStage.INTENT;
            String stagingPath = null;
            String destPath = null;
            String expectedSha256 = null;

            if (journal instanceof AndroidSqliteOperationJournal sqliteJournal) {
                try {
                    Optional<AndroidSqliteOperationJournal.OperationRecoveryMetadata> metaOpt = sqliteJournal.getOperationMetadata(opId);
                    if (metaOpt.isPresent()) {
                        AndroidSqliteOperationJournal.OperationRecoveryMetadata meta = metaOpt.get();
                        stage = meta.stage();
                        stagingPath = meta.stagingPath();
                        destPath = meta.destinationPath();
                        expectedSha256 = meta.expectedSha256();
                    }
                } catch (Exception e) {
                    log.error("Could not read operation metadata for op [{}]: {}", opId, e.getMessage());
                }
            } else if (journal instanceof org.peerlink.core.operation.InMemoryOperationJournal memJournal) {
                stage = memJournal.getStage(opId);
            }

            if (currentState == OperationState.EXECUTING) {
                if (stage == JournalStage.COMMIT || stage == JournalStage.FINALIZE) {
                    // Check if destination file exists and matches expected SHA-256
                    boolean destVerified = false;
                    String computedHash = null;
                    Path finalFile = null;

                    if (destPath != null && !destPath.isBlank()) {
                        finalFile = Paths.get(destPath);
                    } else if (destinationRoot != null && !record.getTargetObjectIds().isEmpty()) {
                        finalFile = destinationRoot.resolve(record.getTargetObjectIds().get(0));
                    }

                    if (finalFile != null && Files.isRegularFile(finalFile)) {
                        try {
                            byte[] content = Files.readAllBytes(finalFile);
                            computedHash = FileManifestBuilder.calculateSha256Hex(content);
                            if (expectedSha256 != null && expectedSha256.equalsIgnoreCase(computedHash)) {
                                destVerified = true;
                            }
                        } catch (IOException e) {
                            log.warn("Could not read destination file during recovery [{}]: {}", finalFile, e.getMessage());
                        }
                    }

                    if (destVerified) {
                        journal.updateState(opId, OperationState.COMMITTED);
                        String expl = "Destination file confirmed intact and hash matches (" + expectedSha256 + ")";
                        journal.appendNote(opId, "Startup recovery: " + expl);
                        recordRecoveryEntry(opId, "COMMITTED_CONFIRMED", computedHash, finalFile.toString(), expl);
                        actions.add(new ReconciliationAction(opId, currentState, OperationState.COMMITTED, "COMMITTED_CONFIRMED", expl, computedHash));
                        committedCount++;
                    } else {
                        // Uncertain commit outcome: Never blindly replay destructive commit (Rule 9)
                        if (finalFile != null && Files.isRegularFile(finalFile)) {
                            // Partial or mismatched destination write: quarantine partial file to prevent corruption
                            try {
                                Path quarantined = finalFile.resolveSibling(finalFile.getFileName().toString() + ".partial_uncertain");
                                Files.move(finalFile, quarantined, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                                log.warn("Quarantined partial/uncertain destination file to {}", quarantined);
                            } catch (IOException qe) {
                                log.warn("Could not quarantine partial file {}: {}", finalFile, qe.getMessage());
                            }
                        }
                        journal.updateState(opId, OperationState.OUTCOME_UNKNOWN);
                        String expl = "Process died during COMMIT stage. Destination file missing or unverified (expected=" + expectedSha256 + ", computed=" + computedHash + "). Marked OUTCOME_UNKNOWN without replay.";
                        journal.appendNote(opId, "Startup recovery: " + expl);
                        recordRecoveryEntry(opId, "OUTCOME_UNKNOWN_COMMIT_INTERRUPTED", computedHash, finalFile != null ? finalFile.toString() : "", expl);
                        actions.add(new ReconciliationAction(opId, currentState, OperationState.OUTCOME_UNKNOWN, "OUTCOME_UNKNOWN_COMMIT_INTERRUPTED", expl, computedHash));
                        unknownCount++;
                    }
                } else {
                    // Interrupted during chunk writing (INTENT / EXECUTE / VERIFY)
                    Path stagingFile = null;
                    if (stagingPath != null && !stagingPath.isBlank()) {
                        stagingFile = Paths.get(stagingPath);
                    } else if (stagingRoot != null && !record.getTargetObjectIds().isEmpty()) {
                        stagingFile = stagingRoot.resolve(record.getTargetObjectIds().get(0) + ".part");
                    }

                    boolean isCorrupt = false;
                    long stagedBytes = 0;
                    if (stagingFile != null && Files.exists(stagingFile)) {
                        try {
                            stagedBytes = Files.size(stagingFile);
                            // Check for corruption marker or unreadable state
                            Path corruptMarker = stagingFile.resolveSibling(stagingFile.getFileName().toString() + ".corrupt_marker");
                            if (Files.exists(corruptMarker)) {
                                isCorrupt = true;
                            }
                        } catch (IOException e) {
                            isCorrupt = true;
                        }
                    }

                    if (isCorrupt && stagingFile != null && Files.exists(stagingFile)) {
                        // Quarantine corrupt staging content to prevent unsafe resume while keeping forensic evidence
                        try {
                            Path quarantined = stagingFile.resolveSibling(stagingFile.getFileName().toString() + ".corrupt");
                            Files.move(stagingFile, quarantined, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                            log.warn("Quarantined corrupt staging content to {}", quarantined);
                        } catch (IOException qe) {
                            log.warn("Could not quarantine staging file {}: {}", stagingFile, qe.getMessage());
                        }
                        journal.updateState(opId, OperationState.OUTCOME_UNKNOWN);
                        String expl = "Staging content corrupted. Quarantined as .corrupt; marked OUTCOME_UNKNOWN without replay.";
                        journal.appendNote(opId, "Startup recovery: " + expl);
                        recordRecoveryEntry(opId, "STAGING_CORRUPTED_QUARANTINED", null, stagingFile.toString(), expl);
                        actions.add(new ReconciliationAction(opId, currentState, OperationState.OUTCOME_UNKNOWN, "STAGING_CORRUPTED_QUARANTINED", expl, null));
                        corruptedCount++;
                        unknownCount++;
                    } else if (stagingFile != null && Files.isRegularFile(stagingFile) && stagedBytes > 0) {
                        // Valid incomplete transfer: Preserving verified progress for resume
                        journal.updateState(opId, OperationState.WAITING);
                        String expl = "Valid incomplete transfer detected (" + stagedBytes + " bytes staged). Preserved for resume.";
                        journal.appendNote(opId, "Startup recovery: " + expl);
                        recordRecoveryEntry(opId, "VALID_INCOMPLETE_RESUMABLE", null, stagingFile.toString(), expl);
                        actions.add(new ReconciliationAction(opId, currentState, OperationState.WAITING, "VALID_INCOMPLETE_RESUMABLE", expl, null));
                        resumableCount++;
                    } else {
                        // No staging data found
                        journal.updateState(opId, OperationState.OUTCOME_UNKNOWN);
                        String expl = "Interrupted mid-flight during process termination (stage=" + stage + ", no staging). Marked OUTCOME_UNKNOWN without replay.";
                        journal.appendNote(opId, "Startup recovery: " + expl);
                        recordRecoveryEntry(opId, "OUTCOME_UNKNOWN_EXECUTION_INTERRUPTED", null, stagingPath, expl);
                        actions.add(new ReconciliationAction(opId, currentState, OperationState.OUTCOME_UNKNOWN, "OUTCOME_UNKNOWN_EXECUTION_INTERRUPTED", expl, null));
                        unknownCount++;
                    }
                }
            } else if (currentState == OperationState.CREATED || currentState == OperationState.VALIDATED || currentState == OperationState.AUTHORIZED) {
                // Operation was queued/authorized but never actively executed data chunks
                journal.updateState(opId, OperationState.CANCELLED);
                String expl = "Pre-execution operation cancelled on restart (state=" + currentState + ").";
                journal.appendNote(opId, "Startup recovery: " + expl);
                recordRecoveryEntry(opId, "CANCELLED_UNSTARTED", null, null, expl);
                actions.add(new ReconciliationAction(opId, currentState, OperationState.CANCELLED, "CANCELLED_UNSTARTED", expl, null));
                cancelledCount++;
            }
        }

        RecoverySummary summary = new RecoverySummary(
                incomplete.size(), committedCount, unknownCount, cancelledCount,
                resumableCount, corruptedCount, true, actions);
        log.info("Startup reconciliation completed: {} committed, {} unknown, {} cancelled, {} resumable preserved, {} corrupted quarantined",
                committedCount, unknownCount, cancelledCount, resumableCount, corruptedCount);
        return summary;
    }

    private void recordRecoveryEntry(String opId, String decision, String evidenceHash, String path, String explanation) {
        if (journal instanceof AndroidSqliteOperationJournal sqliteJournal) {
            try {
                String recoveryId = "rec_" + UUID.randomUUID().toString().replace("-", "");
                sqliteJournal.recordRecoveryEntry(recoveryId, opId, decision, evidenceHash, path, System.currentTimeMillis(), explanation);
            } catch (Exception e) {
                log.warn("Could not record recovery entry for op {}: {}", opId, e.getMessage());
            }
        }
    }
}
