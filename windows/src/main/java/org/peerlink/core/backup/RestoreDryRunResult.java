package org.peerlink.core.backup;

import java.util.List;

public record RestoreDryRunResult(
        boolean canSucceed,
        int itemsToCreate,
        int itemsToUpdate,
        int itemsConflicting,
        long totalBytes,
        List<String> plannedActions
) {
    public RestoreDryRunResult {
        plannedActions = List.copyOf(plannedActions);
    }
}