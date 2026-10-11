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
}
