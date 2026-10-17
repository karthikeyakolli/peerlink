package org.peerlink.core.transfer.multipath;

/**
 * Summary metrics of a completed multipath bonded transfer.
 */
public record MultipathTransferResult(
        boolean isSuccess,
        int completedChunks,
        int activeLanes,
        long elapsedDurationMs,
        String failureReason
) {
    public static MultipathTransferResult success(int completedChunks, int activeLanes, long elapsedMs) {
        return new MultipathTransferResult(true, completedChunks, activeLanes, elapsedMs, null);
    }

    public static MultipathTransferResult failed(int completedChunks, int activeLanes, long elapsedMs, String reason) {
        return new MultipathTransferResult(false, completedChunks, activeLanes, elapsedMs, reason);
    }
}
