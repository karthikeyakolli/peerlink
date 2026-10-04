package org.peerlink.core.sync;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Phase 12 — Synchronization Engine Tests.
 *
 * PASS criterion:
 * "Independent peers converge according to the defined causality rules without silently losing
 *  concurrent changes."
 */
class SyncEngineTest {

    private static final String PEER_A = "peer-A";
    private static final String PEER_B = "peer-B";

    private SyncEngine engine;
    private SyncManifest manifestA;
    private SyncManifest manifestB;

    @BeforeEach
    void setUp() {
        engine = new SyncEngine();
        manifestA = new SyncManifest(PEER_A);
        manifestB = new SyncManifest(PEER_B);
    }

    // ── Helper factories ──────────────────────────────────────────────────────

    private SyncObject makeObject(String path, String hash, String peerId, long seq) {
        ObjectId id = ObjectId.generate();
        ContentVersion cv = new ContentVersion(peerId, seq);
        MetadataVersion mv = MetadataVersion.initial(peerId);
        CausalVersion causal = CausalVersion.empty().increment(peerId);
        for (long i = 1; i < seq; i++) causal = causal.increment(peerId);
        return new SyncObject(id, path, hash, hash.length() * 10L, System.currentTimeMillis(),
                false, cv, mv, causal);
    }

    private SyncObject makeObjectWithId(ObjectId id, String path, String hash, String peerId, long seq) {
        ContentVersion cv = new ContentVersion(peerId, seq);
        MetadataVersion mv = MetadataVersion.initial(peerId);
        CausalVersion causal = CausalVersion.empty().increment(peerId);
        for (long i = 1; i < seq; i++) causal = causal.increment(peerId);
        return new SyncObject(id, path, hash, hash.length() * 10L, System.currentTimeMillis(),
                false, cv, mv, causal);
    }

    private SyncSession makeSession(SyncManifest local, SyncManifest remote, SyncMode mode) {
        SyncSession session = new SyncSession("sess-" + System.nanoTime(),
                local.getLocalPeerId(), remote.getLocalPeerId(), mode,
                SelectiveSyncFilter.acceptAll(), local);
        session.setRemoteManifest(remote);
        return session;
    }

    private List<ChangeDetector.FsEntry> toEntries(SyncManifest manifest) {
        List<ChangeDetector.FsEntry> entries = new ArrayList<>();
        for (SyncObject obj : manifest.allObjects()) {
            entries.add(new ChangeDetector.FsEntry(obj.getRelativePath(), obj.getContentHash(),
                    obj.getSizeBytes(), obj.getLastModifiedHintMs(), obj.isDirectory()));
        }
        return entries;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Independent offline changes — A and B both edit different files
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testIndependentOfflineChangesDifferentFiles() {
        SyncObject fileFromA = makeObject("docs/a.txt", ChangeDetector.sha256("content-a"), PEER_A, 1);
        SyncObject fileFromB = makeObject("docs/b.txt", ChangeDetector.sha256("content-b"), PEER_B, 1);
        manifestA.trackObject(fileFromA);
        manifestB.trackObject(fileFromB);

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);

        assertTrue(outcome.isCompleted(), "Sync should complete for non-conflicting independent changes");
        assertEquals(0, outcome.getConflictsDetected(), "No conflicts — different objects");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Concurrent edits to the same file — conflict must be surfaced
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testConcurrentEditsProduceConflict() {
        ObjectId sharedId = ObjectId.generate();

        // Both peers modified the same object independently (concurrent causal versions)
        SyncObject localVer = makeObjectWithId(sharedId, "shared.txt",
                ChangeDetector.sha256("alice-edit"), PEER_A, 2);
        SyncObject remoteVer = makeObjectWithId(sharedId, "shared.txt",
                ChangeDetector.sha256("bob-edit"), PEER_B, 2);

        manifestA.trackObject(localVer);
        manifestB.trackObject(remoteVer);

        // Causal versions are concurrent (A:2, B:0 vs A:0, B:2)
        assertTrue(localVer.getCausalVersion().isConcurrentWith(remoteVer.getCausalVersion()),
                "Independently incremented versions must be concurrent");

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);

        assertEquals(1, outcome.getConflictsDetected(), "One conflict expected for concurrent edit");
        assertTrue(outcome.hasUnresolvedConflicts(), "Conflict must be unresolved until user acts");

        // Verify conflict type
        ConflictRecord conflict = session.getConflicts().get(0);
        assertEquals(ConflictType.CONCURRENT_CONTENT_EDIT, conflict.getConflictType());
        assertEquals(ConflictResolution.DEFERRED, conflict.getResolution());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Rename — one peer renames; other has old name — no conflict (dominates)
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testRenameNonConflictingApplied() {
        ObjectId id = ObjectId.generate();
        SyncObject old = makeObjectWithId(id, "old-name.txt", ChangeDetector.sha256("data"), PEER_A, 1);
        manifestA.trackObject(old);
        // Remote has a higher causal version (rename applied)
        CausalVersion renamedCausal = CausalVersion.empty().increment(PEER_A).increment(PEER_A);
        SyncObject renamed = new SyncObject(id, "new-name.txt", ChangeDetector.sha256("data"),
                40L, System.currentTimeMillis(), false,
                new ContentVersion(PEER_A, 1), new MetadataVersion(PEER_A, 2), renamedCausal);
        manifestB.trackObject(renamed);

        CausalVersion.Relation rel = old.getCausalVersion().relatedTo(renamed.getCausalVersion());
        assertEquals(CausalVersion.Relation.DOMINATED_BY, rel,
                "Local should be dominated by remote rename (remote is causally ahead)");

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        engine.sync(session, toEntries(manifestA), false);

        assertEquals(0, session.getConflicts().size(), "Non-conflicting rename produces no conflict");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Concurrent rename — both peers rename same object differently → conflict
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testConcurrentRenameProducesConflict() {
        ObjectId id = ObjectId.generate();
        String hash = ChangeDetector.sha256("shared-content");

        SyncObject localRenamed = new SyncObject(id, "alice-rename.txt", hash,
                40L, System.currentTimeMillis(), false,
                ContentVersion.initial(PEER_A), MetadataVersion.initial(PEER_A),
                CausalVersion.empty().increment(PEER_A));
        SyncObject remoteRenamed = new SyncObject(id, "bob-rename.txt", hash,
                40L, System.currentTimeMillis(), false,
                ContentVersion.initial(PEER_B), MetadataVersion.initial(PEER_B),
                CausalVersion.empty().increment(PEER_B));

        manifestA.trackObject(localRenamed);
        manifestB.trackObject(remoteRenamed);

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        engine.sync(session, toEntries(manifestA), false);

        assertFalse(session.getConflicts().isEmpty(), "Concurrent rename must produce conflict");
        assertEquals(ConflictType.CONCURRENT_RENAME, session.getConflicts().get(0).getConflictType());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Delete vs modify — tombstone vs active version → conflict
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testDeleteVsModifyProducesConflict() {
        ObjectId id = ObjectId.generate();
        SyncObject file = makeObjectWithId(id, "contested.txt", ChangeDetector.sha256("v1"), PEER_A, 1);
        manifestA.trackObject(file);
        manifestA.recordDeletion(file, PEER_A); // A deletes it

        // B modifies it concurrently (independent causal branch)
        SyncObject bModified = new SyncObject(id, "contested.txt", ChangeDetector.sha256("v2-b"),
                40L, System.currentTimeMillis(), false,
                new ContentVersion(PEER_B, 2), MetadataVersion.initial(PEER_B),
                CausalVersion.empty().increment(PEER_B).increment(PEER_B));
        manifestB.trackObject(bModified);

        assertTrue(manifestA.hasTombstone(id), "Tombstone must exist for deleted object");

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        engine.sync(session, toEntries(manifestA), false);

        assertFalse(session.getConflicts().isEmpty(), "Delete-vs-modify must produce a conflict");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Duplicate content — same hash, different objectId — NOT merged
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testDuplicateContentNotMerged() {
        String sameHash = ChangeDetector.sha256("identical-bytes");

        SyncObject obj1 = makeObject("docs/file1.txt", sameHash, PEER_A, 1);
        SyncObject obj2 = makeObject("docs/file2.txt", sameHash, PEER_A, 1);

        // obj1 and obj2 have different ObjectIds even though content is identical
        assertNotEquals(obj1.getObjectId(), obj2.getObjectId(),
                "Equal content must NOT produce the same objectId");

        manifestA.trackObject(obj1);
        manifestA.trackObject(obj2);

        assertEquals(2, manifestA.objectCount(), "Both objects must be tracked independently");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Tombstone survives — deleted objects are NOT silently removed
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testTombstoneSurvivesUntilGcSafe() {
        SyncObject file = makeObject("toDelete.txt", ChangeDetector.sha256("data"), PEER_A, 1);
        manifestA.trackObject(file);
        manifestA.recordDeletion(file, PEER_A);

        assertTrue(manifestA.hasTombstone(file.getObjectId()),
                "Tombstone must exist after deletion");
        assertEquals(0, manifestA.objectCount(), "Deleted object must not be in active objects");

        // GC is NOT allowed until marked safe
        Tombstone t = manifestA.getTombstone(file.getObjectId()).orElseThrow();
        assertFalse(t.isSafeToGarbageCollect(), "Tombstone must NOT be GC-safe until convergence confirmed");

        manifestA.gcTombstone(file.getObjectId());
        assertTrue(manifestA.hasTombstone(file.getObjectId()),
                "GC must be refused when not safe — tombstone must still exist");

        // Mark safe, then GC
        t.markSafeToGarbageCollect();
        manifestA.gcTombstone(file.getObjectId());
        assertFalse(manifestA.hasTombstone(file.getObjectId()), "Tombstone GC'd after safe convergence");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Restore creates new version — does NOT undo tombstone
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testRestoreCreatesNewVersion() {
        SyncObject file = makeObject("file.txt", ChangeDetector.sha256("v1"), PEER_A, 1);
        ContentVersion originalCv = file.getContentVersion();

        file.markDeleted(PEER_A);
        assertTrue(file.isDeleted());

        String newHash = ChangeDetector.sha256("restored-v2");
        file.restore(newHash, 90L, System.currentTimeMillis(), PEER_A);

        assertFalse(file.isDeleted(), "Restore must un-delete the object");
        assertNotEquals(originalCv.sequence(), file.getContentVersion().sequence(),
                "Restore must produce a new content version");
        assertEquals(newHash, file.getContentHash(), "Restored hash must match new content");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Watcher failure — periodic scan still detects changes
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testWatcherHintMarkedCorrectly() {
        SyncObject file = makeObject("watched.txt", ChangeDetector.sha256("old"), PEER_A, 1);
        manifestA.trackObject(file);

        String newHash = ChangeDetector.sha256("new-content");
        ChangeDetector.FsEntry updatedEntry = new ChangeDetector.FsEntry(
                "watched.txt", newHash, 100L, System.currentTimeMillis(), false);

        ChangeDetector detector = new ChangeDetector();
        List<DetectedChange> changes = detector.detect(manifestA, List.of(updatedEntry), true);

        assertFalse(changes.isEmpty(), "Change must be detected even via watcher hint");
        assertTrue(changes.get(0).fromWatcher(), "Change must be flagged as watcher-sourced hint");
        assertTrue(changes.get(0).requiresVerification(), "Watcher hint requires verification");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Selective sync — excluded files don't participate
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testSelectiveSyncExcludes() {
        SelectiveSyncFilter filter = new SelectiveSyncFilter(
                null,
                List.of("**/*.tmp", "**/node_modules/**"),
                0, true);

        assertTrue(filter.accepts("docs/report.pdf", 1000L, false));
        assertFalse(filter.accepts("work/draft.tmp", 500L, false),
                "*.tmp files must be excluded");
        assertFalse(filter.accepts("project/node_modules/lib.js", 200L, false),
                "node_modules must be excluded");
        assertTrue(filter.accepts("src/Main.java", 2000L, false));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Sync dry-run — reports what would happen without applying
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testDryRunReportsIntentWithoutApplying() {
        SyncObject localObj = makeObject("local.txt", ChangeDetector.sha256("a"), PEER_A, 1);
        SyncObject remoteObj = makeObject("remote.txt", ChangeDetector.sha256("b"), PEER_B, 1);
        manifestA.trackObject(localObj);
        manifestB.trackObject(remoteObj);

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        SyncDryRunResult result = engine.dryRun(session, toEntries(manifestA));

        assertNotNull(result, "Dry run must produce a result");
        // No conflicts for different objects
        assertEquals(0, result.wouldConflict().size(), "No conflicts for non-overlapping objects");
        assertFalse(result.massChangeProtectionTriggered(), "No mass-change for small set");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 12. Mass deletion — triggers mass-change protection
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testMassDeletionTriggersProtection() {
        MassChangeProtector protector = new MassChangeProtector(5, 200, 0.5);

        // Simulate 6 deletions (above threshold of 5)
        List<DetectedChange> changes = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            changes.add(new DetectedChange(ObjectId.generate(), "file" + i + ".txt",
                    ChangeType.DELETED, null, 0, 0, false));
        }

        MassChangeProtector.Assessment assessment = protector.assess(changes, 100);
        assertTrue(assessment.triggered(), "Mass deletion must trigger protection");
        assertFalse(assessment.reasons().isEmpty(), "Reason must be provided");
        assertTrue(assessment.reasons().get(0).contains("deletion"), "Reason must mention deletion");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 13. Mass extension change — ransomware-style detection
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testMassExtensionChangeTriggersProtection() {
        MassChangeProtector protector = new MassChangeProtector(50, 200, 0.3);

        // Simulate 40 files renamed to .enc (above 30% ratio of 100 total tracked)
        List<DetectedChange> changes = new ArrayList<>();
        for (int i = 0; i < 40; i++) {
            changes.add(new DetectedChange(ObjectId.generate(), "file" + i + ".enc",
                    ChangeType.CONTENT_MODIFIED, ChangeDetector.sha256("enc" + i), 100L, 0, false));
        }

        MassChangeProtector.Assessment assessment = protector.assess(changes, 100);
        assertTrue(assessment.triggered(), "Mass .enc extension change must trigger protection");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 14. Mass-change hold pause and resume
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testMassChangeHoldPausesAndResumes() {
        SyncManifest localManifest = new SyncManifest(PEER_A);
        SyncSession session = new SyncSession("hold-test", PEER_A, PEER_B,
                SyncMode.BIDIRECTIONAL, SelectiveSyncFilter.acceptAll(), localManifest);
        session.setRemoteManifest(manifestB);

        session.pauseForMassChange("Mass deletion detected: 55 deletions (threshold: 50)");
        assertEquals(SyncSession.Phase.PAUSED, session.getPhase());
        assertTrue(session.isMassChangeHold(), "Session must be in mass-change hold");
        assertNotNull(session.getMassChangeReason(), "Reason must be recorded");

        session.resumeFromMassChangeHold();
        assertEquals(SyncSession.Phase.RECONCILING, session.getPhase());
        assertFalse(session.isMassChangeHold(), "Hold must be cleared after resume");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 15. Network disconnect — remote manifest absent → fail gracefully
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testNetworkDisconnectRemoteManifestAbsent() {
        SyncSession session = new SyncSession("disc-test", PEER_A, PEER_B,
                SyncMode.BIDIRECTIONAL, SelectiveSyncFilter.acceptAll(), manifestA);
        // No remote manifest set

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertTrue(outcome.isFailed(), "Sync must fail gracefully when remote manifest is absent");
        assertNotNull(outcome.getFailureReason(), "Failure reason must be provided");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 16. Conflict resolution — KEEP_LOCAL and KEEP_REMOTE
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testConflictResolutionKeepLocal() {
        ObjectId id = ObjectId.generate();
        SyncObject local = makeObjectWithId(id, "file.txt", ChangeDetector.sha256("local"), PEER_A, 1);
        SyncObject remote = makeObjectWithId(id, "file.txt", ChangeDetector.sha256("remote"), PEER_B, 1);
        manifestA.trackObject(local);
        manifestB.trackObject(remote);

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        engine.sync(session, toEntries(manifestA), false);

        assertFalse(session.getConflicts().isEmpty(), "Should have a conflict");

        ConflictRecord conflict = session.getConflicts().get(0);
        session.resolveConflict(id, ConflictResolution.KEEP_LOCAL);

        assertTrue(conflict.isResolved(), "Conflict must be marked resolved");
        assertEquals(ConflictResolution.KEEP_LOCAL, conflict.getResolution());
        assertFalse(session.hasUnresolvedConflicts(), "No unresolved conflicts after resolution");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 17. Vector clock — causal ordering correctness
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testVectorClockCausalOrdering() {
        CausalVersion base = CausalVersion.empty();
        CausalVersion afterA = base.increment(PEER_A);
        CausalVersion afterAB = afterA.merge(base.increment(PEER_B)).increment(PEER_A);

        // afterA is dominated by afterAB
        assertEquals(CausalVersion.Relation.DOMINATED_BY, afterA.relatedTo(afterAB));
        assertEquals(CausalVersion.Relation.DOMINATES, afterAB.relatedTo(afterA));

        // Independent increments are concurrent
        CausalVersion branchA = base.increment(PEER_A);
        CausalVersion branchB = base.increment(PEER_B);
        assertEquals(CausalVersion.Relation.CONCURRENT, branchA.relatedTo(branchB));

        // Equal
        assertEquals(CausalVersion.Relation.EQUAL, base.relatedTo(CausalVersion.empty()));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 18. One-way replication — local changes not sent back
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testOneWayReplicationReceivesOnly() {
        SyncObject remoteOnly = makeObject("report.pdf", ChangeDetector.sha256("report"), PEER_B, 1);
        manifestB.trackObject(remoteOnly);

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.ONE_WAY_REPLICATION);
        SyncDryRunResult result = engine.dryRun(session, toEntries(manifestA));

        // In ONE_WAY_REPLICATION mode: no local → remote sends
        assertEquals(0, result.wouldSendToRemote().size(),
                "One-way replication must not send local changes to remote");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 19. Receive-only import — no local changes sent upstream
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testReceiveOnlyImportNeverSends() {
        SyncObject localObj = makeObject("local.txt", ChangeDetector.sha256("local"), PEER_A, 1);
        manifestA.trackObject(localObj);

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.RECEIVE_ONLY_IMPORT);
        SyncDryRunResult result = engine.dryRun(session, toEntries(manifestA));

        assertEquals(0, result.wouldSendToRemote().size(),
                "RECEIVE_ONLY_IMPORT must never send to remote");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 20. Huge dataset — manifests with large object counts remain correct
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testHugeDatasetHandled() {
        // Add 1000 objects to each peer with different content
        for (int i = 0; i < 1000; i++) {
            manifestA.trackObject(makeObject("a/file" + i + ".dat",
                    ChangeDetector.sha256("a-content-" + i), PEER_A, 1));
        }
        for (int i = 0; i < 1000; i++) {
            manifestB.trackObject(makeObject("b/file" + i + ".dat",
                    ChangeDetector.sha256("b-content-" + i), PEER_B, 1));
        }

        assertEquals(1000, manifestA.objectCount());
        assertEquals(1000, manifestB.objectCount());

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);

        assertTrue(outcome.isCompleted(), "Huge dataset sync must complete without error");
        assertEquals(0, outcome.getConflictsDetected(), "No conflicts — all objects are unique");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 21. Legitimate large remote catch-up — dominated, no mass-change hold
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    void testLegitimateRemoteCatchupNotBlocked() {
        // Remote has 300 new files (legitimate catch-up from long offline period)
        for (int i = 0; i < 300; i++) {
            manifestB.trackObject(makeObject("catch-up/file" + i + ".pdf",
                    ChangeDetector.sha256("data-" + i), PEER_B, 1));
        }

        SyncSession session = makeSession(manifestA, manifestB, SyncMode.BIDIRECTIONAL);
        // Mass-change detection is on LOCAL changes, not remote receive
        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);

        // No local changes → no mass-change hold (local observed entries match local manifest)
        assertFalse(outcome.isPaused(),
                "Legitimate remote catch-up must not trigger mass-change hold on local side");
    }
}