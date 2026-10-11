package org.peerlink.core.collaboration.smart;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Coordinates smart scheduled actions with current-state revalidation,
 * duplicate execution prevention, and dependency resolution.
 *
 * Invariant: Never replays stale filesystem paths blindly.
 */
public final class SmartOperationScheduler {

    public interface ObjectPathResolver {
        Optional<Path> resolveCurrentPath(ObjectIdentity objectId);
    }

    public interface SystemEnvironment {
        boolean isConnectedToPeer(String peerId);
        boolean isNetworkSatisfied(NetworkPolicy policy);
        boolean isPowerSatisfied(PowerPolicy policy);
        boolean isOperationCompleted(String operationId);
    }

    private final ObjectPathResolver pathResolver;
    private final SystemEnvironment env;
    private final Map<String, ScheduledOperation> scheduledOps = new ConcurrentHashMap<>();
    private final Set<String> executedIdempotencyKeys = ConcurrentHashMap.newKeySet();

    public SmartOperationScheduler(ObjectPathResolver pathResolver, SystemEnvironment env) {
        this.pathResolver = Objects.requireNonNull(pathResolver, "pathResolver is required");
        this.env = Objects.requireNonNull(env, "env is required");
    }

    public synchronized void schedule(ScheduledOperation op) {
        if (executedIdempotencyKeys.contains(op.getIdempotencyKey())) {
            throw new IllegalStateException("Duplicate scheduled operation with idempotency key: " + op.getIdempotencyKey());
        }
        scheduledOps.put(op.getOperationId(), op);
    }

    public synchronized boolean executeIfReady(String operationId) throws IOException {
        ScheduledOperation op = scheduledOps.get(operationId);
        if (op == null) throw new NoSuchElementException("Operation not found: " + operationId);

        // 1. Duplicate execution guard
        if (executedIdempotencyKeys.contains(op.getIdempotencyKey()) || op.isExecuted()) {
            return false;
        }

        // 2. Dependency check
        if (op.getDependsOnOperationId() != null && !env.isOperationCompleted(op.getDependsOnOperationId())) {
            op.markBlocked();
            return false;
        }

        // 3. Peer connectivity check
        if (!env.isConnectedToPeer(op.getTargetPeerId())) {
            op.markBlocked();
            return false;
        }

        // 4. Network and power policy check
        if (!env.isNetworkSatisfied(op.getNetworkPolicy()) || !env.isPowerSatisfied(op.getPowerPolicy())) {
            op.markBlocked();
            return false;
        }

        // 5. Current-state revalidation (Never replay stale filesystem paths blindly!)
        Optional<Path> currentPathOpt = pathResolver.resolveCurrentPath(op.getTargetObjectId());
        if (currentPathOpt.isEmpty() || !Files.exists(currentPathOpt.get())) {
            op.markFailed();
            throw new IOException("Current-state revalidation failed: Object " + op.getTargetObjectId() + " no longer exists on disk");
        }

        Path currentPath = currentPathOpt.get();
        byte[] currentBytes = Files.readAllBytes(currentPath);
        ContentHash currentHash = ContentHash.computeSha256(currentBytes);

        if (op.getExpectedContentHash() != null && !op.getExpectedContentHash().equals(currentHash)) {
            op.markFailed();
            throw new IOException("Current-state revalidation failed: File content changed since scheduling (" + currentPath + ")");
        }

        // 6. Execute
        if (!op.markExecuting()) {
            return false;
        }

        executedIdempotencyKeys.add(op.getIdempotencyKey());
        op.markCompleted();
        return true;
    }

    public Optional<ScheduledOperation> getOperation(String opId) {
        return Optional.ofNullable(scheduledOps.get(opId));
    }
}