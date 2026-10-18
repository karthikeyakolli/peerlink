package org.peerlink.core.audit;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.access.PathSandboxValidator;
import org.peerlink.core.backup.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.safety.QuarantineRecord;
import org.peerlink.core.safety.QuarantineZone;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

public class AuditDefectsRegressionTest {

    @TempDir
    Path tempDir;

    private Path restoreTargetDir;
    private Path quarantineDir;
    private Path destinationDir;

    @BeforeEach
    void setUp() throws IOException {
        restoreTargetDir = tempDir.resolve("restore_target");
        quarantineDir = tempDir.resolve("quarantine");
        destinationDir = tempDir.resolve("destination");

        Files.createDirectories(restoreTargetDir);
        Files.createDirectories(quarantineDir);
        Files.createDirectories(destinationDir);
    }

    @Test
    @DisplayName("Audit Defect 1: RestoreExecutor must reject relative paths escaping targetDirectory")
    void testRestoreExecutorPathTraversalRejected() throws Exception {
        byte[] payload = "malicious payload".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(payload);

        InMemoryBackupTarget target = new InMemoryBackupTarget();
        target.storePayload(hash.getHexString(), payload);

        ObjectIdentity objId = ObjectIdentity.generate();
        HistoricalVersion maliciousItem = new HistoricalVersion(
                objId,
                "../../escaped_secret.txt",
                hash,
                payload.length,
                1,
                System.currentTimeMillis(),
                false,
                hash.getHexString(),
                false,
                false
        );

        RestorePlan plan = new RestorePlan(
                "bkp_1",
                restoreTargetDir,
                RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION,
                Map.of(objId.getValue(), maliciousItem),
                List.of(),
                payload.length,
                false
        );

        RestoreExecutionResult result = RestoreExecutor.execute(plan, target, null, 100);

        // Outside file must NOT exist
        Path outsideFile = tempDir.resolve("escaped_secret.txt");
        assertFalse(Files.exists(outsideFile), "RestoreExecutor must NOT write outside targetDirectory!");
        // The restore must have failed or recorded error
        assertFalse(result.success(), "Restore should be marked as failure on traversal attempt");
        assertFalse(result.errors().isEmpty(), "Errors list should report traversal attempt");
    }

    @Test
    @DisplayName("Audit Defect 2: QuarantineZone commitFile must reject relative paths escaping destination")
    void testQuarantineZoneCommitPathTraversalRejected() throws Exception {
        QuarantineZone zone = new QuarantineZone(quarantineDir);
        byte[] payload = "test data".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(payload);

        QuarantineRecord record = zone.stageInbound(payload, "../../escaped_q.txt", hash, "peer_attacker");

        assertThrows(SecurityException.class, () -> {
            zone.commitFile(record, destinationDir);
        }, "QuarantineZone.commitFile must throw SecurityException on path traversal");

        Path outsideFile = tempDir.resolve("escaped_q.txt");
        assertFalse(Files.exists(outsideFile), "File must not be committed outside destination directory");
    }

    @Test
    @DisplayName("Audit Defect 3: PathSandboxValidator must reject non-existent paths through symlinked directories")
    void testPathSandboxValidatorIntermediateSymlinkToOutside() throws Exception {
        Path outsideDir = tempDir.resolve("outside_system");
        Path shareRoot = tempDir.resolve("share_root");
        Files.createDirectories(outsideDir);
        Files.createDirectories(shareRoot);

        Path symlinkDir = shareRoot.resolve("sym_dir");
        try {
            Files.createSymbolicLink(symlinkDir, outsideDir);
        } catch (UnsupportedOperationException | IOException e) {
            // If OS/filesystem does not support symlink creation in test environment, skip symlink test
            return;
        }

        PathSandboxValidator validator = new PathSandboxValidator(true);

        // Child does not exist yet!
        assertThrows(PathSandboxValidator.PathTraversalException.class, () -> {
            validator.resolveAndValidate(shareRoot, "sym_dir/non_existent_child.txt");
        }, "PathSandboxValidator must reject non-existent child inside symlinked external directory");
    }

    @Test
    @DisplayName("Audit Defect 4: BackupEngine partial backup must reject path traversal")
    void testBackupEnginePartialBackupPathTraversalRejected() throws Exception {
        Path sourceDir = tempDir.resolve("source");
        Files.createDirectories(sourceDir);

        // Put a sensitive file outside source
        Path outsideSecret = tempDir.resolve("secret.key");
        Files.writeString(outsideSecret, "super_secret_key");

        InMemoryBackupTarget target = new InMemoryBackupTarget();
        BackupEngine engine = new BackupEngine(target);
        BackupJobConfig config = new BackupJobConfig(
                "job_1", "test_job", sourceDir, "target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        assertThrows(SecurityException.class, () -> {
            engine.performPartialBackup(config, Set.of("../../secret.key"));
        }, "BackupEngine.performPartialBackup must throw SecurityException on path traversal attempt");
    }

    // ── Section D: Audit Hash Chain & Self-Healing Safety Tests ──────────────

    @Test
    @DisplayName("Audit Hash Chain: Valid unbroken sequence and links verify successfully")
    void testAuditHashChainValidVerification() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        log.append("SHARE_CREATED", "peer_local", "op_1", "hash_meta_1");
        log.append("TRANSFER_START", "peer_remote", "op_2", "hash_meta_2");
        log.append("TRANSFER_COMPLETE", "peer_remote", "op_2", "hash_meta_3");

        VerifiableAuditLog.AuditIntegrityReport report = log.verifyIntegrity();
        assertTrue(report.isValid(), "Intact audit chain must pass integrity verification");
        assertEquals(3, report.verifiedCount());
        assertNotNull(report.tipHash());
        assertNull(report.failureReason());
    }

    @Test
    @DisplayName("Audit Hash Chain: Detects record deletion or sequence truncation")
    void testAuditHashChainDetectsDeletionOrTruncation() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        log.append("EVENT_1", "peer_local", "op_1", "meta_1");
        log.append("EVENT_2", "peer_local", "op_2", "meta_2");
        log.append("EVENT_3", "peer_local", "op_3", "meta_3");

        // Attacker creates a modified copy with EVENT_2 deleted
        List<VerifiableAuditLog.VerifiableAuditRecord> records = new ArrayList<>(log.getRecords());
        records.remove(1); // delete sequence 2

        VerifiableAuditLog tamperedLog = new VerifiableAuditLog();
        // Insert tampered list into private chain using reflection
        try {
            var field = VerifiableAuditLog.class.getDeclaredField("chain");
            field.setAccessible(true);
            var internalChain = (List<VerifiableAuditLog.VerifiableAuditRecord>) field.get(tamperedLog);
            internalChain.addAll(records);
        } catch (Exception e) {
            fail("Reflection setup failed: " + e.getMessage());
        }

        VerifiableAuditLog.AuditIntegrityReport report = tamperedLog.verifyIntegrity();
        assertFalse(report.isValid(), "Audit chain with deleted middle record must fail verification");
        assertTrue(report.failureReason().contains("Sequence discontinuity") || report.failureReason().contains("broken"));
    }

    @Test
    @DisplayName("Audit Hash Chain: Detects record reordering")
    void testAuditHashChainDetectsReordering() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        log.append("EVENT_1", "peer_local", "op_1", "meta_1");
        log.append("EVENT_2", "peer_local", "op_2", "meta_2");

        List<VerifiableAuditLog.VerifiableAuditRecord> records = new ArrayList<>(log.getRecords());
        // Swap 0 and 1
        Collections.swap(records, 0, 1);

        VerifiableAuditLog reorderedLog = new VerifiableAuditLog();
        try {
            var field = VerifiableAuditLog.class.getDeclaredField("chain");
            field.setAccessible(true);
            var internalChain = (List<VerifiableAuditLog.VerifiableAuditRecord>) field.get(reorderedLog);
            internalChain.addAll(records);
        } catch (Exception e) {
            fail("Reflection setup failed: " + e.getMessage());
        }

        VerifiableAuditLog.AuditIntegrityReport report = reorderedLog.verifyIntegrity();
        assertFalse(report.isValid(), "Reordered audit records must fail verification");
    }

    @Test
    @DisplayName("Audit Hash Chain: Detects unauthorized metadata rewriting")
    void testAuditHashChainDetectsRewriting() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        log.append("AUTHENTIC_EVENT", "peer_local", "op_1", "meta_original");

        VerifiableAuditLog.VerifiableAuditRecord original = log.getRecords().get(0);
        // Tamper with eventType while keeping hashes same
        VerifiableAuditLog.VerifiableAuditRecord tampered = new VerifiableAuditLog.VerifiableAuditRecord(
                original.sequenceNumber(), original.timestampUtcMs(), "TAMPERED_EVENT",
                original.actorPeerId(), original.operationId(), original.metadataDigest(),
                original.previousHash(), original.recordHash()
        );

        VerifiableAuditLog tamperedLog = new VerifiableAuditLog();
        try {
            var field = VerifiableAuditLog.class.getDeclaredField("chain");
            field.setAccessible(true);
            var internalChain = (List<VerifiableAuditLog.VerifiableAuditRecord>) field.get(tamperedLog);
            internalChain.add(tampered);
        } catch (Exception e) {
            fail("Reflection setup failed: " + e.getMessage());
        }

        VerifiableAuditLog.AuditIntegrityReport report = tamperedLog.verifyIntegrity();
        assertFalse(report.isValid(), "Modified metadata must invalidate hash signature");
        assertTrue(report.failureReason().contains("hash signature invalid"));
    }

    @Test
    @DisplayName("Audit Defect: Burn-After-Read log excludes sensitive plaintext or keys")
    void testBurnAfterReadAuditLogMinimization() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        VerifiableAuditLog.VerifiableAuditRecord record = log.logBurnAfterReadErasure(
                "xfer_confidential", "peer_bob", "VIEWER_DISMISSED"
        );

        assertEquals("BURN_AFTER_READ_ERASED", record.eventType());
        assertEquals("peer_bob", record.actorPeerId());
        // Metadata is a non-reversible SHA-256 digest
        assertNotNull(record.metadataDigest());
        assertEquals(64, record.metadataDigest().length());
        assertFalse(record.metadataDigest().contains("confidential"));
    }

    @Test
    @DisplayName("Self-Healing: Retry connection rate limiter prevents transport flooding")
    void testRetryConnectionRateLimiting() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        String peerId = "peer_test_node";

        // First attempt allowed
        assertTrue(log.canRetryConnection(peerId, 1000), "Initial retry should be allowed");
        // Immediate second attempt blocked (within 1000ms window)
        assertFalse(log.canRetryConnection(peerId, 1000), "Immediate retry flood must be blocked");
    }

    @Test
    @DisplayName("Self-Healing: OUTCOME_UNKNOWN prohibits replay without remote state reconciliation")
    void testOutcomeUnknownReplayProtection() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        String opId = "op_unconfirmed_xfer";

        // Without reconciliation, replay must be rejected
        assertFalse(log.canReplayOutcomeUnknown(opId, false),
                "Destructive replay must be prohibited when remote outcome is unconfirmed");

        // After successful reconciliation, replay decision is authorized
        assertTrue(log.canReplayOutcomeUnknown(opId, true),
                "Replay authorized once state has been explicitly reconciled with remote peer");
    }

    @Test
    @DisplayName("Self-Healing: Quarantine cleanup preserves active transfers and valid chunks")
    void testQuarantineCleanupPreservesActiveData() {
        VerifiableAuditLog log = new VerifiableAuditLog();
        long now = System.currentTimeMillis();

        var entryActive = new VerifiableAuditLog.QuarantineFileEntry("1", "staging/active.bin",
                VerifiableAuditLog.QuarantineStatus.ACTIVE_TRANSFER_STAGING, now);
        var entryValidChunks = new VerifiableAuditLog.QuarantineFileEntry("2", "staging/chunks.part",
                VerifiableAuditLog.QuarantineStatus.VALID_STAGED_CHUNKS, now);
        var entryCorrupt = new VerifiableAuditLog.QuarantineFileEntry("3", "quarantine/corrupt.exe",
                VerifiableAuditLog.QuarantineStatus.CORRUPTED, now - 500000);
        var entryExpired = new VerifiableAuditLog.QuarantineFileEntry("4", "quarantine/expired.tmp",
                VerifiableAuditLog.QuarantineStatus.EXPIRED, now - 900000);

        List<VerifiableAuditLog.QuarantineFileEntry> allEntries = List.of(entryActive, entryValidChunks, entryCorrupt, entryExpired);
        List<VerifiableAuditLog.QuarantineFileEntry> safeToDelete = log.filterForQuarantineCleanup(allEntries);

        assertEquals(2, safeToDelete.size(), "Only corrupted and expired items may be pruned");
        assertTrue(safeToDelete.contains(entryCorrupt));
        assertTrue(safeToDelete.contains(entryExpired));
        assertFalse(safeToDelete.contains(entryActive), "Active transfer staging must NEVER be deleted");
        assertFalse(safeToDelete.contains(entryValidChunks), "Valid staged chunks must NEVER be deleted");
    }
}
