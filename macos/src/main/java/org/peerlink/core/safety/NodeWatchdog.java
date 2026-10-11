package org.peerlink.core.safety;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.ThreadMXBean;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;

/**
 * Watchdog and self-healing monitor for the Local Node.
 *
 * <p>Enforces Section 14 requirements:
 * <ul>
 *   <li>Local Node health detection (DB integrity, memory, deadlocks)</li>
 *   <li>Stale temporary file and staging cleanup</li>
 *   <li>Stale session cleanup</li>
 *   <li>Restart loop prevention (inhibit automatic restart if excessive crashes occur)</li>
 *   <li>Journal reconciliation checks</li>
 * </ul>
 */
public final class NodeWatchdog {
    private static final Logger log = LoggerFactory.getLogger(NodeWatchdog.class);

    public static final int MAX_RESTARTS_PER_WINDOW = 3;
    public static final long RESTART_WINDOW_MS = 5 * 60 * 1000L; // 5 minutes
    public static final long DEFAULT_STALE_TEMP_AGE_MS = 2 * 3600 * 1000L; // 2 hours

    public record HealthReport(
            Instant checkedAt,
            boolean healthy,
            boolean dbIntegrityOk,
            boolean hasDeadlockedThreads,
            long memoryUsedBytes,
            long memoryMaxBytes,
            int cleanedStaleFiles,
            int cleanedStaleSessions,
            boolean restartLoopInhibited,
            List<String> warnings
    ) {}

    private final Path stagingRoot;
    private final BooleanSupplier dbIntegrityChecker;
    private final Supplier<Integer> staleSessionCleaner;
    private final Runnable reconciliationTrigger;
    private final List<Long> restartTimestamps = new CopyOnWriteArrayList<>();
    private final AtomicInteger consecutiveFailures = new AtomicInteger(0);

    public NodeWatchdog(
            Path stagingRoot,
            BooleanSupplier dbIntegrityChecker,
            Supplier<Integer> staleSessionCleaner,
            Runnable reconciliationTrigger) {
        this.stagingRoot = stagingRoot;
        this.dbIntegrityChecker = dbIntegrityChecker != null ? dbIntegrityChecker : () -> true;
        this.staleSessionCleaner = staleSessionCleaner != null ? staleSessionCleaner : () -> 0;
        this.reconciliationTrigger = reconciliationTrigger != null ? reconciliationTrigger : () -> {};
    }

    /**
     * Inspects node health and triggers self-healing passes.
     */
    public HealthReport inspectAndHeal() {
        Instant now = Instant.now();
        List<String> warnings = new ArrayList<>();

        // 1. Database Integrity Check
        boolean dbOk = false;
        try {
            dbOk = dbIntegrityChecker.getAsBoolean();
            if (!dbOk) {
                warnings.add("Database integrity check reported corruption");
            }
        } catch (Exception e) {
            warnings.add("Database check threw exception: " + e.getMessage());
        }

        // 2. Thread Deadlock Detection
        boolean deadlocks = false;
        ThreadMXBean threadBean = ManagementFactory.getThreadMXBean();
        long[] deadlockedIds = threadBean.findDeadlockedThreads();
        if (deadlockedIds != null && deadlockedIds.length > 0) {
            deadlocks = true;
            warnings.add("Detected " + deadlockedIds.length + " deadlocked threads!");
        }

        // 3. Memory Consumption
        Runtime runtime = Runtime.getRuntime();
        long usedMem = runtime.totalMemory() - runtime.freeMemory();
        long maxMem = runtime.maxMemory();
        if (maxMem > 0 && (double) usedMem / maxMem > 0.90) {
            warnings.add("High memory utilization (>90%): " + (usedMem / 1024 / 1024) + "MB / " + (maxMem / 1024 / 1024) + "MB");
        }

        // 4. Stale Temporary/Staging File Cleanup
        int cleanedFiles = 0;
        if (stagingRoot != null && Files.exists(stagingRoot)) {
            cleanedFiles = cleanupStaleFiles(stagingRoot, DEFAULT_STALE_TEMP_AGE_MS);
        }

        // 5. Stale Session Cleanup
        int cleanedSessions = 0;
        try {
            cleanedSessions = staleSessionCleaner.get();
        } catch (Exception e) {
            warnings.add("Failed to clean stale sessions: " + e.getMessage());
        }

        // 6. Trigger Journal Reconciliation if necessary
        try {
            reconciliationTrigger.run();
        } catch (Exception e) {
            warnings.add("Journal reconciliation warning: " + e.getMessage());
        }

        boolean restartInhibited = isRestartLoopDetected();
        if (restartInhibited) {
            warnings.add("Restart loop protection active: excessive restart attempts detected");
        }

        boolean overallHealthy = dbOk && !deadlocks && warnings.isEmpty();
        if (!overallHealthy) {
            consecutiveFailures.incrementAndGet();
        } else {
            consecutiveFailures.set(0);
        }

        return new HealthReport(
                now,
                overallHealthy,
                dbOk,
                deadlocks,
                usedMem,
                maxMem,
                cleanedFiles,
                cleanedSessions,
                restartInhibited,
                warnings
        );
    }

    /**
     * Record a restart attempt and check whether a restart loop is in progress.
     */
    public synchronized boolean recordRestartAndCheckPermitted() {
        long now = System.currentTimeMillis();
        restartTimestamps.removeIf(ts -> now - ts > RESTART_WINDOW_MS);
        restartTimestamps.add(now);

        if (restartTimestamps.size() > MAX_RESTARTS_PER_WINDOW) {
            log.error("CRITICAL: Restart loop detected! {} restarts in {} ms. Inhibiting further automatic restarts.",
                    restartTimestamps.size(), RESTART_WINDOW_MS);
            return false;
        }
        return true;
    }

    public synchronized boolean isRestartLoopDetected() {
        long now = System.currentTimeMillis();
        restartTimestamps.removeIf(ts -> now - ts > RESTART_WINDOW_MS);
        return restartTimestamps.size() > MAX_RESTARTS_PER_WINDOW;
    }

    public int cleanupStaleFiles(Path directory, long maxAgeMs) {
        long cutoff = System.currentTimeMillis() - maxAgeMs;
        int cleaned = 0;
        try {
            cleaned = cleanupRecursive(directory, cutoff);
        } catch (Exception e) {
            log.warn("Error cleaning stale files in {}: {}", directory, e.getMessage());
        }
        return cleaned;
    }

    private int cleanupRecursive(Path dir, long cutoff) throws IOException {
        int count = 0;
        if (!Files.exists(dir) || !Files.isDirectory(dir)) return 0;

        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dir)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry)) {
                    count += cleanupRecursive(entry, cutoff);
                    try {
                        // Attempt to remove empty directory
                        Files.deleteIfExists(entry);
                    } catch (Exception ignored) {}
                } else {
                    long lastModified = Files.getLastModifiedTime(entry).toMillis();
                    if (lastModified < cutoff) {
                        try {
                            Files.deleteIfExists(entry);
                            count++;
                        } catch (Exception ignored) {}
                    }
                }
            }
        }
        return count;
    }

    public int getConsecutiveFailures() {
        return consecutiveFailures.get();
    }
}
