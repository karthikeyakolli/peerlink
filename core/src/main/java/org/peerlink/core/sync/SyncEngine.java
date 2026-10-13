package org.peerlink.core.sync;

import java.io.IOException;
import java.nio.file.Path;
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
 *   <li>Tombstones prevent stale copies from resurrecting deleted data.</li>
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

        // 1. Detect local changes (watcher events are hints — always verify against observed state)
        List<DetectedChange> localChanges = changeDetector.detect(
                session.getLocalManifest(), observedLocal, fromWatcher);

        // 2. Mass-change protection assessment
        MassChangeProtector.Assessment assessment = massChangeProtector.assess(
                localChanges, session.getLocalManifest().objectCount(), session.getLocalManifest());
        if (assessment.triggered()) {
            session.pauseForMassChange(String.join("; ", assessment.reasons()));
            return SyncOutcome.paused(assessment.reasons());
        }

        // 3. Reconcile verified local changes into the local manifest
        reconcileLocalChanges(session, localChanges);

        session.beginReconciling();

        // 4. Detect conflicts between local and remote manifests
        List<ConflictRecord> conflicts = conflictDetector.detect(
                session.getLocalManifest(), session.getRemoteManifest());
        for (ConflictRecord c : conflicts) session.addConflict(c);

        if (!conflicts.isEmpty()) {
            session.beginConflictResolution();
        }

        // 5. Compute what to send and receive (non-conflicting changes)
        List<SyncObject> toSend = computeToSend(session);
        List<SyncObject> toReceive = computeToReceive(session);
        List<Tombstone> deletionsToSend = computeDeletionsToSend(session);
        List<Tombstone> deletionsToReceive = computeDeletionsToReceive(session);

        // 6. Dry-run mode: return what would happen without applying
        if (session.getMode() == null) {
            List<Tombstone> allDeletions = new ArrayList<>(deletionsToSend);
            allDeletions.addAll(deletionsToReceive);
            return SyncOutcome.dryRun(session.dryRun(toSend, toReceive, allDeletions, assessment));
        }

        session.beginApplying();

        // 7. Apply incoming non-conflicting remote changes to local manifest
        int applied = 0;
        for (SyncObject obj : toReceive) {
            applyRemoteChange(session, obj);
            applied++;
        }
        for (Tombstone t : deletionsToReceive) {
            applyRemoteTombstone(session, t);
            applied++;
        }

        session.complete();
        return SyncOutcome.completed(applied, conflicts.size(), session.hasUnresolvedConflicts());
    }

    /**
     * Performs a sync cycle against a real filesystem directory using FilesystemScanner.
     */
    public SyncOutcome syncDirectory(Path rootDir, SyncSession session, boolean fromWatcher) throws IOException {
        FilesystemScanner scanner = new FilesystemScanner(session.getFilter());
        List<ChangeDetector.FsEntry> observed = scanner.scan(rootDir);
        return sync(session, observed, fromWatcher);
    }

    /**
     * Reconciles detected local filesystem changes into the local manifest.
     */
    public void reconcileLocalChanges(SyncSession session, List<DetectedChange> localChanges) {
        String peerId = session.getLocalPeerId();
        SyncManifest manifest = session.getLocalManifest();

        for (DetectedChange change : localChanges) {
            switch (change.changeType()) {
                case CREATED, DUPLICATE_CONTENT -> {
                    if (change.objectId() == null) {
                        ObjectId newId = ObjectId.generate();
                        ContentVersion cv = ContentVersion.initial(peerId);
                        MetadataVersion mv = MetadataVersion.initial(peerId);
                        CausalVersion causal = manifest.getManifestCausalVersion().increment(peerId);
                        SyncObject newObj = new SyncObject(
                                newId, change.relativePath(), change.newContentHash(),
                                change.newSizeBytes(), change.lastModifiedHintMs(),
                                false, cv, mv, causal
                        );
                        manifest.trackObject(newObj);
                    }
                }
                case CONTENT_MODIFIED -> {
                    if (change.objectId() != null) {
                        manifest.findById(change.objectId()).ifPresent(obj ->
                                obj.applyContentChange(change.newContentHash(), change.newSizeBytes(),
                                        change.lastModifiedHintMs(), peerId)
                        );
                    }
                }
                case METADATA_CHANGED -> {
                    if (change.objectId() != null) {
                        manifest.findById(change.objectId()).ifPresent(obj -> {
                            manifest.updatePath(obj.getObjectId(), obj.getRelativePath(), change.relativePath());
                            obj.applyMetadataChange(change.relativePath(), change.lastModifiedHintMs(), peerId);
                        });
                    }
                }
                case DELETED -> {
                    if (change.objectId() != null) {
                        manifest.findById(change.objectId()).ifPresent(obj ->
                                manifest.recordDeletion(obj, peerId)
                        );
                    }
                }
            }
        }
    }

    /**
     * Executes explicit conflict resolution policy, preserving divergent changes where appropriate.
     */
    public void executeConflictResolution(SyncSession session, ObjectId objectId, ConflictResolution resolution) {
        session.resolveConflict(objectId, resolution);
        SyncManifest local = session.getLocalManifest();
        SyncManifest remote = session.getRemoteManifest();
        String localPeer = session.getLocalPeerId();
        String remotePeer = session.getRemotePeerId();

        Optional<ConflictRecord> recordOpt = session.getConflicts().stream()
                .filter(c -> c.getObjectId().equals(objectId))
                .findFirst();

        if (recordOpt.isEmpty()) return;
        ConflictRecord record = recordOpt.get();

        switch (resolution) {
            case KEEP_LOCAL -> {
                // Local version wins: advance local causal version so it strictly dominates remote
                if (record.getLocalVersion() != null) {
                    CausalVersion remoteClock = record.getRemoteVersion() != null
                            ? record.getRemoteVersion().getCausalVersion()
                            : (remote != null ? remote.getManifestCausalVersion() : CausalVersion.empty());
                    record.getLocalVersion().resolveWithMergedClock(remoteClock, localPeer);
                    local.applyOrTrackObject(record.getLocalVersion());
                }
            }
            case KEEP_REMOTE -> {
                // Remote version wins: adopt remote version into local manifest
                if (record.getRemoteVersion() != null) {
                    SyncObject adopted = record.getRemoteVersion().copy();
                    CausalVersion localClock = record.getLocalVersion() != null
                            ? record.getLocalVersion().getCausalVersion()
                            : local.getManifestCausalVersion();
                    adopted.resolveWithMergedClock(localClock, localPeer);
                    local.applyOrTrackObject(adopted);
                } else if (record.getConflictType() == ConflictType.DELETE_VS_MODIFY && record.getLocalVersion() != null) {
                    // Remote deletion won: delete local version
                    local.recordDeletion(record.getLocalVersion(), localPeer);
                }
            }
            case KEEP_BOTH -> {
                // Preserve both divergent changes!
                // Local remains at original path; remote is preserved at disambiguated path
                if (record.getLocalVersion() != null && record.getRemoteVersion() != null) {
                    String disambiguatedPath = computeConflictDisambiguatedPath(
                            record.getRemoteVersion().getRelativePath(), remotePeer);
                    ObjectId newRemoteCopyId = ObjectId.generate();
                    CausalVersion mergedClock = record.getLocalVersion().getCausalVersion()
                            .merge(record.getRemoteVersion().getCausalVersion())
                            .increment(localPeer);

                    SyncObject conflictedCopy = new SyncObject(
                            newRemoteCopyId, disambiguatedPath,
                            record.getRemoteVersion().getContentHash(),
                            record.getRemoteVersion().getSizeBytes(),
                            record.getRemoteVersion().getLastModifiedHintMs(),
                            record.getRemoteVersion().isDirectory(),
                            ContentVersion.initial(localPeer),
                            MetadataVersion.initial(localPeer),
                            mergedClock
                    );
                    local.trackObject(conflictedCopy);
                }
            }
            case DEFERRED -> {
                // Keep unchanged until decided
            }
            case MERGE -> {
                if (record.getLocalVersion() != null && record.getRemoteVersion() != null) {
                    record.getLocalVersion().resolveWithMergedClock(
                            record.getRemoteVersion().getCausalVersion(), localPeer);
                    local.applyOrTrackObject(record.getLocalVersion());
                }
            }
        }
    }

    /**
     * Computes a disambiguated conflict filename preserving directory structure and extension.
     */
    public static String computeConflictDisambiguatedPath(String originalPath, String peerId) {
        if (originalPath == null || originalPath.isBlank()) {
            return "conflicted_" + peerId;
        }
        int lastDot = originalPath.lastIndexOf('.');
        int lastSlash = Math.max(originalPath.lastIndexOf('/'), originalPath.lastIndexOf('\\'));
        if (lastDot > lastSlash && lastDot > 0) {
            String base = originalPath.substring(0, lastDot);
            String ext = originalPath.substring(lastDot);
            return base + " (conflicted copy " + peerId + ")" + ext;
        } else {
            return originalPath + " (conflicted copy " + peerId + ")";
        }
    }

    /**
     * Performs a sync dry-run without applying any changes.
     */
    public SyncDryRunResult dryRun(SyncSession session, List<ChangeDetector.FsEntry> observedLocal) {
        List<DetectedChange> localChanges = changeDetector.detect(
                session.getLocalManifest(), observedLocal, false);
        MassChangeProtector.Assessment assessment = massChangeProtector.assess(
                localChanges, session.getLocalManifest().objectCount(), session.getLocalManifest());
        List<ConflictRecord> conflicts = conflictDetector.detect(
                session.getLocalManifest(), session.getRemoteManifest() != null
                        ? session.getRemoteManifest() : new SyncManifest("empty"));
        for (ConflictRecord c : conflicts) session.addConflict(c);
        List<SyncObject> toSend = computeToSend(session);
        List<SyncObject> toReceive = computeToReceive(session);
        List<Tombstone> deletions = new ArrayList<>(computeDeletionsToSend(session));
        deletions.addAll(computeDeletionsToReceive(session));
        return session.dryRun(toSend, toReceive, deletions, assessment);
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    private List<SyncObject> computeToSend(SyncSession session) {
        if (session.getMode() == SyncMode.RECEIVE_ONLY_IMPORT) return Collections.emptyList();
        if (session.getRemoteManifest() == null) return Collections.emptyList();

        List<SyncObject> result = new ArrayList<>();
        for (SyncObject localObj : session.getLocalManifest().allObjects()) {
            if (isConflicting(session, localObj.getObjectId())) continue;

            session.getRemoteManifest().findById(localObj.getObjectId()).ifPresentOrElse(
                    remoteObj -> {
                        CausalVersion.Relation rel = localObj.getCausalVersion()
                                .relatedTo(remoteObj.getCausalVersion());
                        if (rel == CausalVersion.Relation.DOMINATES) {
                            result.add(localObj);
                        }
                    },
                    () -> {
                        // Remote doesn't have it in active objects. Check if remote has a tombstone!
                        Optional<Tombstone> remoteTomb = session.getRemoteManifest().getTombstone(localObj.getObjectId());
                        if (remoteTomb.isPresent()) {
                            CausalVersion.Relation rel = localObj.getCausalVersion()
                                    .relatedTo(remoteTomb.get().getDeletionCausalVersion());
                            if (rel == CausalVersion.Relation.DOMINATES) {
                                // Recreated on local after remote deletion
                                result.add(localObj);
                            }
                        } else {
                            result.add(localObj); // New on local
                        }
                    }
            );
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
                        if (rel == CausalVersion.Relation.DOMINATED_BY) {
                            result.add(remoteObj);
                        }
                    },
                    () -> {
                        // Local does not have active object.
                        // Check if local has a tombstone for this object!
                        Optional<Tombstone> tomb = session.getLocalManifest().getTombstone(remoteObj.getObjectId());
                        if (tomb.isPresent()) {
                            CausalVersion.Relation rel = tomb.get().getDeletionCausalVersion()
                                    .relatedTo(remoteObj.getCausalVersion());
                            // If local deletion dominates or equals remote object:
                            // STALE COPY PREVENTED FROM RESURRECTING!
                            if (rel == CausalVersion.Relation.DOMINATES || rel == CausalVersion.Relation.EQUAL) {
                                return;
                            }
                            if (rel == CausalVersion.Relation.CONCURRENT) {
                                return; // Conflict handled via conflict records
                            }
                            // If DOMINATED_BY: remote object was legitimately recreated/restored after deletion
                            result.add(remoteObj);
                        } else {
                            result.add(remoteObj); // Legitimately new on remote
                        }
                    }
            );
        }
        return result;
    }

    private List<Tombstone> computeDeletionsToSend(SyncSession session) {
        if (session.getRemoteManifest() == null) return Collections.emptyList();
        List<Tombstone> result = new ArrayList<>();
        for (Tombstone t : session.getLocalManifest().allTombstones()) {
            if (!session.getRemoteManifest().hasTombstone(t.getObjectId())) {
                result.add(t);
            }
        }
        return result;
    }

    private List<Tombstone> computeDeletionsToReceive(SyncSession session) {
        if (session.getRemoteManifest() == null) return Collections.emptyList();
        List<Tombstone> result = new ArrayList<>();
        for (Tombstone rt : session.getRemoteManifest().allTombstones()) {
            if (!session.getLocalManifest().hasTombstone(rt.getObjectId())) {
                session.getLocalManifest().findById(rt.getObjectId()).ifPresentOrElse(
                        localObj -> {
                            CausalVersion.Relation rel = localObj.getCausalVersion()
                                    .relatedTo(rt.getDeletionCausalVersion());
                            if (rel == CausalVersion.Relation.DOMINATED_BY || rel == CausalVersion.Relation.EQUAL) {
                                result.add(rt);
                            }
                        },
                        () -> result.add(rt)
                );
            }
        }
        return result;
    }

    private boolean isConflicting(SyncSession session, ObjectId id) {
        return session.getConflicts().stream()
                .anyMatch(c -> c.getObjectId().equals(id) && !c.isResolved());
    }

    private void applyRemoteChange(SyncSession session, SyncObject obj) {
        session.getLocalManifest().applyOrTrackObject(obj);
    }

    private void applyRemoteTombstone(SyncSession session, Tombstone t) {
        session.getLocalManifest().recordTombstone(t);
    }
}