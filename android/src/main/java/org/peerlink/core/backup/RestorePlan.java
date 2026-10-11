package org.peerlink.core.backup;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;

public record RestorePlan(
        String backupId,
        Path targetDirectory,
        RestoreConflictPolicy conflictPolicy,
        Map<String, HistoricalVersion> itemsToRestore,
        List<String> conflicts,
        long totalBytesToRestore,
        boolean requiresDecryption
) {
    public RestorePlan {
        itemsToRestore = Map.copyOf(itemsToRestore);
        conflicts = List.copyOf(conflicts);
    }
}