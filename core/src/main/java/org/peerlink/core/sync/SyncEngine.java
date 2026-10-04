package org.peerlink.core.sync;

import java.util.*;

/**
 * Core synchronization engine.
 *
 * <p>Implements sync correctness from version/causality — NOT from timestamps or watcher events.
 *
 * <p>Phases:
 * <ol>
 *   <li>SCANNING — collect current filesystem state; watcher events used as hints only.</li>
 *   <li>RECONCILING — compare local and remote manifests using causal versions.</li>
 *   <li>CONFLICT_RESOLUTION — surface concurrent changes; await user/policy decision.</li>
 *   <li>APPLYING — apply non-conflicting changes; skip unresolved conflicts.</li>
 *   <li>MASS_CHANGE_HOLD — pause if suspicious burst detected.</li>
 * </ol>
 *
 * <p>Invariants:
 * <ul>
 *   <li>objectId != contentHash. Equal content does NOT merge logical objects.</li>
 *   <li>Deletions always produce tombstones; tombstones survive until safe convergence.</li>
 *   <li>Restore creates a new version — does NOT undo the tombstone.</li>
 *   <li>Local cache/placeholder deletion does NOT delete source content unless separately authorized.</li>
 *   <li>File locking is advisory only — correctness comes from version/causality.</li>
 *   <li>Watcher events are hints — periodic reconciliation is always performed.</li>
 * </ul>
 */
public final class SyncEngine {

    private final ChangeDetector changeDetector;
    private final ConflictDetector conflictDetector;
    private final MassChangeProtector massChangeProtector;

    public SyncEngine() {
        this(new ChangeDetector(), new ConflictDetector(), new MassChangeProtector());
    }

    public SyncEngine(ChangeDetector changeDetector, ConflictDetector conflictDetector,
                       MassChangeProtector massChangeProtector) {
        this.changeDetector = changeDetector;
        this.conflictDetector = conflictDetector;
        this.massChangeProtector = massChangeProtector;
    }

    /**
     * Performs a complete synchronization cycle for a session.
     *
     * @param session       the sync session with local manifest and remote manifest already set
     * @param observedLocal current filesystem entries for local peer (from scanner or watcher)
     * @param fromWatcher   whether the scan was triggered by a watcher event (hint) or periodic scan
     * @return SyncOutcome describing what was done
     */
    public SyncOutcome sync(SyncSession session, List<ChangeDetector.FsEntry> observedLocal,
                             boolean fromWatcher) {
        if (session.getRemoteManifest() == null) {
            session.fail("Remote manifest not set");
            return SyncOutcome.failed("Remote manifest not set");
        }

        session.beginScanning();

        // 1. Detect local changes (watcher events are hints — always verify)
        List<DetectedChange> localChanges = changeDetector.detect(
                session.getLocalManifest(), observedLocal, fromWatcher);

        // 2. Mass-change protection
        MassChangeProtector.Assessment assessment = massChangeProtector.assess(
                localChanges, session.getLocalManifest().objectCount());
        if (assessment.triggered()) {
            session.pauseForMassChange(String.join("; ", assessment.reasons()));
            return SyncOutcome.paused(assessment.reasons());
        }

        session.beginReconciling();

        // 3. Detect conflicts between local and remote manifests
        List<ConflictRecord> conflicts = conflictDetector.detect(
                session.getLocalManifest(), session.getRemoteManifest());
        for (ConflictRecord c : conflicts) session.addConflict(c);

        if (!conflicts.isEmpty()) {
            session.beginConflictResolution();
        }

        // 4. Compute what to send and receive (non-conflicting changes)
        List<SyncObject> toSend = computeToSend(session, localChanges);
        List<SyncObject> toReceive = computeToReceive(session);
        List<Tombstone> deletionsToPropagate = computeDeletions(session);

        // 5. Dry-run mode: return what would happen without applying
        if (session.getMode() == null) {
            return SyncOutcome.dryRun(session.dryRun(toSend, toReceive, deletionsToPropagate, assessment));
        }

        session.beginApplying();

        // 6. Apply (actual transfer deferred to transport layer — engine records intent)
        int applied = 0;
        for (SyncObject obj : toSend) {
            applyLocalChange(session, obj);
            applied++;
        }
        for (SyncObject obj : toReceive) {
            applyRemoteChange(session, obj);
            applied++;
        }
        for (Tombstone t : deletionsToPropagate) {
            applyTombstone(session, t);
            applied++;
        }

        session.complete();
        return SyncOutcome.completed(applied, conflicts.size(), session.hasUnresolvedConflicts());
    }

    /**
     * Performs a sync dry-run without applying any changes.
     */
    public SyncDryRunResult dryRun(SyncSession session, List<ChangeDetector.FsEntry> observedLocal) {
        List<DetectedChange> localChanges = changeDetector.detect(
                session.getLocalManifest(), observedLocal, false);
        MassChangeProtector.Assessment assessment = massChangeProtector.assess(
                localChanges, session.getLocalManifest().objectCount());
        List<ConflictRecord> conflicts = conflictDetector.detect(
                session.getLocalManifest(), session.getRemoteManifest() != null
                        ? session.getRemoteManifest() : new SyncManifest("empty"));
        for (ConflictRecord c : conflicts) session.addConflict(c);
        List<SyncObject> toSend = computeToSend(session, localChanges);
        List<SyncObject> toReceive = computeToReceive(session);
        List<Tombstone> deletions = computeDeletions(session);
        return session.dryRun(toSend, toReceive, deletions, assessment);
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    private List<SyncObject> computeToSend(SyncSession session, List<DetectedChange> localChanges) {
        if (session.getMode() == SyncMode.RECEIVE_ONLY_IMPORT) return Collections.emptyList();
        List<SyncObject> result = new ArrayList<>();
        for (DetectedChange change : localChanges) {
            if (change.changeType() == ChangeType.DELETED) continue; // handled as tombstone
            if (change.objectId() == null) continue; // new local object — not yet tracked remotely
            if (isConflicting(session, change.objectId())) continue; // skip conflicting
            session.getLocalManifest().findById(change.objectId()).ifPresent(result::add);
        }
        return result;
    }

    private List<SyncObject> computeToReceive(SyncSession session) {
        if (session.getMode() == SyncMode.ONE_WAY_REPLICATION) return Collections.emptyList();
        if (session.getRemoteManifest() == null) return Collections.emptyList();
        List<SyncObject> result = new ArrayList<>();
        for (SyncObject remoteObj : session.getRemoteManifest().allObjects()) {
            if (isConflicting(session, remoteObj.getObjectId())) continue;
            session.getLocalManifest().findById(remoteObj.getObjectId()).ifPresentOrElse(
                    localObj -> {
                        CausalVersion.Relation rel = localObj.getCausalVersion()
                                .relatedTo(remoteObj.getCausalVersion());
                        if (rel == CausalVersion.Relation.DOMINATED_BY) result.add(remoteObj);
                    },
                    () -> result.add(remoteObj) // new on remote
            );
        }
        return result;
    }

    private List<Tombstone> computeDeletions(SyncSession session) {
        if (session.getRemoteManifest() == null) return Collections.emptyList();
        List<Tombstone> result = new ArrayList<>();
        for (Tombstone t : session.getLocalManifest().allTombstones()) {
            if (!session.getRemoteManifest().hasTombstone(t.getObjectId())) {
                result.add(t);
            }
        }
        return result;
    }

    private boolean isConflicting(SyncSession session, ObjectId id) {
        return session.getConflicts().stream()
                .anyMatch(c -> c.getObjectId().equals(id) && !c.isResolved());
    }

    // These are stubs — actual apply is handled by transport/filesystem layer
    private void applyLocalChange(SyncSession session, SyncObject obj) { /* send to remote */ }
    private void applyRemoteChange(SyncSession session, SyncObject obj) { /* receive from remote */ }
    private void applyTombstone(SyncSession session, Tombstone t) { /* propagate deletion */ }
}