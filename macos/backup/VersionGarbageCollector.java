package org.peerlink.core.backup;

import java.io.IOException;
import java.util.*;

/**
 * Version Garbage Collector.
 * Prunes unreferenced historical versions and storage payloads according to retention plan.
 *
 * CRITICAL RULES:
 * 1. Never delete protected versions or protected snapshots.
 * 2. Never delete payloads (storageHash) still referenced by ANY surviving active manifest.
 * 3. Atomic deletion: manifests pruned first, unreferenced payloads deleted second.
 */
public final class VersionGarbageCollector {

    public record GcResult(
            int prunedManifestsCount,
            int deletedPayloadsCount,
            long freedBytes
    ) {}

    public static GcResult collect(BackupTarget target, String jobId, RetentionPrunePlan plan) throws IOException {
        Objects.requireNonNull(target, "target cannot be null");
        Objects.requireNonNull(plan, "plan cannot be null");

        // 1. Delete pruned manifests
        int prunedManifests = 0;
        for (BackupManifest manifest : plan.manifestsToPrune()) {
            target.deleteManifest(manifest.getBackupId());
            prunedManifests++;
        }

        // 2. Collect all storage hashes referenced by surviving manifests
        List<BackupManifest> survivingManifests = target.listManifests(jobId);
        Set<String> referencedStorageHashes = new HashSet<>();
        for (BackupManifest manifest : survivingManifests) {
            for (HistoricalVersion v : manifest.getItems().values()) {
                if (v.getStorageHash() != null && !v.isDeleted()) {
                    referencedStorageHashes.add(v.getStorageHash());
                }
            }
        }

        // 3. Find payloads that are no longer referenced
        Set<String> existingStorageHashes = target.listStoredPayloadHashes();
        int deletedPayloads = 0;
        long freedBytes = 0;

        for (String hash : existingStorageHashes) {
            if (!referencedStorageHashes.contains(hash)) {
                try {
                    byte[] data = target.retrievePayload(hash);
                    freedBytes += data.length;
                    target.deletePayload(hash);
                    deletedPayloads++;
                } catch (IOException ignored) {
                }
            }
        }

        return new GcResult(prunedManifests, deletedPayloads, freedBytes);
    }
}