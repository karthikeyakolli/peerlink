package org.peerlink.core.backup;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * Plans restore actions and detects potential conflicts before execution.
 */
public final class RestorePlanner {

    public static RestorePlan plan(BackupManifest manifest,
                                   Path targetDirectory,
                                   RestoreConflictPolicy policy,
                                   Set<String> selectedPaths) throws IOException {
        Objects.requireNonNull(manifest, "manifest cannot be null");
        Objects.requireNonNull(targetDirectory, "targetDirectory cannot be null");
        Objects.requireNonNull(policy, "policy cannot be null");

        Map<String, HistoricalVersion> itemsToRestore = new HashMap<>();
        List<String> conflicts = new ArrayList<>();
        long totalBytes = 0;

        for (HistoricalVersion item : manifest.getItems().values()) {
            if (item.isDeleted()) continue;
            if (selectedPaths != null && !selectedPaths.isEmpty() && !selectedPaths.contains(item.getRelativePath())) {
                continue;
            }

            itemsToRestore.put(item.getRelativePath(), item);
            totalBytes += item.getSizeBytes();

            Path localFile = targetDirectory.resolve(item.getRelativePath());
            if (Files.exists(localFile)) {
                byte[] existingBytes = Files.readAllBytes(localFile);
                if (item.getContentHash() != null && !item.getContentHash().matches(existingBytes)) {
                    conflicts.add(item.getRelativePath() + " (existing file differs)");
                }
            }
        }

        return new RestorePlan(manifest.getBackupId(), targetDirectory, policy,
                itemsToRestore, conflicts, totalBytes, manifest.isBlind());
    }

    public static RestoreDryRunResult dryRun(RestorePlan plan) {
        Objects.requireNonNull(plan, "plan cannot be null");

        int createCount = 0;
        int updateCount = 0;
        List<String> actions = new ArrayList<>();

        for (Map.Entry<String, HistoricalVersion> entry : plan.itemsToRestore().entrySet()) {
            String path = entry.getKey();
            Path localFile = plan.targetDirectory().resolve(path);
            if (Files.exists(localFile)) {
                updateCount++;
                actions.add("UPDATE: " + path + " (version sequence -> new successor)");
            } else {
                createCount++;
                actions.add("CREATE: " + path);
            }
        }

        boolean canSucceed = true;
        if (!plan.conflicts().isEmpty() && plan.conflictPolicy() == RestoreConflictPolicy.FAIL_ON_CONFLICT) {
            canSucceed = false;
            actions.add("ABORT: Conflicting files detected under FAIL_ON_CONFLICT policy");
        }

        return new RestoreDryRunResult(canSucceed, createCount, updateCount,
                plan.conflicts().size(), plan.totalBytesToRestore(), actions);
    }
}