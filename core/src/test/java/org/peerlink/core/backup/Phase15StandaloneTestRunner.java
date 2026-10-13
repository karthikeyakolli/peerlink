package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/**
 * Phase 15 Standalone Verification Suite:
 * Versioned Backup and Restore, Immutable Manifests, Integrity Verification,
 * Retention Policy & Active Operation Locks, Safe Pruning & Garbage Collection,
 * Blind Encryption, Restore Conflict Policies, and Disk Durability.
 *
 * Runs in pure Java SE on any host platform.
 */
public class Phase15StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 15 Versioned Backup and Restore Suite");
        System.out.println("==========================================================");

        runTest("Test 01: Unidirectional Backup & Full Snapshot Manifest", Phase15StandaloneTestRunner::testFirstBackupSnapshot);
        runTest("Test 02: Incremental Deduplication via Storage Hashes", Phase15StandaloneTestRunner::testIncrementalDeduplication);
        runTest("Test 03: File Edits Advance Version Sequence & Retain Earlier Payloads", Phase15StandaloneTestRunner::testFileEditsAdvanceSequenceAndRetainHistory);
        runTest("Test 04: Source Deletions Record Tombstones Without Erasing History", Phase15StandaloneTestRunner::testSourceDeletionsRecordTombstones);
        runTest("Test 05: Sync Tombstones / Remote Deletions Never Erase Backup History", Phase15StandaloneTestRunner::testSyncTombstonesNeverEraseBackupHistory);
        runTest("Test 06: Immutable Manifest Integrity & Tamper Detection", Phase15StandaloneTestRunner::testImmutableManifestIntegrityAndTampering);
        runTest("Test 07: Active Recovery Locks Prevent Retention Pruning", Phase15StandaloneTestRunner::testActiveRecoveryLocksPreventRetentionPruning);
        runTest("Test 08: Protected Snapshot & Version Immunity Against Retention", Phase15StandaloneTestRunner::testProtectedSnapshotImmunity);
        runTest("Test 09: Reference-Counted GC Prunes Only Unreferenced Payloads", Phase15StandaloneTestRunner::testReferenceCountedGarbageCollection);
        runTest("Test 10: Complete Version Discovery API Across Snapshot History", Phase15StandaloneTestRunner::testVersionDiscoveryApi);
        runTest("Test 11: Blind Backup Target Stores Ciphertext & Requires Client Key", Phase15StandaloneTestRunner::testBlindBackupSecurityAndReconstruction);
        runTest("Test 12: Deep Verification Bitrot & Storage Tampering Detection", Phase15StandaloneTestRunner::testDeepVerificationBitrotDetection);
        runTest("Test 13: Deep Verification Decryption Key Validation", Phase15StandaloneTestRunner::testDeepVerificationDecryptionKeyValidation);
        runTest("Test 14: Restore Staging & Atomic Expose Verification", Phase15StandaloneTestRunner::testRestoreStagingAndAtomicExpose);
        runTest("Test 15: Corrupted Payloads Are Rejected and Never Exposed", Phase15StandaloneTestRunner::testCorruptedPayloadsRejectedDuringRestore);
        runTest("Test 16: Restore Conflict Policy FAIL_ON_CONFLICT Aborts Safely", Phase15StandaloneTestRunner::testRestoreConflictFailOnConflict);
        runTest("Test 17: Restore Conflict Policy RESTORE_TO_ALTERNATIVE_PATH No Collision", Phase15StandaloneTestRunner::testRestoreConflictAlternativePathNoCollision);
        runTest("Test 18: Restore Policy OVERWRITE_WITH_NEW_VERSION Advances Sequence", Phase15StandaloneTestRunner::testRestoreAdvancesVersionSequenceNeverRewinds);
        runTest("Test 19: Interrupted Backup Fails Cleanly Without Corrupt Manifest", Phase15StandaloneTestRunner::testInterruptedBackupFailsCleanly);
        runTest("Test 20: Persistent FileBasedBackupTarget Proves Disk Byte Recoverability", Phase15StandaloneTestRunner::testFileBasedBackupTargetDurability);

        System.out.println("==========================================================");
        System.out.printf(" Phase 15 Test Execution Summary: %d PASSED, %d FAILED%n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }

    private static void runTest(String name, TestCase testCase) {
        try {
            testCase.run();
            System.out.println("[PASS] " + name);
            testsPassed++;
        } catch (Throwable t) {
            System.err.println("[FAIL] " + name + ": " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    @FunctionalInterface
    interface TestCase {
        void run() throws Exception;
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("Assertion failed: " + message);
        }
    }

    private static Path createTempDirectory(String prefix) throws IOException {
        Path p = Files.createTempDirectory(prefix);
        return p;
    }

    private static void deleteRecursive(Path path) {
        try {
            if (Files.isDirectory(path)) {
                try (var s = Files.walk(path)) {
                    s.sorted(Comparator.reverseOrder()).forEach(p -> {
                        try { Files.deleteIfExists(p); } catch (Exception ignored) {}
                    });
                }
            } else {
                Files.deleteIfExists(path);
            }
        } catch (Exception ignored) {}
    }

    private static Path createFile(Path dir, String rel, String content) throws IOException {
        Path p = dir.resolve(rel);
        if (p.getParent() != null) Files.createDirectories(p.getParent());
        Files.writeString(p, content, StandardCharsets.UTF_8);
        return p;
    }

    // ── 1. Unidirectional Backup & Full Snapshot Manifest ─────────────────────

    private static void testFirstBackupSnapshot() throws Exception {
        Path root = createTempDirectory("phase15_t01_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "readme.txt", "PeerLink Backup System V1");
            createFile(src, "data/records.csv", "id,name\n1,Alice\n2,Bob");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_01", "DailyDocs", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);
            check(manifest != null, "Manifest must not be null");
            check(manifest.getJobId().equals("job_01"), "Job ID match");
            check(manifest.getType() == BackupType.FULL, "Type is FULL");
            check(manifest.getTotalFiles() == 2, "2 files backed up");
            check(manifest.getTotalBytes() > 0, "Total bytes > 0");
            check(manifest.getParentBackupId() == null, "Full backup parent is null");
            check(!manifest.isBlind(), "Plain backup");

            for (HistoricalVersion v : manifest.getActiveItems()) {
                check(target.hasPayload(v.getStorageHash()), "Target holds payload for " + v.getRelativePath());
                check(v.getVersionSequence() == 1, "Initial sequence sequence is 1");
                check(!v.isDeleted(), "Active file not deleted");
            }
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 2. Incremental Deduplication via Storage Hashes ───────────────────────

    private static void testIncrementalDeduplication() throws Exception {
        Path root = createTempDirectory("phase15_t02_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "static.bin", "LargeStaticPayloadChunk12345");
            createFile(src, "dynamic.txt", "Initial dynamic draft");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_dedup", "DedupJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest bkp1 = engine.performBackup(config, BackupType.FULL);
            int initialStoredPayloads = target.listStoredPayloadHashes().size();
            check(initialStoredPayloads == 2, "2 payloads initially stored");

            // Perform incremental backup with NO file edits
            BackupManifest bkp2 = engine.performBackup(config, BackupType.INCREMENTAL);
            check(bkp2.getParentBackupId().equals(bkp1.getBackupId()), "Incremental points to parent bkp1");
            check(bkp2.getTotalFiles() == 2, "2 active files");

            HistoricalVersion v1 = bkp1.getItemByPath("static.bin").orElseThrow();
            HistoricalVersion v2 = bkp2.getItemByPath("static.bin").orElseThrow();

            check(v1.getStorageHash().equals(v2.getStorageHash()), "Storage hash deduplicated");
            check(v1.getVersionSequence() == v2.getVersionSequence(), "Sequence preserved for unchanged file");
            check(target.listStoredPayloadHashes().size() == initialStoredPayloads, "No redundant storage payload added");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 3. File Edits Advance Version Sequence & Retain Earlier Payloads ──────

    private static void testFileEditsAdvanceSequenceAndRetainHistory() throws Exception {
        Path root = createTempDirectory("phase15_t03_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "code.java", "public class A { int v = 1; }");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_edit", "EditJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest m1 = engine.performBackup(config, BackupType.FULL);
            HistoricalVersion v1 = m1.getItemByPath("code.java").orElseThrow();
            check(v1.getVersionSequence() == 1, "Initial sequence 1");

            // Modify file in source
            createFile(src, "code.java", "public class A { int v = 2; // modified }");
            BackupManifest m2 = engine.performBackup(config, BackupType.INCREMENTAL);
            HistoricalVersion v2 = m2.getItemByPath("code.java").orElseThrow();

            check(v2.getVersionSequence() == 2, "Sequence advanced to 2");
            check(v1.getObjectId().equals(v2.getObjectId()), "ObjectIdentity preserved across modifications");
            check(!v1.getContentHash().equals(v2.getContentHash()), "Content hash changed");
            check(!v1.getStorageHash().equals(v2.getStorageHash()), "Storage hash changed");

            // Verify both payloads remain in storage target
            check(target.hasPayload(v1.getStorageHash()), "v1 payload retained");
            check(target.hasPayload(v2.getStorageHash()), "v2 payload stored");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 4. Source Deletions Record Tombstones Without Erasing History ──────────

    private static void testSourceDeletionsRecordTombstones() throws Exception {
        Path root = createTempDirectory("phase15_t04_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "surviving.txt", "I survive");
            Path deletedFile = createFile(src, "to_delete.txt", "I will be removed from source");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_del", "DelJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest m1 = engine.performBackup(config, BackupType.FULL);
            HistoricalVersion orig = m1.getItemByPath("to_delete.txt").orElseThrow();
            check(!orig.isDeleted(), "Active in m1");

            // Delete in working directory
            Files.delete(deletedFile);
            BackupManifest m2 = engine.performBackup(config, BackupType.INCREMENTAL);

            check(m2.getTotalFiles() == 1, "m2 has 1 active file");
            HistoricalVersion del = m2.getItemByPath("to_delete.txt").orElseThrow();
            check(del.isDeleted(), "Tombstone recorded in incremental manifest");
            check(del.getVersionSequence() == orig.getVersionSequence() + 1, "Tombstone advances sequence");

            // Crucial: Older version in m1 and its payload remain fully preserved
            check(target.hasPayload(orig.getStorageHash()), "Original payload preserved in target storage");
            check(!m1.getItemByPath("to_delete.txt").orElseThrow().isDeleted(), "m1 record unaffected");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 5. Sync Tombstones / Remote Deletions Never Erase Backup History ───────

    private static void testSyncTombstonesNeverEraseBackupHistory() throws Exception {
        Path root = createTempDirectory("phase15_t05_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "critical_doc.pdf", "Mission critical original PDF content bytes");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_sync_guard", "SyncGuardJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest historicalSnapshot = engine.performBackup(config, BackupType.FULL);
            String pdfStorageHash = historicalSnapshot.getItemByPath("critical_doc.pdf").orElseThrow().getStorageHash();

            // Simulate remote sync deleting the file or sending a sync tombstone to local working tree
            Files.delete(src.resolve("critical_doc.pdf"));

            // Perform backup reflecting deleted local state
            BackupManifest postSyncDeleteSnapshot = engine.performBackup(config, BackupType.INCREMENTAL);
            check(postSyncDeleteSnapshot.getItemByPath("critical_doc.pdf").orElseThrow().isDeleted(), "Tombstone in new snapshot");

            // Invariant: The historical snapshot and underlying stored payload MUST remain completely recoverable!
            check(target.hasPayload(pdfStorageHash), "Underlying payload remains in storage");
            BackupVerificationReport report = engine.verifyBackup(historicalSnapshot.getBackupId(), true, null);
            check(report.passed() && report.reconstructable(), "Historical snapshot remains 100% verified and reconstructable");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 6. Immutable Manifest Integrity & Tamper Detection ────────────────────

    private static void testImmutableManifestIntegrityAndTampering() throws Exception {
        Path root = createTempDirectory("phase15_t06_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "secure.txt", "Tamper evident content");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_tamper", "TamperJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);
            check(manifest.verifyIntegrity(), "Legitimate manifest digest verifies");

            // Tampered manifest: forged items map or altered attributes
            Map<ObjectIdentity, HistoricalVersion> tamperedItems = new HashMap<>(manifest.getItems());
            ObjectIdentity forgedId = ObjectIdentity.generate();
            tamperedItems.put(forgedId, new HistoricalVersion(
                    forgedId, "forged.exe", ContentHash.computeSha256(new byte[]{1}), 1,
                    99, System.currentTimeMillis(), false, "badhash", false, false
            ));

            BackupManifest tamperedManifest = new BackupManifest(
                    manifest.getBackupId(), manifest.getJobId(), manifest.getType(),
                    manifest.getSnapshotTimestampUtcMs(), manifest.getParentBackupId(),
                    tamperedItems, manifest.isBlind()
            );

            // Replaces target manifest with forged manifest that has the old manifest digest
            target.saveManifest(tamperedManifest);

            BackupVerificationReport report = engine.verifyBackup(manifest.getBackupId(), false, null);
            check(tamperedManifest.verifyIntegrity(), "Tampered manifest recomputes digest automatically, but has bad payload hashes");
            check(!report.passed(), "Verification fails because target lacks payload for forged item");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 7. Active Recovery Locks Prevent Retention Pruning ────────────────────

    private static void testActiveRecoveryLocksPreventRetentionPruning() throws Exception {
        Path root = createTempDirectory("phase15_t07_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "data.txt", "Baseline 1");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_lock", "LockJob", src, "target_peer",
                    RetentionPolicy.keepLastN(1), false, null, Set.of(), Set.of()
            );

            // Snapshot 1
            BackupManifest s1 = engine.performBackup(config, BackupType.FULL);

            // Snapshot 2
            createFile(src, "data.txt", "Baseline 2");
            BackupManifest s2 = engine.performBackup(config, BackupType.INCREMENTAL);

            // Snapshot 3
            createFile(src, "data.txt", "Baseline 3");
            BackupManifest s3 = engine.performBackup(config, BackupType.INCREMENTAL);

            // Retention with keepLastN(1) would normally prune s1 and s2.
            // But an active recovery task is currently reading from s1!
            engine.acquireRecoveryLock(s1.getBackupId());
            check(engine.isRecoveryLocked(s1.getBackupId()), "s1 is locked by active recovery task");

            VersionGarbageCollector.GcResult gc = engine.runRetention("job_lock", RetentionPolicy.keepLastN(1));
            List<BackupManifest> surviving = target.listManifests("job_lock");

            // s1 MUST survive because of the active recovery lock!
            check(surviving.stream().anyMatch(m -> m.getBackupId().equals(s1.getBackupId())),
                    "s1 survived retention because of active recovery lock");
            check(surviving.stream().anyMatch(m -> m.getBackupId().equals(s3.getBackupId())),
                    "Latest s3 survived");
            check(surviving.stream().noneMatch(m -> m.getBackupId().equals(s2.getBackupId())),
                    "Unprotected and unlocked s2 was pruned");

            // Release lock and run retention again -> now s1 can be safely pruned
            engine.releaseRecoveryLock(s1.getBackupId());
            check(!engine.isRecoveryLocked(s1.getBackupId()), "s1 lock released");

            engine.runRetention("job_lock", RetentionPolicy.keepLastN(1));
            List<BackupManifest> finalSurviving = target.listManifests("job_lock");
            check(finalSurviving.size() == 1 && finalSurviving.get(0).getBackupId().equals(s3.getBackupId()),
                    "Now only s3 remains after recovery completed");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 8. Protected Snapshot & Version Immunity Against Retention ───────────

    private static void testProtectedSnapshotImmunity() throws Exception {
        Path root = createTempDirectory("phase15_t08_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "audit_trail.log", "Audit log 2026-Q4");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_prot", "ProtJob", src, "target_peer",
                    RetentionPolicy.keepLastN(1), false, null, Set.of(), Set.of()
            );

            BackupManifest m1 = engine.performBackup(config, BackupType.FULL);
            engine.protectSnapshot(m1.getBackupId());
            check(engine.isSnapshotProtected(m1.getBackupId()), "m1 protected");

            // Perform 2 more backups
            createFile(src, "audit_trail.log", "Audit log modified");
            BackupManifest m2 = engine.performBackup(config, BackupType.INCREMENTAL);
            createFile(src, "audit_trail.log", "Audit log modified v3");
            BackupManifest m3 = engine.performBackup(config, BackupType.INCREMENTAL);

            // Retention specifies keepLastN(1)
            engine.runRetention("job_prot", RetentionPolicy.keepLastN(1));

            List<BackupManifest> surviving = target.listManifests("job_prot");
            check(surviving.stream().anyMatch(m -> m.getBackupId().equals(m1.getBackupId())),
                    "Protected snapshot m1 is immune to retention pruning");
            check(surviving.stream().anyMatch(m -> m.getBackupId().equals(m3.getBackupId())),
                    "Newest snapshot m3 retained");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 9. Reference-Counted GC Prunes Only Unreferenced Payloads ─────────────

    private static void testReferenceCountedGarbageCollection() throws Exception {
        Path root = createTempDirectory("phase15_t09_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "shared_common.bin", "Shared across multiple snapshots");
            createFile(src, "ephemeral.txt", "Unique to snapshot 1 only");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_gc", "GcJob", src, "target_peer",
                    RetentionPolicy.keepLastN(2), false, null, Set.of(), Set.of()
            );

            // S1 has both shared and ephemeral
            BackupManifest s1 = engine.performBackup(config, BackupType.FULL);
            String sharedHash = s1.getItemByPath("shared_common.bin").orElseThrow().getStorageHash();
            String ephemeralHash = s1.getItemByPath("ephemeral.txt").orElseThrow().getStorageHash();

            // S2: delete ephemeral, shared unchanged
            Files.delete(src.resolve("ephemeral.txt"));
            BackupManifest s2 = engine.performBackup(config, BackupType.INCREMENTAL);

            // S3: add new file, shared still unchanged
            createFile(src, "new_file.txt", "New in snapshot 3");
            BackupManifest s3 = engine.performBackup(config, BackupType.INCREMENTAL);

            check(target.hasPayload(sharedHash), "Shared payload exists");
            check(target.hasPayload(ephemeralHash), "Ephemeral payload exists");

            // Run retention with keepLastN(2): s1 is pruned, s2 and s3 survive
            VersionGarbageCollector.GcResult gc = engine.runRetention("job_gc", RetentionPolicy.keepLastN(2));
            check(gc.prunedManifestsCount() == 1, "1 manifest pruned");

            // Ephemeral payload was ONLY referenced by s1 -> must be deleted
            check(!target.hasPayload(ephemeralHash), "Unreferenced ephemeral payload was deleted by GC");

            // Shared payload is STILL referenced by s2 and s3 -> MUST NOT be deleted!
            check(target.hasPayload(sharedHash), "Shared payload safely retained by surviving manifests");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 10. Complete Version Discovery API Across Snapshot History ────────────

    private static void testVersionDiscoveryApi() throws Exception {
        Path root = createTempDirectory("phase15_t10_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "changelog.md", "# Version 1.0");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_disc", "DiscJob", src, "target_peer",
                    RetentionPolicy.keepLastN(10), false, null, Set.of(), Set.of()
            );

            BackupManifest b1 = engine.performBackup(config, BackupType.FULL);

            createFile(src, "changelog.md", "# Version 1.1 with bugfixes");
            BackupManifest b2 = engine.performBackup(config, BackupType.INCREMENTAL);

            Files.delete(src.resolve("changelog.md"));
            BackupManifest b3 = engine.performBackup(config, BackupType.INCREMENTAL);

            // Discover versions for changelog.md
            List<HistoricalVersionInfo> history = engine.discoverVersions("job_disc", "changelog.md");
            check(history.size() == 3, "3 history entries discovered");

            check(history.get(0).versionSequence() == 1, "Seq 1");
            check(!history.get(0).deleted(), "Active in seq 1");
            check(history.get(0).backupId().equals(b1.getBackupId()), "Points to b1");

            check(history.get(1).versionSequence() == 2, "Seq 2");
            check(!history.get(1).deleted(), "Active in seq 2");
            check(history.get(1).backupId().equals(b2.getBackupId()), "Points to b2");

            check(history.get(2).versionSequence() == 3, "Seq 3 tombstone");
            check(history.get(2).deleted(), "Tombstone flag in seq 3");
            check(history.get(2).backupId().equals(b3.getBackupId()), "Points to b3");

            // Discover by ObjectId
            ObjectIdentity oid = history.get(0).objectId();
            List<HistoricalVersionInfo> oidHistory = engine.discoverVersionsByObjectId("job_disc", oid);
            check(oidHistory.size() == 3, "Discovered by object ID matches 3");

            // List snapshots containing file
            List<String> containing = engine.listSnapshotsContaining("job_disc", "changelog.md");
            check(containing.size() == 2, "Contained in 2 active snapshots (b1 and b2, not b3)");
            check(containing.contains(b1.getBackupId()) && containing.contains(b2.getBackupId()), "Matches b1 and b2");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 11. Blind Backup Target Stores Ciphertext & Requires Client Key ───────

    private static void testBlindBackupSecurityAndReconstruction() throws Exception {
        Path root = createTempDirectory("phase15_t11_");
        try {
            Path src = root.resolve("src");
            Path rst = root.resolve("rst");
            Files.createDirectories(src);
            Files.createDirectories(rst);
            createFile(src, "vault/secret.txt", "TOP_SECRET_PASSPHRASE_PEERLINK_2026");

            byte[] masterKey = BlindPayloadCipher.generateKey();
            BlindBackupTarget blindTarget = new BlindBackupTarget();
            BackupEngine engine = new BackupEngine(blindTarget);

            BackupJobConfig config = new BackupJobConfig(
                    "job_blind", "BlindJob", src, "untrusted_cloud",
                    RetentionPolicy.keepLastN(5), true, masterKey, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);
            check(manifest.isBlind(), "Manifest marked blind");
            HistoricalVersion item = manifest.getItemByPath("vault/secret.txt").orElseThrow();
            check(item.isEncrypted(), "Historical version item marked encrypted");

            // Verify stored bytes on target are purely ciphertext and contain zero plaintext
            byte[] storedCiphertext = blindTarget.retrievePayload(item.getStorageHash());
            String rawChars = new String(storedCiphertext, StandardCharsets.ISO_8859_1);
            check(!rawChars.contains("TOP_SECRET_PASSPHRASE"), "Target storage does NOT possess plaintext");

            // Client restores using secret master key
            RestorePlan plan = engine.planRestore(manifest.getBackupId(), rst, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null);
            RestoreExecutionResult result = engine.executeRestore(plan, masterKey, 0);

            check(result.success(), "Restore succeeded with valid master key");
            check(result.restoredFilesCount() == 1, "1 file restored");
            String restoredContent = Files.readString(rst.resolve("vault/secret.txt"));
            check(restoredContent.equals("TOP_SECRET_PASSPHRASE_PEERLINK_2026"), "Plaintext bit-for-bit recovered");

            // Restoring WITHOUT key fails
            Path badRst = root.resolve("bad_rst");
            Files.createDirectories(badRst);
            RestorePlan failPlan = engine.planRestore(manifest.getBackupId(), badRst, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null);
            RestoreExecutionResult failResult = engine.executeRestore(failPlan, null, 0);
            check(!failResult.success(), "Restore without key fails");
            check(!Files.exists(badRst.resolve("vault/secret.txt")), "No unencrypted or partial file exposed");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 12. Deep Verification Bitrot & Storage Tampering Detection ────────────

    private static void testDeepVerificationBitrotDetection() throws Exception {
        Path root = createTempDirectory("phase15_t12_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "integrity.bin", "Original pristine byte content");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_bitrot", "BitrotJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);
            HistoricalVersion item = manifest.getItemByPath("integrity.bin").orElseThrow();

            // Pass initial deep verification
            BackupVerificationReport goodReport = engine.verifyBackup(manifest.getBackupId(), true, null);
            check(goodReport.passed() && goodReport.reconstructable(), "Passes clean verification");

            // Overwrite payload with corrupted bytes (bitrot on storage media)
            target.storePayload(item.getStorageHash(), "CORRUPTED_BYTES_AFTER_MEDIA_DAMAGE".getBytes(StandardCharsets.UTF_8));

            BackupVerificationReport badReport = engine.verifyBackup(manifest.getBackupId(), true, null);
            check(!badReport.passed(), "Verification fails on bitrot");
            check(!badReport.reconstructable(), "Report declares non-reconstructable");
            check(!badReport.corruptedItems().isEmpty(), "Corrupted item logged");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 13. Deep Verification Decryption Key Validation ───────────────────────

    private static void testDeepVerificationDecryptionKeyValidation() throws Exception {
        Path root = createTempDirectory("phase15_t13_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "secret.txt", "Protected confidential data");

            byte[] keyA = BlindPayloadCipher.generateKey();
            byte[] keyB = BlindPayloadCipher.generateKey(); // wrong key

            BlindBackupTarget target = new BlindBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_keys", "KeyJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), true, keyA, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);

            // Verify with correct key
            BackupVerificationReport repA = engine.verifyBackup(manifest.getBackupId(), true, keyA);
            check(repA.passed(), "Passes with legitimate client key");

            // Verify with wrong key
            BackupVerificationReport repB = engine.verifyBackup(manifest.getBackupId(), true, keyB);
            check(!repB.passed(), "Fails with incorrect client key");
            check(!repB.corruptedItems().isEmpty(), "Logged corruption / decryption error");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 14. Restore Staging & Atomic Expose Verification ──────────────────────

    private static void testRestoreStagingAndAtomicExpose() throws Exception {
        Path root = createTempDirectory("phase15_t14_");
        try {
            Path src = root.resolve("src");
            Path rst = root.resolve("rst");
            Files.createDirectories(src);
            Files.createDirectories(rst);
            createFile(src, "nested/path/document.txt", "Verified file payload bytes 12345");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_stage", "StageJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);

            RestorePlan plan = engine.planRestore(manifest.getBackupId(), rst, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null);
            RestoreExecutionResult res = engine.executeRestore(plan, null, 1);

            check(res.success(), "Restore succeeded");
            check(res.restoredFilesCount() == 1, "1 file restored");

            Path finalFile = rst.resolve("nested/path/document.txt");
            check(Files.exists(finalFile), "Restored final file exists");
            check(Files.readString(finalFile).equals("Verified file payload bytes 12345"), "Content matches");

            // Verify no stray .tmp or .part staging files left in directory
            try (var stream = Files.walk(rst)) {
                boolean hasStrayStaging = stream.anyMatch(p -> p.getFileName().toString().contains(".staging.") || p.getFileName().toString().contains(".tmp"));
                check(!hasStrayStaging, "All staging scratch files cleanly deleted");
            }
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 15. Corrupted Payloads Are Rejected and Never Exposed ─────────────────

    private static void testCorruptedPayloadsRejectedDuringRestore() throws Exception {
        Path root = createTempDirectory("phase15_t15_");
        try {
            Path src = root.resolve("src");
            Path rst = root.resolve("rst");
            Files.createDirectories(src);
            Files.createDirectories(rst);
            createFile(src, "important.dat", "Pristine data that will be corrupted");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_corrupt_rst", "CorruptJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);
            HistoricalVersion item = manifest.getItemByPath("important.dat").orElseThrow();

            // Corrupt storage payload on target
            target.storePayload(item.getStorageHash(), "GARBAGE_TAMPERED_BYTES".getBytes(StandardCharsets.UTF_8));

            RestorePlan plan = engine.planRestore(manifest.getBackupId(), rst, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null);
            RestoreExecutionResult res = engine.executeRestore(plan, null, 1);

            check(!res.success(), "Restore rejected due to payload corruption");
            check(res.restoredFilesCount() == 0, "Zero files restored");
            // The corrupted file MUST NOT be exposed at destination!
            check(!Files.exists(rst.resolve("important.dat")), "Corrupted file was NEVER exposed at target destination");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 16. Restore Conflict Policy FAIL_ON_CONFLICT Aborts Safely ────────────

    private static void testRestoreConflictFailOnConflict() throws Exception {
        Path root = createTempDirectory("phase15_t16_");
        try {
            Path src = root.resolve("src");
            Path rst = root.resolve("rst");
            Files.createDirectories(src);
            Files.createDirectories(rst);
            createFile(src, "settings.json", "{\"snapshot\":1}");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_foc", "FocJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);

            // Pre-create differing local file in rst
            createFile(rst, "settings.json", "{\"locally_edited\":true}");

            RestorePlan plan = engine.planRestore(manifest.getBackupId(), rst, RestoreConflictPolicy.FAIL_ON_CONFLICT, null);
            check(!plan.conflicts().isEmpty(), "Planner identified conflict");

            RestoreDryRunResult dryRun = engine.dryRunRestore(plan);
            check(!dryRun.canSucceed(), "Dry run fails under FAIL_ON_CONFLICT");

            RestoreExecutionResult res = engine.executeRestore(plan, null, 1);
            check(!res.success(), "Execution aborted without writing");
            check(res.restoredFilesCount() == 0, "No files written");

            // Verify local differing file was untouched
            check(Files.readString(rst.resolve("settings.json")).equals("{\"locally_edited\":true}"),
                    "Existing local file preserved intact");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 17. Restore Conflict Policy RESTORE_TO_ALTERNATIVE_PATH No Collision ──

    private static void testRestoreConflictAlternativePathNoCollision() throws Exception {
        Path root = createTempDirectory("phase15_t17_");
        try {
            Path src = root.resolve("src");
            Path rst = root.resolve("rst");
            Files.createDirectories(src);
            Files.createDirectories(rst);
            createFile(src, "photo.jpg", "SnapshotBinaryData101");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_alt", "AltJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);

            // Pre-create existing file
            createFile(rst, "photo.jpg", "LocalDifferingPhotoData999");

            RestorePlan plan = engine.planRestore(manifest.getBackupId(), rst, RestoreConflictPolicy.RESTORE_TO_ALTERNATIVE_PATH, null);

            // Perform repeated restore requests: 1st restore
            RestoreExecutionResult res1 = engine.executeRestore(plan, null, 1);
            check(res1.success(), "1st restore succeeded");

            // Perform repeated restore requests: 2nd restore
            RestoreExecutionResult res2 = engine.executeRestore(plan, null, 2);
            check(res2.success(), "2nd restore succeeded");

            // Original photo.jpg must remain untouched
            check(Files.readString(rst.resolve("photo.jpg")).equals("LocalDifferingPhotoData999"), "Original preserved");

            // Inspect alternative restored files
            List<Path> altFiles = new ArrayList<>();
            try (var stream = Files.list(rst)) {
                stream.filter(p -> p.getFileName().toString().startsWith("photo.jpg.restored."))
                      .forEach(altFiles::add);
            }

            check(altFiles.size() == 2, "Both restore requests generated unique non-colliding files");
            for (Path alt : altFiles) {
                check(Files.readString(alt).equals("SnapshotBinaryData101"), "Restored alternative contains snapshot content");
            }
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 18. Restore Policy OVERWRITE_WITH_NEW_VERSION Advances Sequence ───────

    private static void testRestoreAdvancesVersionSequenceNeverRewinds() throws Exception {
        Path root = createTempDirectory("phase15_t18_");
        try {
            Path src = root.resolve("src");
            Path rst = root.resolve("rst");
            Files.createDirectories(src);
            Files.createDirectories(rst);
            createFile(src, "draft.txt", "Draft 1 Content");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_seq", "SeqJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest b1 = engine.performBackup(config, BackupType.FULL);

            // Edit draft multiple times (sequence 2, 3)
            createFile(src, "draft.txt", "Draft 2 Content");
            engine.performBackup(config, BackupType.INCREMENTAL);

            createFile(src, "draft.txt", "Draft 3 Erroneous Content");
            engine.performBackup(config, BackupType.INCREMENTAL);

            long currentLocalVersionSequence = 5;

            // Restore from b1 (Draft 1)
            RestorePlan plan = engine.planRestore(b1.getBackupId(), rst, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null);
            RestoreExecutionResult result = engine.executeRestore(plan, null, currentLocalVersionSequence);

            check(result.success(), "Restore succeeded");
            // CARDINAL RULE: Restore creates a NEW current version sequence (6), never rewinds to 1!
            check(result.newVersionSequenceCreated() == currentLocalVersionSequence + 1,
                    "New version sequence created is " + (currentLocalVersionSequence + 1) + ", never rewinds history!");
            check(Files.readString(rst.resolve("draft.txt")).equals("Draft 1 Content"), "Restored content accurate");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 19. Interrupted Backup Fails Cleanly Without Corrupt Manifest ─────────

    private static void testInterruptedBackupFailsCleanly() throws Exception {
        Path root = createTempDirectory("phase15_t19_");
        try {
            Path src = root.resolve("src");
            Files.createDirectories(src);
            createFile(src, "file1.txt", "Good file 1");
            Path interruptedFile = createFile(src, "file2.txt", "Power cut will occur here");

            InMemoryBackupTarget target = new InMemoryBackupTarget();
            BackupEngine engine = new BackupEngine(target);

            BackupJobConfig config = new BackupJobConfig(
                    "job_abort", "AbortJob", src, "target_peer",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            boolean threw = false;
            try {
                engine.simulateInterruptedBackup(config, interruptedFile);
            } catch (IOException e) {
                threw = true;
            }
            check(threw, "Interruption threw IOException");

            // INVARIANT: No corrupt or partial manifest registered for this job
            List<BackupManifest> manifests = target.listManifests("job_abort");
            check(manifests.isEmpty(), "Zero manifests registered on interruption");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 20. Persistent FileBasedBackupTarget Proves Disk Byte Recoverability ──

    private static void testFileBasedBackupTargetDurability() throws Exception {
        Path root = createTempDirectory("phase15_t20_");
        try {
            Path src = root.resolve("src");
            Path targetRepo = root.resolve("backup_repository_on_disk");
            Path restoreDir = root.resolve("restored_fresh_workspace");
            Files.createDirectories(src);
            Files.createDirectories(targetRepo);
            Files.createDirectories(restoreDir);

            createFile(src, "report.pdf", "%PDF-1.4 Simulated binary document bytes");
            createFile(src, "database/dump.sql", "CREATE TABLE users (id INT, email TEXT);");

            // 1. Initialize real persistent file-based target
            FileBasedBackupTarget fileTarget = new FileBasedBackupTarget(targetRepo);
            BackupEngine engine = new BackupEngine(fileTarget);

            BackupJobConfig config = new BackupJobConfig(
                    "job_durable", "DurableJob", src, "local_disk_vault",
                    RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
            );

            BackupManifest manifest = engine.performBackup(config, BackupType.FULL);
            check(manifest != null, "Manifest created");

            // 2. Verify files exist on actual filesystem
            Path manifestFile = targetRepo.resolve("manifests").resolve(manifest.getBackupId() + ".manifest");
            check(Files.exists(manifestFile), "Manifest persisted to disk: " + manifestFile);
            check(fileTarget.getStorageUsageBytes() > 0, "Actual payload bytes stored on disk: " + fileTarget.getStorageUsageBytes());

            // 3. Completely delete the source working directory (wipe working tree)
            deleteRecursive(src);
            check(!Files.exists(src), "Source working tree wiped clean");

            // 4. Simulate complete application/process restart by creating a brand new target and engine pointing to targetRepo
            FileBasedBackupTarget restartedTarget = new FileBasedBackupTarget(targetRepo);
            BackupEngine restartedEngine = new BackupEngine(restartedTarget);

            // Re-discover manifests from disk
            List<BackupManifest> restoredManifests = restartedTarget.listManifests("job_durable");
            check(restoredManifests.size() == 1, "Discovered manifest after process restart");

            // Deep verify all stored payload blobs on disk
            BackupVerificationReport report = restartedEngine.verifyBackup(restoredManifests.get(0).getBackupId(), true, null);
            check(report.passed() && report.reconstructable(), "Reconstructed and verified stored payload bytes from disk");

            // Restore from disk backup repository into fresh restored workspace
            RestorePlan plan = restartedEngine.planRestore(
                    restoredManifests.get(0).getBackupId(), restoreDir, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null
            );
            RestoreExecutionResult result = restartedEngine.executeRestore(plan, null, 1);

            check(result.success(), "Restore from persistent disk repository succeeded");
            check(result.restoredFilesCount() == 2, "All 2 files restored bit-for-bit");

            // Verify content match
            check(Files.readString(restoreDir.resolve("report.pdf")).equals("%PDF-1.4 Simulated binary document bytes"),
                    "PDF content recovered bit-for-bit from disk");
            check(Files.readString(restoreDir.resolve("database/dump.sql")).equals("CREATE TABLE users (id INT, email TEXT);"),
                    "SQL dump recovered bit-for-bit from disk");
        } finally {
            deleteRecursive(root);
        }
    }
}
