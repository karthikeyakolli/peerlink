package org.peerlink.core.collaboration.smart;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.operation.OperationIntent;

import java.io.Serializable;
import java.util.Objects;

/**
 * Scheduled collaboration action (e.g. Send Later / Send Again).
 *
 * Invariant: Uses ObjectIdentity rather than stale filesystem paths.
 * Re-resolves and revalidates current state before execution!
 */
public final class ScheduledOperation implements Serializable {
    private static final long serialVersionUID = 1L;

    public enum Status {
        PENDING,
        READY,
        EXECUTING,
        COMPLETED,
        FAILED,
        BLOCKED_BY_POLICY
    }

    private final String operationId;
    private final String idempotencyKey;
    private final OperationIntent intent;
    private final ObjectIdentity targetObjectId;
    private final String targetPeerId;
    private final String dependsOnOperationId;
    private final NetworkPolicy networkPolicy;
    private final PowerPolicy powerPolicy;
    private final UserPolicy userPolicy;
    private final ContentHash expectedContentHash;
    private final long scheduledAtUtcMs;

    private volatile Status status = Status.PENDING;
    private volatile boolean executed = false;

    public ScheduledOperation(
            String operationId,
            String idempotencyKey,
            OperationIntent intent,
            ObjectIdentity targetObjectId,
            String targetPeerId,
            String dependsOnOperationId,
            NetworkPolicy networkPolicy,
            PowerPolicy powerPolicy,
            UserPolicy userPolicy,
            ContentHash expectedContentHash,
            long scheduledAtUtcMs
    ) {
        this.operationId = Objects.requireNonNull(operationId, "operationId is required");
        this.idempotencyKey = Objects.requireNonNull(idempotencyKey, "idempotencyKey is required");
        this.intent = Objects.requireNonNull(intent, "intent is required");
        this.targetObjectId = Objects.requireNonNull(targetObjectId, "targetObjectId is required");
        this.targetPeerId = Objects.requireNonNull(targetPeerId, "targetPeerId is required");
        this.dependsOnOperationId = dependsOnOperationId;
        this.networkPolicy = networkPolicy != null ? networkPolicy : NetworkPolicy.ANY;
        this.powerPolicy = powerPolicy != null ? powerPolicy : PowerPolicy.ANY;
        this.userPolicy = userPolicy != null ? userPolicy : UserPolicy.AUTOMATIC;
        this.expectedContentHash = expectedContentHash;
        this.scheduledAtUtcMs = scheduledAtUtcMs;
    }

    public synchronized boolean markExecuting() {
        if (executed || status == Status.COMPLETED || status == Status.EXECUTING) {
            return false; // Prevent duplicate execution!
        }
        this.status = Status.EXECUTING;
        return true;
    }

    public synchronized void markCompleted() {
        this.status = Status.COMPLETED;
        this.executed = true;
    }

    public synchronized void markFailed() {
        this.status = Status.FAILED;
    }

    public synchronized void markBlocked() {
        this.status = Status.BLOCKED_BY_POLICY;
    }

    public String getOperationId() { return operationId; }
    public String getIdempotencyKey() { return idempotencyKey; }
    public OperationIntent getIntent() { return intent; }
    public ObjectIdentity getTargetObjectId() { return targetObjectId; }
    public String getTargetPeerId() { return targetPeerId; }
    public String getDependsOnOperationId() { return dependsOnOperationId; }
    public NetworkPolicy getNetworkPolicy() { return networkPolicy; }
    public PowerPolicy getPowerPolicy() { return powerPolicy; }
    public UserPolicy getUserPolicy() { return userPolicy; }
    public ContentHash getExpectedContentHash() { return expectedContentHash; }
    public long getScheduledAtUtcMs() { return scheduledAtUtcMs; }
    public Status getStatus() { return status; }
    public boolean isExecuted() { return executed; }
}