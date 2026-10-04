package org.peerlink.core.operation;

import java.io.Serializable;
import java.util.*;

/**
 * Immutable durable operation record.
 */
public final class OperationRecord implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String operationId;
    private final OperationIntent intent;
    private final String actorPeerId;
    private final List<String> targetObjectIds;
    private final OperationState state;
    private final String idempotencyKey;
    private final long createdAtUtcMs;
    private final long updatedAtUtcMs;

    public OperationRecord(
            String operationId,
            OperationIntent intent,
            String actorPeerId,
            List<String> targetObjectIds,
            OperationState state,
            String idempotencyKey,
            long createdAtUtcMs,
            long updatedAtUtcMs) {
        this.operationId = Objects.requireNonNull(operationId, "operationId is required");
        this.intent = Objects.requireNonNull(intent, "intent is required");
        this.actorPeerId = Objects.requireNonNull(actorPeerId, "actorPeerId is required");
        this.targetObjectIds = List.copyOf(Objects.requireNonNull(targetObjectIds));
        this.state = Objects.requireNonNull(state, "state is required");
        this.idempotencyKey = Objects.requireNonNull(idempotencyKey, "idempotencyKey is required");
        this.createdAtUtcMs = createdAtUtcMs;
        this.updatedAtUtcMs = updatedAtUtcMs;
    }

    public static OperationRecord create(String operationId, OperationIntent intent, String actorPeerId, List<String> targetObjects, String idempotencyKey) {
        long now = System.currentTimeMillis();
        return new OperationRecord(operationId, intent, actorPeerId, targetObjects, OperationState.CREATED, idempotencyKey, now, now);
    }

    public OperationRecord withState(OperationState newState) {
        return new OperationRecord(
                this.operationId,
                this.intent,
                this.actorPeerId,
                this.targetObjectIds,
                newState,
                this.idempotencyKey,
                this.createdAtUtcMs,
                System.currentTimeMillis()
        );
    }

    public String getOperationId() { return operationId; }
    public OperationIntent getIntent() { return intent; }
    public String getActorPeerId() { return actorPeerId; }
    public List<String> getTargetObjectIds() { return targetObjectIds; }
    public OperationState getState() { return state; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public long getCreatedAtUtcMs() { return createdAtUtcMs; }
    public long getUpdatedAtUtcMs() { return updatedAtUtcMs; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof OperationRecord that)) return false;
        return Objects.equals(operationId, that.operationId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(operationId);
    }

    @Override
    public String toString() {
        return "OperationRecord[id=" + operationId + ", intent=" + intent + ", state=" + state + "]";
    }
}
