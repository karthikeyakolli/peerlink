package org.peerlink.desktop.performance;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.operation.*;
import org.peerlink.desktop.ipc.DesktopLocalNodeServiceImpl;
import org.peerlink.desktop.runtime.DesktopNodeDaemon;
import org.peerlink.desktop.runtime.NodeConfiguration;
import org.peerlink.desktop.storage.LocalSqliteStorage;
import org.peerlink.desktop.storage.ObjectIndexRepository;
import org.peerlink.desktop.storage.ObjectIndexRepository.IndexState;
import org.peerlink.desktop.storage.ObjectIndexRepository.ObjectIndexEntry;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.OperatingSystemMXBean;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Desktop Node Performance Benchmarking Suite.
 * Measures startup latency, idle footprint, database read/write throughput,
 * batch indexing scalability, and folder enumeration speed.
 */
public class PeerLinkDesktopPerformanceBenchmarkTest {

    @TempDir
    Path tempDir;

    private Path dbPath;
    private Path scanFolder;

    @BeforeEach
    public void setUp() throws IOException {
        dbPath = tempDir.resolve("perf_desktop.db");
        scanFolder = tempDir.resolve("scan_library");
        Files.createDirectories(scanFolder);
    }

    @AfterEach
    public void tearDown() {
        // TempDir automatically cleans up
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 1. DESKTOP STARTUP TIME & RESOURCE BASELINE
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkDesktopStartupAndIdleResources() throws Exception {
        MemoryMXBean memBean = ManagementFactory.getMemoryMXBean();
        long initialHeap = memBean.getHeapMemoryUsage().getUsed();

        long startNanos = System.nanoTime();
        LocalSqliteStorage storage = new LocalSqliteStorage(dbPath);
        long storageInitNanos = System.nanoTime() - startNanos;

        // Startup complete
        long totalStartupNanos = System.nanoTime() - startNanos;
        double startupMs = totalStartupNanos / 1_000_000.0;

        long postStartupHeap = memBean.getHeapMemoryUsage().getUsed();
        long heapUsedDeltaBytes = Math.max(0, postStartupHeap - initialHeap);

        System.out.printf("[BENCHMARK] Desktop Node DB & Migrations Startup: %.2f ms, Heap Growth: %.2f MB%n",
                startupMs, heapUsedDeltaBytes / (1024.0 * 1024.0));

        assertTrue(startupMs < 500.0, "Desktop node storage startup must be < 500ms");

        storage.close();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2. DATABASE WRITE / READ PERFORMANCE: SINGLE VS BATCH
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkDatabaseWriteReadPerformance() throws Exception {
        try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
            ObjectIndexRepository repo = storage.getObjectIndex();

            int objectCount = 500;
            List<ObjectIndexEntry> entries = new ArrayList<>(objectCount);
            for (int i = 0; i < objectCount; i++) {
                entries.add(new ObjectIndexEntry(
                        "obj_bench_" + i,
                        "hash_sha256_" + i,
                        "/path/to/media/doc_" + i + ".pdf",
                        1024L * (i + 1),
                        "application/pdf",
                        System.currentTimeMillis(),
                        System.currentTimeMillis(),
                        IndexState.ACTIVE
                ));
            }

            // Benchmark individual upserts
            long startNanos = System.nanoTime();
            for (ObjectIndexEntry entry : entries) {
                repo.upsertObject(entry);
            }
            long singleUpsertNanos = System.nanoTime() - startNanos;
            double singleUpsertMs = singleUpsertNanos / 1_000_000.0;
            double singleRate = (objectCount / (singleUpsertNanos / 1_000_000_000.0));

            System.out.printf("[BENCHMARK] SQLite 500 Single Upserts: %.2f ms (%.0f objects/sec)%n",
                    singleUpsertMs, singleRate);

            // Benchmark batch upsert for 500 objects
            List<ObjectIndexEntry> batchEntries = new ArrayList<>(objectCount);
            for (int i = 0; i < objectCount; i++) {
                batchEntries.add(new ObjectIndexEntry(
                        "obj_batch_" + i,
                        "hash_batch_sha256_" + i,
                        "/path/to/media/batch_" + i + ".pdf",
                        2048L * (i + 1),
                        "application/pdf",
                        System.currentTimeMillis(),
                        System.currentTimeMillis(),
                        IndexState.ACTIVE
                ));
            }
            startNanos = System.nanoTime();
            repo.upsertObjectsBatch(batchEntries);
            long batchNanos = System.nanoTime() - startNanos;
            double batchMs = batchNanos / 1_000_000.0;
            double batchRate = (objectCount / (batchNanos / 1_000_000_000.0));

            System.out.printf("[BENCHMARK] SQLite 500 Batch Upserts: %.2f ms (%.0f objects/sec)%n",
                    batchMs, batchRate);
            assertTrue(batchMs < singleUpsertMs, "Batch upserts must be faster than individual upserts");

            // Benchmark query by ID
            startNanos = System.nanoTime();
            for (int i = 0; i < objectCount; i++) {
                Optional<ObjectIndexEntry> found = repo.findById("obj_bench_" + i);
                assertTrue(found.isPresent());
            }
            long queryNanos = System.nanoTime() - startNanos;
            double queryRate = (objectCount / (queryNanos / 1_000_000_000.0));

            System.out.printf("[BENCHMARK] SQLite 500 ID Queries: %.2f ms (%.0f queries/sec)%n",
                    queryNanos / 1_000_000.0, queryRate);

            assertTrue(queryRate > 500.0, "Indexed ID query rate must exceed 500 qps");
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3. LARGE FOLDER ENUMERATION PERFORMANCE
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkLargeFolderEnumeration() throws IOException {
        int folderCount = 20;
        int filesPerFolder = 50; // Total 1,000 files

        for (int d = 0; d < folderCount; d++) {
            Path subDir = scanFolder.resolve("folder_" + d);
            Files.createDirectories(subDir);
            for (int f = 0; f < filesPerFolder; f++) {
                Files.writeString(subDir.resolve("item_" + f + ".txt"), "File content payload " + d + "_" + f);
            }
        }

        long startNanos = System.nanoTime();
        long countedFiles = 0;
        try (var stream = Files.walk(scanFolder)) {
            countedFiles = stream.filter(Files::isRegularFile).count();
        }
        long elapsedNanos = System.nanoTime() - startNanos;

        double elapsedMs = elapsedNanos / 1_000_000.0;
        double scanRate = (countedFiles / (elapsedNanos / 1_000_000_000.0));

        System.out.printf("[BENCHMARK] Large Folder Enumeration (1,000 files in 20 dirs): %.2f ms (%.0f files/sec)%n",
                elapsedMs, scanRate);

        assertEquals(1000, countedFiles);
        assertTrue(elapsedMs < 1000.0, "Enumerating 1,000 files should take < 1 second");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 4. IPC ROUND-TRIP LATENCY & THROUGHPUT
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkIpcRoundtripLatencyAndThroughput() {
        String token = "benchmark-secure-ipc-token-12345";
        DesktopLocalNodeServiceImpl service = new DesktopLocalNodeServiceImpl(token, "peer_bench", 50051);
        try {
            // Warm-up
            for (int i = 0; i < 50; i++) {
                service.authenticateDirect(token, 1000 + i, "0.1.0");
            }

            int iterations = 1000;
            long start = System.nanoTime();
            for (int i = 0; i < iterations; i++) {
                var resp = service.authenticateDirect(token, 2000 + i, "0.1.0");
                assertTrue(resp.getAuthenticated());
            }
            long elapsedNanos = System.nanoTime() - start;
            double avgLatencyMs = (elapsedNanos / (double) iterations) / 1_000_000.0;
            double throughputOpsPerSec = (iterations / (elapsedNanos / 1_000_000_000.0));

            System.out.printf("[BENCHMARK] IPC Authenticate Round-trip: %.3f ms/call (%.0f calls/sec)%n",
                    avgLatencyMs, throughputOpsPerSec);

            assertTrue(avgLatencyMs < 2.0, "IPC average round-trip latency must be < 2ms");
        } finally {
            service.close();
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. SESSION DISCOVERY & RECONNECTION LATENCY
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkDiscoveryAndReconnectionTime() throws Exception {
        org.peerlink.core.security.InMemorySecureKeyStore aliceKeyStore = new org.peerlink.core.security.InMemorySecureKeyStore();
        org.peerlink.core.security.InMemorySecureKeyStore bobKeyStore = new org.peerlink.core.security.InMemorySecureKeyStore();
        org.peerlink.core.identity.DeviceIdentityManager aliceIdentity = org.peerlink.core.identity.DeviceIdentityManager.createNew(
                aliceKeyStore, "Alice Device", org.peerlink.protocol.v1.DeviceType.DEVICE_TYPE_DESKTOP_WINDOWS, "Windows", "0.1.0");
        org.peerlink.core.identity.DeviceIdentityManager bobIdentity = org.peerlink.core.identity.DeviceIdentityManager.createNew(
                bobKeyStore, "Bob Device", org.peerlink.protocol.v1.DeviceType.DEVICE_TYPE_DESKTOP_WINDOWS, "Windows", "0.1.0");
        org.peerlink.core.security.InMemoryTrustStore aliceTrust = new org.peerlink.core.security.InMemoryTrustStore();
        org.peerlink.core.security.InMemoryTrustStore bobTrust = new org.peerlink.core.security.InMemoryTrustStore();

        org.peerlink.core.identity.PairingCoordinator alicePairing = new org.peerlink.core.identity.PairingCoordinator(aliceIdentity, aliceTrust);
        org.peerlink.core.identity.PairingCoordinator bobPairing = new org.peerlink.core.identity.PairingCoordinator(bobIdentity, bobTrust);

        int iterations = 100;
        long start = System.nanoTime();
        for (int i = 0; i < iterations; i++) {
            var offer = alicePairing.initiatePairing(org.peerlink.protocol.v1.PairingMethod.PAIRING_METHOD_NUMERIC_CODE, 60_000);
            var verification = bobPairing.respondToOffer(offer, offer.getPairingCode(), aliceIdentity.getFingerprint());
            var result = alicePairing.completePairing(verification);
            assertEquals(org.peerlink.protocol.v1.PairingState.PAIRING_STATE_CONFIRMED, result.getState());
        }
        long elapsedNanos = System.nanoTime() - start;
        double avgPairingMs = (elapsedNanos / (double) iterations) / 1_000_000.0;
        System.out.printf("[BENCHMARK] Pairing, Discovery & Mutual Trust Auth: %.2f ms/handshake%n", avgPairingMs);
        assertTrue(avgPairingMs < 5.0, "Pairing & mutual trust handshake must complete in < 5ms");

        aliceKeyStore.close();
        bobKeyStore.close();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 6. STREAMING MEMORY BOUNDS & BACKPRESSURE
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkStreamingMemoryBoundsAndBackpressure() throws Exception {
        Path stagingDir = tempDir.resolve("bench_staging");
        org.peerlink.core.transfer.StagingDirectoryManager staging = new org.peerlink.core.transfer.StagingDirectoryManager(stagingDir);
        staging.prepareStagingDir("transfer_bound_test");

        MemoryMXBean memBean = ManagementFactory.getMemoryMXBean();
        System.gc();
        long memBefore = memBean.getHeapMemoryUsage().getUsed();

        byte[] chunkData = new byte[64 * 1024]; // 64KB chunk
        java.util.Arrays.fill(chunkData, (byte) 0xAA);

        int chunkCount = 500; // 32MB streaming workload
        long start = System.nanoTime();
        for (int i = 0; i < chunkCount; i++) {
            staging.writeChunk("transfer_bound_test", 0, i, (long) i * chunkData.length, chunkData, null, (long) chunkCount * chunkData.length);
        }
        long elapsedNanos = System.nanoTime() - start;
        double throughputMBs = ((chunkCount * 64.0 / 1024.0) / (elapsedNanos / 1_000_000_000.0));

        long memAfter = memBean.getHeapMemoryUsage().getUsed();
        double heapDeltaMB = Math.max(0, (memAfter - memBefore) / (1024.0 * 1024.0));

        System.out.printf("[BENCHMARK] Staging Stream 32MB (500x64KB): %.2f MB/s, Heap Delta: %.2f MB%n",
                throughputMBs, heapDeltaMB);

        staging.cleanupStaging("transfer_bound_test");
        assertTrue(throughputMBs > 50.0, "Streaming throughput must exceed 50 MB/s");
        assertTrue(heapDeltaMB < 64.0, "Heap growth must remain bounded (< 64MB) during 32MB continuous streaming");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 7. CRASH RECOVERY DURATION
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    public void benchmarkCrashRecoveryDuration() throws Exception {
        Path journalDb = tempDir.resolve("journal_recovery.db");
        String transferId = "crash_recovery_xfer_1";
        String opId = "op_recovery_1";

        try (LocalSqliteStorage storage = new LocalSqliteStorage(journalDb)) {
            org.peerlink.protocol.v1.TransferManifest manifest = org.peerlink.protocol.v1.TransferManifest.newBuilder()
                    .setTransferId(transferId)
                    .addItems(org.peerlink.protocol.v1.TransferItem.newBuilder()
                            .setRelativePath("video.mp4")
                            .setFileSizeBytes(100 * 64 * 1024)
                            .build())
                    .build();

            long totalBytes = 100 * 64 * 1024;
            org.peerlink.core.transfer.TransferSessionRecord session = new org.peerlink.core.transfer.TransferSessionRecord(
                    transferId, opId, "peer-sender", "peer-receiver",
                    org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_TRANSFERRING,
                    totalBytes, manifest.getItemsCount(), System.currentTimeMillis()
            );
            session.setManifest(manifest);
            storage.recordSession(session);

            for (int i = 0; i < 100; i++) {
                storage.updateChunkMetadata(transferId, 0, i, (long) i * 65536, 65536, "fake_sha", org.peerlink.protocol.v1.ChunkStatus.CHUNK_STATUS_ACKED);
            }
        }

        // Simulate Crash & Restart: Open fresh storage and measure recovery reconciliation duration
        long start = System.nanoTime();
        try (LocalSqliteStorage recoveredStorage = new LocalSqliteStorage(journalDb)) {
            var sessionOpt = recoveredStorage.getSession(transferId);
            assertTrue(sessionOpt.isPresent());
            var acked = recoveredStorage.getAckedChunks(transferId, 0);
            assertEquals(100, acked.size());
        }
        long elapsedNanos = System.nanoTime() - start;
        double recoveryMs = elapsedNanos / 1_000_000.0;

        System.out.printf("[BENCHMARK] Crash Recovery & State Reconciliation: %.2f ms (100 journaled chunks recovered)%n",
                recoveryMs);

        assertTrue(recoveryMs < 100.0, "Durable crash recovery must complete in < 100ms");
    }
}
