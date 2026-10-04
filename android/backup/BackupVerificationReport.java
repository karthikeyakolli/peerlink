package org.peerlink.core.backup;

import java.util.List;

public record BackupVerificationReport(
        boolean passed,
        long verifiedFiles,
        long verifiedBytes,
        List<String> missingPayloads,
        List<String> corruptedItems,
        boolean reconstructable
) {
    public BackupVerificationReport {
        missingPayloads = List.copyOf(missingPayloads);
        corruptedItems = List.copyOf(corruptedItems);
    }
}