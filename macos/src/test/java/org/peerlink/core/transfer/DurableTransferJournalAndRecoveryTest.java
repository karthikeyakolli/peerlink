package org.peerlink.core.transfer;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationJournal;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Phase 05 Failure-Injection & Recovery Test Suite.
 *
 * Verifies durable SQLite transfer-session journaling, durability contracts,
 * acknowledgement order invariants, crash recovery, and reconciliation.
 */
class DurableTransferJournalAndRecoveryTest {

    @TempDir
    Path tempDir;

    private Path dbPath;
    private Path stagingDir;
    private Path destDir;

    private Connection dbConnection;
    private SqliteTransferSessionJournal sessionJournal;
    private TestOperationJournal opJournal;
    private StagingDirectoryManager stagingManager;
    private PeerTransferEngine engine;

    @BeforeEach
    void setUp() throws SQLException, IOException {
        dbPath = tempDir.resolve("journal_test.db");
        stagingDir = tempDir.resolve("staging");
        destDir = tempDir.resolve("dest");

        Files.createDirectories(stagingDir);
        Files.createDirectories(destDir);

        openDatabase();
        opJournal = new TestOperationJournal();
        stagingManager = new StagingDirectoryManager(stagingDir);
        engine = new PeerTransferEngine(opJournal, sessionJournal, stagingManager,
                new TransferPreflight(), new DestinationConflictResolver(),
                new BandwidthLimiter(), new TransferQueueManager());
    }

    private void openDatabase() throws SQLException {
        dbConnection = DriverManager.getConnection("jdbc:sqlite:" + dbPath.toAbsolutePath());
        try (Statement stmt = dbConnection.createStatement()) {
            stmt.execute("PRAGMA journal_mode = WAL;");
            stmt.execute("PRAGMA synchronous = NORMAL;");
        }
        sessionJournal = new SqliteTransferSessionJournal(dbConnection);
    }

    private void closeDatabase() throws SQLException {
        if (dbConnection != null && !dbConnection.isClosed()) {
            dbConnection.close();
        }
    }

    @AfterEach
    void tearDown() throws SQLException {
        closeDatabase();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 1. Process termination during transfer
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testProcessTerminationDuringTransferAndRestart() throws Exception {
        String transferId = "xfer-crash-mid";
        String opId = "op-crash-mid";
        byte[] fileBytes = "Chunk 0 data, Chunk 1 data, Chunk 2 data".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "test.txt", fileBytes, 15);
        setupSession(transferId, opId, manifest);

        // Receive chunk 0 and chunk 1
        byte[] chunk0 = Arrays.copyOfRange(fileBytes, 0, 15);
        byte[] chunk1 = Arrays.copyOfRange(fileBytes, 15, 30);

        TransferChunkAck ack0 = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, chunk0));
        assertTrue(ack0.getSuccess());

        TransferChunkAck ack1 = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 1, 15, chunk1));
        assertTrue(ack1.getSuccess());

        // Verify chunks persisted in SQLite
        Set<Long> ackedBeforeCrash = sessionJournal.getAckedChunks(transferId, 0);
        assertEquals(Set.of(0L, 1L), ackedBeforeCrash);

        // Simulate crash: close DB connection and discard engine instance
        closeDatabase();

        // Simulate restart: reopen DB and initialize fresh engine
        openDatabase();
        PeerTransferEngine restartedEngine = new PeerTransferEngine(opJournal, sessionJournal, stagingDir);

        // Reconcile at startup
        var report = restartedEngine.reconcileAtStartup(destDir);
        assertEquals(1, report.examinedSessions());
        assertEquals(1, report.pausedForResume());
        assertTrue(report.diagnostics().get(0).contains("marked PAUSED"));

        // Verify session in SQLite is PAUSED and acked chunks are intact
        var session = sessionJournal.getSession(transferId).orElseThrow();
        assertEquals(TransferState.TRANSFER_STATE_PAUSED, session.getState());
        assertEquals(Set.of(0L, 1L), sessionJournal.getAckedChunks(transferId, 0));

        // Sender offers resume
        TransferResumeOffer resumeOffer = TransferResumeOffer.newBuilder()
                .setTransferId(transferId)
                .setManifest(manifest)
                .build();
        TransferResumeState resumeState = restartedEngine.handleResumeOffer(resumeOffer, destDir);
        assertTrue(resumeState.getCanResume());
        assertEquals(2, resumeState.getAckedChunkIndicesCount());

        // Resume: transfer chunk 2
        byte[] chunk2 = Arrays.copyOfRange(fileBytes, 30, fileBytes.length);
        TransferChunkAck ack2 = restartedEngine.handleIncomingChunk(createChunkMsg(transferId, 0, 2, 30, chunk2));
        assertTrue(ack2.getSuccess());

        // Verify and commit
        TransferVerifyResult verify = restartedEngine.verifyReceivedTransfer(transferId, manifest);
        assertTrue(verify.getVerified());
        TransferCompletedReceipt finResp = restartedEngine.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(finResp.getSuccess());

        // Verify final content
        Path finalized = destDir.resolve("test.txt");
        assertTrue(Files.exists(finalized));
        assertArrayEquals(fileBytes, Files.readAllBytes(finalized));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Process termination after receiving data but before acknowledgement
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testProcessTerminationAfterReceivingDataBeforeAcknowledgement() throws Exception {
        String transferId = "xfer-unacked-write";
        String opId = "op-unacked-write";
        byte[] fileBytes = "Deterministic chunk data payload".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "unacked.txt", fileBytes, 16);
        setupSession(transferId, opId, manifest);

        byte[] chunk0 = Arrays.copyOfRange(fileBytes, 0, 16);
        byte[] chunk1 = Arrays.copyOfRange(fileBytes, 16, fileBytes.length);

        // Chunk 0 is normally acknowledged
        TransferChunkAck ack0 = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, chunk0));
        assertTrue(ack0.getSuccess());

        // Simulate chunk 1 data written to staging, but process crashes before SQLite metadata update / ACK
        stagingManager.writeChunk(transferId, 0, 1, 16, chunk1, null, fileBytes.length);

        // Simulate crash
        closeDatabase();
        openDatabase();
        PeerTransferEngine restartedEngine = new PeerTransferEngine(opJournal, sessionJournal, stagingDir);

        // SQLite only contains chunk 0
        Set<Long> ackedInDb = sessionJournal.getAckedChunks(transferId, 0);
        assertEquals(Set.of(0L), ackedInDb);
        assertFalse(ackedInDb.contains(1L));

        // Sender re-sends unacknowledged chunk 1
        TransferChunkAck ack1 = restartedEngine.handleIncomingChunk(createChunkMsg(transferId, 0, 1, 16, chunk1));
        assertTrue(ack1.getSuccess());
        assertTrue(sessionJournal.getAckedChunks(transferId, 0).contains(1L));

        // Finalize and verify
        TransferVerifyResult verify = restartedEngine.verifyReceivedTransfer(transferId, manifest);
        assertTrue(verify.getVerified());
        TransferCompletedReceipt finResp = restartedEngine.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(finResp.getSuccess());
        assertArrayEquals(fileBytes, Files.readAllBytes(destDir.resolve("unacked.txt")));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Process termination after acknowledgement but before next persisted state
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testProcessTerminationAfterAcknowledgementBeforeNextState() throws Exception {
        String transferId = "xfer-ack-before-state";
        String opId = "op-ack-before-state";
        byte[] fileBytes = "Data acked safely in SQLite".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "ack_state.txt", fileBytes, 32);
        setupSession(transferId, opId, manifest);

        // Chunk 0 is acknowledged and recorded in SQLite
        TransferChunkAck ack0 = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, fileBytes));
        assertTrue(ack0.getSuccess());

        // Crash occurs before finalize
        closeDatabase();
        openDatabase();
        PeerTransferEngine restartedEngine = new PeerTransferEngine(opJournal, sessionJournal, stagingDir);

        var report = restartedEngine.reconcileAtStartup(destDir);
        assertEquals(1, report.pausedForResume());

        // Acked chunk is safely retained in SQLite
        assertEquals(Set.of(0L), sessionJournal.getAckedChunks(transferId, 0));

        // Finalize completes successfully
        TransferVerifyResult verify = restartedEngine.verifyReceivedTransfer(transferId, manifest);
        assertTrue(verify.getVerified());
        TransferCompletedReceipt finResp = restartedEngine.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(finResp.getSuccess());
        assertTrue(Files.exists(destDir.resolve("ack_state.txt")));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Full disk and SQLite write failures
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testSqliteWriteFailurePreventsPositiveAcknowledgement() throws Exception {
        String transferId = "xfer-db-fail";
        String opId = "op-db-fail";
        byte[] data = "Failure injection data".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "fail.txt", data, 32);
        setupSession(transferId, opId, manifest);

        // Put database connection in read-only mode to simulate SQLite write failure
        try (Statement stmt = dbConnection.createStatement()) {
            stmt.execute("PRAGMA query_only = ON;");
        }

        // Attempt to process chunk: must NOT return success = true!
        TransferChunkAck ack = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, data));
        assertFalse(ack.getSuccess(), "Must NOT acknowledge positive completion when SQLite write fails");
        assertTrue(ack.getRetryRequested());
        assertTrue(ack.getErrorMessage().contains("persistence failure") || ack.getErrorMessage().contains("readonly"));

        // Restore read-write
        try (Statement stmt = dbConnection.createStatement()) {
            stmt.execute("PRAGMA query_only = OFF;");
        }

        // Now retrying succeeds
        TransferChunkAck retryAck = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, data));
        assertTrue(retryAck.getSuccess());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Corrupted or missing staging files
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testCorruptedChunkAndMissingStagingRecovery() throws Exception {
        String transferId = "xfer-corrupt-staging";
        String opId = "op-corrupt-staging";
        byte[] validData = "Good data payload".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "corrupt.txt", validData, 32);
        setupSession(transferId, opId, manifest);

        // Send chunk with corrupt hash
        TransferChunk corruptChunk = TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(validData))
                .setChunkSha256("0000000000000000000000000000000000000000000000000000000000000000") // corrupt hash
                .build();

        TransferChunkAck ack = engine.handleIncomingChunk(corruptChunk);
        assertFalse(ack.getSuccess());
        assertTrue(ack.getRetryRequested());

        // Test missing staging file during startup reconciliation
        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_TRANSFERRING);
        stagingManager.cleanupStaging(transferId);

        var report = engine.reconcileAtStartup(destDir);
        assertEquals(1, report.markedFailed());
        assertTrue(report.diagnostics().get(0).contains("Staging missing, marked FAILED"));
        assertEquals(TransferState.TRANSFER_STATE_FAILED, sessionJournal.getSession(transferId).orElseThrow().getState());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 6. Lost connections and duplicate chunks
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testDuplicateChunksHandledIdempotently() throws Exception {
        String transferId = "xfer-idempotent-dup";
        String opId = "op-idempotent-dup";
        byte[] data = "Duplicate chunk test data payload".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "dup.txt", data, 64);
        setupSession(transferId, opId, manifest);

        TransferChunk chunkMsg = createChunkMsg(transferId, 0, 0, 0, data);

        // First delivery: success
        TransferChunkAck ack1 = engine.handleIncomingChunk(chunkMsg);
        assertTrue(ack1.getSuccess());
        assertEquals(data.length, ack1.getBytesReceived());

        // Duplicate delivery (lost connection / retransmitted packet): idempotent success
        TransferChunkAck ack2 = engine.handleIncomingChunk(chunkMsg);
        assertTrue(ack2.getSuccess());
        assertEquals(data.length, ack2.getBytesReceived());

        // Conflicting duplicate delivery (tampered data with different hash): rejected!
        TransferChunk conflicting = TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom("Tampered data".getBytes(StandardCharsets.UTF_8)))
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex("Tampered data".getBytes(StandardCharsets.UTF_8)))
                .build();

        TransferChunkAck conflictAck = engine.handleIncomingChunk(conflicting);
        assertFalse(conflictAck.getSuccess());
        assertFalse(conflictAck.getRetryRequested());
        assertTrue(conflictAck.getErrorMessage().contains("Conflicting chunk"));
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Failure during finalization
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testFailureDuringFinalizationNeverBlindlyReplaysUncertainCommit() throws Exception {
        String transferId = "xfer-uncertain-fin";
        String opId = "op-uncertain-fin";

        byte[] file0Data = "File 0 content".getBytes(StandardCharsets.UTF_8);
        byte[] file1Data = "File 1 content".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setChunkSizeBytes(64)
                .addItems(TransferItem.newBuilder()
                        .setRelativePath("file0.txt")
                        .setFileSizeBytes(file0Data.length)
                        .setSha256Hex(FileManifestBuilder.calculateSha256Hex(file0Data))
                        .setIsDirectory(false)
                        .build())
                .addItems(TransferItem.newBuilder()
                        .setRelativePath("file1.txt")
                        .setFileSizeBytes(file1Data.length)
                        .setSha256Hex(FileManifestBuilder.calculateSha256Hex(file1Data))
                        .setIsDirectory(false)
                        .build())
                .build();

        setupSession(transferId, opId, manifest);

        // Receive chunks for both files
        engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, file0Data));
        engine.handleIncomingChunk(createChunkMsg(transferId, 1, 0, 0, file1Data));

        // Simulate crash during finalization where file0 was moved to destination, but file1 was not!
        Files.write(destDir.resolve("file0.txt"), file0Data);
        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_COMMITTING);
        opJournal.updateState(opId, OperationState.EXECUTING);

        // Node restarts and runs reconciliation
        var report = engine.reconcileAtStartup(destDir);
        assertEquals(1, report.uncertainPartials());
        assertTrue(report.diagnostics().get(0).contains("Partial commit detected, marked OUTCOME_UNKNOWN"));

        // Invariant: Operation is marked OUTCOME_UNKNOWN — NEVER blindly replayed
        assertEquals(OperationState.OUTCOME_UNKNOWN, opJournal.getOperation(opId).orElseThrow().getState());
        assertEquals(TransferState.TRANSFER_STATE_FAILED, sessionJournal.getSession(transferId).orElseThrow().getState());
    }

    @Test
    void testCrashAfterCompletePromotionBeforeDbCommitReconcilesToCompleted() throws Exception {
        String transferId = "xfer-full-promoted";
        String opId = "op-full-promoted";
        byte[] fileData = "Fully promoted content".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = createManifest(transferId, "full.txt", fileData, 64);
        setupSession(transferId, opId, manifest);

        // File was fully placed in destination before crash
        Files.write(destDir.resolve("full.txt"), fileData);
        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_COMMITTING);
        opJournal.updateState(opId, OperationState.EXECUTING);

        // Reconciliation detects all items match manifest hashes
        var report = engine.reconcileAtStartup(destDir);
        assertEquals(1, report.recoveredCompleted());

        assertEquals(OperationState.COMMITTED, opJournal.getOperation(opId).orElseThrow().getState());
        assertEquals(TransferState.TRANSFER_STATE_COMPLETED, sessionJournal.getSession(transferId).orElseThrow().getState());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 8. Restart with a partially completed multi-file transfer
    // ──────────────────────────────────────────────────────────────────────────

    @Test
    void testRestartWithPartiallyCompletedMultiFileTransferTruncatesUnackedTornBytes() throws Exception {
        String transferId = "xfer-multi-partial";
        String opId = "op-multi-partial";

        byte[] file0Data = "Complete file 0 payload".getBytes(StandardCharsets.UTF_8);
        byte[] file1Chunk0 = "Chunk 0 of file 1 (ACKed)".getBytes(StandardCharsets.UTF_8);
        byte[] file1TornBytes = "Torn unacknowledged trailing bytes".getBytes(StandardCharsets.UTF_8);

        TransferManifest manifest = TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setChunkSizeBytes(32)
                .addItems(TransferItem.newBuilder()
                        .setRelativePath("multi0.txt")
                        .setFileSizeBytes(file0Data.length)
                        .setSha256Hex(FileManifestBuilder.calculateSha256Hex(file0Data))
                        .setIsDirectory(false)
                        .build())
                .addItems(TransferItem.newBuilder()
                        .setRelativePath("multi1.txt")
                        .setFileSizeBytes(file1Chunk0.length + 50)
                        .setSha256Hex(FileManifestBuilder.calculateSha256Hex("dummy".getBytes()))
                        .setIsDirectory(false)
                        .build())
                .build();

        setupSession(transferId, opId, manifest);

        // File 0: fully received and ACKed
        TransferChunkAck ack0 = engine.handleIncomingChunk(createChunkMsg(transferId, 0, 0, 0, file0Data));
        assertTrue(ack0.getSuccess());

        // File 1: chunk 0 received and ACKed
        TransferChunkAck ack1_0 = engine.handleIncomingChunk(createChunkMsg(transferId, 1, 0, 0, file1Chunk0));
        assertTrue(ack1_0.getSuccess());

        // Simulate torn/unacked write appending extra bytes to file 1 staging file past the chunk boundary
        Path file1Part = stagingManager.getStagedPartPath(transferId, 1);
        Files.write(file1Part, file1TornBytes, StandardOpenOption.APPEND);
        assertTrue(Files.size(file1Part) > manifest.getChunkSizeBytes());

        // Restart and reconcile
        var report = engine.reconcileAtStartup(destDir);
        assertEquals(1, report.pausedForResume());

        // Verify file 1 staging file was truncated back to the valid ACKed boundary
        long file1SizeAfter = Files.size(file1Part);
        assertEquals(manifest.getChunkSizeBytes(), file1SizeAfter);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    private void setupSession(String transferId, String opId, TransferManifest manifest) {
        long totalBytes = 0;
        for (TransferItem item : manifest.getItemsList()) {
            totalBytes += item.getFileSizeBytes();
        }

        TransferSessionRecord session = new TransferSessionRecord(
                transferId, opId, "peer-sender", "peer-receiver",
                TransferState.TRANSFER_STATE_TRANSFERRING,
                totalBytes, manifest.getItemsCount(), System.currentTimeMillis()
        );
        session.setManifest(manifest);
        sessionJournal.recordSession(session);

        opJournal.recordOperation(new OperationRecord(
                opId, OperationIntent.SYNC, "peer-sender", List.of("obj-1"),
                OperationState.EXECUTING, "idemp-" + transferId,
                System.currentTimeMillis(), System.currentTimeMillis()
        ));

        TransferOffer req = TransferOffer.newBuilder()
                .setManifest(manifest)
                .build();
        engine.handleIncomingOffer(req, destDir);
    }

    private TransferManifest createManifest(String transferId, String relativePath, byte[] data, int chunkSize) {
        return TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setChunkSizeBytes(chunkSize)
                .addItems(TransferItem.newBuilder()
                        .setRelativePath(relativePath)
                        .setFileSizeBytes(data.length)
                        .setSha256Hex(FileManifestBuilder.calculateSha256Hex(data))
                        .setIsDirectory(false)
                        .build())
                .build();
    }

    private TransferChunk createChunkMsg(String transferId, int itemIndex, long chunkIndex, long offset, byte[] data) {
        return TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(itemIndex)
                .setChunkIndex(chunkIndex)
                .setOffsetBytes(offset)
                .setData(com.google.protobuf.ByteString.copyFrom(data))
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(data))
                .build();
    }

    private static class TestOperationJournal implements OperationJournal {
        private final Map<String, OperationRecord> operations = new ConcurrentHashMap<>();

        @Override
        public void recordOperation(OperationRecord record) {
            operations.put(record.getOperationId(), record);
        }

        @Override
        public Optional<OperationRecord> getOperation(String operationId) {
            return Optional.ofNullable(operations.get(operationId));
        }

        @Override
        public void updateState(String operationId, OperationState newState) {
            OperationRecord existing = operations.get(operationId);
            if (existing != null) {
                operations.put(operationId, existing.withState(newState));
            }
        }

        @Override
        public void recordJournalStage(String operationId, org.peerlink.core.operation.JournalStage stage) {}

        @Override
        public void appendNote(String operationId, String note) {}

        @Override
        public List<OperationRecord> listIncompleteOperations() {
            return operations.values().stream()
                    .filter(r -> r.getState() != OperationState.COMMITTED &&
                                 r.getState() != OperationState.FAILED &&
                                 r.getState() != OperationState.CANCELLED &&
                                 r.getState() != OperationState.OUTCOME_UNKNOWN)
                    .toList();
        }

        @Override
        public List<OperationRecord> listInterruptedOperations() {
            return operations.values().stream()
                    .filter(r -> r.getState() == OperationState.EXECUTING)
                    .toList();
        }

        @Override
        public List<OperationRecord> listUnknownOutcomeOperations() {
            return operations.values().stream()
                    .filter(r -> r.getState() == OperationState.OUTCOME_UNKNOWN)
                    .toList();
        }

        @Override
        public Optional<String> findOperationByIdempotencyKey(String idempotencyKey) {
            return operations.values().stream()
                    .filter(r -> r.getIdempotencyKey().equals(idempotencyKey))
                    .map(OperationRecord::getOperationId)
                    .findFirst();
        }

        @Override
        public void markInterruptedOperationsUnknown(String reason) {}
    }
}
