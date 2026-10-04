package org.peerlink.core.backup;

import java.util.List;

public record RetentionPrunePlan(
        List<BackupManifest> manifestsToKeep,
        List<BackupManifest> manifestsToPrune,
        long estimatedReclaimableBytes
) {
    public RetentionPrunePlan {
        manifestsToKeep = List.copyOf(manifestsToKeep);
        manifestsToPrune = List.copyOf(manifestsToPrune);
    }
}