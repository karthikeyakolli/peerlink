package org.peerlink.core.sync;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Manages a single synchronization session between two peers.
 *
 * <p>A session progresses through: INITIALIZING → SCANNING → RECONCILING →
 * CONFLICT_RESOLUTION → APPLYING → COMPLETED | PAUSED | FAILED.
 *
 * <p>Watcher events are hints. The SCANNING phase always does a full reconciliation
 * before entering APPLYING.
 */
public final class SyncSession {

    public enum Phase {
        INITIALIZING,
        SCANNING,
        RECONCILING,
        CONFLICT_RESOLUTION,
        APPLYING,
        COMPLETED,
        PAUSED,
        FAILED
    }

    private final String sessionId;
    private final String localPeerId;
    private final String remotePeerId;
    private final SyncMode mode;
    private final SelectiveSyncFilter filter;

    private volatile Phase phase;
    private final SyncManifest localManifest;
    private volatile SyncManifest remoteManifest;
    private final List<ConflictRecord> conflicts = new CopyOnWriteArrayList<>();
    private final List<DetectedChange> pendingChanges = new CopyOnWriteArrayList<>();
    private volatile boolean massChangeHold;
    private volatile String massChangeReason;
    private volatile String failureReason;
    private final long startedAtUtcMs;

    public SyncSession(String sessionId, String localPeerId, String remotePeerId,
                       SyncMode mode, SelectiveSyncFilter filter, SyncManifest localManifest) {
        this.sessionId = sessionId;
        this.localPeerId = localPeerId;
        this.remotePeerId = remotePeerId;
        this.mode = mode;
        this.filter = filter;
        this.localManifest = localManifest;
        this.phase = Phase.INITIALIZING;
        this.startedAtUtcMs = System.currentTimeMillis();
    }

    // ── Phase transitions ────────────────────────────────────────────────────

    public void beginScanning() { transitionTo(Phase.SCANNING); }
    public void beginReconciling() { transitionTo(Phase.RECONCILING); }
    public void beginConflictResolution() { transitionTo(Phase.CONFLICT_RESOLUTION); }
    public void beginApplying() { transitionTo(Phase.APPLYING); }
    public void complete() { transitionTo(Phase.COMPLETED); }
    public void fail(String reason) { this.failureReason = reason; transitionTo(Phase.FAILED); }

    public void pauseForMassChange(String reason) {
        this.massChangeHold = true;
        this.massChangeReason = reason;
        transitionTo(Phase.PAUSED);
    }

    public void resumeFromMassChangeHold() {
        if (!massChangeHold) throw new IllegalStateException("Not in mass-change hold");
        this.massChangeHold = false;
        this.massChangeReason = null;
        transitionTo(Phase.RECONCILING);
    }

    private void transitionTo(Phase next) { this.phase = next; }

    // ── Conflict management ──────────────────────────────────────────────────

    public void addConflict(ConflictRecord conflict) { conflicts.add(conflict); }

    public boolean hasUnresolvedConflicts() {
        return conflicts.stream().anyMatch(c -> !c.isResolved());
    }

    public void resolveConflict(ObjectId objectId, ConflictResolution resolution) {
        conflicts.stream()
                .filter(c -> c.getObjectId().equals(objectId))
                .findFirst()
                .ifPresent(c -> c.resolve(resolution));
    }

    // ── Dry run ──────────────────────────────────────────────────────────────

    public SyncDryRunResult dryRun(List<SyncObject> wouldSend, List<SyncObject> wouldReceive,
                                    List<Tombstone> deletions, MassChangeProtector.Assessment massAssessment) {
        long bytes = wouldSend.stream().mapToLong(SyncObject::getSizeBytes).sum()
                + wouldReceive.stream().mapToLong(SyncObject::getSizeBytes).sum();
        return new SyncDryRunResult(
                new ArrayList<>(wouldSend),
                new ArrayList<>(wouldReceive),
                new ArrayList<>(conflicts),
                new ArrayList<>(deletions),
                massAssessment.reasons(),
                bytes,
                massAssessment.triggered()
        );
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    public String getSessionId() { return sessionId; }
    public String getLocalPeerId() { return localPeerId; }
    public String getRemotePeerId() { return remotePeerId; }
    public SyncMode getMode() { return mode; }
    public SelectiveSyncFilter getFilter() { return filter; }
    public Phase getPhase() { return phase; }
    public SyncManifest getLocalManifest() { return localManifest; }
    public SyncManifest getRemoteManifest() { return remoteManifest; }
    public void setRemoteManifest(SyncManifest m) { this.remoteManifest = m; }
    public List<ConflictRecord> getConflicts() { return Collections.unmodifiableList(conflicts); }
    public boolean isMassChangeHold() { return massChangeHold; }
    public String getMassChangeReason() { return massChangeReason; }
    public String getFailureReason() { return failureReason; }
    public long getStartedAtUtcMs() { return startedAtUtcMs; }
}