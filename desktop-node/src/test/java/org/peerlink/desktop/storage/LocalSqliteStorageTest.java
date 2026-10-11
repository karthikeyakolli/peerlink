package org.peerlink.desktop.storage;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.operation.*;

import java.nio.file.Path;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class LocalSqliteStorageTest {

    @TempDir
    Path tempDir;

    private Path dbPath;
    private LocalSqliteStorage storage;

    @BeforeEach
    void setUp() throws SQLException {
        dbPath = tempDir.resolve("peerlink_test.db");
        storage = new LocalSqliteStorage(dbPath);
    }

    @AfterEach
    void tearDown() {
        if (storage != null) {
            storage.close();
        }
    }

    @Test
    void testWalModeAndPragmaConfiguration() throws SQLException {
        try (Statement stmt = storage.getConnection().createStatement()) {
            try (ResultSet rs = stmt.executeQuery("PRAGMA journal_mode;")) {
                assertTrue(rs.next());
                assertEquals("wal", rs.getString(1).toLowerCase());
            }
            try (ResultSet rs = stmt.executeQuery("PRAGMA foreign_keys;")) {
                assertTrue(rs.next());
                assertEquals(1, rs.getInt(1));
            }
        }
    }

    @Test
    void testSchemaMigrationsApplied() throws SQLException {
        assertEquals(DatabaseMigrationManager.CURRENT_SCHEMA_VERSION, storage.schemaVersion());
        assertTrue(storage.checkIntegrity());
    }

    @Test
    void testOperationRecordAndStateTransitions() {
        long now = System.currentTimeMillis();
        OperationRecord op = new OperationRecord(
                "op-100",
                OperationIntent.SEND,
                "peer-alice",
                List.of("obj-1"),
                OperationState.CREATED,
                "idemp-key-100",
                now,
                now
        );

        storage.recordOperation(op);

        Optional<OperationRecord> fetched = storage.getOperation("op-100");
        assertTrue(fetched.isPresent());
        assertEquals("op-100", fetched.get().getOperationId());
        assertEquals(OperationState.CREATED, fetched.get().getState());
        assertEquals("idemp-key-100", fetched.get().getIdempotencyKey());

        // Transition CREATED -> VALIDATED -> AUTHORIZED -> EXECUTING
        storage.updateState("op-100", OperationState.VALIDATED);
        assertEquals(OperationState.VALIDATED, storage.getOperation("op-100").get().getState());

        storage.updateState("op-100", OperationState.AUTHORIZED);
        assertEquals(OperationState.AUTHORIZED, storage.getOperation("op-100").get().getState());

        storage.recordJournalStage("op-100", JournalStage.EXECUTE);
        storage.updateState("op-100", OperationState.EXECUTING);
        assertEquals(OperationState.EXECUTING, storage.getOperation("op-100").get().getState());

        // Finish: COMMITTED (terminal)
        storage.recordJournalStage("op-100", JournalStage.COMMIT);
        storage.updateState("op-100", OperationState.COMMITTED);
        assertEquals(OperationState.COMMITTED, storage.getOperation("op-100").get().getState());

        // Attempting to transition from terminal state should fail
        assertThrows(IllegalStateTransitionException.class, () ->
                storage.updateState("op-100", OperationState.EXECUTING));
    }

    @Test
    void testDuplicateIdempotencyKeyRejected() {
        long now = System.currentTimeMillis();
        OperationRecord op1 = new OperationRecord(
                "op-original",
                OperationIntent.SEND,
                "peer-alice",
                List.of("obj-1"),
                OperationState.CREATED,
                "shared-key-1",
                now,
                now
        );
        storage.recordOperation(op1);

        OperationRecord op2 = new OperationRecord(
                "op-duplicate",
                OperationIntent.SEND,
                "peer-alice",
                List.of("obj-1"),
                OperationState.CREATED,
                "shared-key-1",
                now,
                now
        );

        assertThrows(DuplicateOperationException.class, () -> storage.recordOperation(op2));
    }

    @Test
    void testInterruptedOperationsMarkedUnknownOnCrash() {
        long now = System.currentTimeMillis();
        OperationRecord executingOp = new OperationRecord(
                "op-in-flight",
                OperationIntent.SYNC,
                "peer-alice",
                List.of("obj-1"),
                OperationState.EXECUTING,
                "idemp-crash-1",
                now,
                now
        );
        storage.recordOperation(executingOp);

        List<OperationRecord> interrupted = storage.listInterruptedOperations();
        assertEquals(1, interrupted.size());
        assertEquals("op-in-flight", interrupted.get(0).getOperationId());

        storage.markInterruptedOperationsUnknown("Process crash detected");

        OperationRecord updated = storage.getOperation("op-in-flight").orElseThrow();
        assertEquals(OperationState.OUTCOME_UNKNOWN, updated.getState());

        List<OperationRecord> unknownList = storage.listUnknownOutcomeOperations();
        assertEquals(1, unknownList.size());
        assertEquals("op-in-flight", unknownList.get(0).getOperationId());
    }

    @Test
    void testObjectIndexRepositoryOperations() {
        ObjectIndexRepository repo = storage.getObjectIndex();
        long now = System.currentTimeMillis();

        ObjectIndexRepository.ObjectIndexEntry entry = new ObjectIndexRepository.ObjectIndexEntry(
                "obj-xyz",
                "sha256-abcdef1234567890",
                "/tmp/testfile.dat",
                1048576L,
                "application/octet-stream",
                now,
                now,
                ObjectIndexRepository.IndexState.ACTIVE
        );

        repo.upsertObject(entry);

        Optional<ObjectIndexRepository.ObjectIndexEntry> fetched = repo.findById("obj-xyz");
        assertTrue(fetched.isPresent());
        assertEquals("obj-xyz", fetched.get().objectId());
        assertEquals("sha256-abcdef1234567890", fetched.get().contentHash());
        assertEquals(1048576L, fetched.get().sizeBytes());

        // Find by content hash
        List<ObjectIndexRepository.ObjectIndexEntry> byHash = repo.findByContentHash("sha256-abcdef1234567890");
        assertEquals(1, byHash.size());

        // Mark stale
        repo.markStale("obj-xyz");
        assertEquals(ObjectIndexRepository.IndexState.STALE, repo.findById("obj-xyz").get().indexState());

        // Mark deleted
        repo.markDeleted("obj-xyz");
        assertEquals(ObjectIndexRepository.IndexState.DELETED, repo.findById("obj-xyz").get().indexState());
    }

    @Test
    void testMetadataStorage() {
        storage.setMetadata("node_mode", "DESKTOP");
        assertEquals(Optional.of("DESKTOP"), storage.getMetadata("node_mode"));
        assertEquals(Optional.empty(), storage.getMetadata("non_existent_key"));
    }

    @Test
    void testDurableTransferSessionJournalDelegation() {
        assertNotNull(storage.getTransferSessionJournal());

        long now = System.currentTimeMillis();
        org.peerlink.core.transfer.TransferSessionRecord session = new org.peerlink.core.transfer.TransferSessionRecord(
                "xfer-401", "op-401", "peer-alice", "peer-bob",
                org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_TRANSFERRING,
                10240, 2, now
        );

        storage.recordSession(session);

        Optional<org.peerlink.core.transfer.TransferSessionRecord> fetched = storage.getSession("xfer-401");
        assertTrue(fetched.isPresent());
        assertEquals("op-401", fetched.get().getOperationId());
        assertEquals(org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_TRANSFERRING, fetched.get().getState());

        // Update chunk statuses and metadata
        storage.updateChunkMetadata("xfer-401", 0, 0, 0, 1024, "chunk-hash-0", org.peerlink.protocol.v1.ChunkStatus.CHUNK_STATUS_ACKED);
        storage.updateChunkMetadata("xfer-401", 0, 1, 1024, 1024, "chunk-hash-1", org.peerlink.protocol.v1.ChunkStatus.CHUNK_STATUS_ACKED);

        var acked = storage.getAckedChunks("xfer-401", 0);
        assertEquals(2, acked.size());
        assertTrue(acked.contains(0L));
        assertTrue(acked.contains(1L));

        // Verify incomplete sessions list
        List<org.peerlink.core.transfer.TransferSessionRecord> incomplete = storage.getIncompleteSessions();
        assertFalse(incomplete.isEmpty());
        assertTrue(incomplete.stream().anyMatch(s -> s.getTransferId().equals("xfer-401")));
    }
}

