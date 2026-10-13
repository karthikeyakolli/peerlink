package org.peerlink.core.sync;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;

/**
 * Phase 14 Standalone Verification Suite:
 * Sync Convergence, Conflict Safety, Causal Lineage, Tombstone Resurrection Prevention,
 * Watcher Hints vs Startup Scanning, Mass-Change Protection, and Real Multi-Peer Convergence.
 *
 * Runs in pure Java SE on any host platform.
 */
public class Phase14StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 14 Sync Convergence & Conflict Safety Suite");
        System.out.println("==========================================================");

        runTest("Test 01: Object Identity vs Content Hash Independence", Phase14StandaloneTestRunner::testObjectIdentityVsContentHash);
        runTest("Test 02: Causal Lineage & Vector Clock Ordering", Phase14StandaloneTestRunner::testCausalLineageAndVectorClocks);
        runTest("Test 03: Simultaneous Concurrent Edits Produce Conflict", Phase14StandaloneTestRunner::testSimultaneousEditsProduceConflict);
        runTest("Test 04: Offline Divergence & Independent Edits Convergence", Phase14StandaloneTestRunner::testOfflineDivergenceConvergence);
        runTest("Test 05: Non-Conflicting Rename/Move Propagation (Stable ObjectId)", Phase14StandaloneTestRunner::testNonConflictingRenamePropagation);
        runTest("Test 06: Concurrent Rename Conflict Detection", Phase14StandaloneTestRunner::testConcurrentRenameConflict);
        runTest("Test 07: Concurrent Move Conflict Detection", Phase14StandaloneTestRunner::testConcurrentMoveConflict);
        runTest("Test 08: Path Collision Conflict (BOTH_CREATED_SAME_PATH)", Phase14StandaloneTestRunner::testBothCreatedSamePathConflict);
        runTest("Test 09: Deletion & Recreation Conflict (TOMBSTONE_VS_NEW_OBJECT)", Phase14StandaloneTestRunner::testTombstoneVsNewObjectConflict);
        runTest("Test 10: Tombstone Resurrection Prevention (Stale Copy Rejection)", Phase14StandaloneTestRunner::testTombstonePreventsStaleResurrection);
        runTest("Test 11: Delete vs Modify Concurrent Conflict Detection", Phase14StandaloneTestRunner::testDeleteVsModifyConflict);
        runTest("Test 12: Legitimate Restore / Recreation After Tombstone", Phase14StandaloneTestRunner::testLegitimateRestoreAfterTombstone);
        runTest("Test 13: Stale Manifest Reconciliation Without Data Loss", Phase14StandaloneTestRunner::testStaleManifestReconciliation);
        runTest("Test 14: Interrupted Sync & Idempotency", Phase14StandaloneTestRunner::testInterruptedSyncAndIdempotency);
        runTest("Test 15: Missed Watcher Events Reconciled via Startup Scan", Phase14StandaloneTestRunner::testMissedWatcherEventsStartupScan);
        runTest("Test 16: Duplicate Watcher Hint Deduplication", Phase14StandaloneTestRunner::testDuplicateWatcherHintDeduplication);
        runTest("Test 17: Conflict Resolution KEEP_BOTH Preserves Divergent Changes", Phase14StandaloneTestRunner::testConflictResolutionKeepBoth);
        runTest("Test 18: Conflict Resolution KEEP_LOCAL & KEEP_REMOTE Convergence", Phase14StandaloneTestRunner::testConflictResolutionKeepLocalAndRemote);
        runTest("Test 19: Mass-Deletion & Mass-Change Protection Policy Hold", Phase14StandaloneTestRunner::testMassChangeProtectionPolicy);
        runTest("Test 20: Real Multi-Peer Filesystem Convergence Demonstration", Phase14StandaloneTestRunner::testRealMultiPeerFilesystemConvergence);

        System.out.println("==========================================================");
        System.out.printf(" Phase 14 Test Execution Summary: %d PASSED, %d FAILED%n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }

    private static void runTest(String name, TestCase testCase) {
        try {
            testCase.run();
            System.out.println("[PASS] " + name);
            testsPassed++;
        } catch (Throwable t) {
            System.err.println("[FAIL] " + name + " -> " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    @FunctionalInterface
    interface TestCase {
        void run() throws Exception;
    }

    private static void assertEquals(Object expected, Object actual, String message) {
        if (expected instanceof Number && actual instanceof Number) {
            if (((Number) expected).longValue() != ((Number) actual).longValue()) {
                throw new AssertionError(message + " (expected: " + expected + ", got: " + actual + ")");
            }
            return;
        }
        if (!Objects.equals(expected, actual)) {
            throw new AssertionError(message + " (expected: " + expected + ", got: " + actual + ")");
        }
    }

    private static void assertEquals(Object expected, Object actual) {
        assertEquals(expected, actual, "Values must match");
    }

    private static void assertTrue(boolean condition, String message) {
        if (!condition) throw new AssertionError(message + " (expected true)");
    }

    private static void assertTrue(boolean condition) {
        assertTrue(condition, "Condition must be true");
    }

    private static void assertFalse(boolean condition, String message) {
        if (condition) throw new AssertionError(message + " (expected false)");
    }

    private static void assertFalse(boolean condition) {
        assertFalse(condition, "Condition must be false");
    }

    private static void assertNotNull(Object obj, String message) {
        if (obj == null) throw new AssertionError(message + " (expected non-null)");
    }

    // ── Helper factories ──────────────────────────────────────────────────────

    private static SyncObject makeObject(String path, String content, String peerId, long seq) {
        ObjectId id = ObjectId.generate();
        String hash = ChangeDetector.sha256(content);
        ContentVersion cv = new ContentVersion(peerId, seq);
        MetadataVersion mv = MetadataVersion.initial(peerId);
        CausalVersion causal = CausalVersion.empty().increment(peerId);
        for (long i = 1; i < seq; i++) causal = causal.increment(peerId);
        return new SyncObject(id, path, hash, content.length(), System.currentTimeMillis(),
                false, cv, mv, causal);
    }

    private static SyncObject makeObjectWithId(ObjectId id, String path, String content, String peerId, long seq) {
        String hash = ChangeDetector.sha256(content);
        ContentVersion cv = new ContentVersion(peerId, seq);
        MetadataVersion mv = MetadataVersion.initial(peerId);
        CausalVersion causal = CausalVersion.empty().increment(peerId);
        for (long i = 1; i < seq; i++) causal = causal.increment(peerId);
        return new SyncObject(id, path, hash, content.length(), System.currentTimeMillis(),
                false, cv, mv, causal);
    }

    private static List<ChangeDetector.FsEntry> toEntries(SyncManifest manifest) {
        List<ChangeDetector.FsEntry> entries = new ArrayList<>();
        for (SyncObject obj : manifest.allObjects()) {
            entries.add(new ChangeDetector.FsEntry(obj.getRelativePath(), obj.getContentHash(),
                    obj.getSizeBytes(), obj.getLastModifiedHintMs(), obj.isDirectory()));
        }
        return entries;
    }

    private static void deleteRecursively(Path root) {
        try {
            if (Files.exists(root)) {
                Files.walk(root)
                        .sorted(Comparator.reverseOrder())
                        .forEach(p -> {
                            try { Files.deleteIfExists(p); } catch (IOException ignored) {}
                        });
            }
        } catch (IOException ignored) {}
    }

    // ── Test Implementations ──────────────────────────────────────────────────

    private static void testObjectIdentityVsContentHash() {
        String identicalContent = "The exact same content bytes across two different files.";
        String hash = ChangeDetector.sha256(identicalContent);

        SyncObject obj1 = makeObject("docs/contract_v1.txt", identicalContent, "peer-A", 1);
        SyncObject obj2 = makeObject("archive/backup.txt", identicalContent, "peer-A", 1);

        assertNotNull(obj1.getObjectId(), "Object 1 must have valid objectId");
        assertNotNull(obj2.getObjectId(), "Object 2 must have valid objectId");
        assertFalse(obj1.getObjectId().equals(obj2.getObjectId()), "Equal content must NOT produce identical ObjectId");
        assertEquals(hash, obj1.getContentHash(), "Content hash 1 must match computed SHA-256");
        assertEquals(hash, obj2.getContentHash(), "Content hash 2 must match computed SHA-256");

        // When obj1 content is updated, objectId remains stable
        ObjectId originalId = obj1.getObjectId();
        obj1.applyContentChange(ChangeDetector.sha256("Updated content"), 15, System.currentTimeMillis(), "peer-A");
        assertEquals(originalId, obj1.getObjectId(), "ObjectId must remain invariant across content changes");
        assertEquals(2L, obj1.getContentVersion().sequence(), "ContentVersion sequence must increment");
    }

    private static void testCausalLineageAndVectorClocks() {
        CausalVersion base = CausalVersion.empty();
        CausalVersion vA1 = base.increment("peer-A");
        CausalVersion vA2 = vA1.increment("peer-A");
        CausalVersion vB1 = base.increment("peer-B");

        // vA2 dominates vA1
        assertEquals(CausalVersion.Relation.DOMINATES, vA2.relatedTo(vA1), "vA2 must dominate vA1");
        assertEquals(CausalVersion.Relation.DOMINATED_BY, vA1.relatedTo(vA2), "vA1 must be dominated by vA2");

        // vA1 and vB1 are concurrent (independent branches)
        assertEquals(CausalVersion.Relation.CONCURRENT, vA1.relatedTo(vB1), "Independent peer increments must be concurrent");
        assertEquals(CausalVersion.Relation.CONCURRENT, vB1.relatedTo(vA1), "Concurrence must be symmetric");

        // Merged version dominates both branches
        CausalVersion vMerged = vA1.merge(vB1).increment("peer-A");
        assertEquals(CausalVersion.Relation.DOMINATES, vMerged.relatedTo(vA1), "Merged clock must dominate vA1");
        assertEquals(CausalVersion.Relation.DOMINATES, vMerged.relatedTo(vB1), "Merged clock must dominate vB1");
    }

    private static void testSimultaneousEditsProduceConflict() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId sharedId = ObjectId.generate();
        SyncObject editA = makeObjectWithId(sharedId, "report.md", "Alice changes to report", "peer-A", 2);
        SyncObject editB = makeObjectWithId(sharedId, "report.md", "Bob changes to report", "peer-B", 2);

        manifestA.trackObject(editA);
        manifestB.trackObject(editB);

        SyncSession session = new SyncSession("sess-simul", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);

        assertEquals(1, outcome.getConflictsDetected(), "Concurrent edits must surface exactly 1 conflict");
        assertTrue(outcome.hasUnresolvedConflicts(), "Conflict must remain unresolved pending policy decision");
        assertEquals(ConflictType.CONCURRENT_CONTENT_EDIT, session.getConflicts().get(0).getConflictType(),
                "Conflict must be classified as CONCURRENT_CONTENT_EDIT");
    }

    private static void testOfflineDivergenceConvergence() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        // Both peers edit distinct files while offline
        SyncObject fileA1 = makeObject("alice/notes.txt", "Alice independent notes", "peer-A", 1);
        SyncObject fileA2 = makeObject("shared/alpha.txt", "Alice alpha doc", "peer-A", 1);
        manifestA.trackObject(fileA1);
        manifestA.trackObject(fileA2);

        SyncObject fileB1 = makeObject("bob/logs.txt", "Bob independent logs", "peer-B", 1);
        SyncObject fileB2 = makeObject("shared/beta.txt", "Bob beta doc", "peer-B", 1);
        manifestB.trackObject(fileB1);
        manifestB.trackObject(fileB2);

        // Peer A syncs with Peer B
        SyncSession sessionAB = new SyncSession("sess-ab", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        sessionAB.setRemoteManifest(manifestB);
        SyncOutcome outcomeA = engine.sync(sessionAB, toEntries(manifestA), false);
        assertTrue(outcomeA.isCompleted(), "Peer A sync must complete");

        // Peer B syncs with Peer A
        SyncSession sessionBA = new SyncSession("sess-ba", "peer-B", "peer-A", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestB);
        sessionBA.setRemoteManifest(manifestA);
        SyncOutcome outcomeB = engine.sync(sessionBA, toEntries(manifestB), false);
        assertTrue(outcomeB.isCompleted(), "Peer B sync must complete");

        // Replicas converged to all 4 files
        assertEquals(4, manifestA.objectCount(), "Peer A must have 4 converged objects");
        assertEquals(4, manifestB.objectCount(), "Peer B must have 4 converged objects");
    }

    private static void testNonConflictingRenamePropagation() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId fileId = ObjectId.generate();
        String content = "Official Project Specification";

        // Initial state at peer A
        SyncObject original = makeObjectWithId(fileId, "docs/spec_draft.pdf", content, "peer-A", 1);
        manifestA.trackObject(original);

        // Peer B renamed it to spec_final.pdf with higher causal clock
        CausalVersion renamedClock = original.getCausalVersion().increment("peer-B");
        SyncObject renamed = new SyncObject(fileId, "docs/spec_final.pdf", original.getContentHash(),
                original.getSizeBytes(), System.currentTimeMillis(), false,
                original.getContentVersion(), original.getMetadataVersion().next(), renamedClock);
        manifestB.trackObject(renamed);

        SyncSession session = new SyncSession("rename-sess", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertTrue(outcome.isCompleted(), "Non-conflicting rename must complete");
        assertEquals(0, outcome.getConflictsDetected(), "No conflicts for dominated rename");

        // Manifest A path index updated to new name; old name removed
        assertTrue(manifestA.findByPath("docs/spec_final.pdf").isPresent(), "New path must be tracked in manifest A");
        assertTrue(manifestA.findByPath("docs/spec_draft.pdf").isEmpty(), "Old path must be removed from manifest A");
        assertEquals(fileId, manifestA.findByPath("docs/spec_final.pdf").get().getObjectId(),
                "Stable ObjectId must be preserved across rename");
    }

    private static void testConcurrentRenameConflict() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId fileId = ObjectId.generate();
        String content = "Meeting summary";

        SyncObject renameA = new SyncObject(fileId, "meetings/alice_summary.txt", ChangeDetector.sha256(content),
                content.length(), System.currentTimeMillis(), false,
                ContentVersion.initial("peer-A"), MetadataVersion.initial("peer-A").next(),
                CausalVersion.empty().increment("peer-A"));

        SyncObject renameB = new SyncObject(fileId, "meetings/bob_summary.txt", ChangeDetector.sha256(content),
                content.length(), System.currentTimeMillis(), false,
                ContentVersion.initial("peer-B"), MetadataVersion.initial("peer-B").next(),
                CausalVersion.empty().increment("peer-B"));

        manifestA.trackObject(renameA);
        manifestB.trackObject(renameB);

        SyncSession session = new SyncSession("conc-rename", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertEquals(1, outcome.getConflictsDetected(), "Concurrent rename must produce conflict");
        assertEquals(ConflictType.CONCURRENT_RENAME, session.getConflicts().get(0).getConflictType());
    }

    private static void testConcurrentMoveConflict() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId fileId = ObjectId.generate();
        String contentA = "Moved and updated content A";
        String contentB = "Moved and updated content B";

        SyncObject moveA = new SyncObject(fileId, "archive_a/doc.txt", ChangeDetector.sha256(contentA),
                contentA.length(), System.currentTimeMillis(), false,
                new ContentVersion("peer-A", 2), MetadataVersion.initial("peer-A").next(),
                CausalVersion.empty().increment("peer-A"));

        SyncObject moveB = new SyncObject(fileId, "archive_b/doc.txt", ChangeDetector.sha256(contentB),
                contentB.length(), System.currentTimeMillis(), false,
                new ContentVersion("peer-B", 2), MetadataVersion.initial("peer-B").next(),
                CausalVersion.empty().increment("peer-B"));

        manifestA.trackObject(moveA);
        manifestB.trackObject(moveB);

        SyncSession session = new SyncSession("conc-move", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertEquals(1, outcome.getConflictsDetected(), "Concurrent move must produce conflict");
        assertEquals(ConflictType.CONCURRENT_MOVE, session.getConflicts().get(0).getConflictType());
    }

    private static void testBothCreatedSamePathConflict() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        // Peer A and Peer B independently created distinct files at the same path "notes.txt"
        SyncObject objA = makeObject("notes.txt", "Alice original notes", "peer-A", 1);
        SyncObject objB = makeObject("notes.txt", "Bob original notes", "peer-B", 1);

        assertFalse(objA.getObjectId().equals(objB.getObjectId()), "Distinct creations have different objectIds");

        manifestA.trackObject(objA);
        manifestB.trackObject(objB);

        SyncSession session = new SyncSession("both-path", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertEquals(1, outcome.getConflictsDetected(), "BOTH_CREATED_SAME_PATH must produce conflict");
        assertEquals(ConflictType.BOTH_CREATED_SAME_PATH, session.getConflicts().get(0).getConflictType());
    }

    private static void testTombstoneVsNewObjectConflict() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        // Peer A had an old file and deleted it, producing a tombstone
        SyncObject oldObj = makeObject("readme.txt", "Old readme", "peer-A", 1);
        manifestA.trackObject(oldObj);
        manifestA.recordDeletion(oldObj, "peer-A");
        assertTrue(manifestA.hasTombstone(oldObj.getObjectId()));

        // Peer B created a brand new object at the same path "readme.txt"
        SyncObject newObj = makeObject("readme.txt", "Brand new readme from Bob", "peer-B", 1);
        manifestB.trackObject(newObj);

        SyncSession session = new SyncSession("tomb-vs-new", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertEquals(1, outcome.getConflictsDetected(), "TOMBSTONE_VS_NEW_OBJECT must produce conflict");
        assertEquals(ConflictType.TOMBSTONE_VS_NEW_OBJECT, session.getConflicts().get(0).getConflictType());
    }

    private static void testTombstonePreventsStaleResurrection() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId fileId = ObjectId.generate();

        // Object existed at version 1
        SyncObject fileV1 = makeObjectWithId(fileId, "secrets.txt", "Old secret text", "peer-A", 1);

        // Peer B was offline and kept the stale version 1
        manifestB.trackObject(fileV1);

        // Peer A modified to version 2, then deleted it, creating tombstone with clock [A:3]
        SyncObject fileV2 = makeObjectWithId(fileId, "secrets.txt", "Updated secret text", "peer-A", 2);
        manifestA.trackObject(fileV2);
        manifestA.recordDeletion(fileV2, "peer-A");

        assertTrue(manifestA.hasTombstone(fileId), "Manifest A must have tombstone");
        assertTrue(manifestA.getTombstone(fileId).get().getDeletionCausalVersion()
                .relatedTo(fileV1.getCausalVersion()) == CausalVersion.Relation.DOMINATES,
                "Tombstone clock must dominate stale copy");

        // Sync Peer A with stale Peer B
        SyncSession session = new SyncSession("resurrect-test", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertTrue(outcome.isCompleted(), "Sync must complete");
        assertEquals(0, outcome.getConflictsDetected(), "Stale dominated copy must not conflict");

        // Crucial invariant: Stale copy was NOT resurrected on Peer A
        assertTrue(manifestA.findById(fileId).isEmpty(), "Stale copy must NOT resurrect deleted file on Peer A");
        assertTrue(manifestA.hasTombstone(fileId), "Tombstone must be preserved on Peer A");
    }

    private static void testDeleteVsModifyConflict() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId fileId = ObjectId.generate();

        // Peer A deleted it concurrently [A:2]
        SyncObject fileA = makeObjectWithId(fileId, "data.csv", "base data", "peer-A", 1);
        manifestA.trackObject(fileA);
        manifestA.recordDeletion(fileA, "peer-A");

        // Peer B modified it concurrently [B:2]
        SyncObject fileB = new SyncObject(fileId, "data.csv", ChangeDetector.sha256("bob modified"),
                20L, System.currentTimeMillis(), false,
                new ContentVersion("peer-B", 2), MetadataVersion.initial("peer-B"),
                CausalVersion.empty().increment("peer-B"));
        manifestB.trackObject(fileB);

        SyncSession session = new SyncSession("del-vs-mod", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertEquals(1, outcome.getConflictsDetected(), "Delete vs Modify must produce conflict");
        assertEquals(ConflictType.DELETE_VS_MODIFY, session.getConflicts().get(0).getConflictType());
    }

    private static void testLegitimateRestoreAfterTombstone() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId fileId = ObjectId.generate();

        // Peer A had file at [A:1], then deleted it, creating tombstone at [A:2]
        SyncObject fileA = makeObjectWithId(fileId, "contract.txt", "v1", "peer-A", 1);
        manifestA.trackObject(fileA);
        manifestA.recordDeletion(fileA, "peer-A");

        // Peer B subsequently legitimately restored / recreated it with clock [A:2, B:1] (dominating deletion)
        CausalVersion dominatingClock = manifestA.getTombstone(fileId).get()
                .getDeletionCausalVersion().increment("peer-B");
        SyncObject restoredB = new SyncObject(fileId, "contract.txt", ChangeDetector.sha256("v2-restored"),
                15L, System.currentTimeMillis(), false,
                new ContentVersion("peer-B", 2), MetadataVersion.initial("peer-B"), dominatingClock);
        manifestB.trackObject(restoredB);

        SyncSession session = new SyncSession("restore-sess", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        SyncOutcome outcome = engine.sync(session, toEntries(manifestA), false);
        assertTrue(outcome.isCompleted(), "Legitimate restore sync must complete");
        assertEquals(0, outcome.getConflictsDetected(), "No conflict on dominated deletion");

        // Dominating restore un-tombstones and tracks active object
        assertTrue(manifestA.findById(fileId).isPresent(), "Restored object must be active on Peer A");
        assertFalse(manifestA.hasTombstone(fileId), "Tombstone must be cleared upon dominating restore");
    }

    private static void testStaleManifestReconciliation() {
        SyncEngine engine = new SyncEngine();
        SyncManifest freshManifestA = new SyncManifest("peer-A");
        SyncManifest staleManifestB = new SyncManifest("peer-B");

        // Fresh peer A has 10 updated files with high causal versions
        for (int i = 0; i < 10; i++) {
            freshManifestA.trackObject(makeObject("doc_" + i + ".txt", "content " + i, "peer-A", 5));
        }

        // Stale peer B only knows about 2 old files at version 1
        staleManifestB.trackObject(makeObjectWithId(freshManifestA.findByPath("doc_0.txt").get().getObjectId(),
                "doc_0.txt", "old content 0", "peer-A", 1));
        staleManifestB.trackObject(makeObjectWithId(freshManifestA.findByPath("doc_1.txt").get().getObjectId(),
                "doc_1.txt", "old content 1", "peer-A", 1));

        SyncSession session = new SyncSession("stale-sess", "peer-B", "peer-A", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), staleManifestB);
        session.setRemoteManifest(freshManifestA);

        SyncOutcome outcome = engine.sync(session, toEntries(staleManifestB), false);
        assertTrue(outcome.isCompleted(), "Stale manifest sync must complete cleanly");
        assertEquals(0, outcome.getConflictsDetected(), "Older versions dominated by fresh peer — no conflicts");
        assertEquals(10, staleManifestB.objectCount(), "Stale peer must now be caught up to all 10 objects");
    }

    private static void testInterruptedSyncAndIdempotency() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        for (int i = 0; i < 5; i++) {
            manifestA.trackObject(makeObject("file_" + i + ".bin", "payload " + i, "peer-A", 1));
        }

        SyncSession session1 = new SyncSession("sess-part-1", "peer-B", "peer-A", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestB);
        session1.setRemoteManifest(manifestA);

        // Run sync cycle 1
        SyncOutcome outcome1 = engine.sync(session1, toEntries(manifestB), false);
        assertEquals(5, manifestB.objectCount(), "First sync receives 5 objects");

        // Re-running sync (idempotency check / recovery after network drop)
        SyncSession session2 = new SyncSession("sess-part-2", "peer-B", "peer-A", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestB);
        session2.setRemoteManifest(manifestA);

        SyncOutcome outcome2 = engine.sync(session2, toEntries(manifestB), false);
        assertEquals(5, manifestB.objectCount(), "Re-run sync must remain stable with 5 objects");
        assertEquals(0, outcome2.getChangesApplied(), "Idempotent repeat must apply 0 new changes");
        assertEquals(0, outcome2.getConflictsDetected(), "Idempotent repeat must produce 0 conflicts");
    }

    private static void testMissedWatcherEventsStartupScan() throws IOException {
        Path tempDir = Files.createTempDirectory("peerlink_scanner_test");
        try {
            // Write physical files to disk
            Files.writeString(tempDir.resolve("local_doc.txt"), "Local content", StandardCharsets.UTF_8);
            Files.createDirectories(tempDir.resolve("subfolder"));
            Files.writeString(tempDir.resolve("subfolder/report.pdf"), "PDF bytes", StandardCharsets.UTF_8);

            FilesystemScanner scanner = new FilesystemScanner(SelectiveSyncFilter.acceptAll());
            List<ChangeDetector.FsEntry> entries = scanner.scan(tempDir);

            assertEquals(3, entries.size(), "Scanner must find 2 files and 1 directory");

            SyncEngine engine = new SyncEngine();
            SyncManifest manifest = new SyncManifest("peer-A");

            // Empty manifest + scanned entries -> detect missed edits
            ChangeDetector detector = new ChangeDetector();
            List<DetectedChange> changes = detector.detect(manifest, entries, false);

            assertEquals(3, changes.size(), "Change detector must find 3 new creations");
            assertFalse(changes.get(0).fromWatcher(), "Startup scan entries must NOT be flagged as unverified watcher hints");

            SyncSession session = new SyncSession("startup-sess", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                    SelectiveSyncFilter.acceptAll(), manifest);
            engine.reconcileLocalChanges(session, changes);

            assertEquals(3, manifest.objectCount(), "Manifest must be reconciled with all 3 objects after startup scan");
        } finally {
            deleteRecursively(tempDir);
        }
    }

    private static void testDuplicateWatcherHintDeduplication() {
        SyncManifest manifest = new SyncManifest("peer-A");
        SyncObject obj = makeObject("active.txt", "content v1", "peer-A", 1);
        manifest.trackObject(obj);

        ChangeDetector detector = new ChangeDetector();

        // Single entry observed
        ChangeDetector.FsEntry entry = new ChangeDetector.FsEntry(
                "active.txt", obj.getContentHash(), obj.getSizeBytes(), obj.getLastModifiedHintMs(), false);

        // Run detector multiple times with watcher hint
        List<DetectedChange> changes1 = detector.detect(manifest, List.of(entry, entry), true);
        assertEquals(0, changes1.size(), "Unchanged content must produce 0 detected changes even when duplicate hints sent");
    }

    private static void testConflictResolutionKeepBoth() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId sharedId = ObjectId.generate();
        SyncObject localObj = makeObjectWithId(sharedId, "design/mockup.png", "Alice mockup design", "peer-A", 2);
        SyncObject remoteObj = makeObjectWithId(sharedId, "design/mockup.png", "Bob mockup design", "peer-B", 2);

        manifestA.trackObject(localObj);
        manifestB.trackObject(remoteObj);

        SyncSession session = new SyncSession("keep-both-sess", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session.setRemoteManifest(manifestB);

        engine.sync(session, toEntries(manifestA), false);
        assertEquals(1, session.getConflicts().size(), "Conflict must be detected");

        // User chooses KEEP_BOTH
        engine.executeConflictResolution(session, sharedId, ConflictResolution.KEEP_BOTH);

        // Verify divergent changes preserved
        assertEquals(2, manifestA.objectCount(), "KEEP_BOTH must preserve both divergent versions in manifest");
        assertTrue(manifestA.findByPath("design/mockup.png").isPresent(), "Original local file path preserved");

        String expectedDisambiguated = "design/mockup (conflicted copy peer-B).png";
        assertTrue(manifestA.findByPath(expectedDisambiguated).isPresent(),
                "Conflicted copy must be preserved at disambiguated path");
        assertEquals(remoteObj.getContentHash(), manifestA.findByPath(expectedDisambiguated).get().getContentHash(),
                "Disambiguated copy must preserve Bob's content hash bit-for-bit");
    }

    private static void testConflictResolutionKeepLocalAndRemote() {
        SyncEngine engine = new SyncEngine();
        SyncManifest manifestA = new SyncManifest("peer-A");
        SyncManifest manifestB = new SyncManifest("peer-B");

        ObjectId id1 = ObjectId.generate();
        SyncObject local1 = makeObjectWithId(id1, "file1.txt", "alice 1", "peer-A", 2);
        SyncObject remote1 = makeObjectWithId(id1, "file1.txt", "bob 1", "peer-B", 2);
        manifestA.trackObject(local1);
        manifestB.trackObject(remote1);

        SyncSession session1 = new SyncSession("res-kl", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session1.setRemoteManifest(manifestB);
        engine.sync(session1, toEntries(manifestA), false);

        // 1. KEEP_LOCAL resolution
        engine.executeConflictResolution(session1, id1, ConflictResolution.KEEP_LOCAL);
        assertEquals(ChangeDetector.sha256("alice 1"), manifestA.findById(id1).get().getContentHash());
        assertTrue(manifestA.findById(id1).get().getCausalVersion().relatedTo(remote1.getCausalVersion()) == CausalVersion.Relation.DOMINATES,
                "KEEP_LOCAL must make local causal version strictly dominate remote");

        // 2. KEEP_REMOTE resolution
        ObjectId id2 = ObjectId.generate();
        SyncObject local2 = makeObjectWithId(id2, "file2.txt", "alice 2", "peer-A", 2);
        SyncObject remote2 = makeObjectWithId(id2, "file2.txt", "bob 2", "peer-B", 2);
        manifestA.trackObject(local2);
        manifestB.trackObject(remote2);

        SyncSession session2 = new SyncSession("res-kr", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifestA);
        session2.setRemoteManifest(manifestB);
        engine.sync(session2, toEntries(manifestA), false);

        engine.executeConflictResolution(session2, id2, ConflictResolution.KEEP_REMOTE);
        assertEquals(ChangeDetector.sha256("bob 2"), manifestA.findById(id2).get().getContentHash(),
                "KEEP_REMOTE must adopt remote content hash");
    }

    private static void testMassChangeProtectionPolicy() {
        MassChangePolicy policy = new MassChangePolicy(10, 50, 0.5,
                MassChangePolicy.ConfirmationMode.REQUIRE_EXPLICIT_CONFIRMATION);

        MassChangeProtector protector = policy.createProtector();

        List<DetectedChange> changes = new ArrayList<>();
        for (int i = 0; i < 15; i++) {
            changes.add(new DetectedChange(ObjectId.generate(), "del_" + i + ".txt",
                    ChangeType.DELETED, null, 0, 0, false));
        }

        MassChangeProtector.Assessment assessment = protector.assess(changes, 50);
        assertTrue(assessment.triggered(), "Mass deletion above threshold must trigger protection");

        SyncManifest manifest = new SyncManifest("peer-A");
        SyncSession session = new SyncSession("mass-test", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                SelectiveSyncFilter.acceptAll(), manifest);

        session.pauseForMassChange(String.join("; ", assessment.reasons()));
        assertEquals(SyncSession.Phase.PAUSED, session.getPhase());
        assertTrue(session.isMassChangeHold());

        // Explicit user approval
        session.approveMassChange();
        assertEquals(SyncSession.Phase.RECONCILING, session.getPhase());
        assertFalse(session.isMassChangeHold());

        // Rejection path
        session.pauseForMassChange("Another burst");
        session.rejectMassChange("Safety limit reached");
        assertEquals(SyncSession.Phase.FAILED, session.getPhase());
        assertEquals("Safety limit reached", session.getFailureReason());
    }

    private static void testRealMultiPeerFilesystemConvergence() throws IOException {
        Path rootA = Files.createTempDirectory("peerlink_replica_A");
        Path rootB = Files.createTempDirectory("peerlink_replica_B");

        try {
            // Replica A files
            Files.writeString(rootA.resolve("shared.txt"), "Original shared content v1", StandardCharsets.UTF_8);
            Files.writeString(rootA.resolve("alice_file.txt"), "Alice sole file", StandardCharsets.UTF_8);

            // Replica B files
            Files.writeString(rootB.resolve("shared.txt"), "Original shared content v1", StandardCharsets.UTF_8);
            Files.writeString(rootB.resolve("bob_file.txt"), "Bob sole file", StandardCharsets.UTF_8);

            SyncEngine engine = new SyncEngine();
            SyncManifest manifestA = new SyncManifest("peer-A");
            SyncManifest manifestB = new SyncManifest("peer-B");

            // Startup scan both real directories
            FilesystemScanner scanner = new FilesystemScanner();
            List<ChangeDetector.FsEntry> entriesA = scanner.scan(rootA);
            List<ChangeDetector.FsEntry> entriesB = scanner.scan(rootB);

            ChangeDetector detector = new ChangeDetector();
            SyncSession initA = new SyncSession("init-a", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                    SelectiveSyncFilter.acceptAll(), manifestA);
            engine.reconcileLocalChanges(initA, detector.detect(manifestA, entriesA, false));

            SyncSession initB = new SyncSession("init-b", "peer-B", "peer-A", SyncMode.BIDIRECTIONAL,
                    SelectiveSyncFilter.acceptAll(), manifestB);
            engine.reconcileLocalChanges(initB, detector.detect(manifestB, entriesB, false));

            // Sync A with B
            SyncSession sessionAB = new SyncSession("sync-ab", "peer-A", "peer-B", SyncMode.BIDIRECTIONAL,
                    SelectiveSyncFilter.acceptAll(), manifestA);
            sessionAB.setRemoteManifest(manifestB);
            SyncOutcome outcomeAB = engine.sync(sessionAB, entriesA, false);

            // Sync B with A
            SyncSession sessionBA = new SyncSession("sync-ba", "peer-B", "peer-A", SyncMode.BIDIRECTIONAL,
                    SelectiveSyncFilter.acceptAll(), manifestB);
            sessionBA.setRemoteManifest(manifestA);
            SyncOutcome outcomeBA = engine.sync(sessionBA, entriesB, false);

            assertTrue(outcomeAB.isCompleted(), "Replication A->B must complete");
            assertTrue(outcomeBA.isCompleted(), "Replication B->A must complete");

            // Replicas now converge:
            // Both manifests have all distinct files
            assertTrue(manifestA.findByPath("bob_file.txt").isPresent(), "Replica A must have received bob_file.txt");
            assertTrue(manifestB.findByPath("alice_file.txt").isPresent(), "Replica B must have received alice_file.txt");

            // Check that manifests agree on object count
            assertEquals(manifestA.objectCount(), manifestB.objectCount(), "Both replicas must converge on identical object count");

        } finally {
            deleteRecursively(rootA);
            deleteRecursively(rootB);
        }
    }
}
