package org.peerlink.core.performance;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.backup.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.sync.*;
import org.peerlink.core.transfer.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Performance benchmarking test suite for PeerLink Core.
 * Measures baseline throughput, latency, memory allocations, and stress scalability
 * across hashing, encryption, transfer, sync, and backup engines.
 */
public class PeerLinkCorePerformanceBenchmarkTest {

    @TempDir
    Path tempDir;

    private Path stagingDir;
    private Path targetDir;
    private Path backupSourceDir;

    @BeforeEach
    public void setUp() throws IOException {
        stagingDir = tempDir.resolve("staging");
        targetDir = tempDir.resolve("target");
        backupSourceDir = tempDir.resolve("backup_src");

        Files.createDirectories(stagingDir);
        Files.createDirectories(targetDir);
        Files.createDirectories(backupSourceDir);
    }

    @AfterEach
    public void tearDown() {
        // TempDir automatically cleans up
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 1. HASHING & INTEGRITY VERIFICATION OVERHEAD
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkHashingOverhead() throws IOException {
        // Generate 10MB deterministic payload
        byte[] payload10MB = new byte[10 * 1024 * 1024];
        new Random(42).nextBytes(payload10MB);
        Path testFile = tempDir.resolve("payload10MB.bin");
        Files.write(testFile, payload10MB);

        // Warm up JIT
        for (int i = 0; i < 3; i++) {
            FileManifestBuilder.calculateSha256Hex(testFile);
        }

        // Measure SHA-256 file stream hashing
        long startNanos = System.nanoTime();
        String shaFile = FileManifestBuilder.calculateSha256Hex(testFile);
        long elapsedNanos = System.nanoTime() - startNanos;

        double elapsedMs = elapsedNanos / 1_000_000.0;
        double throughputMBps = (10.0 / elapsedNanos) * 1_000_000_000.0;

        System.out.printf("[BENCHMARK] SHA-256 10MB Streaming: %.2f ms (%.2f MB/s), hash=%s%n",
                elapsedMs, throughputMBps, shaFile.substring(0, 8));

        assertNotNull(shaFile);
        assertTrue(throughputMBps > 5.0, "Streaming hashing must achieve > 5 MB/s");

        // Measure in-memory byte[] hashing for 1,000 64KB chunks
        byte[] chunk = new byte[64 * 1024];
        new Random(123).nextBytes(chunk);

        startNanos = System.nanoTime();
        for (int i = 0; i < 1000; i++) {
            FileManifestBuilder.calculateSha256Hex(chunk);
        }
        elapsedNanos = System.nanoTime() - startNanos;
        double chunkRate = (1000.0 / elapsedNanos) * 1_000_000_000.0;

        System.out.printf("[BENCHMARK] SHA-256 1,000 Chunks (64KB): %.2f ms (%.0f chunks/sec)%n",
                elapsedNanos / 1_000_000.0, chunkRate);
        assertTrue(chunkRate > 100.0, "Chunk hashing must achieve > 100 chunks/s");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2. ENCRYPTION OVERHEAD (BLIND PAYLOAD CIPHER)
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkBlindEncryptionOverhead() throws Exception {
        byte[] key = new byte[32];
        new SecureRandom().nextBytes(key);

        byte[] payload1MB = new byte[1024 * 1024];
        new Random(99).nextBytes(payload1MB);

        // Warm up
        for (int i = 0; i < 5; i++) {
            byte[] ct = BlindPayloadCipher.encrypt(payload1MB, key);
            BlindPayloadCipher.decrypt(ct, key);
        }

        // Measure Encryption
        long startNanos = System.nanoTime();
        byte[] ciphertext = BlindPayloadCipher.encrypt(payload1MB, key);
        long encNanos = System.nanoTime() - startNanos;

        // Measure Decryption
        startNanos = System.nanoTime();
        byte[] plaintext = BlindPayloadCipher.decrypt(ciphertext, key);
        long decNanos = System.nanoTime() - startNanos;

        double encThroughput = (1.0 / encNanos) * 1_000_000_000.0;
        double decThroughput = (1.0 / decNanos) * 1_000_000_000.0;

        System.out.printf("[BENCHMARK] Blind Encryption (1MB): %.2f ms (%.2f MB/s)%n",
                encNanos / 1_000_000.0, encThroughput);
        System.out.printf("[BENCHMARK] Blind Decryption (1MB): %.2f ms (%.2f MB/s)%n",
                decNanos / 1_000_000.0, decThroughput);

        assertArrayEquals(payload1MB, plaintext);
        assertTrue(encThroughput > 1.0, "Encryption must achieve > 1 MB/s");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3. TRANSFER ENGINE: CHUNK STREAMING & STAGING
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkTransferEngineSingleLargeFile() throws Exception {
        StagingDirectoryManager staging = new StagingDirectoryManager(stagingDir);
        String transferId = "bench_xfer_large_" + UUID.randomUUID().toString().replace("-", "");
        staging.prepareStagingDir(transferId);

        // Simulate 4MB file in 64KB chunks (64 chunks)
        int chunkSize = 64 * 1024;
        int chunkCount = 64;
        byte[] chunkData = new byte[chunkSize];
        new Random(77).nextBytes(chunkData);
        String chunkSha = FileManifestBuilder.calculateSha256Hex(chunkData);

        long startNanos = System.nanoTime();
        for (int i = 0; i < chunkCount; i++) {
            staging.writeChunk(transferId, 0, i, (long) i * chunkSize, chunkData, chunkSha);
        }
        long writeNanos = System.nanoTime() - startNanos;

        // Commit item
        Path destFile = targetDir.resolve("large_committed.bin");
        startNanos = System.nanoTime();
        staging.commitItem(transferId, 0, destFile);
        long commitNanos = System.nanoTime() - startNanos;

        double totalMB = (chunkSize * chunkCount) / (1024.0 * 1024.0);
        double writeThroughput = (totalMB / writeNanos) * 1_000_000_000.0;

        System.out.printf("[BENCHMARK] Transfer Staging 4MB (64KB chunks): %.2f ms (%.2f MB/s), Commit: %.2f ms%n",
                writeNanos / 1_000_000.0, writeThroughput, commitNanos / 1_000_000.0);

        assertTrue(Files.exists(destFile));
        assertEquals(chunkSize * chunkCount, Files.size(destFile));
    }

    @Test
    public void benchmarkTransferEngineManySmallFiles() throws Exception {
        StagingDirectoryManager staging = new StagingDirectoryManager(stagingDir);
        String transferId = "bench_xfer_small_" + UUID.randomUUID().toString().replace("-", "");
        staging.prepareStagingDir(transferId);

        int fileCount = 200;
        byte[] smallData = new byte[4 * 1024]; // 4KB each
        new Random(88).nextBytes(smallData);

        long startNanos = System.nanoTime();
        for (int i = 0; i < fileCount; i++) {
            staging.writeChunk(transferId, i, 0, 0, smallData, null);
        }
        long stageNanos = System.nanoTime() - startNanos;

        startNanos = System.nanoTime();
        for (int i = 0; i < fileCount; i++) {
            Path dest = targetDir.resolve("small_files/file_" + i + ".dat");
            staging.commitItem(transferId, i, dest);
        }
        long commitNanos = System.nanoTime() - startNanos;

        System.out.printf("[BENCHMARK] Many Small Files (200 x 4KB): Staging %.2f ms (%.0f files/s), Commit %.2f ms (%.0f files/s)%n",
                stageNanos / 1_000_000.0, (fileCount * 1_000_000_000.0) / stageNanos,
                commitNanos / 1_000_000.0, (fileCount * 1_000_000_000.0) / commitNanos);

        assertEquals(fileCount, Files.list(targetDir.resolve("small_files")).count());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 4. SYNC ENGINE: LARGE DATASET & CONFLICT WORKLOADS
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkSyncEngineWorkloads() {
        SyncManifest localManifest = new SyncManifest("peerA");
        SyncManifest remoteManifest = new SyncManifest("peerB");

        for (int i = 0; i < 1000; i++) {
            ObjectId id = ObjectId.generate();
            ContentVersion cvA = new ContentVersion("peerA", 1);
            MetadataVersion mvA = MetadataVersion.initial("peerA");
            CausalVersion vA = CausalVersion.empty().increment("peerA");

            ContentVersion cvB = (i % 10 == 0) ? new ContentVersion("peerB", 2) : cvA;
            CausalVersion vB = (i % 10 == 0) ? vA.increment("peerB") : vA;

            localManifest.trackObject(new SyncObject(id, "docs/file_" + i + ".txt", "hash_" + i, 1024,
                    System.currentTimeMillis(), false, cvA, mvA, vA));
            remoteManifest.trackObject(new SyncObject(id, "docs/file_" + i + ".txt", "hash_remote_" + i, 1024,
                    System.currentTimeMillis(), false, cvB, mvA, vB));
        }

        ConflictDetector conflictDetector = new ConflictDetector();

        long startNanos = System.nanoTime();
        List<ConflictRecord> conflicts = conflictDetector.detect(localManifest, remoteManifest);
        long elapsedNanos = System.nanoTime() - startNanos;

        System.out.printf("[BENCHMARK] Sync Conflict Detection (1,000 objects): %.2f ms, detected=%d%n",
                elapsedNanos / 1_000_000.0, conflicts.size());

        assertTrue(elapsedNanos / 1_000_000.0 < 200.0, "Conflict detection over 1,000 objects should take < 200ms");

        // Conflict-heavy workload: 500 concurrent modifications
        SyncManifest heavyLocal = new SyncManifest("peerA");
        SyncManifest heavyRemote = new SyncManifest("peerB");
        for (int i = 0; i < 500; i++) {
            ObjectId id = ObjectId.generate();
            ContentVersion cvA = new ContentVersion("peerA", 2);
            ContentVersion cvB = new ContentVersion("peerB", 2);
            MetadataVersion mv = MetadataVersion.initial("peerA");
            CausalVersion vA = CausalVersion.empty().increment("peerA");
            CausalVersion vB = CausalVersion.empty().increment("peerB"); // strictly concurrent!

            heavyLocal.trackObject(new SyncObject(id, "conflicts/file_" + i + ".txt", "hashA_" + i, 2048,
                    System.currentTimeMillis(), false, cvA, mv, vA));
            heavyRemote.trackObject(new SyncObject(id, "conflicts/file_" + i + ".txt", "hashB_" + i, 2048,
                    System.currentTimeMillis(), false, cvB, mv, vB));
        }

        startNanos = System.nanoTime();
        List<ConflictRecord> heavyConflicts = conflictDetector.detect(heavyLocal, heavyRemote);
        elapsedNanos = System.nanoTime() - startNanos;

        System.out.printf("[BENCHMARK] Conflict-Heavy Detection (500 concurrent conflicts): %.2f ms, detected=%d%n",
                elapsedNanos / 1_000_000.0, heavyConflicts.size());
        assertEquals(500, heavyConflicts.size());
        assertTrue(elapsedNanos / 1_000_000.0 < 150.0, "Conflict detection over 500 items must be < 150ms");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. BACKUP ENGINE: FULL, INCREMENTAL, RESTORE
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkBackupAndRestore() throws IOException {
        InMemoryBackupTarget target = new InMemoryBackupTarget();
        BackupEngine backupEngine = new BackupEngine(target);

        // Generate 100 files in source dir
        for (int i = 0; i < 100; i++) {
            Files.writeString(backupSourceDir.resolve("doc_" + i + ".txt"), "Content of document " + i + " " + UUID.randomUUID());
        }

        BackupJobConfig config = new BackupJobConfig(
                "job_bench", "Benchmark Backup", backupSourceDir, "peer_target",
                RetentionPolicy.keepLastN(5), false, null, Set.of(), Set.of()
        );

        // Benchmark Full Backup
        long startNanos = System.nanoTime();
        BackupManifest fullManifest = backupEngine.performBackup(config, BackupType.FULL);
        long fullNanos = System.nanoTime() - startNanos;

        System.out.printf("[BENCHMARK] Full Backup (100 files): %.2f ms, items=%d%n",
                fullNanos / 1_000_000.0, fullManifest.getItems().size());
        assertEquals(100, fullManifest.getItems().size());

        // Modify 10 files
        for (int i = 0; i < 10; i++) {
            Files.writeString(backupSourceDir.resolve("doc_" + i + ".txt"), "UPDATED content " + UUID.randomUUID());
        }

        // Benchmark Incremental Backup
        startNanos = System.nanoTime();
        BackupManifest incManifest = backupEngine.performBackup(config, BackupType.INCREMENTAL);
        long incNanos = System.nanoTime() - startNanos;

        System.out.printf("[BENCHMARK] Incremental Backup (10 modified, 90 reused): %.2f ms%n",
                incNanos / 1_000_000.0);
        assertTrue(incNanos < fullNanos, "Incremental backup must be faster than full backup");

        // Benchmark Restore Execution
        Path restoreDest = tempDir.resolve("restored_dest");
        Files.createDirectories(restoreDest);

        Map<String, HistoricalVersion> itemsToRestore = new HashMap<>();
        for (var entry : incManifest.getItems().entrySet()) {
            itemsToRestore.put(entry.getKey().getValue(), entry.getValue());
        }

        RestorePlan plan = new RestorePlan(
                incManifest.getBackupId(),
                restoreDest,
                RestoreConflictPolicy.OVERWRITE_WITH_NEW_VERSION,
                itemsToRestore,
                List.of(),
                100 * 50,
                false
        );

        startNanos = System.nanoTime();
        RestoreExecutionResult restoreResult = RestoreExecutor.execute(plan, target, null, 1L);
        long restoreNanos = System.nanoTime() - startNanos;

        System.out.printf("[BENCHMARK] Restore Execution (100 files): %.2f ms, success=%b%n",
                restoreNanos / 1_000_000.0, restoreResult.success());

        assertTrue(restoreResult.success());
        assertEquals(100, Files.list(restoreDest).count());
    }
}
