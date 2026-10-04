package org.peerlink.core.backup;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Phase 13: Backup and Restore System Tests")
class BackupSystemTest {

    @TempDir
    Path tempDir;

    private Path sourceDir;
    private Path restoreDir;
    private InMemoryBackupTarget backupTarget;
    private BackupEngine backupEngine;

    @BeforeEach
    void setUp() throws IOException {
        sourceDir = tempDir.resolve("source");
        restoreDir = tempDir.resolve("restore");
        Files.createDirectories(sourceDir);
        Files.createDirectories(restoreDir);

        backupTarget = new InMemoryBackupTarget();
        backupEngine = new BackupEngine(backupTarget);
    }

    private Path createFile(Path dir, String relativePath, String content) throws IOException {
        Path target = dir.resolve(relativePath);
        if (target.getParent() != null) {
            Files.createDirectories(target.getParent());
        }
        Files.writeString(target, content, StandardCharsets.UTF_8);
        return target;
    }

    // ── 1. First Backup ──────────────────────────────────────────────────────

    @Test
    @DisplayName("1. First backup: Creates full snapshot manifest with all files and storage payloads")
    void testFirstBackup() throws IOException {
        createFile(sourceDir, "docs/readme.txt", "Hello PeerLink Backup");
        createFile(sourceDir, "data/file1.bin", "BinaryDataChunk1");
        createFile(sourceDir, "config.json", "{\"backup\":true}");

        BackupJobConfig config = new BackupJobConfig(
                "job_01", "DailyDocs", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest manifest = backupEngine.performBackup(config, BackupType.FULL);

        assertNotNull(manifest);
        assertEquals("job_01", manifest.getJobId());
        assertEquals(BackupType.FULL, manifest.getType());
        assertEquals(3, manifest.getTotalFiles());
        assertTrue(manifest.getTotalBytes() > 0);
        assertNull(manifest.getParentBackupId());
        assertFalse(manifest.isBlind());

        // Verify all 3 files exist on target storage
        for (HistoricalVersion item : manifest.getActiveItems()) {
            assertTrue(backupTarget.hasPayload(item.getStorageHash()), "Payload must exist in target repository");
            assertEquals(1, item.getVersionSequence(), "Initial version sequence must be 1");
            assertFalse(item.isDeleted());
        }
    }

    // ── 2. Incremental Backup ────────────────────────────────────────────────

    @Test
    @DisplayName("2. Incremental backup: Reuses existing unchanged storage hashes without duplicating payloads")
    void testIncrementalBackup() throws IOException {
        createFile(sourceDir, "file_a.txt", "Static content that does not change");
        createFile(sourceDir, "file_b.txt", "Initial content for file B");

        BackupJobConfig config = new BackupJobConfig(
                "job_inc", "IncrementalJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest bkp1 = backupEngine.performBackup(config, BackupType.FULL);
        long payloadCountAfterFull = backupTarget.listStoredPayloadHashes().size();
        assertEquals(2, payloadCountAfterFull);

        // Perform incremental backup with NO changes
        BackupManifest bkp2 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        assertEquals(bkp1.getBackupId(), bkp2.getParentBackupId(), "Incremental parent should point to bkp1");
        assertEquals(2, bkp2.getTotalFiles());

        HistoricalVersion a1 = bkp1.getItemByPath("file_a.txt").orElseThrow();
        HistoricalVersion a2 = bkp2.getItemByPath("file_a.txt").orElseThrow();

        assertEquals(a1.getStorageHash(), a2.getStorageHash(), "Storage hash must be reused");
        assertEquals(a1.getVersionSequence(), a2.getVersionSequence(), "Sequence must remain identical for unchanged file");
        assertEquals(payloadCountAfterFull, backupTarget.listStoredPayloadHashes().size(), "No new storage payload should be written");
    }

    // ── 3. Changed File ──────────────────────────────────────────────────────

    @Test
    @DisplayName("3. Changed file: Increments version sequence, writes new payload, retains old version in history")
    void testChangedFile() throws IOException {
        createFile(sourceDir, "notes.txt", "Version 1 Notes");

        BackupJobConfig config = new BackupJobConfig(
                "job_changed", "NotesJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest m1 = backupEngine.performBackup(config, BackupType.FULL);
        HistoricalVersion v1 = m1.getItemByPath("notes.txt").orElseThrow();
        assertEquals(1, v1.getVersionSequence());

        // Modify notes.txt
        createFile(sourceDir, "notes.txt", "Version 2 Notes Updated Content");
        BackupManifest m2 = backupEngine.performBackup(config, BackupType.INCREMENTAL);
        HistoricalVersion v2 = m2.getItemByPath("notes.txt").orElseThrow();

        assertEquals(2, v2.getVersionSequence(), "Version sequence must advance to 2");
        assertEquals(v1.getObjectId(), v2.getObjectId(), "Object identity must remain stable across edits");
        assertNotEquals(v1.getContentHash(), v2.getContentHash(), "Content hash must change");
        assertNotEquals(v1.getStorageHash(), v2.getStorageHash(), "Storage hash must change");

        // Old version v1 payload must still exist in target for historical recovery
        assertTrue(backupTarget.hasPayload(v1.getStorageHash()));
        assertTrue(backupTarget.hasPayload(v2.getStorageHash()));
    }

    // ── 4. Deleted File ──────────────────────────────────────────────────────

    @Test
    @DisplayName("4. Deleted file: Records deletion tombstone in incremental manifest while preserving past versions")
    void testDeletedFile() throws IOException {
        Path f1 = createFile(sourceDir, "keep.txt", "Keep me");
        Path f2 = createFile(sourceDir, "delete_me.txt", "I will be removed");

        BackupJobConfig config = new BackupJobConfig(
                "job_del", "DeleteJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest m1 = backupEngine.performBackup(config, BackupType.FULL);
        HistoricalVersion orig = m1.getItemByPath("delete_me.txt").orElseThrow();
        assertFalse(orig.isDeleted());

        // Delete the file from source
        Files.delete(f2);

        BackupManifest m2 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        assertEquals(1, m2.getTotalFiles(), "Active totalFiles count should be 1");
        HistoricalVersion delEntry = m2.getItemByPath("delete_me.txt").orElseThrow();
        assertTrue(delEntry.isDeleted(), "Item must be flagged as deleted in manifest");
        assertEquals(orig.getVersionSequence() + 1, delEntry.getVersionSequence(), "Deletion records advance sequence");

        // The previous payload for delete_me.txt must still be preserved in target storage
        assertTrue(backupTarget.hasPayload(orig.getStorageHash()));
    }

    // ── 5. Historical Restore creates NEW version ────────────────────────────

    @Test
    @DisplayName("5. Historical restore: Restores earlier content and creates a NEW current version (Never rewrite history)")
    void testHistoricalRestoreCreatesNewVersion() throws IOException {
        Path doc = createFile(sourceDir, "document.md", "# Original Title\nDraft 1 content");

        BackupJobConfig config = new BackupJobConfig(
                "job_doc", "DocJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest bkp1 = backupEngine.performBackup(config, BackupType.FULL);

        // Edit document multiple times
        createFile(sourceDir, "document.md", "# New Title\nDraft 2 content with changes");
        BackupManifest bkp2 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        createFile(sourceDir, "document.md", "# Ruined Title\nErroneous deletion in draft 3");
        BackupManifest bkp3 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        long currentSourceSeq = 3;

        // Plan historical restore from bkp1 (Draft 1) into restoreDir
        RestorePlan plan = backupEngine.planRestore(
                bkp1.getBackupId(), restoreDir, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null
        );

        RestoreExecutionResult result = backupEngine.executeRestore(plan, null, currentSourceSeq);

        assertTrue(result.success());
        assertEquals(1, result.restoredFilesCount());
        // RESTORE RULE: Restore creates a NEW current version sequence (e.g. 4), not rewinding to 1!
        assertEquals(4, result.newVersionSequenceCreated());

        String restoredText = Files.readString(restoreDir.resolve("document.md"));
        assertEquals("# Original Title\nDraft 1 content", restoredText);
    }

    // ── 6. Partial Backup ────────────────────────────────────────────────────

    @Test
    @DisplayName("6. Partial backup: Selects and stores only specified relative subpaths")
    void testPartialBackup() throws IOException {
        createFile(sourceDir, "included/target1.txt", "Target 1 payload");
        createFile(sourceDir, "included/target2.txt", "Target 2 payload");
        createFile(sourceDir, "ignored/other.txt", "Should not be backed up");

        BackupJobConfig config = new BackupJobConfig(
                "job_partial", "PartialJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest manifest = backupEngine.performPartialBackup(
                config, Set.of("included/target1.txt", "included/target2.txt")
        );

        assertEquals(2, manifest.getTotalFiles());
        assertTrue(manifest.getItemByPath("included/target1.txt").isPresent());
        assertTrue(manifest.getItemByPath("included/target2.txt").isPresent());
        assertFalse(manifest.getItemByPath("ignored/other.txt").isPresent());
    }

    // ── 7. Interrupted Backup ────────────────────────────────────────────────

    @Test
    @DisplayName("7. Interrupted backup: Fails cleanly without writing a corrupt or partial manifest to target")
    void testInterruptedBackup() throws IOException {
        Path f1 = createFile(sourceDir, "good.txt", "Fine file");
        Path f2 = createFile(sourceDir, "bad.txt", "Interrupted mid-stream");

        BackupJobConfig config = new BackupJobConfig(
                "job_interrupt", "InterruptJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        assertThrows(IOException.class, () -> backupEngine.simulateInterruptedBackup(config, f2));

        // Invariant: No half-baked manifest was registered under this job ID
        List<BackupManifest> manifests = backupTarget.listManifests("job_interrupt");
        assertTrue(manifests.isEmpty(), "No incomplete manifest should be saved on interruption");
    }

    // ── 8. Backup Verification ───────────────────────────────────────────────

    @Test
    @DisplayName("8. Backup verification: Confirms reconstructability and all payloads exist")
    void testBackupVerificationShallowAndDeep() throws IOException {
        createFile(sourceDir, "verified_a.txt", "Sample A content");
        createFile(sourceDir, "verified_b.txt", "Sample B content");

        BackupJobConfig config = new BackupJobConfig(
                "job_verify", "VerifyJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest manifest = backupEngine.performBackup(config, BackupType.FULL);

        // Shallow verification
        BackupVerificationReport shallow = backupEngine.verifyBackup(manifest.getBackupId(), false, null);
        assertTrue(shallow.passed());
        assertTrue(shallow.reconstructable());
        assertEquals(2, shallow.verifiedFiles());

        // Deep verification
        BackupVerificationReport deep = backupEngine.verifyBackup(manifest.getBackupId(), true, null);
        assertTrue(deep.passed());
        assertTrue(deep.reconstructable());
        assertTrue(deep.missingPayloads().isEmpty());
        assertTrue(deep.corruptedItems().isEmpty());
    }

    @Test
    @DisplayName("8b. Backup verification: Detects bitrot and missing chunks")
    void testBackupVerificationBitrotDetection() throws IOException {
        createFile(sourceDir, "file_tamper.txt", "Original clean data");

        BackupJobConfig config = new BackupJobConfig(
                "job_tamper", "TamperJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        BackupManifest manifest = backupEngine.performBackup(config, BackupType.FULL);
        HistoricalVersion item = manifest.getItemByPath("file_tamper.txt").orElseThrow();

        // Simulate bitrot on target storage by overwriting payload with corrupted bytes
        backupTarget.storePayload(item.getStorageHash(), "CORRUPTED BITROT DATA".getBytes(StandardCharsets.UTF_8));

        BackupVerificationReport report = backupEngine.verifyBackup(manifest.getBackupId(), true, null);
        assertFalse(report.passed(), "Verification must fail on bitrot");
        assertFalse(report.reconstructable());
        assertFalse(report.corruptedItems().isEmpty());
    }

    // ── 9. Retention & Garbage Collection ────────────────────────────────────

    @Test
    @DisplayName("9. Retention: Prunes older snapshots and garbage-collects unreferenced payloads")
    void testRetentionPolicyAndGarbageCollection() throws IOException {
        BackupJobConfig config = new BackupJobConfig(
                "job_ret", "RetentionJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(2), false, null, Set.of(), Set.of()
        );

        // Snapshot 1: unique file 1
        createFile(sourceDir, "old.txt", "Ephemeral ancient content 1");
        BackupManifest m1 = backupEngine.performBackup(config, BackupType.FULL);
        String oldPayloadHash = m1.getItemByPath("old.txt").orElseThrow().getStorageHash();

        // Snapshot 2: remove old.txt, add file 2
        Files.delete(sourceDir.resolve("old.txt"));
        createFile(sourceDir, "file2.txt", "Content 2");
        BackupManifest m2 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        // Snapshot 3: add file 3
        createFile(sourceDir, "file3.txt", "Content 3");
        BackupManifest m3 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        assertEquals(3, backupTarget.listManifests("job_ret").size());
        assertTrue(backupTarget.hasPayload(oldPayloadHash));

        // Run retention with keepLastN(2) -> m1 should be pruned, and oldPayloadHash collected
        VersionGarbageCollector.GcResult gcResult = backupEngine.runRetention("job_ret", RetentionPolicy.keepLastN(2));

        assertEquals(1, gcResult.prunedManifestsCount(), "Manifest 1 should be pruned");
        assertTrue(gcResult.deletedPayloadsCount() >= 1, "Unreferenced old payload should be garbage collected");

        // m1 is gone, m2 and m3 survive
        List<BackupManifest> surviving = backupTarget.listManifests("job_ret");
        assertEquals(2, surviving.size());
        assertEquals(m2.getBackupId(), surviving.get(0).getBackupId());
        assertEquals(m3.getBackupId(), surviving.get(1).getBackupId());

        // unreferenced payload is deleted
        assertFalse(backupTarget.hasPayload(oldPayloadHash), "Pruned payload should no longer exist");
    }

    // ── 10. Protected Version ────────────────────────────────────────────────

    @Test
    @DisplayName("10. Protected version: Protected snapshots and versions are immune to retention pruning")
    void testProtectedVersionImmunity() throws IOException {
        BackupJobConfig config = new BackupJobConfig(
                "job_prot", "ProtectedJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(1), false, null, Set.of(), Set.of()
        );

        createFile(sourceDir, "legal_hold.txt", "Important audit trail 2026");
        BackupManifest m1 = backupEngine.performBackup(config, BackupType.FULL);

        // Explicitly protect snapshot 1
        backupEngine.protectSnapshot(m1.getBackupId());
        assertTrue(backupEngine.isSnapshotProtected(m1.getBackupId()));

        createFile(sourceDir, "legal_hold.txt", "Updated text");
        BackupManifest m2 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        createFile(sourceDir, "legal_hold.txt", "Updated text v3");
        BackupManifest m3 = backupEngine.performBackup(config, BackupType.INCREMENTAL);

        // Retention policy specifies keepLastN(1).
        // Without protection, only m3 would be kept.
        // With protection, m1 MUST be kept alongside m3!
        VersionGarbageCollector.GcResult gc = backupEngine.runRetention("job_prot", RetentionPolicy.keepLastN(1));

        List<BackupManifest> surviving = backupTarget.listManifests("job_prot");
        assertTrue(surviving.stream().anyMatch(m -> m.getBackupId().equals(m1.getBackupId())),
                "Protected snapshot m1 must survive retention pruning");
        assertTrue(surviving.stream().anyMatch(m -> m.getBackupId().equals(m3.getBackupId())),
                "Latest snapshot m3 must survive");
    }

    // ── 11. Restore Conflict Policies ────────────────────────────────────────

    @Test
    @DisplayName("11a. Restore conflict: FAIL_ON_CONFLICT aborts without modifying existing target files")
    void testRestoreConflictFailOnConflict() throws IOException {
        createFile(sourceDir, "conflict.txt", "Backup snapshot content");
        BackupJobConfig config = new BackupJobConfig(
                "job_cnf", "ConflictJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );
        BackupManifest m1 = backupEngine.performBackup(config, BackupType.FULL);

        // Create conflicting local file in restoreDir
        createFile(restoreDir, "conflict.txt", "Locally modified differing content");

        RestorePlan plan = backupEngine.planRestore(
                m1.getBackupId(), restoreDir, RestoreConflictPolicy.FAIL_ON_CONFLICT, null
        );

        assertEquals(1, plan.conflicts().size());

        RestoreDryRunResult dryRun = backupEngine.dryRunRestore(plan);
        assertFalse(dryRun.canSucceed(), "Dry run must fail on conflict under FAIL_ON_CONFLICT");

        RestoreExecutionResult execution = backupEngine.executeRestore(plan, null, 1);
        assertFalse(execution.success(), "Execution must fail without overwriting");
        assertEquals(0, execution.restoredFilesCount());

        // File unchanged
        assertEquals("Locally modified differing content", Files.readString(restoreDir.resolve("conflict.txt")));
    }

    @Test
    @DisplayName("11b. Restore conflict: RESTORE_TO_ALTERNATIVE_PATH writes restored copy without overwriting")
    void testRestoreConflictAlternativePath() throws IOException {
        createFile(sourceDir, "asset.png", "OriginalBinaryData");
        BackupJobConfig config = new BackupJobConfig(
                "job_alt", "AltJob", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );
        BackupManifest m1 = backupEngine.performBackup(config, BackupType.FULL);

        createFile(restoreDir, "asset.png", "ExistingLocalDifferingData");

        RestorePlan plan = backupEngine.planRestore(
                m1.getBackupId(), restoreDir, RestoreConflictPolicy.RESTORE_TO_ALTERNATIVE_PATH, null
        );

        RestoreExecutionResult execution = backupEngine.executeRestore(plan, null, 1);
        assertTrue(execution.success());
        assertEquals(1, execution.restoredFilesCount());

        // Existing file preserved
        assertEquals("ExistingLocalDifferingData", Files.readString(restoreDir.resolve("asset.png")));

        // Restored file written to alternative path
        boolean alternativeFound = false;
        try (var stream = Files.list(restoreDir)) {
            for (Path p : stream.toList()) {
                if (p.getFileName().toString().startsWith("asset.png.restored.")) {
                    alternativeFound = true;
                    assertEquals("OriginalBinaryData", Files.readString(p));
                }
            }
        }
        assertTrue(alternativeFound, "Restored alternative file must exist");
    }

    // ── 12. Blind / Untrusted Target Behavior ────────────────────────────────

    @Test
    @DisplayName("12. Blind target: Stores only ciphertext; target lacks decryption authority; requires client key")
    void testBlindTargetBehavior() throws Exception {
        createFile(sourceDir, "secret_notes.txt", "CONFIDENTIAL TOP SECRET VAULT DATA");
        byte[] encryptionKey = BlindPayloadCipher.generateKey();

        BlindBackupTarget blindTarget = new BlindBackupTarget();
        BackupEngine blindEngine = new BackupEngine(blindTarget);

        BackupJobConfig blindConfig = new BackupJobConfig(
                "job_blind", "BlindBackup", sourceDir, "peer_untrusted_cloud",
                RetentionPolicy.keepLastN(5), true, encryptionKey, Set.of(), Set.of()
        );

        BackupManifest manifest = blindEngine.performBackup(blindConfig, BackupType.FULL);
        assertTrue(manifest.isBlind());

        HistoricalVersion item = manifest.getItemByPath("secret_notes.txt").orElseThrow();
        assertTrue(item.isEncrypted());

        // Inspect raw data stored in blind target: It MUST be ciphertext, never containing plaintext!
        byte[] storedBytes = blindTarget.retrievePayload(item.getStorageHash());
        String storedString = new String(storedBytes, StandardCharsets.ISO_8859_1);
        assertFalse(storedString.contains("CONFIDENTIAL"), "Stored payload on untrusted target must NOT contain plaintext");

        // Verify deep integrity using the client secret key
        BackupVerificationReport verify = blindEngine.verifyBackup(manifest.getBackupId(), true, encryptionKey);
        assertTrue(verify.passed());
        assertTrue(verify.reconstructable());

        // Deep verification with WRONG key fails
        byte[] wrongKey = BlindPayloadCipher.generateKey();
        BackupVerificationReport wrongVerify = blindEngine.verifyBackup(manifest.getBackupId(), true, wrongKey);
        assertFalse(wrongVerify.passed(), "Verification with wrong key must fail");

        // Restore to target directory with valid key
        RestorePlan plan = blindEngine.planRestore(
                manifest.getBackupId(), restoreDir, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null
        );
        RestoreExecutionResult restore = blindEngine.executeRestore(plan, encryptionKey, 1);
        assertTrue(restore.success());
        assertEquals("CONFIDENTIAL TOP SECRET VAULT DATA", Files.readString(restoreDir.resolve("secret_notes.txt")));

        // Attempting restore WITHOUT key fails
        Path failDir = tempDir.resolve("fail_restore");
        Files.createDirectories(failDir);
        RestorePlan failPlan = blindEngine.planRestore(
                manifest.getBackupId(), failDir, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null
        );
        RestoreExecutionResult failResult = blindEngine.executeRestore(failPlan, null, 1);
        assertFalse(failResult.success(), "Restore without key must fail");
    }
}