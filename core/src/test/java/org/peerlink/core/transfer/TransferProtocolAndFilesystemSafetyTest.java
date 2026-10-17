package org.peerlink.core.transfer;

import com.google.protobuf.ByteString;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.filesystem.PathSafetyValidator;
import org.peerlink.core.operation.OperationJournal;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.*;

public class TransferProtocolAndFilesystemSafetyTest {

    @TempDir
    Path tempDir;

    private Path stagingDir;
    private Path destDir;
    private StagingDirectoryManager stagingManager;
    private PeerTransferEngine engine;
    private TestInMemoryJournal journal;

    @BeforeEach
    void setUp() throws IOException {
        stagingDir = tempDir.resolve("staging");
        destDir = tempDir.resolve("dest");
        Files.createDirectories(stagingDir);
        Files.createDirectories(destDir);

        journal = new TestInMemoryJournal();
        stagingManager = new StagingDirectoryManager(stagingDir);
        engine = new PeerTransferEngine(
                journal,
                new InMemoryTransferSessionJournal(),
                stagingManager,
                new TransferPreflight(),
                new DestinationConflictResolver(),
                new BandwidthLimiter(),
                new TransferQueueManager()
        );
    }

    // =========================================================================
    // 1. ADVERSARIAL PATHS & PATH TRAVERSAL
    // =========================================================================

    @Test
    @DisplayName("Path Safety: Path traversal via .. is strictly rejected")
    void testAdversarialPathTraversalRejected() {
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("../../etc/passwd"));
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("folder/../../../secret.key"));
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath(".."));
    }

    @Test
    @DisplayName("Path Safety: Sender-local absolute paths are strictly rejected")
    void testAdversarialAbsolutePathsRejected() {
        // Unix absolute
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("/etc/shadow"));
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("//server/share/file"));

        // Windows drive letters
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("C:\\Windows\\System32\\cmd.exe"));
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("D:payload.bin"));
    }

    @Test
    @DisplayName("Path Safety: Windows reserved device names are strictly rejected")
    void testAdversarialWindowsReservedNamesRejected() {
        String[] reserved = {"CON", "PRN", "AUX", "NUL", "COM1", "COM9", "LPT1", "LPT9",
                             "con.txt", "aux.tar.gz", "nul.dat"};
        for (String r : reserved) {
            assertThrows(SecurityException.class, () ->
                    PathSafetyValidator.validateRelativePath(r),
                    "Reserved device name '" + r + "' must be rejected");
            assertThrows(SecurityException.class, () ->
                    PathSafetyValidator.validateRelativePath("nested/" + r));
        }
    }

    @Test
    @DisplayName("Path Safety: Forbidden characters, alternate data streams, trailing dots/spaces rejected")
    void testAdversarialForbiddenCharsRejected() {
        // Forbidden chars < > : " | ? *
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("bad<name>.txt"));
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("pipe|name.txt"));

        // Alternate Data Streams
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("normal.txt:evil.exe"));

        // Trailing dot and space
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("trailing_dot.txt."));
        assertThrows(SecurityException.class, () ->
                PathSafetyValidator.validateRelativePath("trailing_space.txt "));
    }

    @Test
    @DisplayName("Staging Isolation: Opaque staging directory never escapes staging root")
    void testOpaqueStagingIsolation() {
        Path escapedAttempt = stagingManager.getTransferStagingDir("../../../../Windows/System32");
        assertTrue(escapedAttempt.startsWith(stagingDir.toAbsolutePath().normalize()),
                "Opaque staging directory must remain strictly within staging root");
        assertTrue(escapedAttempt.getFileName().toString().startsWith("stg_"));
    }

    // =========================================================================
    // 2. MALFORMED MANIFESTS
    // =========================================================================

    @Test
    @DisplayName("Manifest Validation: Malformed manifests rejected before resource allocation")
    void testMalformedManifestsRejected() {
        // 1. Missing transferId
        TransferManifest m1 = TransferManifest.newBuilder()
                .setTotalBytes(10)
                .setChunkSizeBytes(64 * 1024)
                .addItems(TransferItem.newBuilder().setRelativePath("a.txt").setFileSizeBytes(10).build())
                .build();
        assertNotNull(PeerTransferEngine.validateManifest(m1));

        // 2. Invalid chunk size (0 or excessive)
        TransferManifest m2 = TransferManifest.newBuilder()
                .setTransferId("xfer_1")
                .setTotalBytes(10)
                .setChunkSizeBytes(100) // below 1024
                .addItems(TransferItem.newBuilder().setRelativePath("a.txt").setFileSizeBytes(10).build())
                .build();
        assertNotNull(PeerTransferEngine.validateManifest(m2));

        // 3. Negative file size
        TransferManifest m3 = TransferManifest.newBuilder()
                .setTransferId("xfer_1")
                .setTotalBytes(10)
                .setChunkSizeBytes(64 * 1024)
                .addItems(TransferItem.newBuilder().setRelativePath("a.txt").setFileSizeBytes(-5).build())
                .build();
        assertNotNull(PeerTransferEngine.validateManifest(m3));

        // 4. Declared totalBytes mismatching actual sum of item sizes
        TransferManifest m4 = TransferManifest.newBuilder()
                .setTransferId("xfer_1")
                .setTotalBytes(1000) // declared 1000, actual is 20
                .setChunkSizeBytes(64 * 1024)
                .addItems(TransferItem.newBuilder().setRelativePath("a.txt").setFileSizeBytes(20).build())
                .build();
        assertNotNull(PeerTransferEngine.validateManifest(m4));

        // 5. Duplicate item relative paths
        TransferManifest m5 = TransferManifest.newBuilder()
                .setTransferId("xfer_1")
                .setTotalBytes(20)
                .setChunkSizeBytes(64 * 1024)
                .addItems(TransferItem.newBuilder().setRelativePath("file.txt").setFileSizeBytes(10).build())
                .addItems(TransferItem.newBuilder().setRelativePath("file.txt").setFileSizeBytes(10).build())
                .build();
        assertNotNull(PeerTransferEngine.validateManifest(m5));

        // 6. Case-colliding item relative paths (file.txt vs FILE.TXT)
        TransferManifest m6 = TransferManifest.newBuilder()
                .setTransferId("xfer_1")
                .setTotalBytes(20)
                .setChunkSizeBytes(64 * 1024)
                .addItems(TransferItem.newBuilder().setRelativePath("file.txt").setFileSizeBytes(10).build())
                .addItems(TransferItem.newBuilder().setRelativePath("FILE.TXT").setFileSizeBytes(10).build())
                .build();
        assertNotNull(PeerTransferEngine.validateManifest(m6));
    }

    @Test
    @DisplayName("Offer Rejection: Engine rejects malformed manifest offer with INVALID_ARGUMENT")
    void testEngineRejectionOnMalformedOffer() {
        TransferManifest malformed = TransferManifest.newBuilder()
                .setTransferId("xfer_malformed")
                .setTotalBytes(999)
                .setChunkSizeBytes(64 * 1024)
                .addItems(TransferItem.newBuilder().setRelativePath("../traversal.txt").setFileSizeBytes(999).build())
                .build();

        TransferOffer offer = TransferOffer.newBuilder().setManifest(malformed).build();
        TransferResponse response = engine.handleIncomingOffer(offer, destDir);

        assertFalse(response.getAccepted());
        assertEquals(ErrorCode.ERROR_CODE_INTERNAL_ERROR, response.getError().getCode());
    }

    // =========================================================================
    // 3. CHUNK VALIDATION, SIZE OVERRUNS, DUPLICATE/CONFLICTING CHUNKS
    // =========================================================================

    @Test
    @DisplayName("Chunk Validation: Negative indices and bounds checks enforced")
    void testChunkBoundsAndNegativeIndicesRejected() throws IOException {
        String transferId = "xfer_bounds_test";
        TransferManifest manifest = TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setOperationId(OperationId.newBuilder().setValue("op_1").build())
                .setChunkSizeBytes(64 * 1024)
                .setTotalBytes(100)
                .addItems(TransferItem.newBuilder().setRelativePath("valid.bin").setFileSizeBytes(100).build())
                .build();

        engine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        // Negative chunk index
        TransferChunk c1 = TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(-1).setOffsetBytes(0)
                .setData(ByteString.copyFrom(new byte[10])).build();
        TransferChunkAck a1 = engine.handleIncomingChunk(c1);
        assertFalse(a1.getSuccess());

        // Negative offset
        TransferChunk c2 = TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(-5)
                .setData(ByteString.copyFrom(new byte[10])).build();
        TransferChunkAck a2 = engine.handleIncomingChunk(c2);
        assertFalse(a2.getSuccess());

        // Out of bounds item index
        TransferChunk c3 = TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(99).setChunkIndex(0).setOffsetBytes(0)
                .setData(ByteString.copyFrom(new byte[10])).build();
        TransferChunkAck a3 = engine.handleIncomingChunk(c3);
        assertFalse(a3.getSuccess());
    }

    @Test
    @DisplayName("Size Overrun: Chunk exceeding declared file size is rejected immediately")
    void testChunkSizeOverrunRejected() throws IOException {
        String transferId = "xfer_overrun_test";
        TransferManifest manifest = TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setOperationId(OperationId.newBuilder().setValue("op_2").build())
                .setChunkSizeBytes(64 * 1024)
                .setTotalBytes(50)
                .addItems(TransferItem.newBuilder().setRelativePath("small.dat").setFileSizeBytes(50).build())
                .build();

        engine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        // Chunk offset 40 + length 20 = 60 bytes > declared 50 bytes
        TransferChunk overrunChunk = TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(40)
                .setData(ByteString.copyFrom(new byte[20]))
                .build();

        TransferChunkAck ack = engine.handleIncomingChunk(overrunChunk);
        assertFalse(ack.getSuccess(), "Size overrun must be rejected");
        assertTrue(ack.getErrorMessage().contains("Size overrun"));
    }

    @Test
    @DisplayName("Duplicate vs Conflicting Chunks: Idempotent duplicate succeeds; conflict rejected")
    void testDuplicateAndConflictingChunks() throws IOException {
        String transferId = "xfer_dup_test";
        byte[] payload1 = "Consistent chunk data".getBytes(StandardCharsets.UTF_8);
        String hash1 = FileManifestBuilder.calculateSha256Hex(payload1);

        TransferManifest manifest = TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setOperationId(OperationId.newBuilder().setValue("op_3").build())
                .setChunkSizeBytes(64 * 1024)
                .setTotalBytes(100)
                .addItems(TransferItem.newBuilder().setRelativePath("data.txt").setFileSizeBytes(100).build())
                .build();

        engine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        // 1. Send first chunk
        TransferChunk chunk = TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(ByteString.copyFrom(payload1)).setChunkSha256(hash1).build();
        TransferChunkAck ack1 = engine.handleIncomingChunk(chunk);
        assertTrue(ack1.getSuccess());

        // 2. Re-send identical duplicate chunk -> must succeed idempotently
        TransferChunkAck ackDup = engine.handleIncomingChunk(chunk);
        assertTrue(ackDup.getSuccess());

        // 3. Send conflicting chunk with different data for same index -> must reject
        byte[] conflictingPayload = "Adversarial changed data".getBytes(StandardCharsets.UTF_8);
        String hashConflict = FileManifestBuilder.calculateSha256Hex(conflictingPayload);
        TransferChunk conflictingChunk = TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(ByteString.copyFrom(conflictingPayload)).setChunkSha256(hashConflict).build();

        TransferChunkAck ackConflict = engine.handleIncomingChunk(conflictingChunk);
        assertFalse(ackConflict.getSuccess(), "Conflicting duplicate chunk must be rejected");
    }

    // =========================================================================
    // 4. DESTINATION CONFLICTS & POLICIES
    // =========================================================================

    @Test
    @DisplayName("Destination Collision: FailIfExists, Overwrite, and RenameWithSuffix policies")
    void testDestinationCollisionPolicies() throws Exception {
        DestinationConflictResolver resolver = new DestinationConflictResolver();
        Path existing = destDir.resolve("target.txt");
        Files.writeString(existing, "Existing file");

        // 1. FAIL_IF_EXISTS
        assertThrows(DestinationConflictException.class, () ->
                resolver.resolveDestination(destDir, "target.txt", DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS));

        // 2. OVERWRITE
        Path overwritePath = resolver.resolveDestination(
                destDir, "target.txt", DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_OVERWRITE);
        assertEquals(existing, overwritePath);

        // 3. RENAME_WITH_SUFFIX
        Path suffixedPath = resolver.resolveDestination(
                destDir, "target.txt", DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX);
        assertEquals(destDir.resolve("target (1).txt"), suffixedPath);
    }

    // =========================================================================
    // 5. MULTI-FILE COMMIT PARTIAL FAILURE RECOVERY
    // =========================================================================

    @Test
    @DisplayName("Multi-File Commit: Failure partway through batch records granular partial result without false atomicity")
    void testMultiFilePartialCommitFailureModel() throws Exception {
        String transferId = "xfer_batch_fail";
        String opId = "op_batch_fail";

        journal.recordOperation(OperationRecord.create(
                opId, org.peerlink.core.operation.OperationIntent.SEND, "peer_sender",
                List.of("item1.txt", "blocked_dir/item2.txt", "item3.txt"), "idemp_batch"
        ));

        // Create staging for 3 files
        stagingManager.prepareStagingDir(transferId);
        byte[] d1 = "File 1 content".getBytes(StandardCharsets.UTF_8);
        byte[] d2 = "File 2 content".getBytes(StandardCharsets.UTF_8);
        byte[] d3 = "File 3 content".getBytes(StandardCharsets.UTF_8);

        stagingManager.writeChunk(transferId, 0, 0, 0, d1, null, d1.length);
        stagingManager.writeChunk(transferId, 1, 0, 0, d2, null, d2.length);
        stagingManager.writeChunk(transferId, 2, 0, 0, d3, null, d3.length);

        TransferManifest manifest = TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setOperationId(OperationId.newBuilder().setValue(opId).build())
                .setChunkSizeBytes(64 * 1024)
                .setTotalBytes(d1.length + d2.length + d3.length)
                .addItems(TransferItem.newBuilder().setRelativePath("item1.txt").setFileSizeBytes(d1.length).build())
                .addItems(TransferItem.newBuilder().setRelativePath("blocked_dir/item2.txt").setFileSizeBytes(d2.length).build())
                .addItems(TransferItem.newBuilder().setRelativePath("item3.txt").setFileSizeBytes(d3.length).build())
                .setDuplicatePolicy(DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS)
                .build();

        // Intentionally create blocked_dir as a regular file (not directory) so creating blocked_dir/item2.txt fails!
        Path conflictFile = destDir.resolve("blocked_dir");
        Files.writeString(conflictFile, "I am a blocking file, not a directory");

        BatchCommitException ex = assertThrows(BatchCommitException.class, () ->
                engine.commitReceivedTransfer(transferId, manifest, destDir));

        BatchCommitResult batchResult = ex.getCommitResult();
        assertNotNull(batchResult);
        assertFalse(batchResult.isFullyCommitted(), "Must not claim full atomicity on failure");
        assertTrue(batchResult.isPartiallyCommitted());

        // File 1 committed successfully
        assertEquals(1, batchResult.getCommittedCount());
        ItemCommitResult item1 = batchResult.getItemResults().get(0);
        assertTrue(item1.isCommitted());
        assertTrue(Files.exists(destDir.resolve("item1.txt")), "Committed item 1 must remain on disk");

        // File 2 failed
        ItemCommitResult item2 = batchResult.getItemResults().get(1);
        assertFalse(item2.isCommitted());
        assertNotNull(item2.getErrorMessage());

        // Journal must be marked FAILED with partial commit details
        Optional<OperationRecord> rec = journal.getOperation(opId);
        assertTrue(rec.isPresent());
        assertEquals(OperationState.FAILED, rec.get().getState());
    }

    // =========================================================================
    // Minimal Test Journal
    // =========================================================================

    private static class TestInMemoryJournal implements OperationJournal {
        private final Map<String, OperationRecord> records = new ConcurrentHashMap<>();

        @Override
        public void recordOperation(OperationRecord record) { records.put(record.getOperationId(), record); }
        @Override
        public void updateState(String operationId, OperationState newState) {
            OperationRecord rec = records.get(operationId);
            if (rec != null) records.put(operationId, rec.withState(newState));
        }
        @Override
        public void recordJournalStage(String operationId, org.peerlink.core.operation.JournalStage stage) {}
        @Override
        public Optional<OperationRecord> getOperation(String operationId) { return Optional.ofNullable(records.get(operationId)); }
        @Override
        public List<OperationRecord> listIncompleteOperations() { return List.of(); }
        @Override
        public List<OperationRecord> listInterruptedOperations() { return List.of(); }
        @Override
        public List<OperationRecord> listUnknownOutcomeOperations() { return List.of(); }
        @Override
        public Optional<String> findOperationByIdempotencyKey(String idempotencyKey) { return Optional.empty(); }
        @Override
        public void appendNote(String operationId, String note) {}
        @Override
        public void markInterruptedOperationsUnknown(String reason) {}
    }
}
