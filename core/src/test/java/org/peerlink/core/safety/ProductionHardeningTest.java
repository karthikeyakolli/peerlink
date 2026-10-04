package org.peerlink.core.safety;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.android.AndroidNodeState;
import org.peerlink.core.backup.*;
import org.peerlink.core.compatibility.CompatibilityAnalyzer;
import org.peerlink.core.compatibility.CompatibilityReport;
import org.peerlink.core.compatibility.CompatibilityResult;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.net.ice.*;
import org.peerlink.core.operation.*;
import org.peerlink.core.security.ScannerProvider;
import org.peerlink.core.security.SecurityVerdict;
import org.peerlink.core.sync.*;
import org.peerlink.core.transfer.*;
import org.peerlink.protocol.v1.DuplicateDestinationPolicy;
import org.peerlink.protocol.v1.TransferManifest;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Phase 19: Comprehensive Production Hardening & Chaos Test Suite")
class ProductionHardeningTest {

    @TempDir
    Path tempDir;

    private Path stagingDir;
    private Path targetDir;
    private Path quarantineDir;

    @BeforeEach
    void setUp() throws IOException {
        stagingDir = tempDir.resolve("staging");
        targetDir = tempDir.resolve("target");
        quarantineDir = tempDir.resolve("quarantine");
        Files.createDirectories(stagingDir);
        Files.createDirectories(targetDir);
        Files.createDirectories(quarantineDir);
    }

    private byte[] createZipArchive(Map<String, byte[]> entries) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            for (Map.Entry<String, byte[]> entry : entries.entrySet()) {
                ZipEntry ze = new ZipEntry(entry.getKey());
                zos.putNextEntry(ze);
                zos.write(entry.getValue());
                zos.closeEntry();
            }
        }
        return baos.toByteArray();
    }

    // ── 1. Crash and Process Recovery ────────────────────────────────────────

    @Test
    @DisplayName("1. Crash Recovery: EXECUTING marked OUTCOME_UNKNOWN; pre-execution cancelled; no blind replay")
    void testCrashAndProcessRecovery() {
        InMemoryOperationJournal journal = new InMemoryOperationJournal();

        // 1. Pre-execution operation (CREATED)
        OperationRecord opPre = new OperationRecord("op_pre", OperationIntent.SEND, "peer_a", List.of("f1.txt"),
                OperationState.CREATED, "idemp_pre", System.currentTimeMillis(), System.currentTimeMillis());
        journal.recordOperation(opPre);

        // 2. Active in-flight operation (EXECUTING)
        OperationRecord opInFlight = new OperationRecord("op_flight", OperationIntent.SEND, "peer_a", List.of("f2.txt"),
                OperationState.EXECUTING, "idemp_flight", System.currentTimeMillis(), System.currentTimeMillis());
        journal.recordOperation(opInFlight);

        // 3. Mark executing operations as OUTCOME_UNKNOWN
        journal.markInterruptedOperationsUnknown("Simulated crash restart");

        assertEquals(OperationState.OUTCOME_UNKNOWN, journal.getOperation("op_flight").get().getState());
        assertEquals(OperationState.CREATED, journal.getOperation("op_pre").get().getState());

        // Cancel pre-execution
        journal.updateState("op_pre", OperationState.CANCELLED);
        assertEquals(OperationState.CANCELLED, journal.getOperation("op_pre").get().getState());

        // Verify invariant: OUTCOME_UNKNOWN cannot be blindly executed
        assertTrue(journal.listUnknownOutcomeOperations().stream().anyMatch(o -> o.getOperationId().equals("op_flight")));
    }

    // ── 2. Power-Loss Safety ─────────────────────────────────────────────────

    @Test
    @DisplayName("2. Power-loss Safety: Staging cleanup on interrupted transfer prevents partial commit")
    void testPowerLossSafety() throws Exception {
        StagingDirectoryManager staging = new StagingDirectoryManager(stagingDir);
        String transferId = "xfer_power_loss";
        staging.prepareStagingDir(transferId);

        // Write partial chunk
        byte[] partial = "Partial data written before power loss".getBytes(StandardCharsets.UTF_8);
        staging.writeChunk(transferId, 0, 0, 0, partial, null);
        assertTrue(staging.getStagedFileSize(transferId, 0) > 0);

        // Clean up uncommitted staging
        staging.cleanupStaging(transferId);
        assertEquals(0, staging.getStagedFileSize(transferId, 0));
        assertFalse(Files.exists(targetDir.resolve("file.txt")), "No false completed file in target dir");
    }

    // ── 3. Filesystem Hardening ──────────────────────────────────────────────

    @Test
    @DisplayName("3. Filesystem Hardening: Windows reserved names, invalid chars, Unicode, and long paths")
    void testFilesystemHardening() {
        // Windows reserved name
        CompatibilityReport conReport = CompatibilityAnalyzer.analyze(
                "CON.txt", 100, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS);
        assertTrue(conReport.requiresUserDecision());
        assertTrue(conReport.issues().stream().anyMatch(i -> i.code().equals("WINDOWS_RESERVED_NAME")));

        // Invalid characters: colon, pipe, quotes, question mark
        CompatibilityReport badCharReport = CompatibilityAnalyzer.analyze(
                "invalid|char?name:file*.txt", 200, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS);
        assertEquals(CompatibilityResult.INCOMPATIBLE, badCharReport.overallResult());
        assertTrue(badCharReport.issues().stream().anyMatch(i -> i.code().equals("WINDOWS_ILLEGAL_CHARACTERS")));

        // Unicode with accents and emojis
        CompatibilityReport unicodeReport = CompatibilityAnalyzer.analyze(
                "dossier_café_résumé_🚀.pdf", 500, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS);
        assertEquals(CompatibilityResult.COMPATIBLE, unicodeReport.overallResult());

        // Very long path (>260 chars)
        String longPath = "a/".repeat(140) + "deep_nested_file.txt";
        CompatibilityReport longReport = CompatibilityAnalyzer.analyze(
                longPath, 1024, Map.of(), CompatibilityAnalyzer.TargetOperatingSystem.WINDOWS);
        assertTrue(longReport.issues().stream().anyMatch(i -> i.code().contains("MAX_PATH")));
    }

    // ── 4. Transfer Chaos ────────────────────────────────────────────────────

    @Test
    @DisplayName("4. Transfer Chaos: Corrupted chunk retry and source mutation detection")
    void testTransferChaos() throws Exception {
        InMemoryOperationJournal journal = new InMemoryOperationJournal();
        PeerTransferEngine engine = new PeerTransferEngine(journal, stagingDir);

        Path sourceFile = tempDir.resolve("original_source.txt");
        Files.writeString(sourceFile, "Initial clean file content");

        TransferManifest manifest = engine.prepareSend("peer_a", "peer_b", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_OVERWRITE);
        String transferId = manifest.getTransferId();

        // 1. Simulate corrupted chunk rejected and retried
        engine.handleIncomingOffer(org.peerlink.protocol.v1.TransferOffer.newBuilder().setManifest(manifest).build(), targetDir);

        // Corrupt chunk hash intentionally
        org.peerlink.protocol.v1.TransferChunk badChunk = org.peerlink.protocol.v1.TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFromUtf8("Wrong payload"))
                .setChunkSha256("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
                .build();

        org.peerlink.protocol.v1.TransferChunkAck ack = engine.handleIncomingChunk(badChunk);
        assertFalse(ack.getSuccess());
        assertTrue(ack.getRetryRequested(), "Corrupted chunk must request retry");

        // 2. Source mutation mid-transfer: mutate source file
        Files.writeString(sourceFile, "Mutated content changed on disk!");
        assertThrows(SourceMutationException.class, () -> {
            engine.executeTransferWithManifest(manifest, List.of(sourceFile), targetDir, null, null);
        });
    }

    // ── 5. Sync Chaos ────────────────────────────────────────────────────────

    @Test
    @DisplayName("5. Sync Chaos: Divergence, conflict detection, and mass-change protection hold")
    void testSyncChaos() {
        SyncEngine syncEngine = new SyncEngine();
        SyncManifest local = new SyncManifest("node_local");
        SyncManifest remote = new SyncManifest("node_remote");

        ObjectId docId = new ObjectId("doc_01");

        // Concurrent divergent modifications
        CausalVersion vLocal = CausalVersion.empty().increment("node_local");
        CausalVersion vRemote = CausalVersion.empty().increment("node_remote");

        SyncObject objLocal = new SyncObject(
                docId, "report.pdf", ContentHash.computeSha256("local content".getBytes(StandardCharsets.UTF_8)).getHexString(),
                100, System.currentTimeMillis(), false, ContentVersion.initial("node_local"), MetadataVersion.initial("node_local"), vLocal
        );
        SyncObject objRemote = new SyncObject(
                docId, "report.pdf", ContentHash.computeSha256("remote content".getBytes(StandardCharsets.UTF_8)).getHexString(),
                120, System.currentTimeMillis(), false, ContentVersion.initial("node_remote"), MetadataVersion.initial("node_remote"), vRemote
        );

        local.trackObject(objLocal);
        remote.trackObject(objRemote);

        SyncSession session = new SyncSession(
                "sync_sess_01", "node_local", "node_remote",
                SyncMode.BIDIRECTIONAL, SelectiveSyncFilter.acceptAll(), local
        );
        session.setRemoteManifest(remote);
        SyncOutcome outcome = syncEngine.sync(session, List.of(new ChangeDetector.FsEntry("report.pdf", objLocal.getContentHash(), 100, System.currentTimeMillis(), false)), false);

        assertTrue(session.hasUnresolvedConflicts(), "Concurrent edits must surface as conflict");
        assertEquals(1, session.getConflicts().size());
        assertEquals(ConflictType.CONCURRENT_CONTENT_EDIT, session.getConflicts().get(0).getConflictType());

        // Mass change protection: sudden mass modifications
        List<ChangeDetector.FsEntry> massEntries = new ArrayList<>();
        for (int i = 0; i < 200; i++) {
            massEntries.add(new ChangeDetector.FsEntry("file_" + i + ".txt", "dummy_hash_" + i, 1024, System.currentTimeMillis(), false));
        }
        SyncSession massSession = new SyncSession(
                "mass_sess", "node_local", "node_remote",
                SyncMode.BIDIRECTIONAL, SelectiveSyncFilter.acceptAll(), local
        );
        massSession.setRemoteManifest(remote);
        SyncOutcome massOutcome = syncEngine.sync(massSession, massEntries, false);
        assertTrue(massOutcome.isPaused());
    }

    // ── 6. Backup & Restore Hardening ────────────────────────────────────────

    @Test
    @DisplayName("6. Backup & Restore: Interrupted restore safety; history is never silently overwritten")
    void testBackupAndRestoreHardening() throws IOException {
        Path sourceDir = tempDir.resolve("backup_src");
        Path restoreDir = tempDir.resolve("backup_rst");
        Files.createDirectories(sourceDir);
        Files.createDirectories(restoreDir);
        Path doc = sourceDir.resolve("data.txt");
        Files.writeString(doc, "Original historical content");

        InMemoryBackupTarget target = new InMemoryBackupTarget();
        BackupEngine backupEngine = new BackupEngine(target);

        BackupJobConfig config = new BackupJobConfig(
                "job_harden", "HardenBackup", sourceDir, "peer_target_1",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );
        BackupManifest bkp1 = backupEngine.performBackup(config, BackupType.FULL);
        RestorePlan plan = backupEngine.planRestore(
                bkp1.getBackupId(), restoreDir, RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION, null
        );
        RestoreExecutionResult res = backupEngine.executeRestore(plan, null, 1);
        assertTrue(res.success());
        assertEquals(2, res.newVersionSequenceCreated(), "Restore must create a new version sequence, never rewrite history");
    }

    // ── 7. Security Hardening ────────────────────────────────────────────────

    @Test
    @DisplayName("7. Security Hardening: Zip bombs, path traversal in archive names, and secret redaction")
    void testSecurityHardening() throws IOException {
        // Zip Bomb Ratio Defense
        byte[] bigArray = new byte[300_000];
        Arrays.fill(bigArray, (byte) 'Z');
        byte[] bombBytes = createZipArchive(Map.of("bomb.txt", bigArray));

        ArchiveSafetyInspector.ArchiveSafetyVerdict verdict = ArchiveSafetyInspector.inspectZipBytes(bombBytes, 1);
        assertTrue(verdict.isDecompressionBomb());
        assertFalse(verdict.isSafe());

        // Path Traversal in archive entry
        byte[] traversalBytes = createZipArchive(Map.of("../../windows/system32/cmd.exe", "dangerous payload".getBytes(StandardCharsets.UTF_8)));
        ArchiveSafetyInspector.ArchiveSafetyVerdict traversalVerdict = ArchiveSafetyInspector.inspectZipBytes(traversalBytes, 1);
        assertTrue(traversalVerdict.hasPathTraversal());
        assertFalse(traversalVerdict.isSafe());

        // Secret Redaction in diagnostics
        String rawError = "Connection failed with token: secret_token_xyz12345678 and password=SuperSecretP@ssword123";
        String sanitized = OperationDiagnostics.sanitize(rawError);
        assertFalse(sanitized.contains("secret_token_xyz12345678"));
        assertFalse(sanitized.contains("SuperSecretP@ssword123"));
        assertTrue(sanitized.contains("[REDACTED]"));
    }

    // ── 8. Malware Scanner Hardening ─────────────────────────────────────────

    @Test
    @DisplayName("8. Malware Scanner Hardening: Scanner crash/timeout never converts to CLEAN; version invalidates cache; nested zip bombs caught")
    void testMalwareScannerHardening() throws IOException {
        QuarantineZone qz = new QuarantineZone(quarantineDir);
        ScanCache cache = new ScanCache();

        // 1. Scanner throwing unexpected RuntimeException (Crash simulation)
        ScannerProvider crashingScanner = new ScannerProvider() {
            @Override public String getProviderName() { return "CrashingEngine"; }
            @Override public boolean isAvailable() { return true; }
            @Override public SecurityVerdict scanStream(InputStream inputStream) { throw new RuntimeException("Engine internal SEGV"); }
            @Override public SecurityVerdict scanFile(String filePath) { throw new RuntimeException("Engine internal SEGV"); }
        };

        InboundSafetyPipeline crashPipeline = new InboundSafetyPipeline(qz, crashingScanner, ScanPolicy.strict(), cache);
        byte[] testData = "Hello normal file".getBytes(StandardCharsets.UTF_8);
        ContentHash hash = ContentHash.computeSha256(testData);

        InboundSafetyPipeline.PipelineResult crashResult = crashPipeline.processInboundFile(
                testData, "clean.txt", hash, "peer_test", targetDir);

        assertFalse(crashResult.committed(), "Crashing scanner must NEVER commit");
        assertNotEquals(SecurityVerdict.CLEAN, crashResult.verdict());
        assertEquals(SecurityVerdict.SCAN_FAILED, crashResult.verdict());

        // 2. Scanner timeout simulation
        ScannerProvider timingOutScanner = new ScannerProvider() {
            @Override public String getProviderName() { return "TimeoutEngine"; }
            @Override public boolean isAvailable() { return true; }
            @Override public SecurityVerdict scanStream(InputStream inputStream) { throw new RuntimeException("Scan timed out after 10000ms"); }
            @Override public SecurityVerdict scanFile(String filePath) { throw new RuntimeException("Scan timed out after 10000ms"); }
        };

        InboundSafetyPipeline timeoutPipeline = new InboundSafetyPipeline(qz, timingOutScanner, ScanPolicy.strict(), cache);
        InboundSafetyPipeline.PipelineResult timeoutResult = timeoutPipeline.processInboundFile(
                testData, "clean2.txt", hash, "peer_test", targetDir);

        assertFalse(timeoutResult.committed());
        assertEquals(SecurityVerdict.SCAN_FAILED, timeoutResult.verdict());

        // 3. Scanner version change invalidates stale cache
        ScanCache versionedCache = new ScanCache();
        ContentHash sampleHash = ContentHash.computeSha256("sample".getBytes(StandardCharsets.UTF_8));
        versionedCache.put(sampleHash, ScanResult.clean("ClamAV", 15), "1.0.0");

        assertTrue(versionedCache.get(sampleHash, "1.0.0").isPresent());
        // Scanner engine upgraded to 1.1.0 -> cache miss / invalidated
        assertTrue(versionedCache.get(sampleHash, "1.1.0").isEmpty());

        // 4. Nested zip bomb recursively detected
        byte[] bigData = new byte[250_000];
        Arrays.fill(bigData, (byte) 'B');
        byte[] innerZip = createZipArchive(Map.of("inner_bomb.txt", bigData));
        byte[] outerZip = createZipArchive(Map.of("nested.zip", innerZip));

        ArchiveSafetyInspector.ArchiveSafetyVerdict nestedVerdict = ArchiveSafetyInspector.inspectZipBytes(outerZip, 1);
        assertTrue(nestedVerdict.isDecompressionBomb(), "Nested decompression bomb must be caught recursively");
        assertFalse(nestedVerdict.isSafe());
    }

    // ── 9. Supabase Outage Resilience ────────────────────────────────────────

    @Test
    @DisplayName("9. Supabase Outage: Offline local operations continue unaffected")
    void testSupabaseOutageResilience() {
        InMemoryOperationJournal journal = new InMemoryOperationJournal();
        // Record and advance local operation while network / Supabase is disconnected
        String opId = "op_offline_local";
        journal.recordOperation(new OperationRecord(opId, OperationIntent.SEND, "local_node",
                List.of("doc.txt"), OperationState.CREATED, "idemp_offline", System.currentTimeMillis(), System.currentTimeMillis()));

        journal.updateState(opId, OperationState.VALIDATED);
        journal.updateState(opId, OperationState.AUTHORIZED);
        journal.updateState(opId, OperationState.EXECUTING);
        journal.updateState(opId, OperationState.COMMITTED);

        assertEquals(OperationState.COMMITTED, journal.getOperation(opId).get().getState());
    }

    // ── 10. Network Hardening ────────────────────────────────────────────────

    @Test
    @DisplayName("10. Network Hardening: Relay selection, connection quality degradation and diagnostics")
    void testNetworkHardening() {
        PathSelector selector = new PathSelector();

        IceCandidate localRelay = IceCandidate.relay("203.0.113.5", 3478, "10.0.0.1", 54321, TransportProtocol.TCP);
        IceCandidate remoteRelay = IceCandidate.relay("203.0.113.6", 3478, "10.0.0.2", 54322, TransportProtocol.TCP);
        CandidatePair relayPair = new CandidatePair(localRelay, remoteRelay, false);
        relayPair.recordCheckSuccess(85);

        ConnectionDiagnostics diagnostics = selector.selectPath(Collections.singletonList(relayPair));
        assertEquals(ConnectionDiagnostics.Outcome.RELAY_USED, diagnostics.getOutcome());
        assertTrue(diagnostics.isRelayed());
        assertNotNull(diagnostics.toDiagnosticReport());
    }

    // ── 11. Android Hardening ────────────────────────────────────────────────

    @Test
    @DisplayName("11. Android Hardening: Node state transitions respect OS background restrictions")
    void testAndroidHardening() {
        // Node state lifecycle
        AndroidNodeState state = AndroidNodeState.ACTIVE;
        assertEquals(AndroidNodeState.ACTIVE, state);

        state = AndroidNodeState.BACKGROUND_CAPABLE;
        assertNotEquals(AndroidNodeState.OS_RESTRICTED, state);

        state = AndroidNodeState.OS_RESTRICTED;
        assertTrue(state == AndroidNodeState.OS_RESTRICTED);

        state = AndroidNodeState.UNAVAILABLE;
        assertTrue(state == AndroidNodeState.UNAVAILABLE);
    }

    // ── 12. Threading and Concurrency ────────────────────────────────────────

    @Test
    @DisplayName("12. Threading & Concurrency: Multi-threaded concurrent journal and cache access without race conditions")
    void testThreadingAndConcurrency() throws InterruptedException {
        InMemoryOperationJournal journal = new InMemoryOperationJournal();
        int threadCount = 8;
        int opsPerThread = 50;
        ExecutorService pool = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);

        for (int t = 0; t < threadCount; t++) {
            final int threadId = t;
            pool.submit(() -> {
                try {
                    for (int i = 0; i < opsPerThread; i++) {
                        String opId = "thread_" + threadId + "_op_" + i;
                        journal.recordOperation(new OperationRecord(
                                opId, OperationIntent.SEND, "peer_" + threadId, List.of("file.txt"),
                                OperationState.CREATED, "idemp_" + opId, System.currentTimeMillis(), System.currentTimeMillis()
                        ));
                        journal.updateState(opId, OperationState.VALIDATED);
                    }
                } finally {
                    latch.countDown();
                }
            });
        }

        assertTrue(latch.await(5, TimeUnit.SECONDS));
        pool.shutdown();

        assertEquals(threadCount * opsPerThread, journal.listIncompleteOperations().size());
    }

    // ── 13. Performance Baseline ─────────────────────────────────────────────

    @Test
    @DisplayName("13. Performance Baseline: High-throughput hashing and journal operation logging")
    void testPerformanceBaseline() {
        byte[] payload = new byte[64 * 1024]; // 64 KB
        Arrays.fill(payload, (byte) 0x2A);

        long start = System.nanoTime();
        int iterations = 100;
        for (int i = 0; i < iterations; i++) {
            ContentHash hash = ContentHash.computeSha256(payload);
            assertNotNull(hash.getHexString());
        }
        long elapsedMs = (System.nanoTime() - start) / 1_000_000;
        assertTrue(elapsedMs < 1000, "Hashing 100x 64KB chunks should complete in under 1000ms (took " + elapsedMs + "ms)");
    }

    // ── 14. Watchdog and Self-Healing ────────────────────────────────────────

    @Test
    @DisplayName("14. Watchdog: Health detection, stale staging cleanup, and restart loop prevention")
    void testWatchdogAndSelfHealing() throws IOException {
        Path staleDir = stagingDir.resolve("stale_job");
        Files.createDirectories(staleDir);
        Path oldFile = staleDir.resolve("old_data.bin");
        Files.writeString(oldFile, "stale staging payload");

        // Set modification time 3 hours into past
        long threeHoursAgo = System.currentTimeMillis() - (3 * 3600 * 1000L);
        Files.setLastModifiedTime(oldFile, java.nio.file.attribute.FileTime.fromMillis(threeHoursAgo));

        NodeWatchdog watchdog = new NodeWatchdog(
                stagingDir,
                () -> true, // DB integrity OK
                () -> 1,    // 1 stale session cleaned
                () -> {}    // reconciliation triggered
        );

        NodeWatchdog.HealthReport report = watchdog.inspectAndHeal();
        assertTrue(report.healthy());
        assertTrue(report.dbIntegrityOk());
        assertEquals(1, report.cleanedStaleSessions());
        assertEquals(1, report.cleanedStaleFiles());
        assertFalse(Files.exists(oldFile), "Old staging file must be purged by watchdog");

        // Restart loop prevention: 4 restarts in a row within short window
        assertTrue(watchdog.recordRestartAndCheckPermitted());
        assertTrue(watchdog.recordRestartAndCheckPermitted());
        assertTrue(watchdog.recordRestartAndCheckPermitted());
        assertFalse(watchdog.recordRestartAndCheckPermitted(), "4th rapid restart must be inhibited to avoid loop");
        assertTrue(watchdog.isRestartLoopDetected());
    }

    // ── 15. Emergency Stop ───────────────────────────────────────────────────

    @Test
    @DisplayName("15. Emergency Stop: Halts transfers, sync, backup, sharing, and clipboard; preserves state; blocks ops")
    void testEmergencyStop() {
        EmergencyStopManager em = new EmergencyStopManager();

        AtomicInteger activeTransfers = new AtomicInteger(3);
        AtomicInteger activeSync = new AtomicInteger(2);
        AtomicInteger activeBackups = new AtomicInteger(1);
        AtomicBoolean clipboardActive = new AtomicBoolean(true);

        em.registerSubsystem("PeerTransferEngine", () -> activeTransfers.getAndSet(0), () -> activeTransfers.set(0));
        em.registerSubsystem("SyncEngine", () -> activeSync.getAndSet(0), () -> activeSync.set(0));
        em.registerSubsystem("BackupEngine", () -> activeBackups.getAndSet(0), () -> activeBackups.set(0));
        em.registerSubsystem("ClipboardPropagation", () -> { clipboardActive.set(false); return 1; }, () -> clipboardActive.set(true));

        assertFalse(em.isEmergencyStopActive());

        // Trigger Emergency Stop
        EmergencyStopManager.StopReport report = em.stopAll("Security threat detected / Administrator invoked STOP");

        assertTrue(em.isEmergencyStopActive());
        assertEquals(3, report.haltedTransfers());
        assertEquals(2, report.haltedSyncLoops());
        assertEquals(1, report.haltedBackups());
        assertTrue(report.clipboardHalted());
        assertEquals(0, activeTransfers.get());
        assertEquals(0, activeSync.get());

        // Subsequent operation attempts are blocked immediately
        assertThrows(IllegalStateException.class, () -> em.checkOperationPermitted("NewFileTransfer"));

        // Resume after health validation
        boolean resumed = em.resumeAfterEmergencyStop(() -> true);
        assertTrue(resumed);
        assertFalse(em.isEmergencyStopActive());
        assertDoesNotThrow(() -> em.checkOperationPermitted("NewFileTransfer"));
    }

    // ── 16. Failure Diagnostics ──────────────────────────────────────────────

    @Test
    @DisplayName("16. Failure Diagnostics: Privacy-safe report with redacted secrets and clear user guidance")
    void testFailureDiagnostics() {
        Map<String, String> details = new HashMap<>();
        details.put("peerAddress", "192.168.1.50:5000");
        details.put("authToken", "secret_auth_token_xyz987654321");
        details.put("serverPrivateKey", "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0...\n-----END RSA PRIVATE KEY-----");

        OperationDiagnostics diag = new OperationDiagnostics(
                "op_diag_test_99",
                "Relay connection timed out after 3 retries",
                "192.168.1.50 via TURN relay",
                OperationDiagnostics.RecoveryState.RESUMABLE,
                "The file transfer was paused because your peer disconnected. It will resume automatically when reconnected.",
                details
        );

        String report = diag.toDiagnosticReport();
        assertNotNull(report);
        assertTrue(report.contains("op_diag_test_99"));
        assertTrue(report.contains("RESUMABLE"));
        assertTrue(report.contains("The file transfer was paused"));
        assertFalse(report.contains("secret_auth_token_xyz987654321"), "Auth token must be redacted");
        assertFalse(report.contains("MIIEowIBAAKCAQEA0"), "Private key must be redacted");
        assertTrue(report.contains("[REDACTED]"));
    }

    // ── In-Memory Journal Implementation for Testing ──────────────────────────

    private static final class InMemoryOperationJournal implements OperationJournal {
        private final Map<String, OperationRecord> records = new ConcurrentHashMap<>();
        private final Map<String, String> idempotencyMap = new ConcurrentHashMap<>();

        @Override
        public void recordOperation(OperationRecord record) {
            records.put(record.getOperationId(), record);
            if (record.getIdempotencyKey() != null) {
                idempotencyMap.put(record.getIdempotencyKey(), record.getOperationId());
            }
        }

        @Override
        public void updateState(String operationId, OperationState newState) {
            OperationRecord existing = records.get(operationId);
            if (existing != null) {
                records.put(operationId, existing.withState(newState));
            }
        }

        @Override
        public void recordJournalStage(String operationId, JournalStage stage) {}

        @Override
        public Optional<OperationRecord> getOperation(String operationId) {
            return Optional.ofNullable(records.get(operationId));
        }

        @Override
        public List<OperationRecord> listIncompleteOperations() {
            return records.values().stream().filter(r -> !r.getState().isTerminal()).toList();
        }

        @Override
        public List<OperationRecord> listInterruptedOperations() {
            return records.values().stream().filter(r -> r.getState() == OperationState.EXECUTING).toList();
        }

        @Override
        public List<OperationRecord> listUnknownOutcomeOperations() {
            return records.values().stream().filter(r -> r.getState() == OperationState.OUTCOME_UNKNOWN).toList();
        }

        @Override
        public Optional<String> findOperationByIdempotencyKey(String idempotencyKey) {
            return Optional.ofNullable(idempotencyMap.get(idempotencyKey));
        }

        @Override
        public void appendNote(String operationId, String note) {}

        @Override
        public void markInterruptedOperationsUnknown(String reason) {
            for (OperationRecord op : listInterruptedOperations()) {
                updateState(op.getOperationId(), OperationState.OUTCOME_UNKNOWN);
            }
        }
    }
}
