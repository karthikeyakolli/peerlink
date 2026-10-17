package org.peerlink.core.transfer;

import java.nio.file.Path;
import java.util.List;

public class PeerTransferEngine {
    public record StartupReconciliationReport(
            int examinedSessions,
            int recoveredCompleted,
            int pausedForResume,
            int markedFailed,
            int uncertainPartials,
            List<String> diagnostics
    ) {
        public String summary() {
            return String.format("examined=%d recoveredCompleted=%d pausedForResume=%d markedFailed=%d uncertainPartials=%d",
                    examinedSessions, recoveredCompleted, pausedForResume, markedFailed, uncertainPartials);
        }
    }

    public StartupReconciliationReport reconcileAtStartup(Path defaultDestinationDir) {
        return new StartupReconciliationReport(0, 0, 0, 0, 0, List.of());
    }
}
