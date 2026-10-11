package org.peerlink.core.backup;

import java.util.List;

public record RestoreExecutionResult(
        String restoreId,
        String backupId,
        boolean success,
        int restoredFilesCount,
        long restoredBytes,
        long newVersionSequenceCreated,
        List<String> errors
) {
    public RestoreExecutionResult {
        errors = List.copyOf(errors);
    }
}