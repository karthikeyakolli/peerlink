package org.peerlink.core.sync;

import java.util.List;

/** Result of a synchronization operation. */
public final class SyncOutcome {

    public enum Status { COMPLETED, PAUSED, FAILED, DRY_RUN }

    private final Status status;
    private final int changesApplied;
    private final int conflictsDetected;
    private final boolean hasUnresolvedConflicts;
    private final List<String> pauseReasons;
    private final String failureReason;
    private final SyncDryRunResult dryRunResult;

    private SyncOutcome(Status status, int changesApplied, int conflictsDetected,
                         boolean hasUnresolvedConflicts, List<String> pauseReasons,
                         String failureReason, SyncDryRunResult dryRunResult) {
        this.status = status;
        this.changesApplied = changesApplied;
        this.conflictsDetected = conflictsDetected;
        this.hasUnresolvedConflicts = hasUnresolvedConflicts;
        this.pauseReasons = pauseReasons;
        this.failureReason = failureReason;
        this.dryRunResult = dryRunResult;
    }

    public static SyncOutcome completed(int applied, int conflicts, boolean hasUnresolved) {
        return new SyncOutcome(Status.COMPLETED, applied, conflicts, hasUnresolved, List.of(), null, null);
    }

    public static SyncOutcome paused(List<String> reasons) {
        return new SyncOutcome(Status.PAUSED, 0, 0, false, reasons, null, null);
    }

    public static SyncOutcome failed(String reason) {
        return new SyncOutcome(Status.FAILED, 0, 0, false, List.of(), reason, null);
    }

    public static SyncOutcome dryRun(SyncDryRunResult result) {
        return new SyncOutcome(Status.DRY_RUN, 0, result.wouldConflict().size(),
                !result.wouldConflict().isEmpty(), List.of(), null, result);
    }

    public Status getStatus() { return status; }
    public int getChangesApplied() { return changesApplied; }
    public int getConflictsDetected() { return conflictsDetected; }
    public boolean hasUnresolvedConflicts() { return hasUnresolvedConflicts; }
    public List<String> getPauseReasons() { return pauseReasons; }
    public String getFailureReason() { return failureReason; }
    public SyncDryRunResult getDryRunResult() { return dryRunResult; }
    public boolean isCompleted() { return status == Status.COMPLETED; }
    public boolean isPaused() { return status == Status.PAUSED; }
    public boolean isFailed() { return status == Status.FAILED; }

    @Override
    public String toString() {
        return "SyncOutcome{status=" + status + ", applied=" + changesApplied
                + ", conflicts=" + conflictsDetected + "}";
    }
}