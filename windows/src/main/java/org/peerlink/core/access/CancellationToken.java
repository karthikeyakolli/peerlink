package org.peerlink.core.access;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Thread-safe cooperative cancellation token for remote access operations.
 */
public final class CancellationToken {
    private final AtomicBoolean cancelled = new AtomicBoolean(false);
    private volatile String cancellationReason = "";

    public boolean isCancelled() {
        return cancelled.get();
    }

    public void cancel(String reason) {
        if (cancelled.compareAndSet(false, true)) {
            this.cancellationReason = (reason != null) ? reason : "Operation cancelled";
        }
    }

    public String getReason() {
        return cancellationReason;
    }

    public void throwIfCancelled() throws OperationCancelledException {
        if (isCancelled()) {
            throw new OperationCancelledException(cancellationReason);
        }
    }

    public static class OperationCancelledException extends Exception {
        public OperationCancelledException(String message) {
            super(message);
        }
    }
}
