package org.peerlink.core.transfer;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
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
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;

class PeerTransferEngineTest {

    @TempDir
    Path tempDir;

    private Path sourceDir;
    private Path destDir;
    private Path stagingDir;
    private InMemoryJournal journal;
    private PeerTransferEngine engine;
    private final List<TransferProgress> progressUpdates = Collections.synchronizedList(new ArrayList<>());

    @BeforeEach
    void setUp() throws IOException {
        sourceDir = tempDir.resolve("source");
        destDir = tempDir.resolve("dest");
        stagingDir = tempDir.resolve("staging");

        Files.createDirectories(sourceDir);
        Files.createDirectories(destDir);
        Files.createDirectories(stagingDir);

        journal = new InMemoryJournal();
        engine = new PeerTransferEngine(journal, stagingDir);
    }

    @AfterEach
    void tearDown() {
        progressUpdates.clear();
    }

    @Test
    void testSmallFileTransfer() throws Exception {
        Path file = sourceDir.resolve("small.txt");
        String content = "Hello PeerLink P2P World!";
        Files.writeString(file, content, StandardCharsets.UTF_8);

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(file),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        assertEquals(content.getBytes(StandardCharsets.UTF_8).length, receipt.getTotalBytesTransferred());

        Path committedFile = destDir.resolve("small.txt");
        assertTrue(Files.exists(committedFile), "Committed file must exist in destination");
        assertEquals(content, Files.readString(committedFile, StandardCharsets.UTF_8));

        // Staging directory must be cleaned up
        assertEquals(0, Files.list(stagingDir).count(), "Staging dir must be purged after commit");
    }

    @Test
    void testZeroByteFileTransfer() throws Exception {
        Path emptyFile = sourceDir.resolve("empty.dat");
        Files.createFile(emptyFile);

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(emptyFile),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        assertEquals(0, receipt.getTotalBytesTransferred());

        Path committedFile = destDir.resolve("empty.dat");
        assertTrue(Files.exists(committedFile));
        assertEquals(0, Files.size(committedFile));
    }

    @Test
    void testLargeFileMultiChunkTransfer() throws Exception {
        Path largeFile = sourceDir.resolve("large_payload.bin");
        // 256 KB file with 64 KB chunks = 4 chunks
        byte[] payload = new byte[256 * 1024];
        new Random(42).nextBytes(payload);
        Files.write(largeFile, payload);

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(largeFile),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        assertEquals(payload.length, receipt.getTotalBytesTransferred());

        Path committed = destDir.resolve("large_payload.bin");
        assertTrue(Files.exists(committed));
        assertArrayEquals(payload, Files.readAllBytes(committed));

        // Verification that progress events fired and reached COMPLETED
        assertFalse(progressUpdates.isEmpty());
        assertEquals(TransferState.TRANSFER_STATE_COMPLETED,
                progressUpdates.get(progressUpdates.size() - 1).getState());
    }

    @Test
    void testMultipleFilesTransfer() throws Exception {
        Path file1 = sourceDir.resolve("doc1.txt");
        Path file2 = sourceDir.resolve("doc2.txt");
        Path file3 = sourceDir.resolve("doc3.txt");

        Files.writeString(file1, "First content");
        Files.writeString(file2, "Second content");
        Files.writeString(file3, "Third content");

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(file1, file2, file3),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        assertEquals(Files.size(file1) + Files.size(file2) + Files.size(file3),
                receipt.getTotalBytesTransferred());

        assertEquals("First content", Files.readString(destDir.resolve("doc1.txt")));
        assertEquals("Second content", Files.readString(destDir.resolve("doc2.txt")));
        assertEquals("Third content", Files.readString(destDir.resolve("doc3.txt")));
    }

    @Test
    void testFolderTransferPreservesHierarchy() throws Exception {
        Path subFolder = sourceDir.resolve("my_folder").resolve("nested");
        Files.createDirectories(subFolder);

        Path rootDoc = sourceDir.resolve("my_folder").resolve("root_doc.txt");
        Path nestedDoc = subFolder.resolve("nested_doc.txt");

        Files.writeString(rootDoc, "Root document text");
        Files.writeString(nestedDoc, "Nested document text");

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(sourceDir.resolve("my_folder")),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        Path committedRoot = destDir.resolve("my_folder").resolve("root_doc.txt");
        Path committedNested = destDir.resolve("my_folder").resolve("nested").resolve("nested_doc.txt");

        assertTrue(Files.exists(committedRoot));
        assertTrue(Files.exists(committedNested));
        assertEquals("Root document text", Files.readString(committedRoot));
        assertEquals("Nested document text", Files.readString(committedNested));
    }

    @Test
    void testUnicodeFilenameTransfer() throws Exception {
        String unicodeName = "日本語ドキュメント_Über_🎉.txt";
        Path file = sourceDir.resolve(unicodeName);
        String text = "UTF-8 encoded multilingual content: Здравствуйте, 世界!";
        Files.writeString(file, text, StandardCharsets.UTF_8);

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(file),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        Path committed = destDir.resolve(unicodeName);
        assertTrue(Files.exists(committed));
        assertEquals(text, Files.readString(committed, StandardCharsets.UTF_8));
    }

    @Test
    void testDuplicateFilenameFailIfExistsThrowsException() throws Exception {
        Path file = sourceDir.resolve("contract.pdf");
        Files.writeString(file, "Source version 1");

        // Pre-create destination file with different content
        Path existingDest = destDir.resolve("contract.pdf");
        Files.writeString(existingDest, "Existing version at destination");

        assertThrows(DestinationConflictException.class, () ->
                engine.executeTransfer(
                        List.of(file),
                        destDir,
                        DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                        "peer_sender",
                        "peer_receiver",
                        progressUpdates::add));

        // Destination must NOT have been silently overwritten!
        assertEquals("Existing version at destination", Files.readString(existingDest));
    }

    @Test
    void testDuplicateFilenameRenameWithSuffix() throws Exception {
        Path file = sourceDir.resolve("report.docx");
        Files.writeString(file, "New report content");

        // Existing file
        Path existing = destDir.resolve("report.docx");
        Files.writeString(existing, "Old report content");

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(file),
                destDir,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX,
                "peer_sender",
                "peer_receiver",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        // Original intact
        assertEquals("Old report content", Files.readString(existing));
        // Renamed suffix created
        Path suffixed = destDir.resolve("report (1).docx");
        assertTrue(Files.exists(suffixed));
        assertEquals("New report content", Files.readString(suffixed));
    }

    @Test
    void testCancellationPurgesStaging() throws Exception {
        Path file = sourceDir.resolve("cancel_me.dat");
        byte[] data = new byte[128 * 1024];
        Files.write(file, data);

        AtomicBoolean cancelledDuringProgress = new AtomicBoolean(false);

        // Cancel on first progress callback
        assertThrows(Exception.class, () ->
                engine.executeTransfer(
                        List.of(file),
                        destDir,
                        DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                        "peer_sender",
                        "peer_receiver",
                        progress -> {
                            if (progress.getState() == TransferState.TRANSFER_STATE_TRANSFERRING) {
                                engine.cancelTransfer(progress.getTransferId(), "User aborted transfer");
                                cancelledDuringProgress.set(true);
                            }
                        }));

        assertTrue(cancelledDuringProgress.get());
        // Destination must not contain final committed file
        assertFalse(Files.exists(destDir.resolve("cancel_me.dat")));
        // Staging must be purged
        assertEquals(0, Files.list(stagingDir).count());
    }

    @Test
    void testHashMismatchRejectionPurgesStagingAndNeverCommits() throws Exception {
        Path file = sourceDir.resolve("corrupted.bin");
        Files.writeString(file, "Genuine uncorrupted content");

        FileManifestBuilder builder = new FileManifestBuilder();
        TransferManifest manifest = builder.buildManifest(
                "xfer_corrupt_test",
                "op_corrupt_test",
                "peer_sender",
                "peer_receiver",
                List.of(file),
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);

        // Offer
        TransferOffer offer = TransferOffer.newBuilder()
                .setManifest(manifest)
                .setTimestampUtcMs(System.currentTimeMillis())
                .build();
        TransferResponse response = engine.handleIncomingOffer(offer, destDir);
        assertTrue(response.getAccepted());

        // Send corrupted chunk
        byte[] corruptedData = "TAMPERED BY MITM ADVERSARY".getBytes(StandardCharsets.UTF_8);
        TransferChunk chunk = TransferChunk.newBuilder()
                .setTransferId("xfer_corrupt_test")
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(corruptedData))
                .setIsLastChunk(true)
                .build();
        engine.handleIncomingChunk(chunk);

        // Run verification -> MUST fail
        TransferVerifyResult verifyResult = engine.verifyReceivedTransfer("xfer_corrupt_test", manifest);
        assertFalse(verifyResult.getVerified(), "Verification must fail on hash mismatch");
        assertNotEquals(manifest.getItems(0).getSha256Hex(), verifyResult.getComputedSha256());

        // Verify destination file was NEVER created
        assertFalse(Files.exists(destDir.resolve("corrupted.bin")),
                "Unverified content must NEVER be written to destination");

        // Staging part must be deleted
        assertFalse(Files.exists(stagingDir.resolve("xfer_corrupt_test").resolve("0.part")),
                "Corrupted staging file must be purged");
    }

    @Test
    void testDiskFullPreflightRejection() throws IOException {
        Path file = sourceDir.resolve("preflight_test.bin");
        Files.writeString(file, "Data for disk preflight");

        // Configure preflight with an impossibly high reserve (1000 Petabytes)
        TransferPreflight strictPreflight = new TransferPreflight(Long.MAX_VALUE - 1000);
        PeerTransferEngine strictEngine = new PeerTransferEngine(
                journal,
                new StagingDirectoryManager(stagingDir),
                strictPreflight,
                new DestinationConflictResolver());

        assertThrows(PreflightException.class, () ->
                strictEngine.executeTransfer(
                        List.of(file),
                        destDir,
                        DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                        "peer_sender",
                        "peer_receiver",
                        progressUpdates::add));

        assertFalse(Files.exists(destDir.resolve("preflight_test.bin")));
    }

    @Test
    void testDestinationUnavailablePreflightRejection() throws IOException {
        Path file = sourceDir.resolve("dest_unavail.txt");
        Files.writeString(file, "Some content");

        // Use a path on a non-existent drive (e.g. Z:\invalid_drive\...)
        Path invalidDest = Path.of("Z:\\non_existent_drive_peerlink\\test_folder");

        assertThrows(PreflightException.class, () ->
                engine.executeTransfer(
                        List.of(file),
                        invalidDest,
                        DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                        "peer_sender",
                        "peer_receiver",
                        progressUpdates::add));
    }

    @Test
    void testWindowsNodeAToWindowsNodeBTransfer() throws Exception {
        // Windows PeerLink A (sender) -> Windows PeerLink B (receiver)
        Path nodeASource = tempDir.resolve("nodeA_workspace").resolve("peerlink_doc.pdf");
        Files.createDirectories(nodeASource.getParent());
        String documentBody = "%PDF-1.4 Authoritative PeerLink Data Transfer Output %EOF";
        Files.writeString(nodeASource, documentBody);

        Path nodeBDestination = tempDir.resolve("nodeB_received");
        Files.createDirectories(nodeBDestination);

        TransferCompletedReceipt receipt = engine.executeTransfer(
                List.of(nodeASource),
                nodeBDestination,
                DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                "peerlink_node_A_windows",
                "peerlink_node_B_windows",
                progressUpdates::add);

        assertTrue(receipt.getSuccess());
        Path bFile = nodeBDestination.resolve("peerlink_doc.pdf");
        assertTrue(Files.exists(bFile));
        assertEquals(documentBody, Files.readString(bFile));

        // Verify operation journal state on receipt
        Optional<OperationRecord> op = journal.getOperation(receipt.getOperationId().getValue());
        assertTrue(op.isPresent());
        assertEquals(OperationState.COMMITTED, op.get().getState());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Minimal in-memory journal for test isolation
    // ──────────────────────────────────────────────────────────────────────────

    private static class InMemoryJournal implements OperationJournal {
        private final Map<String, OperationRecord> operations = new ConcurrentHashMap<>();

        @Override
        public void recordOperation(OperationRecord record) {
            operations.put(record.getOperationId(), record);
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
        public Optional<OperationRecord> getOperation(String operationId) {
            return Optional.ofNullable(operations.get(operationId));
        }

        @Override
        public List<OperationRecord> listIncompleteOperations() {
            return operations.values().stream().filter(o -> !o.getState().isTerminal()).toList();
        }

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
