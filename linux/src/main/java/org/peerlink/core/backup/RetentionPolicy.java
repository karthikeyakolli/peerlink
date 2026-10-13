package org.peerlink.core.backup;

import java.util.*;

/**
 * Immutable retention policy defining rules for preserving and pruning snapshot manifests.
 * Rules:
 * - maxSnapshots: keep at most N latest snapshots
 * - maxAgeMs: prune snapshots older than maxAgeMs
 * - PROTECTED VERSIONS AND PROTECTED SNAPSHOTS ARE IMMUNE TO RETENTION PRUNING.
 */
public final class RetentionPolicy {
    private final int maxSnapshots;
    private final long maxAgeMs;

    public RetentionPolicy(int maxSnapshots, long maxAgeMs) {
        if (maxSnapshots < 1) throw new IllegalArgumentException("maxSnapshots must be >= 1");
        this.maxSnapshots = maxSnapshots;
        this.maxAgeMs = maxAgeMs;
    }

    public static RetentionPolicy keepLastN(int n) {
        return new RetentionPolicy(n, Long.MAX_VALUE);
    }

    public static RetentionPolicy keepWithinAge(long maxAgeMs) {
        return new RetentionPolicy(Integer.MAX_VALUE, maxAgeMs);
    }

    public static RetentionPolicy combine(int maxSnapshots, long maxAgeMs) {
        return new RetentionPolicy(maxSnapshots, maxAgeMs);
    }

    public int getMaxSnapshots() { return maxSnapshots; }
    public long getMaxAgeMs() { return maxAgeMs; }

    public RetentionPrunePlan evaluate(List<BackupManifest> manifests,
                                       Set<String> protectedSnapshotIds,
                                       long currentTimeUtcMs) {
        return evaluate(manifests, protectedSnapshotIds, Collections.emptySet(), currentTimeUtcMs);
    }

    public RetentionPrunePlan evaluate(List<BackupManifest> manifests,
                                       Set<String> protectedSnapshotIds,
                                       Set<String> activeLockedSnapshotIds,
                                       long currentTimeUtcMs) {
        Objects.requireNonNull(manifests, "manifests cannot be null");
        Objects.requireNonNull(protectedSnapshotIds, "protectedSnapshotIds cannot be null");

        // Sort descending by timestamp (newest first)
        List<BackupManifest> sorted = new ArrayList<>(manifests);
        sorted.sort((a, b) -> Long.compare(b.getSnapshotTimestampUtcMs(), a.getSnapshotTimestampUtcMs()));

        List<BackupManifest> toKeep = new ArrayList<>();
        List<BackupManifest> toPrune = new ArrayList<>();

        int retainedCount = 0;
        for (BackupManifest manifest : sorted) {
            boolean isProtected = protectedSnapshotIds.contains(manifest.getBackupId())
                    || (activeLockedSnapshotIds != null && activeLockedSnapshotIds.contains(manifest.getBackupId()))
                    || manifest.hasProtectedItems();

            if (isProtected) {
                toKeep.add(manifest);
                continue;
            }

            long age = currentTimeUtcMs - manifest.getSnapshotTimestampUtcMs();
            boolean ageExceeded = maxAgeMs < Long.MAX_VALUE && age > maxAgeMs;
            boolean countExceeded = retainedCount >= maxSnapshots;

            if (ageExceeded || countExceeded) {
                toPrune.add(manifest);
            } else {
                toKeep.add(manifest);
                retainedCount++;
            }
        }

        long estimatedReclaimableBytes = toPrune.stream().mapToLong(BackupManifest::getTotalBytes).sum();
        return new RetentionPrunePlan(toKeep, toPrune, estimatedReclaimableBytes);
    }
}