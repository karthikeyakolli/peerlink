package org.peerlink.core.sharing;

public final class OneTimeConsumptionTracker {
    private volatile boolean consumed = false;
    private volatile String consumedByOperationId = "";
    private volatile long consumedAtUtcMs = 0L;

    public synchronized boolean isOperationPermitted(String operationId) {
        if (operationId == null || operationId.isBlank()) return false;
        if (!consumed) return true;
        return operationId.equals(consumedByOperationId);
    }

    public synchronized boolean markConsumed(String operationId, long nowUtcMs) {
        if (operationId == null || operationId.isBlank()) return false;
        if (!consumed) {
            this.consumed = true;
            this.consumedByOperationId = operationId;
            this.consumedAtUtcMs = nowUtcMs;
            return true;
        }
        return operationId.equals(consumedByOperationId);
    }

    public boolean isConsumed() { return consumed; }
    public String getConsumedByOperationId() { return consumedByOperationId; }
    public long getConsumedAtUtcMs() { return consumedAtUtcMs; }
}