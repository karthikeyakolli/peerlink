package org.peerlink.core.transfer;

import org.peerlink.protocol.v1.ErrorDetail;
import org.peerlink.protocol.v1.TransferProgress;
import org.peerlink.protocol.v1.TransferState;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

/**
 * Thread-safe progress tracker for an active file transfer session.
 * Tracks bytes transferred, transfer rate (bps), state machine progress, and cancellation.
 */
public final class TransferProgressTracker {

    private final String transferId;
    private final long totalBytes;
    private final int totalItems;
    private final Consumer<TransferProgress> progressListener;

    private final AtomicLong transferredBytes = new AtomicLong(0);
    private final AtomicReference<TransferState> state = new AtomicReference<>(TransferState.TRANSFER_STATE_PREPARING);
    private final AtomicReference<String> currentFile = new AtomicReference<>("");
    private final AtomicLong currentItemIndex = new AtomicLong(0);
    private final AtomicReference<String> destinationPath = new AtomicReference<>("");

    private final AtomicBoolean cancelled = new AtomicBoolean(false);
    private final AtomicReference<String> cancelReason = new AtomicReference<>("");
    private final AtomicBoolean paused = new AtomicBoolean(false);
    private final AtomicReference<String> pauseReason = new AtomicReference<>("");

    private volatile long startTimeMs = System.currentTimeMillis();
    private volatile long lastProgressUpdateMs = System.currentTimeMillis();
    private volatile long lastBytesSample = 0;
    private volatile long currentSpeedBps = 0;
    private volatile ErrorDetail errorDetail = null;

    public TransferProgressTracker(String transferId, long totalBytes, int totalItems, Consumer<TransferProgress> progressListener) {
        this.transferId = transferId;
        this.totalBytes = totalBytes;
        this.totalItems = totalItems;
        this.progressListener = progressListener;
    }

    public void start() {
        this.startTimeMs = System.currentTimeMillis();
        this.lastProgressUpdateMs = startTimeMs;
        updateState(TransferState.TRANSFER_STATE_CONNECTING);
    }

    public void updateState(TransferState newState) {
        this.state.set(newState);
        notifyProgress();
    }

    public void setCurrentItem(int itemIndex, String fileName) {
        this.currentItemIndex.set(itemIndex);
        this.currentFile.set(fileName);
        notifyProgress();
    }

    public void setDestinationPath(String destPath) {
        this.destinationPath.set(destPath);
        notifyProgress();
    }

    public void addBytes(long bytes) {
        if (bytes <= 0) return;
        transferredBytes.addAndGet(bytes);

        long now = System.currentTimeMillis();
        long elapsedDelta = now - lastProgressUpdateMs;
        if (elapsedDelta >= 250) { // Update speed calculation every 250ms
            long currentBytes = transferredBytes.get();
            long deltaBytes = currentBytes - lastBytesSample;
            currentSpeedBps = (deltaBytes * 1000L) / Math.max(1, elapsedDelta);

            lastProgressUpdateMs = now;
            lastBytesSample = currentBytes;
            notifyProgress();
        }
    }

    public void pause(String reason) {
        TransferState current = state.get();
        if (current == TransferState.TRANSFER_STATE_COMPLETED || current == TransferState.TRANSFER_STATE_CANCELLED || current == TransferState.TRANSFER_STATE_FAILED) {
            return;
        }
        if (paused.compareAndSet(false, true)) {
            this.pauseReason.set(reason);
            this.currentSpeedBps = 0;
            this.state.set(TransferState.TRANSFER_STATE_PAUSED);
            notifyProgress();
        }
    }

    public void resume() {
        TransferState current = state.get();
        if (current == TransferState.TRANSFER_STATE_COMPLETED || current == TransferState.TRANSFER_STATE_CANCELLED || current == TransferState.TRANSFER_STATE_FAILED) {
            return;
        }
        if (paused.compareAndSet(true, false)) {
            this.pauseReason.set("");
            this.lastProgressUpdateMs = System.currentTimeMillis();
            this.state.set(TransferState.TRANSFER_STATE_TRANSFERRING);
            notifyProgress();
        }
    }

    public boolean isPaused() {
        return paused.get();
    }

    public String getPauseReason() {
        return pauseReason.get();
    }

    public void cancel(String reason) {
        if (cancelled.compareAndSet(false, true)) {
            this.cancelReason.set(reason);
            this.state.set(TransferState.TRANSFER_STATE_CANCELLED);
            notifyProgress();
        }
    }

    public boolean isCancelled() {
        return cancelled.get();
    }

    public String getCancelReason() {
        return cancelReason.get();
    }

    public void fail(String errorMessage) {
        TransferState current = state.get();
        // Do not override terminal/checkpoint states: a PAUSED transfer should survive service teardown
        // so the resume checkpoint is preserved (DEFECT-BETA-01 fix).
        if (current == TransferState.TRANSFER_STATE_COMPLETED
                || current == TransferState.TRANSFER_STATE_PAUSED
                || current == TransferState.TRANSFER_STATE_CANCELLED) {
            return;
        }
        this.state.set(TransferState.TRANSFER_STATE_FAILED);
        this.errorDetail = ErrorDetail.newBuilder()
                .setCode(org.peerlink.protocol.v1.ErrorCode.ERROR_CODE_INTERNAL_ERROR)
                .setHumanSummary(errorMessage)
                .build();
        notifyProgress();
    }

    public void complete() {
        this.state.set(TransferState.TRANSFER_STATE_COMPLETED);
        this.transferredBytes.set(totalBytes);
        this.currentSpeedBps = 0;
        notifyProgress();
    }

    public TransferProgress currentSnapshot() {
        TransferProgress.Builder builder = TransferProgress.newBuilder()
                .setTransferId(transferId)
                .setTransferredBytes(transferredBytes.get())
                .setTotalBytes(totalBytes)
                .setState(state.get())
                .setSpeedBps(currentSpeedBps)
                .setCurrentFile(currentFile.get())
                .setCurrentItemIndex((int) currentItemIndex.get())
                .setTotalItems(totalItems)
                .setDestinationPath(destinationPath.get());

        if (errorDetail != null) {
            builder.setError(errorDetail);
        }
        return builder.build();
    }

    private void notifyProgress() {
        if (progressListener != null) {
            progressListener.accept(currentSnapshot());
        }
    }

    public String getTransferId() { return transferId; }
    public TransferState getState() { return state.get(); }
    public long getTransferredBytes() { return transferredBytes.get(); }
    public long getTotalBytes() { return totalBytes; }
}
