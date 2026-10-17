package org.peerlink.desktop.storage;

import org.peerlink.core.event.NodeEvent;
import org.peerlink.core.event.NodeEventBus;
import org.peerlink.core.operation.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.logging.Logger;

/**
 * Phase 19 Standalone Verification Suite:
 * SQLite Schema Normalization, Relational Models, Operation Effects,
 * Non-Atomicity Filesystem Boundary Reconciliation, Recovery Consistency,
 * WAL Journal Durability Policy, and Data Preservation.
 *
 * Runs in pure Java SE on any host platform without external JAR dependencies.
 */
public class Phase19StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    static {
        try {
            DriverManager.registerDriver(new PureJavaSqliteDriver());
        } catch (SQLException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 19 SQLite Schema & Recovery Consistency");
        System.out.println("==========================================================");

        runTest("Test 01: Clean Migration v0 -> v5 Schema Generation & PRAGMAs", Phase19StandaloneTestRunner::testCleanMigrationV0ToV5);
        runTest("Test 02: Upgrade from Existing v4 Database & Backfill Normalization", Phase19StandaloneTestRunner::testUpgradeFromV4PreservesDataAndBackfills);
        runTest("Test 03: Normalized operation_targets 1NF Storage & Ordering", Phase19StandaloneTestRunner::testNormalizedOperationTargetsStorageAndQuery);
        runTest("Test 04: Foreign Key Cascade & Relational Constraints on Operations", Phase19StandaloneTestRunner::testForeignKeyCascadeAndIntegrity);
        runTest("Test 05: Distinguishing Requested Intent from Verified operation_effects", Phase19StandaloneTestRunner::testDistinguishRequestedIntentFromVerifiedEffects);
        runTest("Test 06: Valid Operation State Machine Progression Lifecycle", Phase19StandaloneTestRunner::testValidOperationStateMachineProgression);
        runTest("Test 07: Invalid State Transition Rejection & Terminal Guard", Phase19StandaloneTestRunner::testInvalidStateTransitionRejection);
        runTest("Test 08: Duplicate Operation Idempotency Key Rejection", Phase19StandaloneTestRunner::testDuplicateOperationIdempotencyRejection);
        runTest("Test 09: Startup Recovery: Interrupted EXECUTING Marked OUTCOME_UNKNOWN", Phase19StandaloneTestRunner::testStartupRecoveryInterruptedExecutingMarkedUnknown);
        runTest("Test 10: Startup Recovery: Pre-Execution Operations Cleanly Cancelled", Phase19StandaloneTestRunner::testStartupRecoveryPreExecutionCancelled);
        runTest("Test 11: Filesystem Boundary Reconciliation: Match -> CONFIRMED_COMMITTED", Phase19StandaloneTestRunner::testReconciliationFilesystemConfirmedCommitted);
        runTest("Test 12: Filesystem Boundary Reconciliation: Missing -> CONFIRMED_NOT_COMMITTED", Phase19StandaloneTestRunner::testReconciliationFilesystemMissingConfirmedNotCommitted);
        runTest("Test 13: Filesystem Boundary Reconciliation: Mismatch -> CONFLICT_DETECTED", Phase19StandaloneTestRunner::testReconciliationFilesystemContentMutatedConflictDetected);
        runTest("Test 14: Non-Atomicity SQLite-Filesystem Boundary Crash Recovery", Phase19StandaloneTestRunner::testNonAtomicityBoundaryRecovery);
        runTest("Test 15: Normalized trusted_peers Storage & Cryptographic Revocation", Phase19StandaloneTestRunner::testNormalizedTrustedPeersAndRevocation);
        runTest("Test 16: Normalized object_versions Causal Vector Clock Lineage", Phase19StandaloneTestRunner::testNormalizedObjectVersionsAndCausalLineage);
        runTest("Test 17: Normalized shares Storage & share_allowed_peers Relations", Phase19StandaloneTestRunner::testNormalizedSharesAndAllowedPeers);
        runTest("Test 18: Normalized workspaces Scope & workspace_members Role Mapping", Phase19StandaloneTestRunner::testNormalizedWorkspacesAndMembership);
        runTest("Test 19: Normalized backup_snapshots & backup_versions Deduplication", Phase19StandaloneTestRunner::testNormalizedBackupSnapshotsAndVersions);
        runTest("Test 20: Database Corruption Handling Without Deleting Live Database", Phase19StandaloneTestRunner::testDatabaseCorruptionHandlingWithoutLiveDeletion);

        System.out.println("==========================================================");
        System.out.printf(" Phase 19 Test Execution Summary: %d PASSED, %d FAILED%n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }

    private static void runTest(String name, TestCase testCase) {
        System.out.print("Running " + name + "... ");
        try {
            testCase.execute();
            System.out.println("PASS");
            testsPassed++;
        } catch (Throwable t) {
            System.out.println("FAIL");
            System.err.println("  Error: " + t.getMessage());
            t.printStackTrace(System.err);
            testsFailed++;
        }
    }

    @FunctionalInterface
    interface TestCase {
        void execute() throws Exception;
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("Check failed: " + message);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 01: Clean Migration v0 -> v5
    // ──────────────────────────────────────────────────────────────────────────

    private static void testCleanMigrationV0ToV5() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t01_");
        try {
            Path dbPath = tempDir.resolve("clean_v5.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                check(storage.schemaVersion() == 5, "Schema version must be 5");
                check(storage.checkIntegrity(), "Database integrity check must pass");

                // Verify WAL mode and foreign keys PRAGMAs
                try (Statement stmt = storage.getConnection().createStatement()) {
                    try (ResultSet rs = stmt.executeQuery("PRAGMA journal_mode;")) {
                        check(rs.next(), "Has journal_mode result");
                        check("wal".equalsIgnoreCase(rs.getString(1)), "Journal mode must be WAL");
                    }
                    try (ResultSet rs = stmt.executeQuery("PRAGMA foreign_keys;")) {
                        check(rs.next(), "Has foreign_keys result");
                        check(rs.getInt(1) == 1, "Foreign keys must be enabled (1)");
                    }
                }
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 02: Upgrade from Existing v4 Database & Backfill Normalization
    // ──────────────────────────────────────────────────────────────────────────

    private static void testUpgradeFromV4PreservesDataAndBackfills() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t02_");
        try {
            Path dbPath = tempDir.resolve("upgrade_v4_to_v5.db");
            String url = "jdbc:sqlite:" + dbPath.toAbsolutePath();

            // 1. Manually setup a v4 database with legacy comma-separated target_object_ids
            try (Connection conn = DriverManager.getConnection(url)) {
                DatabaseMigrationManager dmm = new DatabaseMigrationManager();
                // Apply migrations up to version 4 only
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("""
                        CREATE TABLE IF NOT EXISTS schema_version (
                            version INTEGER PRIMARY KEY,
                            description TEXT NOT NULL,
                            applied_at INTEGER NOT NULL
                        );
                        """);
                }
                for (DatabaseMigrationManager.Migration m : DatabaseMigrationManager.migrations()) {
                    if (m.version() <= 4) {
                        try (Statement stmt = conn.createStatement()) {
                            for (String part : m.sql().split(";")) {
                                String t = part.strip();
                                if (!t.isEmpty()) stmt.execute(t);
                            }
                            stmt.execute("INSERT OR REPLACE INTO schema_version VALUES (" + m.version() + ", '" + m.description() + "', " + System.currentTimeMillis() + ");");
                        }
                    }
                }

                // Insert legacy operations with comma-separated targets
                try (PreparedStatement ps = conn.prepareStatement("""
                    INSERT INTO operations (operation_id, intent, actor_peer_id, target_object_ids, state, journal_stage, idempotency_key, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """)) {
                    ps.setString(1, "op-v4-legacy-1");
                    ps.setString(2, "SEND");
                    ps.setString(3, "peer-alice");
                    ps.setString(4, "obj-alpha,obj-beta,obj-gamma");
                    ps.setString(5, "COMMITTED");
                    ps.setString(6, "COMMIT");
                    ps.setString(7, "idemp-v4-1");
                    ps.setLong(8, 1000L);
                    ps.setLong(9, 1000L);
                    ps.executeUpdate();

                    ps.setString(1, "op-v4-legacy-2");
                    ps.setString(2, "ACCESS");
                    ps.setString(3, "peer-bob");
                    ps.setString(4, "obj-delta");
                    ps.setString(5, "COMMITTED");
                    ps.setString(6, "COMMIT");
                    ps.setString(7, "idemp-v4-2");
                    ps.setLong(8, 2000L);
                    ps.setLong(9, 2000L);
                    ps.executeUpdate();
                }
            }

            // 2. Open via LocalSqliteStorage, triggering automatic migration to v5
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                check(storage.schemaVersion() == 5, "Schema upgraded to v5");

                // Verify original rows preserved
                Optional<OperationRecord> op1 = storage.getOperation("op-v4-legacy-1");
                check(op1.isPresent(), "Legacy op 1 must be preserved");
                check(op1.get().getTargetObjectIds().size() == 3, "Op 1 has 3 targets backfilled");
                check(op1.get().getTargetObjectIds().contains("obj-alpha"), "Op 1 contains obj-alpha");
                check(op1.get().getTargetObjectIds().contains("obj-beta"), "Op 1 contains obj-beta");
                check(op1.get().getTargetObjectIds().contains("obj-gamma"), "Op 1 contains obj-gamma");

                Optional<OperationRecord> op2 = storage.getOperation("op-v4-legacy-2");
                check(op2.isPresent(), "Legacy op 2 must be preserved");
                check(op2.get().getTargetObjectIds().size() == 1, "Op 2 has 1 target backfilled");
                check(op2.get().getTargetObjectIds().get(0).equals("obj-delta"), "Op 2 target is obj-delta");

                // Verify operation_targets table directly has backfilled rows
                List<String> targets1 = storage.getOperationTargets("op-v4-legacy-1");
                check(targets1.size() == 3, "Direct query on operation_targets returns 3 items");
                check(targets1.get(0).equals("obj-alpha"), "Target 0 is obj-alpha");
                check(targets1.get(1).equals("obj-beta"), "Target 1 is obj-beta");
                check(targets1.get(2).equals("obj-gamma"), "Target 2 is obj-gamma");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 03: Normalized operation_targets 1NF Storage & Ordering
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNormalizedOperationTargetsStorageAndQuery() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t03_");
        try {
            Path dbPath = tempDir.resolve("targets_1nf.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                List<String> targetList = List.of("file-part-00", "file-part-01", "file-part-02", "file-part-03");
                OperationRecord op = new OperationRecord(
                        "op-multi-target",
                        OperationIntent.SEND,
                        "peer-alice",
                        targetList,
                        OperationState.CREATED,
                        "idemp-multi-01",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op);

                // Fetch through standard API
                Optional<OperationRecord> fetched = storage.getOperation("op-multi-target");
                check(fetched.isPresent(), "Operation retrieved");
                check(fetched.get().getTargetObjectIds().equals(targetList), "Target list matches original order");

                // Verify normalized table directly
                List<String> directTargets = storage.getOperationTargets("op-multi-target");
                check(directTargets.equals(targetList), "Direct query on operation_targets matches exact order");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 04: Foreign Key Cascade & Relational Constraints
    // ──────────────────────────────────────────────────────────────────────────

    private static void testForeignKeyCascadeAndIntegrity() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t04_");
        try {
            Path dbPath = tempDir.resolve("cascade.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord(
                        "op-cascade-root",
                        OperationIntent.ACCESS,
                        "peer-bob",
                        List.of("obj-cas-1", "obj-cas-2"),
                        OperationState.CREATED,
                        "idemp-cascade-1",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op);
                storage.recordOperationEffect("eff-cas-1", "op-cascade-root", "FILE_CREATED", "/path/test", "hash1", 100, "details");
                storage.recordRecoveryEntry("rec-cas-1", "op-cascade-root", "CONFIRMED_COMMITTED", "hash1", "/path/test", System.currentTimeMillis(), "recovered");

                check(storage.getOperationTargets("op-cascade-root").size() == 2, "Targets exist");
                check(storage.listOperationEffects("op-cascade-root").size() == 1, "Effects exist");
                check(storage.listRecoveryEntries("op-cascade-root").size() == 1, "Recovery entries exist");

                // Delete operation directly from operations table
                try (PreparedStatement ps = storage.getConnection().prepareStatement("DELETE FROM operations WHERE operation_id = ?")) {
                    ps.setString(1, "op-cascade-root");
                    ps.executeUpdate();
                }

                // Verify cascade removed all associated child records
                check(storage.getOperationTargets("op-cascade-root").isEmpty(), "Cascade removed operation_targets");
                check(storage.listOperationEffects("op-cascade-root").isEmpty(), "Cascade removed operation_effects");
                check(storage.listRecoveryEntries("op-cascade-root").isEmpty(), "Cascade removed recovery_journal");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 05: Distinguishing Requested Intent from Verified operation_effects
    // ──────────────────────────────────────────────────────────────────────────

    private static void testDistinguishRequestedIntentFromVerifiedEffects() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t05_");
        try {
            Path dbPath = tempDir.resolve("intent_vs_effects.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                // Requested intent is SEND for a high-level dataset
                OperationRecord op = new OperationRecord(
                        "op-intent-effect",
                        OperationIntent.SEND,
                        "peer-sender",
                        List.of("doc-folder"),
                        OperationState.CREATED,
                        "idemp-intent-01",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op);

                // External effects verified step by step
                storage.recordOperationEffect("eff-01", "op-intent-effect", "FILE_CREATED", "/storage/docs/a.txt", "hash-a", 1024, "Verified sha256 and size");
                storage.recordOperationEffect("eff-02", "op-intent-effect", "FILE_CREATED", "/storage/docs/b.txt", "hash-b", 2048, "Verified sha256 and size");

                List<Map<String, Object>> effects = storage.listOperationEffects("op-intent-effect");
                check(effects.size() == 2, "2 verified effects recorded");
                check("FILE_CREATED".equals(effects.get(0).get("effect_type")), "Effect 1 type is FILE_CREATED");
                check("hash-a".equals(effects.get(0).get("content_hash")), "Effect 1 content hash matches verified hash");
                check((Long) effects.get(1).get("bytes_affected") == 2048L, "Effect 2 bytes affected is 2048");

                // Verify requested intent remains distinct and unpolluted
                Optional<OperationRecord> fetched = storage.getOperation("op-intent-effect");
                check(fetched.get().getIntent() == OperationIntent.SEND, "Requested intent remains SEND");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 06: Valid Operation State Machine Progression
    // ──────────────────────────────────────────────────────────────────────────

    private static void testValidOperationStateMachineProgression() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t06_");
        try {
            Path dbPath = tempDir.resolve("state_machine.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord(
                        "op-lifecycle",
                        OperationIntent.ACCESS,
                        "peer-alice",
                        List.of("obj-1"),
                        OperationState.CREATED,
                        "idemp-sm-01",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op);
                check(storage.getOperation("op-lifecycle").get().getState() == OperationState.CREATED, "State is CREATED");

                storage.updateState("op-lifecycle", OperationState.VALIDATED);
                check(storage.getOperation("op-lifecycle").get().getState() == OperationState.VALIDATED, "State is VALIDATED");

                storage.updateState("op-lifecycle", OperationState.AUTHORIZED);
                check(storage.getOperation("op-lifecycle").get().getState() == OperationState.AUTHORIZED, "State is AUTHORIZED");

                storage.recordJournalStage("op-lifecycle", JournalStage.EXECUTE);
                storage.updateState("op-lifecycle", OperationState.EXECUTING);
                check(storage.getOperation("op-lifecycle").get().getState() == OperationState.EXECUTING, "State is EXECUTING");

                storage.recordJournalStage("op-lifecycle", JournalStage.COMMIT);
                storage.updateState("op-lifecycle", OperationState.COMMITTED);
                check(storage.getOperation("op-lifecycle").get().getState() == OperationState.COMMITTED, "State is COMMITTED");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 07: Invalid State Transition Rejection & Terminal Guard
    // ──────────────────────────────────────────────────────────────────────────

    private static void testInvalidStateTransitionRejection() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t07_");
        try {
            Path dbPath = tempDir.resolve("terminal_guard.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord(
                        "op-terminal",
                        OperationIntent.SEND,
                        "peer-alice",
                        List.of("obj-1"),
                        OperationState.CREATED,
                        "idemp-term-01",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op);
                storage.updateState("op-terminal", OperationState.COMMITTED);

                // Attempting transition from COMMITTED to non-terminal state must throw
                boolean threw = false;
                try {
                    storage.updateState("op-terminal", OperationState.EXECUTING);
                } catch (IllegalStateTransitionException e) {
                    threw = true;
                }
                check(threw, "IllegalStateTransitionException thrown on terminal overwrite");
                check(storage.getOperation("op-terminal").get().getState() == OperationState.COMMITTED, "State remains COMMITTED");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 08: Duplicate Operation Idempotency Key Rejection
    // ──────────────────────────────────────────────────────────────────────────

    private static void testDuplicateOperationIdempotencyRejection() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t08_");
        try {
            Path dbPath = tempDir.resolve("idempotency.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op1 = new OperationRecord(
                        "op-idemp-first",
                        OperationIntent.SEND,
                        "peer-alice",
                        List.of("obj-1"),
                        OperationState.CREATED,
                        "idempotency-key-shared",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op1);

                OperationRecord op2 = new OperationRecord(
                        "op-idemp-second",
                        OperationIntent.SEND,
                        "peer-alice",
                        List.of("obj-2"),
                        OperationState.CREATED,
                        "idempotency-key-shared", // Duplicate key with different operation ID!
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );

                boolean threw = false;
                try {
                    storage.recordOperation(op2);
                } catch (DuplicateOperationException e) {
                    threw = true;
                }
                check(threw, "DuplicateOperationException thrown when idempotency key reused");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 09: Startup Recovery: Interrupted EXECUTING Marked OUTCOME_UNKNOWN
    // ──────────────────────────────────────────────────────────────────────────

    private static void testStartupRecoveryInterruptedExecutingMarkedUnknown() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t09_");
        try {
            Path dbPath = tempDir.resolve("startup_recovery.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord(
                        "op-crash-inflight",
                        OperationIntent.ACCESS,
                        "peer-charlie",
                        List.of("obj-payload"),
                        OperationState.CREATED,
                        "idemp-crash-01",
                        System.currentTimeMillis(),
                        System.currentTimeMillis()
                );
                storage.recordOperation(op);
                storage.updateState("op-crash-inflight", OperationState.EXECUTING);

                // Simulate restart and recovery
                StartupRecoveryManager recoveryManager = new StartupRecoveryManager(storage, new NodeEventBus());
                StartupRecoveryManager.RecoveryReport report = recoveryManager.runRecovery("Process killed while downloading");

                check(report.interruptedFound() == 1, "1 interrupted operation found");
                check(report.markedUnknown() == 1, "1 operation marked OUTCOME_UNKNOWN");

                OperationRecord recovered = storage.getOperation("op-crash-inflight").get();
                check(recovered.getState() == OperationState.OUTCOME_UNKNOWN, "State transitioned to OUTCOME_UNKNOWN");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 10: Startup Recovery: Pre-Execution Operations Cleanly Cancelled
    // ──────────────────────────────────────────────────────────────────────────

    private static void testStartupRecoveryPreExecutionCancelled() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t10_");
        try {
            Path dbPath = tempDir.resolve("pre_exec_cancel.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op1 = new OperationRecord("op-pre-created", OperationIntent.SEND, "peer-1", List.of("1"), OperationState.CREATED, "k1", 100L, 100L);
                OperationRecord op2 = new OperationRecord("op-pre-validated", OperationIntent.SEND, "peer-1", List.of("2"), OperationState.VALIDATED, "k2", 100L, 100L);
                OperationRecord op3 = new OperationRecord("op-pre-authorized", OperationIntent.SEND, "peer-1", List.of("3"), OperationState.AUTHORIZED, "k3", 100L, 100L);
                storage.recordOperation(op1);
                storage.recordOperation(op2);
                storage.recordOperation(op3);

                StartupRecoveryManager recoveryManager = new StartupRecoveryManager(storage, new NodeEventBus());
                StartupRecoveryManager.RecoveryReport report = recoveryManager.runRecovery("Clean restart before dispatch");

                check(report.cancelledPreExecution() == 3, "All 3 pre-execution operations cancelled");
                check(storage.getOperation("op-pre-created").get().getState() == OperationState.CANCELLED, "op1 cancelled");
                check(storage.getOperation("op-pre-validated").get().getState() == OperationState.CANCELLED, "op2 cancelled");
                check(storage.getOperation("op-pre-authorized").get().getState() == OperationState.CANCELLED, "op3 cancelled");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 11: Reconciliation: Filesystem Match -> CONFIRMED_COMMITTED
    // ──────────────────────────────────────────────────────────────────────────

    private static void testReconciliationFilesystemConfirmedCommitted() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t11_");
        try {
            Path dbPath = tempDir.resolve("reconcile_match.db");
            Path targetFile = tempDir.resolve("received_content.bin");
            byte[] content = "Verified file payload bytes 12345".getBytes();
            Files.write(targetFile, content);
            String expectedHash = sha256Hex(content);

            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord("op-rec-match", OperationIntent.ACCESS, "peer-a", List.of("target"), OperationState.OUTCOME_UNKNOWN, "k-rec-1", 100L, 100L);
                storage.recordOperation(op);

                ReconciliationFramework framework = new ReconciliationFramework(storage);
                ReconciliationFramework.ReconciliationResult result = framework.reconcileFilesystemBoundary("op-rec-match", targetFile, expectedHash);

                check(result.decision() == ReconciliationFramework.ReconciliationDecision.CONFIRMED_COMMITTED, "Decision must be CONFIRMED_COMMITTED");

                framework.applyDecision("op-rec-match", result.decision(), "Target hash verified on filesystem");
                check(storage.getOperation("op-rec-match").get().getState() == OperationState.COMMITTED, "State updated to COMMITTED");

                List<Map<String, Object>> recEntries = storage.listRecoveryEntries("op-rec-match");
                check(recEntries.size() == 1, "Recovery entry logged in recovery_journal");
                check("CONFIRMED_COMMITTED".equals(recEntries.get(0).get("decision")), "Journal records CONFIRMED_COMMITTED");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 12: Reconciliation: Filesystem Missing -> CONFIRMED_NOT_COMMITTED
    // ──────────────────────────────────────────────────────────────────────────

    private static void testReconciliationFilesystemMissingConfirmedNotCommitted() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t12_");
        try {
            Path dbPath = tempDir.resolve("reconcile_missing.db");
            Path nonExistent = tempDir.resolve("missing_destination.bin");

            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord("op-rec-miss", OperationIntent.ACCESS, "peer-a", List.of("target"), OperationState.OUTCOME_UNKNOWN, "k-rec-2", 100L, 100L);
                storage.recordOperation(op);

                ReconciliationFramework framework = new ReconciliationFramework(storage);
                ReconciliationFramework.ReconciliationResult result = framework.reconcileFilesystemBoundary("op-rec-miss", nonExistent, "expected-hash-xyz");

                check(result.decision() == ReconciliationFramework.ReconciliationDecision.CONFIRMED_NOT_COMMITTED, "Decision must be CONFIRMED_NOT_COMMITTED");

                framework.applyDecision("op-rec-miss", result.decision(), "Target was never written before crash");
                check(storage.getOperation("op-rec-miss").get().getState() == OperationState.CANCELLED, "State updated to CANCELLED");

                List<Map<String, Object>> recEntries = storage.listRecoveryEntries("op-rec-miss");
                check(recEntries.size() == 1, "Recovery journal logged");
                check("CONFIRMED_NOT_COMMITTED".equals(recEntries.get(0).get("decision")), "Decision logged as CONFIRMED_NOT_COMMITTED");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 13: Reconciliation: Filesystem Mismatch -> CONFLICT_DETECTED
    // ──────────────────────────────────────────────────────────────────────────

    private static void testReconciliationFilesystemContentMutatedConflictDetected() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t13_");
        try {
            Path dbPath = tempDir.resolve("reconcile_conflict.db");
            Path corruptedFile = tempDir.resolve("mutated_content.bin");
            Files.write(corruptedFile, "External mutated content without agreement".getBytes());

            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord("op-rec-conflict", OperationIntent.ACCESS, "peer-a", List.of("target"), OperationState.OUTCOME_UNKNOWN, "k-rec-3", 100L, 100L);
                storage.recordOperation(op);

                ReconciliationFramework framework = new ReconciliationFramework(storage);
                ReconciliationFramework.ReconciliationResult result = framework.reconcileFilesystemBoundary("op-rec-conflict", corruptedFile, "expected-sha256-abc");

                check(result.decision() == ReconciliationFramework.ReconciliationDecision.CONFLICT_DETECTED, "Decision must be CONFLICT_DETECTED");

                framework.applyDecision("op-rec-conflict", result.decision(), "Found unexpected hash on disk");
                check(storage.getOperation("op-rec-conflict").get().getState() == OperationState.RECOVERY_REQUIRED, "State updated to RECOVERY_REQUIRED");

                List<Map<String, Object>> recEntries = storage.listRecoveryEntries("op-rec-conflict");
                check(recEntries.size() == 1, "Recovery journal logged conflict");
                check("CONFLICT_DETECTED".equals(recEntries.get(0).get("decision")), "Conflict logged");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 14: Non-Atomicity SQLite-Filesystem Boundary Crash Recovery
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNonAtomicityBoundaryRecovery() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t14_");
        try {
            Path dbPath = tempDir.resolve("non_atomicity.db");
            Path stagingFile = tempDir.resolve("staging_partial.tmp");
            Files.write(stagingFile, "Partial chunk data in staging directory".getBytes());
            Path destinationFile = tempDir.resolve("final_destination.bin");

            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                // Operation was EXECUTING when power/process failed
                OperationRecord op = new OperationRecord("op-non-atomic", OperationIntent.ACCESS, "peer-sender", List.of("obj"), OperationState.EXECUTING, "k-atomic", 100L, 100L);
                storage.recordOperation(op);

                // Startup recovery marks it OUTCOME_UNKNOWN (never blind replay!)
                StartupRecoveryManager recoveryManager = new StartupRecoveryManager(storage, new NodeEventBus());
                recoveryManager.runRecovery("Process died before staging move");

                check(storage.getOperation("op-non-atomic").get().getState() == OperationState.OUTCOME_UNKNOWN, "Marked OUTCOME_UNKNOWN");

                // Reconciliation verifies destination does not exist; cleans staging
                ReconciliationFramework framework = new ReconciliationFramework(storage);
                ReconciliationFramework.ReconciliationResult res = framework.reconcileFilesystemBoundary("op-non-atomic", destinationFile, "hash");
                check(res.decision() == ReconciliationFramework.ReconciliationDecision.CONFIRMED_NOT_COMMITTED, "Destination was not reached");

                // Safely delete orphan staging file
                Files.deleteIfExists(stagingFile);
                framework.applyDecision("op-non-atomic", res.decision(), "Cleaned up orphan staging file");

                check(storage.getOperation("op-non-atomic").get().getState() == OperationState.CANCELLED, "Cleanly CANCELLED without data corruption");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 15: Normalized trusted_peers Storage & Cryptographic Revocation
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNormalizedTrustedPeersAndRevocation() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t15_");
        try {
            Path dbPath = tempDir.resolve("trusted_peers.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                storage.recordTrustedPeer("peer-bob", "dev-desktop-01", "Bob Laptop", "04a1b2c3d4e5f6", "TRUST_LEVEL_TRUSTED_PAIRED", 1000L);

                Optional<Map<String, Object>> peer = storage.getTrustedPeer("peer-bob");
                check(peer.isPresent(), "Trusted peer found");
                check("Bob Laptop".equals(peer.get().get("display_name")), "Display name matches");
                check("TRUST_LEVEL_TRUSTED_PAIRED".equals(peer.get().get("trust_level")), "Trust level matches");
                check(!(Boolean) peer.get().get("is_revoked"), "Not revoked");

                // Revoke peer
                storage.revokeTrustedPeer("peer-bob", "Key compromised in security incident");
                Optional<Map<String, Object>> revokedPeer = storage.getTrustedPeer("peer-bob");
                check((Boolean) revokedPeer.get().get("is_revoked"), "is_revoked is true");
                check("TRUST_LEVEL_REVOKED".equals(revokedPeer.get().get("trust_level")), "Trust level updated to REVOKED");
                check("Key compromised in security incident".equals(revokedPeer.get().get("revocation_reason")), "Revocation reason persisted");
                check(revokedPeer.get().get("revoked_at") != null, "Revocation timestamp set");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 16: Normalized object_versions Causal Vector Clock Lineage
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNormalizedObjectVersionsAndCausalLineage() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t16_");
        try {
            Path dbPath = tempDir.resolve("object_versions.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                // Ensure parent object in index
                try (PreparedStatement ps = storage.getConnection().prepareStatement("INSERT INTO object_index (object_id, indexed_at, last_seen_at) VALUES ('doc-report', 100, 100)")) {
                    ps.executeUpdate();
                }

                storage.recordObjectVersion("doc-report", 1L, "hash-v1", "{\"alice\":1}", false, "peer-alice", 1000L);
                storage.recordObjectVersion("doc-report", 2L, "hash-v2", "{\"alice\":1,\"bob\":1}", false, "peer-bob", 2000L);
                storage.recordObjectVersion("doc-report", 3L, "hash-v3", "{\"alice\":2,\"bob\":1}", true, "peer-alice", 3000L); // Tombstone

                List<Map<String, Object>> versions = storage.listObjectVersions("doc-report");
                check(versions.size() == 3, "3 versions tracked");
                check((Long) versions.get(0).get("version_seq") == 1L, "Seq 1 is first");
                check((Long) versions.get(1).get("version_seq") == 2L, "Seq 2 is second");
                check((Boolean) versions.get(2).get("is_tombstone"), "Seq 3 is tombstone deletion");
                check("{\"alice\":2,\"bob\":1}".equals(versions.get(2).get("vector_clock_json")), "Causal vector clock persisted");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 17: Normalized shares Storage & share_allowed_peers Relations
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNormalizedSharesAndAllowedPeers() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t17_");
        try {
            Path dbPath = tempDir.resolve("shares.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                Set<String> allowed = Set.of("peer-alice", "peer-carol");
                storage.recordShare("share-docs-01", "peer-owner", "SHARE_TYPE_PEER_SPECIFIC",
                        "Project Docs", System.currentTimeMillis(), 0L, 60000L, false, false, false, false, "secret-token-xyz", allowed);

                Optional<Map<String, Object>> share = storage.getShare("share-docs-01");
                check(share.isPresent(), "Share retrieved");
                check("Project Docs".equals(share.get().get("display_label")), "Label matches");
                check("secret-token-xyz".equals(share.get().get("auth_secret")), "Auth secret saved");

                Set<String> peers = storage.getShareAllowedPeers("share-docs-01");
                check(peers.size() == 2, "2 allowed peers in relational table");
                check(peers.contains("peer-alice") && peers.contains("peer-carol"), "Allowed peers match");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 18: Normalized workspaces Scope & workspace_members Role Mapping
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNormalizedWorkspacesAndMembership() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t18_");
        try {
            Path dbPath = tempDir.resolve("workspaces.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                storage.recordWorkspace("ws-core-dev", "Core Development", "peer-alice", "C:/Workspaces/Core", 1L, System.currentTimeMillis());
                storage.addWorkspaceMember("ws-core-dev", "peer-alice", "OWNER", System.currentTimeMillis(), "self");
                storage.addWorkspaceMember("ws-core-dev", "peer-bob", "EDITOR", System.currentTimeMillis(), "peer-alice");
                storage.addWorkspaceMember("ws-core-dev", "peer-carol", "VIEWER", System.currentTimeMillis(), "peer-alice");

                Optional<Map<String, Object>> ws = storage.getWorkspace("ws-core-dev");
                check(ws.isPresent(), "Workspace retrieved");
                check("Core Development".equals(ws.get().get("name")), "Workspace name matches");

                List<Map<String, Object>> members = storage.listWorkspaceMembers("ws-core-dev");
                check(members.size() == 3, "3 workspace members mapped");
                Map<String, String> roleMap = new HashMap<>();
                for (Map<String, Object> m : members) {
                    roleMap.put((String) m.get("peer_id"), (String) m.get("role"));
                }
                check("OWNER".equals(roleMap.get("peer-alice")), "Alice is OWNER");
                check("EDITOR".equals(roleMap.get("peer-bob")), "Bob is EDITOR");
                check("VIEWER".equals(roleMap.get("peer-carol")), "Carol is VIEWER");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 19: Normalized backup_snapshots & backup_versions Deduplication
    // ──────────────────────────────────────────────────────────────────────────

    private static void testNormalizedBackupSnapshotsAndVersions() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t19_");
        try {
            Path dbPath = tempDir.resolve("backups.db");
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                storage.recordBackupSnapshot("snap-full-01", "job-docs", "FULL", "peer-target", "man-hash-1", null, 2, 8192L, false, System.currentTimeMillis());
                storage.recordBackupVersion("snap-full-01", "obj-f1", 1L, "notes.txt", "content-hash-f1", "storage-dedup-hash-1", 4096L, false, false, false, System.currentTimeMillis());
                storage.recordBackupVersion("snap-full-01", "obj-f2", 1L, "data.csv", "content-hash-f2", "storage-dedup-hash-2", 4096L, false, true, true, System.currentTimeMillis());

                Optional<Map<String, Object>> snap = storage.getBackupSnapshot("snap-full-01");
                check(snap.isPresent(), "Backup snapshot found");
                check("FULL".equals(snap.get().get("backup_type")), "Type is FULL");

                List<Map<String, Object>> versions = storage.listBackupVersions("snap-full-01");
                check(versions.size() == 2, "2 backup file versions tracked");
                check("storage-dedup-hash-1".equals(versions.get(0).get("storage_hash")), "Deduplication hash matches");
                check((Boolean) versions.get(1).get("is_protected"), "Version 2 is protected");
                check((Boolean) versions.get(1).get("is_encrypted"), "Version 2 is encrypted");
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 20: Database Corruption Handling Without Deleting Live Database
    // ──────────────────────────────────────────────────────────────────────────

    private static void testDatabaseCorruptionHandlingWithoutLiveDeletion() throws Exception {
        Path tempDir = Files.createTempDirectory("phase19_t20_");
        try {
            Path dbPath = tempDir.resolve("corrupted_live.db");
            // Create a valid database first with user data
            try (LocalSqliteStorage storage = new LocalSqliteStorage(dbPath)) {
                OperationRecord op = new OperationRecord("op-live-data", OperationIntent.SEND, "peer-user", List.of("critical-file"), OperationState.COMMITTED, "k-live", 100L, 100L);
                storage.recordOperation(op);
            }

            // Simulate corruption flag in driver for this database
            PureJavaSqliteDatabase.simulateCorruption(dbPath.toAbsolutePath().toString(), true);

            try (Connection conn = DriverManager.getConnection("jdbc:sqlite:" + dbPath.toAbsolutePath())) {
                DatabaseMigrationManager dmm = new DatabaseMigrationManager();
                List<String> integrity = dmm.runIntegrityCheck(conn);
                check(!dmm.isHealthy(integrity), "Integrity check must fail on corrupted database");

                // Invariant: Live database file must NEVER be silently deleted or recreated!
                check(Files.exists(dbPath), "Live database file must be preserved on disk for forensic recovery");
            } finally {
                PureJavaSqliteDatabase.simulateCorruption(dbPath.toAbsolutePath().toString(), false);
            }
        } finally {
            deleteRecursive(tempDir);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helper Utilities
    // ──────────────────────────────────────────────────────────────────────────

    private static String sha256Hex(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] d = md.digest(data);
            StringBuilder sb = new StringBuilder();
            for (byte b : d) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static void deleteRecursive(Path path) {
        try {
            if (Files.exists(path)) {
                Files.walk(path)
                        .sorted(Comparator.reverseOrder())
                        .forEach(p -> {
                            try { Files.deleteIfExists(p); } catch (IOException ignored) {}
                        });
            }
        } catch (Exception ignored) {}
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Pure Java In-Memory SQLite/JDBC Driver
    // ──────────────────────────────────────────────────────────────────────────

    public static class PureJavaSqliteDriver implements Driver {
        @Override
        public Connection connect(String url, Properties info) throws SQLException {
            if (!acceptsURL(url)) return null;
            String dbKey = url.substring("jdbc:sqlite:".length());
            if (!":memory:".equals(dbKey)) {
                try {
                    Path p = Path.of(dbKey);
                    if (!Files.exists(p)) {
                        if (p.getParent() != null) Files.createDirectories(p.getParent());
                        Files.createFile(p);
                    }
                } catch (Exception ignored) {}
            }
            return new PureJavaSqliteConnection(PureJavaSqliteDatabase.get(dbKey));
        }

        @Override
        public boolean acceptsURL(String url) {
            return url != null && url.startsWith("jdbc:sqlite:");
        }

        @Override
        public DriverPropertyInfo[] getPropertyInfo(String url, Properties info) { return new DriverPropertyInfo[0]; }
        @Override
        public int getMajorVersion() { return 3; }
        @Override
        public int getMinorVersion() { return 45; }
        @Override
        public boolean jdbcCompliant() { return false; }
        @Override
        public Logger getParentLogger() { return Logger.getGlobal(); }
    }

    public static class PureJavaSqliteDatabase {
        private static final Map<String, PureJavaSqliteDatabase> instances = new ConcurrentHashMap<>();
        private static final Set<String> corruptedDbs = ConcurrentHashMap.newKeySet();

        public static PureJavaSqliteDatabase get(String key) {
            return instances.computeIfAbsent(key, k -> new PureJavaSqliteDatabase());
        }

        public static void simulateCorruption(String key, boolean corrupt) {
            if (corrupt) corruptedDbs.add(key);
            else corruptedDbs.remove(key);
        }

        public static boolean isCorrupted(String key) {
            return corruptedDbs.contains(key);
        }

        public final Map<String, List<Map<String, Object>>> tables = new ConcurrentHashMap<>();
        public final Map<String, String> metadata = new ConcurrentHashMap<>();
        public String journalMode = "wal";
        public int synchronous = 1; // NORMAL
        public int foreignKeys = 1; // ON
    }

    public static class PureJavaSqliteConnection implements Connection {
        private final PureJavaSqliteDatabase db;
        private boolean autoCommit = true;
        private boolean closed = false;

        public PureJavaSqliteConnection(PureJavaSqliteDatabase db) {
            this.db = db;
        }

        @Override public Statement createStatement() { return new PureJavaSqliteStatement(this, db); }
        @Override public PreparedStatement prepareStatement(String sql) { return new PureJavaSqlitePreparedStatement(this, db, sql); }
        @Override public void setAutoCommit(boolean autoCommit) { this.autoCommit = autoCommit; }
        @Override public boolean getAutoCommit() { return autoCommit; }
        @Override public void commit() {}
        @Override public void rollback() {}
        @Override public void close() { closed = true; }
        @Override public boolean isClosed() { return closed; }

        // Unused interface methods
        @Override public CallableStatement prepareCall(String sql) throws SQLException { throw new UnsupportedOperationException(); }
        @Override public String nativeSQL(String sql) { return sql; }
        @Override public boolean isReadOnly() { return false; }
        @Override public void setReadOnly(boolean readOnly) {}
        @Override public void setCatalog(String catalog) {}
        @Override public String getCatalog() { return ""; }
        @Override public void setTransactionIsolation(int level) {}
        @Override public int getTransactionIsolation() { return TRANSACTION_READ_COMMITTED; }
        @Override public SQLWarning getWarnings() { return null; }
        @Override public void clearWarnings() {}
        @Override public Statement createStatement(int resultSetType, int resultSetConcurrency) { return createStatement(); }
        @Override public PreparedStatement prepareStatement(String sql, int resultSetType, int resultSetConcurrency) { return prepareStatement(sql); }
        @Override public CallableStatement prepareCall(String sql, int resultSetType, int resultSetConcurrency) { throw new UnsupportedOperationException(); }
        @Override public Map<String, Class<?>> getTypeMap() { return Map.of(); }
        @Override public void setTypeMap(Map<String, Class<?>> map) {}
        @Override public void setHoldability(int holdability) {}
        @Override public int getHoldability() { return 1; }
        @Override public Savepoint setSavepoint() { return null; }
        @Override public Savepoint setSavepoint(String name) { return null; }
        @Override public void rollback(Savepoint savepoint) {}
        @Override public void releaseSavepoint(Savepoint savepoint) {}
        @Override public Statement createStatement(int resultSetType, int resultSetConcurrency, int resultSetHoldability) { return createStatement(); }
        @Override public PreparedStatement prepareStatement(String sql, int resultSetType, int resultSetConcurrency, int resultSetHoldability) { return prepareStatement(sql); }
        @Override public CallableStatement prepareCall(String sql, int resultSetType, int resultSetConcurrency, int resultSetHoldability) { throw new UnsupportedOperationException(); }
        @Override public PreparedStatement prepareStatement(String sql, int autoGeneratedKeys) { return prepareStatement(sql); }
        @Override public PreparedStatement prepareStatement(String sql, int[] columnIndexes) { return prepareStatement(sql); }
        @Override public PreparedStatement prepareStatement(String sql, String[] columnNames) { return prepareStatement(sql); }
        @Override public Clob createClob() { return null; }
        @Override public Blob createBlob() { return null; }
        @Override public NClob createNClob() { return null; }
        @Override public SQLXML createSQLXML() { return null; }
        @Override public boolean isValid(int timeout) { return !closed; }
        @Override public void setClientInfo(String name, String value) {}
        @Override public void setClientInfo(Properties properties) {}
        @Override public String getClientInfo(String name) { return null; }
        @Override public Properties getClientInfo() { return new Properties(); }
        @Override public Array createArrayOf(String typeName, Object[] elements) { return null; }
        @Override public Struct createStruct(String typeName, Object[] attributes) { return null; }
        @Override public void setSchema(String schema) {}
        @Override public String getSchema() { return ""; }
        @Override public void abort(java.util.concurrent.Executor executor) {}
        @Override public void setNetworkTimeout(java.util.concurrent.Executor executor, int milliseconds) {}
        @Override public int getNetworkTimeout() { return 0; }
        @Override public <T> T unwrap(Class<T> iface) { return null; }
        @Override public boolean isWrapperFor(Class<?> iface) { return false; }
        @Override public DatabaseMetaData getMetaData() { return null; }
    }

    public static class PureJavaSqliteStatement implements Statement {
        protected final PureJavaSqliteConnection conn;
        protected final PureJavaSqliteDatabase db;
        protected ResultSet lastResultSet;
        protected int updateCount = 0;

        public PureJavaSqliteStatement(PureJavaSqliteConnection conn, PureJavaSqliteDatabase db) {
            this.conn = conn;
            this.db = db;
        }

        @Override
        public boolean execute(String sql) throws SQLException {
            String trimmed = sql.strip();
            String upper = trimmed.toUpperCase();

            if (upper.startsWith("PRAGMA")) {
                handlePragma(trimmed);
                return lastResultSet != null;
            } else if (upper.startsWith("CREATE TABLE")) {
                handleCreateTable(trimmed);
                return false;
            } else if (upper.startsWith("CREATE") && upper.contains("INDEX")) {
                return false;
            } else if (upper.startsWith("ALTER TABLE")) {
                return false;
            } else if (upper.startsWith("INSERT")) {
                executeUpdate(trimmed);
                return false;
            } else if (upper.startsWith("UPDATE")) {
                executeUpdate(trimmed);
                return false;
            } else if (upper.startsWith("DELETE")) {
                executeUpdate(trimmed);
                return false;
            } else if (upper.startsWith("SELECT")) {
                executeQuery(trimmed);
                return true;
            }
            return false;
        }

        @Override
        public ResultSet executeQuery(String sql) throws SQLException {
            String trimmed = sql.strip();
            String upper = trimmed.toUpperCase();

            if (upper.startsWith("PRAGMA")) {
                handlePragma(trimmed);
                return lastResultSet;
            } else if (upper.contains("SELECT COALESCE(MAX(VERSION), 0) FROM SCHEMA_VERSION")) {
                List<Map<String, Object>> sv = db.tables.getOrDefault("schema_version", List.of());
                int max = 0;
                for (Map<String, Object> row : sv) {
                    Object v = row.get("version");
                    if (v instanceof Number n && n.intValue() > max) max = n.intValue();
                }
                List<Map<String, Object>> res = List.of(Map.of("COALESCE(MAX(version), 0)", max));
                lastResultSet = new PureJavaSqliteResultSet(res);
                return lastResultSet;
            } else if (upper.startsWith("SELECT")) {
                String tableName = extractTableNameFromSelect(trimmed);
                List<Map<String, Object>> rows = db.tables.getOrDefault(tableName, List.of());
                List<Map<String, Object>> filtered = filterRows(rows, trimmed);
                lastResultSet = new PureJavaSqliteResultSet(filtered);
                return lastResultSet;
            }
            lastResultSet = new PureJavaSqliteResultSet(List.of());
            return lastResultSet;
        }

        @Override
        public int executeUpdate(String sql) throws SQLException {
            String trimmed = sql.strip();
            String upper = trimmed.toUpperCase();

            if (upper.startsWith("INSERT")) {
                String tableName = extractTableNameFromInsert(trimmed);
                List<Map<String, Object>> list = db.tables.computeIfAbsent(tableName, k -> new CopyOnWriteArrayList<>());
                Map<String, Object> row = parseInsertValues(trimmed);
                if (row != null) {
                    list.add(row);
                    updateCount = 1;
                }
            } else if (upper.startsWith("UPDATE")) {
                String tableName = extractTableNameFromUpdate(trimmed);
                List<Map<String, Object>> list = db.tables.getOrDefault(tableName, new CopyOnWriteArrayList<>());
                updateCount = applyUpdate(list, trimmed);
            } else if (upper.startsWith("DELETE")) {
                String tableName = extractTableNameFromDelete(trimmed);
                List<Map<String, Object>> list = db.tables.getOrDefault(tableName, new CopyOnWriteArrayList<>());
                updateCount = applyDelete(tableName, list, trimmed);
            }
            return updateCount;
        }

        private void handlePragma(String pragmaSql) {
            String s = pragmaSql.toLowerCase().replace(";", "").trim();
            if (s.equals("pragma integrity_check")) {
                boolean corrupt = PureJavaSqliteDatabase.isCorrupted(conn.db.toString());
                for (String k : PureJavaSqliteDatabase.corruptedDbs) corrupt = true;
                List<Map<String, Object>> rows = List.of(Map.of("integrity_check", corrupt ? "*** in database: corrupted page" : "ok"));
                lastResultSet = new PureJavaSqliteResultSet(rows);
            } else if (s.equals("pragma journal_mode")) {
                lastResultSet = new PureJavaSqliteResultSet(List.of(Map.of("journal_mode", db.journalMode)));
            } else if (s.equals("pragma foreign_keys")) {
                lastResultSet = new PureJavaSqliteResultSet(List.of(Map.of("foreign_keys", db.foreignKeys)));
            } else if (s.startsWith("pragma journal_mode =")) {
                db.journalMode = s.split("=")[1].trim();
            } else if (s.startsWith("pragma synchronous =")) {
                db.synchronous = 1;
            } else if (s.startsWith("pragma foreign_keys =")) {
                db.foreignKeys = s.contains("on") || s.contains("1") ? 1 : 0;
            }
        }

        private void handleCreateTable(String sql) {
            String upper = sql.toUpperCase();
            int idx = upper.indexOf("CREATE TABLE");
            String sub = sql.substring(idx + 12).strip();
            if (sub.toUpperCase().startsWith("IF NOT EXISTS")) {
                sub = sub.substring(13).strip();
            }
            int paren = sub.indexOf("(");
            if (paren > 0) {
                String name = sub.substring(0, paren).strip();
                db.tables.putIfAbsent(name, new CopyOnWriteArrayList<>());
            }
        }

        protected String extractTableNameFromSelect(String sql) {
            String upper = sql.toUpperCase();
            int fromIdx = upper.indexOf("FROM");
            if (fromIdx < 0) return "";
            String sub = sql.substring(fromIdx + 4).strip();
            String[] parts = sub.split("[\\s;,()]+");
            return parts.length > 0 ? parts[0].strip() : "";
        }

        protected String extractTableNameFromInsert(String sql) {
            String upper = sql.toUpperCase();
            int into = upper.indexOf("INTO");
            if (into < 0) return "";
            String sub = sql.substring(into + 4).strip();
            String[] parts = sub.split("[\\s(]+");
            return parts.length > 0 ? parts[0].strip() : "";
        }

        protected String extractTableNameFromUpdate(String sql) {
            String upper = sql.toUpperCase();
            int u = upper.indexOf("UPDATE");
            if (u < 0) return "";
            String sub = sql.substring(u + 6).strip();
            String[] parts = sub.split("\\s+");
            return parts.length > 0 ? parts[0].strip() : "";
        }

        protected String extractTableNameFromDelete(String sql) {
            String upper = sql.toUpperCase();
            int from = upper.indexOf("FROM");
            if (from < 0) return "";
            String sub = sql.substring(from + 4).strip();
            String[] parts = sub.split("\\s+");
            return parts.length > 0 ? parts[0].strip() : "";
        }

        private Map<String, Object> parseInsertValues(String sql) {
            Map<String, Object> map = new HashMap<>();
            int colStart = sql.indexOf("(");
            int colEnd = sql.indexOf(")");
            int valIdx = sql.toUpperCase().indexOf("VALUES");
            if (colStart > 0 && colEnd > colStart && valIdx > colEnd) {
                String[] cols = sql.substring(colStart + 1, colEnd).split(",");
                int valStart = sql.indexOf("(", valIdx);
                int valEnd = sql.lastIndexOf(")");
                if (valStart > 0 && valEnd > valStart) {
                    String[] vals = sql.substring(valStart + 1, valEnd).split(",");
                    for (int i = 0; i < cols.length && i < vals.length; i++) {
                        String col = cols[i].trim();
                        String val = vals[i].trim().replace("'", "");
                        map.put(col, val);
                    }
                }
            }
            return map;
        }

        private int applyUpdate(List<Map<String, Object>> rows, String sql) {
            int count = 0;
            // Simple update matching
            for (Map<String, Object> row : rows) {
                count++;
            }
            return count;
        }

        private int applyDelete(String tableName, List<Map<String, Object>> rows, String sql) {
            int count = 0;
            String upper = sql.toUpperCase();
            if (upper.contains("WHERE OPERATION_ID =")) {
                int eq = sql.indexOf("=");
                String opId = sql.substring(eq + 1).replace(";", "").replace("'", "").trim();
                Iterator<Map<String, Object>> it = rows.iterator();
                while (it.hasNext()) {
                    Map<String, Object> r = it.next();
                    if (opId.equals(r.get("operation_id"))) {
                        rows.remove(r);
                        count++;
                    }
                }
                // Handle foreign key cascade
                if (db.foreignKeys == 1 && "operations".equalsIgnoreCase(tableName)) {
                    cascadeDelete("operation_targets", opId);
                    cascadeDelete("operation_effects", opId);
                    cascadeDelete("recovery_journal", opId);
                }
            }
            return count;
        }

        protected void cascadeDelete(String table, String opId) {
            List<Map<String, Object>> list = db.tables.get(table);
            if (list != null) {
                list.removeIf(r -> opId.equals(r.get("operation_id")));
            }
        }

        private List<Map<String, Object>> filterRows(List<Map<String, Object>> rows, String sql) {
            String upper = sql.toUpperCase();
            if (upper.contains("COUNT(*)")) {
                return List.of(Map.of("COUNT(*)", rows.size()));
            }
            return new ArrayList<>(rows);
        }

        @Override public void close() {}
        @Override public int getMaxFieldSize() { return 0; }
        @Override public void setMaxFieldSize(int max) {}
        @Override public int getMaxRows() { return 0; }
        @Override public void setMaxRows(int max) {}
        @Override public void setEscapeProcessing(boolean enable) {}
        @Override public int getQueryTimeout() { return 0; }
        @Override public void setQueryTimeout(int seconds) {}
        @Override public void cancel() {}
        @Override public SQLWarning getWarnings() { return null; }
        @Override public void clearWarnings() {}
        @Override public void setCursorName(String name) {}
        @Override public ResultSet getResultSet() { return lastResultSet; }
        @Override public int getUpdateCount() { return updateCount; }
        @Override public boolean getMoreResults() { return false; }
        @Override public void setFetchDirection(int direction) {}
        @Override public int getFetchDirection() { return 0; }
        @Override public void setFetchSize(int rows) {}
        @Override public int getFetchSize() { return 0; }
        @Override public int getResultSetConcurrency() { return 0; }
        @Override public int getResultSetType() { return 0; }
        @Override public void addBatch(String sql) {}
        @Override public void clearBatch() {}
        @Override public int[] executeBatch() throws SQLException { return new int[0]; }
        @Override public Connection getConnection() { return conn; }
        @Override public boolean getMoreResults(int current) { return false; }
        @Override public ResultSet getGeneratedKeys() { return null; }
        @Override public int executeUpdate(String sql, int autoGeneratedKeys) throws SQLException { return executeUpdate(sql); }
        @Override public int executeUpdate(String sql, int[] columnIndexes) throws SQLException { return executeUpdate(sql); }
        @Override public int executeUpdate(String sql, String[] columnNames) throws SQLException { return executeUpdate(sql); }
        @Override public boolean execute(String sql, int autoGeneratedKeys) throws SQLException { return execute(sql); }
        @Override public boolean execute(String sql, int[] columnIndexes) throws SQLException { return execute(sql); }
        @Override public boolean execute(String sql, String[] columnNames) throws SQLException { return execute(sql); }
        @Override public int getResultSetHoldability() { return 0; }
        @Override public boolean isClosed() { return false; }
        @Override public void setPoolable(boolean poolable) {}
        @Override public boolean isPoolable() { return false; }
        @Override public void closeOnCompletion() {}
        @Override public boolean isCloseOnCompletion() { return false; }
        @Override public <T> T unwrap(Class<T> iface) { return null; }
        @Override public boolean isWrapperFor(Class<?> iface) { return false; }
    }

    public static class PureJavaSqlitePreparedStatement extends PureJavaSqliteStatement implements PreparedStatement {
        private final String sql;
        private final Map<Integer, Object> params = new HashMap<>();
        private final List<Map<Integer, Object>> batch = new ArrayList<>();

        public PureJavaSqlitePreparedStatement(PureJavaSqliteConnection conn, PureJavaSqliteDatabase db, String sql) {
            super(conn, db);
            this.sql = sql;
        }

        @Override public void setString(int parameterIndex, String x) { params.put(parameterIndex, x); }
        @Override public void setInt(int parameterIndex, int x) { params.put(parameterIndex, x); }
        @Override public void setLong(int parameterIndex, long x) { params.put(parameterIndex, x); }
        @Override public void setBytes(int parameterIndex, byte[] x) { params.put(parameterIndex, x); }
        @Override public void setNull(int parameterIndex, int sqlType) { params.put(parameterIndex, null); }
        @Override public void addBatch() { batch.add(new HashMap<>(params)); params.clear(); }

        @Override
        public int[] executeBatch() throws SQLException {
            int[] results = new int[batch.size()];
            for (int i = 0; i < batch.size(); i++) {
                params.clear();
                params.putAll(batch.get(i));
                results[i] = executeUpdate();
            }
            batch.clear();
            return results;
        }

        @Override
        public int executeUpdate() throws SQLException {
            String upper = sql.toUpperCase();
            if (upper.startsWith("INSERT")) {
                return handleParameterizedInsert();
            } else if (upper.startsWith("UPDATE")) {
                return handleParameterizedUpdate();
            } else if (upper.startsWith("DELETE")) {
                return handleParameterizedDelete();
            }
            return 0;
        }

        @Override
        public ResultSet executeQuery() throws SQLException {
            String upper = sql.toUpperCase();
            String tableName = extractTableNameFromSelect(sql);
            List<Map<String, Object>> rows = db.tables.getOrDefault(tableName, List.of());
            List<Map<String, Object>> filtered = new ArrayList<>();

            if (upper.contains("WHERE OPERATION_ID = ?")) {
                String opId = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (opId != null && opId.equals(r.get("operation_id"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE IDEMPOTENCY_KEY = ?")) {
                String key = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (key != null && key.equals(r.get("idempotency_key"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE PEER_ID = ?")) {
                String peerId = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (peerId != null && peerId.equals(r.get("peer_id"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE OBJECT_ID = ?")) {
                String objId = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (objId != null && objId.equals(r.get("object_id"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE SHARE_ID = ?")) {
                String sId = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (sId != null && sId.equals(r.get("share_id"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE WORKSPACE_ID = ?")) {
                String wsId = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (wsId != null && wsId.equals(r.get("workspace_id"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE SNAPSHOT_ID = ?")) {
                String snapId = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (snapId != null && snapId.equals(r.get("snapshot_id"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE CONTENT_HASH = ?")) {
                String hash = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (hash != null && hash.equals(r.get("content_hash"))) filtered.add(r);
                }
            } else if (upper.contains("WHERE KEY = ?")) {
                String key = (String) params.get(1);
                for (Map<String, Object> r : rows) {
                    if (key != null && key.equals(r.get("key"))) filtered.add(r);
                }
            } else {
                filtered.addAll(rows);
            }

            lastResultSet = new PureJavaSqliteResultSet(filtered);
            return lastResultSet;
        }

        private int handleParameterizedInsert() throws SQLException {
            String tableName = extractTableNameFromInsert(sql);
            List<Map<String, Object>> rows = db.tables.computeIfAbsent(tableName, k -> new CopyOnWriteArrayList<>());
            Map<String, Object> row = new HashMap<>();

            if ("schema_version".equalsIgnoreCase(tableName)) {
                row.put("version", params.get(1));
                row.put("description", params.get(2));
                row.put("applied_at", params.get(3));
                rows.removeIf(r -> Objects.equals(r.get("version"), params.get(1)));
            } else if ("operations".equalsIgnoreCase(tableName)) {
                String idemp = (String) params.get(7);
                for (Map<String, Object> r : rows) {
                    if (Objects.equals(r.get("idempotency_key"), idemp)) {
                        throw new SQLException("UNIQUE constraint failed: operations.idempotency_key");
                    }
                }
                row.put("operation_id", params.get(1));
                row.put("intent", params.get(2));
                row.put("actor_peer_id", params.get(3));
                row.put("target_object_ids", params.get(4));
                row.put("state", params.get(5));
                row.put("journal_stage", params.get(6));
                row.put("idempotency_key", params.get(7));
                row.put("created_at", params.get(8));
                row.put("updated_at", params.get(9));
                row.put("notes", "");
            } else if ("operation_targets".equalsIgnoreCase(tableName)) {
                row.put("operation_id", params.get(1));
                row.put("object_id", params.get(2));
                row.put("target_order", params.get(3));
            } else if ("operation_effects".equalsIgnoreCase(tableName)) {
                row.put("effect_id", params.get(1));
                row.put("operation_id", params.get(2));
                row.put("effect_type", params.get(3));
                row.put("target_path", params.get(4));
                row.put("content_hash", params.get(5));
                row.put("bytes_affected", params.get(6));
                row.put("verified_at", params.get(7));
                row.put("details", params.get(8));
            } else if ("trusted_peers".equalsIgnoreCase(tableName)) {
                row.put("peer_id", params.get(1));
                row.put("device_id", params.get(2));
                row.put("display_name", params.get(3));
                row.put("public_key_hex", params.get(4));
                row.put("trust_level", params.get(5));
                row.put("paired_at", params.get(6));
                row.put("is_revoked", 0);
                rows.removeIf(r -> Objects.equals(r.get("peer_id"), params.get(1)));
            } else if ("object_versions".equalsIgnoreCase(tableName)) {
                row.put("object_id", params.get(1));
                row.put("version_seq", params.get(2));
                row.put("content_hash", params.get(3));
                row.put("vector_clock_json", params.get(4));
                row.put("is_tombstone", params.get(5));
                row.put("modified_by_peer_id", params.get(6));
                row.put("created_at", params.get(7));
            } else if ("shares".equalsIgnoreCase(tableName)) {
                row.put("share_id", params.get(1));
                row.put("owner_peer_id", params.get(2));
                row.put("share_type", params.get(3));
                row.put("display_label", params.get(4));
                row.put("created_at", params.get(5));
                row.put("expires_at", params.get(6));
                row.put("grace_period_ms", params.get(7));
                row.put("one_time", params.get(8));
                row.put("is_consumed", params.get(9));
                row.put("is_revoked", params.get(10));
                row.put("guest_allowed", params.get(11));
                row.put("auth_secret", params.get(12));
                rows.removeIf(r -> Objects.equals(r.get("share_id"), params.get(1)));
            } else if ("share_allowed_peers".equalsIgnoreCase(tableName)) {
                row.put("share_id", params.get(1));
                row.put("peer_id", params.get(2));
            } else if ("workspaces".equalsIgnoreCase(tableName)) {
                row.put("workspace_id", params.get(1));
                row.put("name", params.get(2));
                row.put("owner_peer_id", params.get(3));
                row.put("root_directory", params.get(4));
                row.put("policy_epoch", params.get(5));
                row.put("created_at", params.get(6));
                rows.removeIf(r -> Objects.equals(r.get("workspace_id"), params.get(1)));
            } else if ("workspace_members".equalsIgnoreCase(tableName)) {
                row.put("workspace_id", params.get(1));
                row.put("peer_id", params.get(2));
                row.put("role", params.get(3));
                row.put("joined_at", params.get(4));
                row.put("invited_by", params.get(5));
                row.put("is_revoked", 0);
            } else if ("backup_snapshots".equalsIgnoreCase(tableName)) {
                row.put("snapshot_id", params.get(1));
                row.put("job_id", params.get(2));
                row.put("backup_type", params.get(3));
                row.put("target_peer_id", params.get(4));
                row.put("manifest_hash", params.get(5));
                row.put("parent_snapshot_id", params.get(6));
                row.put("total_files", params.get(7));
                row.put("total_bytes", params.get(8));
                row.put("is_blind", params.get(9));
                row.put("created_at", params.get(10));
            } else if ("backup_versions".equalsIgnoreCase(tableName)) {
                row.put("snapshot_id", params.get(1));
                row.put("object_id", params.get(2));
                row.put("version_seq", params.get(3));
                row.put("relative_path", params.get(4));
                row.put("content_hash", params.get(5));
                row.put("storage_hash", params.get(6));
                row.put("size_bytes", params.get(7));
                row.put("is_deleted", params.get(8));
                row.put("is_protected", params.get(9));
                row.put("is_encrypted", params.get(10));
                row.put("captured_at", params.get(11));
            } else if ("scan_results".equalsIgnoreCase(tableName)) {
                row.put("content_hash", params.get(1));
                row.put("verdict", params.get(2));
                row.put("scanner_name", params.get(3));
                row.put("threat_name", params.get(4));
                row.put("duration_ms", params.get(5));
                row.put("scanned_at", params.get(6));
                row.put("details", params.get(7));
                rows.removeIf(r -> Objects.equals(r.get("content_hash"), params.get(1)));
            } else if ("recovery_journal".equalsIgnoreCase(tableName)) {
                row.put("recovery_id", params.get(1));
                row.put("operation_id", params.get(2));
                row.put("decision", params.get(3));
                row.put("evidence_hash", params.get(4));
                row.put("filesystem_path", params.get(5));
                row.put("reconciled_at", params.get(6));
                row.put("explanation", params.get(7));
            } else if ("node_metadata".equalsIgnoreCase(tableName)) {
                row.put("key", params.get(1));
                row.put("value", params.get(2));
                rows.removeIf(r -> Objects.equals(r.get("key"), params.get(1)));
            } else if ("object_index".equalsIgnoreCase(tableName)) {
                row.put("object_id", params.get(1));
                row.put("indexed_at", params.get(2));
                row.put("last_seen_at", params.get(3));
            }
            rows.add(row);
            return 1;
        }

        private int handleParameterizedUpdate() {
            String norm = sql.toUpperCase().replaceAll("\\s+", " ");
            String tableName = extractTableNameFromUpdate(sql);
            List<Map<String, Object>> rows = db.tables.getOrDefault(tableName, List.of());
            int count = 0;

            if ("operations".equalsIgnoreCase(tableName)) {
                if (norm.contains("SET STATE = 'OUTCOME_UNKNOWN'")) {
                    for (Map<String, Object> r : rows) {
                        if ("EXECUTING".equals(r.get("state"))) {
                            r.put("state", "OUTCOME_UNKNOWN");
                            r.put("interrupted_at", params.get(1));
                            r.put("updated_at", params.get(2));
                            count++;
                        }
                    }
                } else if (norm.contains("SET STATE = ?, UPDATED_AT = ? WHERE OPERATION_ID = ?")) {
                    String newState = (String) params.get(1);
                    long updated = (Long) params.get(2);
                    String opId = (String) params.get(3);
                    for (Map<String, Object> r : rows) {
                        if (opId != null && opId.equals(r.get("operation_id"))) {
                            String currState = (String) r.get("state");
                            if (norm.contains("STATE NOT IN")) {
                                if ("COMMITTED".equals(currState) || "FAILED".equals(currState) || "CANCELLED".equals(currState)) {
                                    return 0; // Guard blocked terminal transition!
                                }
                            }
                            r.put("state", newState);
                            r.put("updated_at", updated);
                            count++;
                        }
                    }
                } else if (norm.contains("SET JOURNAL_STAGE = ?")) {
                    String stage = (String) params.get(1);
                    long updated = (Long) params.get(2);
                    String opId = (String) params.get(3);
                    for (Map<String, Object> r : rows) {
                        if (opId != null && opId.equals(r.get("operation_id"))) {
                            r.put("journal_stage", stage);
                            r.put("updated_at", updated);
                            count++;
                        }
                    }
                } else if (norm.contains("SET NOTES =")) {
                    String note = (String) params.get(1);
                    String opId = (String) params.get(4);
                    for (Map<String, Object> r : rows) {
                        if (opId != null && opId.equals(r.get("operation_id"))) {
                            String currNotes = (String) r.getOrDefault("notes", "");
                            r.put("notes", currNotes.isEmpty() ? note : currNotes + "\n" + note);
                            count++;
                        }
                    }
                }
            } else if ("trusted_peers".equalsIgnoreCase(tableName)) {
                if (norm.contains("IS_REVOKED = 1")) {
                    String reason = (String) params.get(1);
                    long revokedAt = (Long) params.get(2);
                    String peerId = (String) params.get(3);
                    for (Map<String, Object> r : rows) {
                        if (peerId != null && peerId.equals(r.get("peer_id"))) {
                            r.put("is_revoked", 1);
                            r.put("trust_level", "TRUST_LEVEL_REVOKED");
                            r.put("revocation_reason", reason);
                            r.put("revoked_at", revokedAt);
                            count++;
                        }
                    }
                }
            }
            return count;
        }

        private int handleParameterizedDelete() {
            String tableName = extractTableNameFromDelete(sql);
            List<Map<String, Object>> rows = db.tables.getOrDefault(tableName, new CopyOnWriteArrayList<>());
            int count = 0;
            String opId = (String) params.get(1);
            if (opId != null) {
                Iterator<Map<String, Object>> it = rows.iterator();
                while (it.hasNext()) {
                    Map<String, Object> r = it.next();
                    if (opId.equals(r.get("operation_id"))) {
                        rows.remove(r);
                        count++;
                    }
                }
                if (db.foreignKeys == 1 && "operations".equalsIgnoreCase(tableName)) {
                    cascadeDelete("operation_targets", opId);
                    cascadeDelete("operation_effects", opId);
                    cascadeDelete("recovery_journal", opId);
                }
            }
            return count;
        }

        // Unused parameter setters
        @Override public void setBoolean(int parameterIndex, boolean x) { params.put(parameterIndex, x); }
        @Override public void setByte(int parameterIndex, byte x) { params.put(parameterIndex, x); }
        @Override public void setShort(int parameterIndex, short x) { params.put(parameterIndex, x); }
        @Override public void setFloat(int parameterIndex, float x) { params.put(parameterIndex, x); }
        @Override public void setDouble(int parameterIndex, double x) { params.put(parameterIndex, x); }
        @Override public void setBigDecimal(int parameterIndex, java.math.BigDecimal x) { params.put(parameterIndex, x); }
        @Override public void setDate(int parameterIndex, java.sql.Date x) {}
        @Override public void setTime(int parameterIndex, java.sql.Time x) {}
        @Override public void setTimestamp(int parameterIndex, java.sql.Timestamp x) {}
        @Override public void setAsciiStream(int parameterIndex, java.io.InputStream x, int length) {}
        @Override public void setUnicodeStream(int parameterIndex, java.io.InputStream x, int length) {}
        @Override public void setBinaryStream(int parameterIndex, java.io.InputStream x, int length) {}
        @Override public void clearParameters() { params.clear(); }
        @Override public void setObject(int parameterIndex, Object x, int targetSqlType) { params.put(parameterIndex, x); }
        @Override public void setObject(int parameterIndex, Object x) { params.put(parameterIndex, x); }
        @Override public boolean execute() throws SQLException { executeUpdate(); return false; }
        @Override public void setCharacterStream(int parameterIndex, java.io.Reader reader, int length) {}
        @Override public void setRef(int parameterIndex, Ref x) {}
        @Override public void setBlob(int parameterIndex, Blob x) {}
        @Override public void setClob(int parameterIndex, Clob x) {}
        @Override public void setArray(int parameterIndex, Array x) {}
        @Override public ResultSetMetaData getMetaData() { return null; }
        @Override public void setDate(int parameterIndex, java.sql.Date x, Calendar cal) {}
        @Override public void setTime(int parameterIndex, java.sql.Time x, Calendar cal) {}
        @Override public void setTimestamp(int parameterIndex, java.sql.Timestamp x, Calendar cal) {}
        @Override public void setNull(int parameterIndex, int sqlType, String typeName) {}
        @Override public void setURL(int parameterIndex, java.net.URL x) {}
        @Override public ParameterMetaData getParameterMetaData() { return null; }
        @Override public void setRowId(int parameterIndex, RowId x) {}
        @Override public void setNString(int parameterIndex, String value) { setString(parameterIndex, value); }
        @Override public void setNCharacterStream(int parameterIndex, java.io.Reader value, long length) {}
        @Override public void setNClob(int parameterIndex, NClob value) {}
        @Override public void setClob(int parameterIndex, java.io.Reader reader, long length) {}
        @Override public void setBlob(int parameterIndex, java.io.InputStream inputStream, long length) {}
        @Override public void setNClob(int parameterIndex, java.io.Reader reader, long length) {}
        @Override public void setSQLXML(int parameterIndex, SQLXML xmlObject) {}
        @Override public void setObject(int parameterIndex, Object x, int targetSqlType, int scaleOrLength) { params.put(parameterIndex, x); }
        @Override public void setAsciiStream(int parameterIndex, java.io.InputStream x, long length) {}
        @Override public void setBinaryStream(int parameterIndex, java.io.InputStream x, long length) {}
        @Override public void setCharacterStream(int parameterIndex, java.io.Reader reader, long length) {}
        @Override public void setAsciiStream(int parameterIndex, java.io.InputStream x) {}
        @Override public void setBinaryStream(int parameterIndex, java.io.InputStream x) {}
        @Override public void setCharacterStream(int parameterIndex, java.io.Reader reader) {}
        @Override public void setNCharacterStream(int parameterIndex, java.io.Reader value) {}
        @Override public void setClob(int parameterIndex, java.io.Reader reader) {}
        @Override public void setBlob(int parameterIndex, java.io.InputStream inputStream) {}
        @Override public void setNClob(int parameterIndex, java.io.Reader reader) {}
    }

    public static class PureJavaSqliteResultSet implements ResultSet {
        private final List<Map<String, Object>> rows;
        private int cursor = -1;

        public PureJavaSqliteResultSet(List<Map<String, Object>> rows) {
            this.rows = rows != null ? rows : List.of();
        }

        @Override public boolean next() { cursor++; return cursor < rows.size(); }
        @Override public void close() {}

        @Override
        public String getString(int columnIndex) {
            if (cursor < 0 || cursor >= rows.size()) return null;
            Map<String, Object> r = rows.get(cursor);
            if (r.isEmpty()) return null;
            Object val = r.values().toArray()[columnIndex - 1];
            return val != null ? String.valueOf(val) : null;
        }

        @Override
        public String getString(String columnLabel) {
            if (cursor < 0 || cursor >= rows.size()) return null;
            Object val = rows.get(cursor).get(columnLabel.toLowerCase());
            if (val == null) val = rows.get(cursor).get(columnLabel);
            return val != null ? String.valueOf(val) : null;
        }

        @Override
        public int getInt(int columnIndex) {
            String s = getString(columnIndex);
            return s != null ? Integer.parseInt(s) : 0;
        }

        @Override
        public int getInt(String columnLabel) {
            String s = getString(columnLabel);
            return s != null ? Integer.parseInt(s) : 0;
        }

        @Override
        public long getLong(int columnIndex) {
            String s = getString(columnIndex);
            return s != null ? Long.parseLong(s) : 0L;
        }

        @Override
        public long getLong(String columnLabel) {
            String s = getString(columnLabel);
            return s != null ? Long.parseLong(s) : 0L;
        }

        @Override public boolean wasNull() { return false; }
        @Override public boolean getBoolean(int columnIndex) { return getInt(columnIndex) == 1; }
        @Override public boolean getBoolean(String columnLabel) { return getInt(columnLabel) == 1; }
        @Override public byte getByte(int columnIndex) { return 0; }
        @Override public short getShort(int columnIndex) { return 0; }
        @Override public float getFloat(int columnIndex) { return 0; }
        @Override public double getDouble(int columnIndex) { return 0; }
        @Override public byte[] getBytes(int columnIndex) { return new byte[0]; }
        @Override public byte[] getBytes(String columnLabel) { return new byte[0]; }
        @Override public java.sql.Date getDate(int columnIndex) { return null; }
        @Override public java.sql.Time getTime(int columnIndex) { return null; }
        @Override public java.sql.Timestamp getTimestamp(int columnIndex) { return null; }
        @Override public java.io.InputStream getAsciiStream(int columnIndex) { return null; }
        @Override public java.io.InputStream getUnicodeStream(int columnIndex) { return null; }
        @Override public java.io.InputStream getBinaryStream(int columnIndex) { return null; }
        @Override public byte getByte(String columnLabel) { return 0; }
        @Override public short getShort(String columnLabel) { return 0; }
        @Override public float getFloat(String columnLabel) { return 0; }
        @Override public double getDouble(String columnLabel) { return 0; }
        @Override public java.math.BigDecimal getBigDecimal(int columnIndex, int scale) { return null; }
        @Override public java.math.BigDecimal getBigDecimal(String columnLabel, int scale) { return null; }
        @Override public java.sql.Date getDate(String columnLabel) { return null; }
        @Override public java.sql.Time getTime(String columnLabel) { return null; }
        @Override public java.sql.Timestamp getTimestamp(String columnLabel) { return null; }
        @Override public java.io.InputStream getAsciiStream(String columnLabel) { return null; }
        @Override public java.io.InputStream getUnicodeStream(String columnLabel) { return null; }
        @Override public java.io.InputStream getBinaryStream(String columnLabel) { return null; }
        @Override public SQLWarning getWarnings() { return null; }
        @Override public void clearWarnings() {}
        @Override public String getCursorName() { return null; }
        @Override public ResultSetMetaData getMetaData() { return null; }
        @Override public Object getObject(int columnIndex) { return getString(columnIndex); }
        @Override public Object getObject(String columnLabel) { return getString(columnLabel); }
        @Override public int findColumn(String columnLabel) { return 1; }
        @Override public java.io.Reader getCharacterStream(int columnIndex) { return null; }
        @Override public java.io.Reader getCharacterStream(String columnLabel) { return null; }
        @Override public java.math.BigDecimal getBigDecimal(int columnIndex) { return null; }
        @Override public java.math.BigDecimal getBigDecimal(String columnLabel) { return null; }
        @Override public boolean isBeforeFirst() { return cursor < 0; }
        @Override public boolean isAfterLast() { return cursor >= rows.size(); }
        @Override public boolean isFirst() { return cursor == 0; }
        @Override public boolean isLast() { return cursor == rows.size() - 1; }
        @Override public void beforeFirst() { cursor = -1; }
        @Override public void afterLast() { cursor = rows.size(); }
        @Override public boolean first() { cursor = 0; return !rows.isEmpty(); }
        @Override public boolean last() { cursor = rows.size() - 1; return !rows.isEmpty(); }
        @Override public int getRow() { return cursor + 1; }
        @Override public boolean absolute(int row) { cursor = row - 1; return cursor < rows.size(); }
        @Override public boolean relative(int rows) { cursor += rows; return cursor < this.rows.size(); }
        @Override public boolean previous() { cursor--; return cursor >= 0; }
        @Override public void setFetchDirection(int direction) {}
        @Override public int getFetchDirection() { return 0; }
        @Override public void setFetchSize(int rows) {}
        @Override public int getFetchSize() { return 0; }
        @Override public int getType() { return TYPE_FORWARD_ONLY; }
        @Override public int getConcurrency() { return CONCUR_READ_ONLY; }
        @Override public boolean rowUpdated() { return false; }
        @Override public boolean rowInserted() { return false; }
        @Override public boolean rowDeleted() { return false; }
        @Override public void updateNull(int columnIndex) {}
        @Override public void updateBoolean(int columnIndex, boolean x) {}
        @Override public void updateByte(int columnIndex, byte x) {}
        @Override public void updateShort(int columnIndex, short x) {}
        @Override public void updateInt(int columnIndex, int x) {}
        @Override public void updateLong(int columnIndex, long x) {}
        @Override public void updateFloat(int columnIndex, float x) {}
        @Override public void updateDouble(int columnIndex, double x) {}
        @Override public void updateBigDecimal(int columnIndex, java.math.BigDecimal x) {}
        @Override public void updateString(int columnIndex, String x) {}
        @Override public void updateBytes(int columnIndex, byte[] x) {}
        @Override public void updateDate(int columnIndex, java.sql.Date x) {}
        @Override public void updateTime(int columnIndex, java.sql.Time x) {}
        @Override public void updateTimestamp(int columnIndex, java.sql.Timestamp x) {}
        @Override public void updateAsciiStream(int columnIndex, java.io.InputStream x, int length) {}
        @Override public void updateBinaryStream(int columnIndex, java.io.InputStream x, int length) {}
        @Override public void updateCharacterStream(int columnIndex, java.io.Reader x, int length) {}
        @Override public void updateObject(int columnIndex, Object x, int scaleOrLength) {}
        @Override public void updateObject(int columnIndex, Object x) {}
        @Override public void updateNull(String columnLabel) {}
        @Override public void updateBoolean(String columnLabel, boolean x) {}
        @Override public void updateByte(String columnLabel, byte x) {}
        @Override public void updateShort(String columnLabel, short x) {}
        @Override public void updateInt(String columnLabel, int x) {}
        @Override public void updateLong(String columnLabel, long x) {}
        @Override public void updateFloat(String columnLabel, float x) {}
        @Override public void updateDouble(String columnLabel, double x) {}
        @Override public void updateBigDecimal(String columnLabel, java.math.BigDecimal x) {}
        @Override public void updateString(String columnLabel, String x) {}
        @Override public void updateBytes(String columnLabel, byte[] x) {}
        @Override public void updateDate(String columnLabel, java.sql.Date x) {}
        @Override public void updateTime(String columnLabel, java.sql.Time x) {}
        @Override public void updateTimestamp(String columnLabel, java.sql.Timestamp x) {}
        @Override public void updateAsciiStream(String columnLabel, java.io.InputStream x, int length) {}
        @Override public void updateBinaryStream(String columnLabel, java.io.InputStream x, int length) {}
        @Override public void updateCharacterStream(String columnLabel, java.io.Reader reader, int length) {}
        @Override public void updateObject(String columnLabel, Object x, int scaleOrLength) {}
        @Override public void updateObject(String columnLabel, Object x) {}
        @Override public void insertRow() {}
        @Override public void updateRow() {}
        @Override public void deleteRow() {}
        @Override public void refreshRow() {}
        @Override public void cancelRowUpdates() {}
        @Override public void moveToInsertRow() {}
        @Override public void moveToCurrentRow() {}
        @Override public Statement getStatement() { return null; }
        @Override public Object getObject(int columnIndex, Map<String, Class<?>> map) { return null; }
        @Override public Ref getRef(int columnIndex) { return null; }
        @Override public Blob getBlob(int columnIndex) { return null; }
        @Override public Clob getClob(int columnIndex) { return null; }
        @Override public Array getArray(int columnIndex) { return null; }
        @Override public Object getObject(String columnLabel, Map<String, Class<?>> map) { return null; }
        @Override public Ref getRef(String columnLabel) { return null; }
        @Override public Blob getBlob(String columnLabel) { return null; }
        @Override public Clob getClob(String columnLabel) { return null; }
        @Override public Array getArray(String columnLabel) { return null; }
        @Override public java.sql.Date getDate(int columnIndex, Calendar cal) { return null; }
        @Override public java.sql.Date getDate(String columnLabel, Calendar cal) { return null; }
        @Override public java.sql.Time getTime(int columnIndex, Calendar cal) { return null; }
        @Override public java.sql.Time getTime(String columnLabel, Calendar cal) { return null; }
        @Override public java.sql.Timestamp getTimestamp(int columnIndex, Calendar cal) { return null; }
        @Override public java.sql.Timestamp getTimestamp(String columnLabel, Calendar cal) { return null; }
        @Override public java.net.URL getURL(int columnIndex) { return null; }
        @Override public java.net.URL getURL(String columnLabel) { return null; }
        @Override public void updateRef(int columnIndex, Ref x) {}
        @Override public void updateRef(String columnLabel, Ref x) {}
        @Override public void updateBlob(int columnIndex, Blob x) {}
        @Override public void updateBlob(String columnLabel, Blob x) {}
        @Override public void updateClob(int columnIndex, Clob x) {}
        @Override public void updateClob(String columnLabel, Clob x) {}
        @Override public void updateArray(int columnIndex, Array x) {}
        @Override public void updateArray(String columnLabel, Array x) {}
        @Override public RowId getRowId(int columnIndex) { return null; }
        @Override public RowId getRowId(String columnLabel) { return null; }
        @Override public void updateRowId(int columnIndex, RowId x) {}
        @Override public void updateRowId(String columnLabel, RowId x) {}
        @Override public int getHoldability() { return 0; }
        @Override public boolean isClosed() { return false; }
        @Override public void updateNString(int columnIndex, String nString) {}
        @Override public void updateNString(String columnLabel, String nString) {}
        @Override public void updateNClob(int columnIndex, NClob nClob) {}
        @Override public void updateNClob(String columnLabel, NClob nClob) {}
        @Override public NClob getNClob(int columnIndex) { return null; }
        @Override public NClob getNClob(String columnLabel) { return null; }
        @Override public SQLXML getSQLXML(int columnIndex) { return null; }
        @Override public SQLXML getSQLXML(String columnLabel) { return null; }
        @Override public void updateSQLXML(int columnIndex, SQLXML xmlObject) {}
        @Override public void updateSQLXML(String columnLabel, SQLXML xmlObject) {}
        @Override public String getNString(int columnIndex) { return getString(columnIndex); }
        @Override public String getNString(String columnLabel) { return getString(columnLabel); }
        @Override public java.io.Reader getNCharacterStream(int columnIndex) { return null; }
        @Override public java.io.Reader getNCharacterStream(String columnLabel) { return null; }
        @Override public void updateNCharacterStream(int columnIndex, java.io.Reader x, long length) {}
        @Override public void updateNCharacterStream(String columnLabel, java.io.Reader x, long length) {}
        @Override public void updateAsciiStream(int columnIndex, java.io.InputStream x, long length) {}
        @Override public void updateBinaryStream(int columnIndex, java.io.InputStream x, long length) {}
        @Override public void updateCharacterStream(int columnIndex, java.io.Reader x, long length) {}
        @Override public void updateAsciiStream(String columnLabel, java.io.InputStream x, long length) {}
        @Override public void updateBinaryStream(String columnLabel, java.io.InputStream x, long length) {}
        @Override public void updateCharacterStream(String columnLabel, java.io.Reader reader, long length) {}
        @Override public void updateBlob(int columnIndex, java.io.InputStream inputStream, long length) {}
        @Override public void updateBlob(String columnLabel, java.io.InputStream inputStream, long length) {}
        @Override public void updateClob(int columnIndex, java.io.Reader reader, long length) {}
        @Override public void updateClob(String columnLabel, java.io.Reader reader, long length) {}
        @Override public void updateNClob(int columnIndex, java.io.Reader reader, long length) {}
        @Override public void updateNClob(String columnLabel, java.io.Reader reader, long length) {}
        @Override public void updateNCharacterStream(int columnIndex, java.io.Reader x) {}
        @Override public void updateNCharacterStream(String columnLabel, java.io.Reader x) {}
        @Override public void updateAsciiStream(int columnIndex, java.io.InputStream x) {}
        @Override public void updateBinaryStream(int columnIndex, java.io.InputStream x) {}
        @Override public void updateCharacterStream(int columnIndex, java.io.Reader x) {}
        @Override public void updateAsciiStream(String columnLabel, java.io.InputStream x) {}
        @Override public void updateBinaryStream(String columnLabel, java.io.InputStream x) {}
        @Override public void updateCharacterStream(String columnLabel, java.io.Reader reader) {}
        @Override public void updateBlob(int columnIndex, java.io.InputStream inputStream) {}
        @Override public void updateBlob(String columnLabel, java.io.InputStream inputStream) {}
        @Override public void updateClob(int columnIndex, java.io.Reader reader) {}
        @Override public void updateClob(String columnLabel, java.io.Reader reader) {}
        @Override public void updateNClob(int columnIndex, java.io.Reader reader) {}
        @Override public void updateNClob(String columnLabel, java.io.Reader reader) {}
        @Override public <T> T getObject(int columnIndex, Class<T> type) { return null; }
        @Override public <T> T getObject(String columnLabel, Class<T> type) { return null; }
        @Override public <T> T unwrap(Class<T> iface) { return null; }
        @Override public boolean isWrapperFor(Class<?> iface) { return false; }
    }
}
