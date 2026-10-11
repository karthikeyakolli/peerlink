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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Deliberate Failure & Recovery Test Suite for Phase 07.
 *
 * Verifies:
 * 1. Interrupt at 10% & resume
 * 2. Interrupt at 40% & resume
 * 3. Kill receiver & recover staging
 * 4. Kill sender & resume
 * 5. Disconnect network (pause)
 * 6. Reconnect & resume
 * 7. Corrupt a chunk & retry
 * 8. Destination disk full / preflight rejection & rollback
 * 9. Mutate source during transfer (detect & abort)
 * 10. Duplicate resume request (idempotent response)
 * 11. Lose final acknowledgement (OUTCOME_UNKNOWN -> query op ID -> reconcile without re-commit)
 * 12. Restart both peers
 *
 * Measures:
 * - retransmitted data
 * - recovery time
 * - resulting hash
 * - final operation state
 */
public class PeerTransferEngineRecoveryTest {
    private static final Logger log = LoggerFactory.getLogger(PeerTransferEngineRecoveryTest.class);

    @TempDir
    Path tempDir;

    private Path sourceDir;
    private Path destDir;
    private Path stagingDir;

    private InMemoryJournal senderOpJournal;
    private InMemoryJournal receiverOpJournal;
    private InMemoryTransferSessionJournal senderSessionJournal;
    private InMemoryTransferSessionJournal receiverSessionJournal;

    private StagingDirectoryManager stagingManager;
    private PeerTransferEngine senderEngine;
    private PeerTransferEngine receiverEngine;

    @BeforeEach
    void setUp() throws IOException {
        sourceDir = tempDir.resolve("source");
        destDir = tempDir.resolve("dest");
        stagingDir = tempDir.resolve("staging");

        Files.createDirectories(sourceDir);
        Files.createDirectories(destDir);
        Files.createDirectories(stagingDir);

        senderOpJournal = new InMemoryJournal();
        receiverOpJournal = new InMemoryJournal();
        senderSessionJournal = new InMemoryTransferSessionJournal();
        receiverSessionJournal = new InMemoryTransferSessionJournal();

        stagingManager = new StagingDirectoryManager(stagingDir);

        senderEngine = new PeerTransferEngine(
                senderOpJournal,
                senderSessionJournal,
                stagingManager,
                new TransferPreflight(),
                new DestinationConflictResolver(),
                new BandwidthLimiter(),
                new TransferQueueManager()
        );

        receiverEngine = new PeerTransferEngine(
                receiverOpJournal,
                receiverSessionJournal,
                stagingManager,
                new TransferPreflight(),
                new DestinationConflictResolver(),
                new BandwidthLimiter(),
                new TransferQueueManager()
        );
    }

    private Path createTestPayload(String fileName, int sizeBytes) throws IOException {
        Path file = sourceDir.resolve(fileName);
        byte[] data = new byte[sizeBytes];
        for (int i = 0; i < sizeBytes; i++) {
            data[i] = (byte) ((i * 31 + 17) % 256);
        }
        Files.write(file, data);
        return file;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 1. Interrupt at 10% and Resume
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test01_InterruptAt10PercentAndResume() throws Exception {
        int totalSize = 256 * 1024; // 256 KB = 4 chunks of 64KB
        Path sourceFile = createTestPayload("test10pct.bin", totalSize);
        String expectedSha256 = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        // Accept offer
        TransferOffer offer = TransferOffer.newBuilder().setManifest(manifest).build();
        TransferResponse response = receiverEngine.handleIncomingOffer(offer, destDir);
        assertTrue(response.getAccepted());

        // Stream only 1st chunk (~25% > 10%)
        byte[] buffer = Files.readAllBytes(sourceFile);
        int chunkSize = manifest.getChunkSizeBytes();
        byte[] chunk0 = Arrays.copyOfRange(buffer, 0, chunkSize);
        String chunk0Sha = FileManifestBuilder.calculateSha256Hex(chunk0);

        TransferChunk chunkMsg0 = TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(chunk0))
                .setIsLastChunk(false)
                .setChunkSha256(chunk0Sha)
                .build();
        TransferChunkAck ack0 = receiverEngine.handleIncomingChunk(chunkMsg0);
        assertTrue(ack0.getSuccess());

        // Pause/interrupt transfer
        senderEngine.pauseTransfer(transferId, "Interrupted at 10% threshold");
        assertEquals(TransferState.TRANSFER_STATE_PAUSED, senderSessionJournal.getSession(transferId).get().getState());

        // RESUME: Query receiver for state
        long startTime = System.currentTimeMillis();
        TransferResumeOffer resumeOffer = TransferResumeOffer.newBuilder()
                .setTransferId(transferId)
                .setOperationId(manifest.getOperationId())
                .setManifest(manifest)
                .build();
        TransferResumeState resumeState = receiverEngine.handleResumeOffer(resumeOffer, destDir);
        assertTrue(resumeState.getCanResume());
        assertTrue(resumeState.getAckedChunkIndicesList().contains(0L));

        // Retransmit ONLY missing chunks (chunks 1, 2, 3)
        AtomicLong retransmittedBytes = new AtomicLong(0);
        Set<Long> alreadyAcked = new HashSet<>(resumeState.getAckedChunkIndicesList());

        long offset = chunkSize;
        for (long chunkIdx = 1; offset < totalSize; chunkIdx++) {
            if (!alreadyAcked.contains(chunkIdx)) {
                int len = (int) Math.min(chunkSize, totalSize - offset);
                byte[] chunkData = Arrays.copyOfRange(buffer, (int) offset, (int) (offset + len));
                boolean isLast = (offset + len >= totalSize);
                String sha = FileManifestBuilder.calculateSha256Hex(chunkData);

                TransferChunk c = TransferChunk.newBuilder()
                        .setTransferId(transferId)
                        .setItemIndex(0)
                        .setChunkIndex(chunkIdx)
                        .setOffsetBytes(offset)
                        .setData(com.google.protobuf.ByteString.copyFrom(chunkData))
                        .setIsLastChunk(isLast)
                        .setChunkSha256(sha)
                        .build();
                TransferChunkAck ack = receiverEngine.handleIncomingChunk(c);
                assertTrue(ack.getSuccess());
                retransmittedBytes.addAndGet(len);
            }
            offset += chunkSize;
        }

        // Verify and commit
        TransferVerifyResult verify = receiverEngine.verifyReceivedTransfer(transferId, manifest);
        assertTrue(verify.getVerified());

        TransferCompletedReceipt receipt = receiverEngine.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(receipt.getSuccess());
        long recoveryTimeMs = System.currentTimeMillis() - startTime;

        Path committedFile = destDir.resolve("test10pct.bin");
        assertTrue(Files.exists(committedFile));
        assertEquals(expectedSha256, FileManifestBuilder.calculateSha256Hex(committedFile));
        assertEquals(totalSize - chunkSize, retransmittedBytes.get(), "Must only transmit missing chunks");

        log.info("Measurement [10% Interrupt]: Retransmitted={} bytes, RecoveryTime={} ms, HashMatch=true, FinalState={}",
                retransmittedBytes.get(), recoveryTimeMs, receipt.getSuccess());
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Interrupt at 40% and Resume
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test02_InterruptAt40PercentAndResume() throws Exception {
        int totalSize = 500 * 1024; // 500 KB = 8 chunks (64KB each)
        Path sourceFile = createTestPayload("test40pct.bin", totalSize);
        String expectedSha256 = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        byte[] buffer = Files.readAllBytes(sourceFile);
        int chunkSize = manifest.getChunkSizeBytes();

        // Stream 40% of chunks (3 out of 8 chunks)
        int chunksToStream = 3;
        for (int i = 0; i < chunksToStream; i++) {
            long off = (long) i * chunkSize;
            int len = (int) Math.min(chunkSize, totalSize - off);
            byte[] chunkData = Arrays.copyOfRange(buffer, (int) off, (int) (off + len));
            TransferChunk c = TransferChunk.newBuilder()
                    .setTransferId(transferId)
                    .setItemIndex(0)
                    .setChunkIndex(i)
                    .setOffsetBytes(off)
                    .setData(com.google.protobuf.ByteString.copyFrom(chunkData))
                    .setIsLastChunk(false)
                    .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunkData))
                    .build();
            assertTrue(receiverEngine.handleIncomingChunk(c).getSuccess());
        }

        // Interrupt
        senderEngine.pauseTransfer(transferId, "Network cut at 40%");

        // Resume
        long startMs = System.currentTimeMillis();
        TransferResumeState resumeState = receiverEngine.handleResumeOffer(
                TransferResumeOffer.newBuilder().setTransferId(transferId).setOperationId(manifest.getOperationId()).setManifest(manifest).build(), destDir);
        assertTrue(resumeState.getCanResume());
        assertEquals(3, resumeState.getAckedChunkIndicesCount());

        AtomicLong resumedBytes = new AtomicLong(0);
        Set<Long> acked = new HashSet<>(resumeState.getAckedChunkIndicesList());
        long off = (long) chunksToStream * chunkSize;
        for (long i = chunksToStream; off < totalSize; i++) {
            assertFalse(acked.contains(i));
            int len = (int) Math.min(chunkSize, totalSize - off);
            byte[] chunkData = Arrays.copyOfRange(buffer, (int) off, (int) (off + len));
            boolean isLast = (off + len >= totalSize);
            TransferChunk c = TransferChunk.newBuilder()
                    .setTransferId(transferId)
                    .setItemIndex(0)
                    .setChunkIndex(i)
                    .setOffsetBytes(off)
                    .setData(com.google.protobuf.ByteString.copyFrom(chunkData))
                    .setIsLastChunk(isLast)
                    .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunkData))
                    .build();
            assertTrue(receiverEngine.handleIncomingChunk(c).getSuccess());
            resumedBytes.addAndGet(len);
            off += chunkSize;
        }

        assertTrue(receiverEngine.verifyReceivedTransfer(transferId, manifest).getVerified());
        TransferCompletedReceipt receipt = receiverEngine.commitReceivedTransfer(transferId, manifest, destDir);
        long duration = System.currentTimeMillis() - startMs;

        Path finalFile = destDir.resolve("test40pct.bin");
        assertEquals(expectedSha256, FileManifestBuilder.calculateSha256Hex(finalFile));
        assertEquals(totalSize - (chunksToStream * chunkSize), resumedBytes.get());
        log.info("Measurement [40% Interrupt]: ResumedBytes={}, Duration={}ms, Hash={}",
                resumedBytes.get(), duration, expectedSha256);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Kill Receiver and Recover Staging
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test03_KillReceiverAndRecoverStaging() throws Exception {
        int totalSize = 128 * 1024; // 2 chunks
        Path sourceFile = createTestPayload("kill_receiver.bin", totalSize);
        String expectedSha = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        byte[] full = Files.readAllBytes(sourceFile);
        int chunkSize = manifest.getChunkSizeBytes();
        byte[] chunk0 = Arrays.copyOfRange(full, 0, chunkSize);
        receiverEngine.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(chunk0)).setIsLastChunk(false)
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunk0)).build());

        // SIMULATE RECEIVER PROCESS TERMINATION:
        // Receiver engine instance is garbage collected / killed.
        receiverEngine = null;

        // RECEIVER RESTARTS: New receiver node initializes with existing staging directory
        long restartStart = System.currentTimeMillis();
        StagingDirectoryManager recoveredStaging = new StagingDirectoryManager(stagingDir);
        assertTrue(recoveredStaging.hasStagedPart(transferId, 0));
        assertEquals(chunkSize, recoveredStaging.getStagedFileSize(transferId, 0));

        PeerTransferEngine restartedReceiver = new PeerTransferEngine(
                receiverOpJournal, receiverSessionJournal, recoveredStaging,
                new TransferPreflight(), new DestinationConflictResolver(),
                new BandwidthLimiter(), new TransferQueueManager());

        // Sender reconnects and offers resume
        TransferResumeState state = restartedReceiver.handleResumeOffer(
                TransferResumeOffer.newBuilder().setTransferId(transferId).setOperationId(manifest.getOperationId()).setManifest(manifest).build(), destDir);
        assertTrue(state.getCanResume());
        assertTrue(state.getAckedChunkIndicesList().contains(0L));

        // Send chunk 1
        byte[] chunk1 = Arrays.copyOfRange(full, chunkSize, totalSize);
        TransferChunkAck ack1 = restartedReceiver.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(1).setOffsetBytes(chunkSize)
                .setData(com.google.protobuf.ByteString.copyFrom(chunk1)).setIsLastChunk(true)
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunk1)).build());
        assertTrue(ack1.getSuccess());

        assertTrue(restartedReceiver.verifyReceivedTransfer(transferId, manifest).getVerified());
        TransferCompletedReceipt receipt = restartedReceiver.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(receipt.getSuccess());
        long recoveryMs = System.currentTimeMillis() - restartStart;

        Path target = destDir.resolve("kill_receiver.bin");
        assertEquals(expectedSha, FileManifestBuilder.calculateSha256Hex(target));
        log.info("Measurement [Kill Receiver]: RecoveryTime={}ms, FileCommitted=true", recoveryMs);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Kill Sender and Resume
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test04_KillSenderAndResume() throws Exception {
        int totalSize = 128 * 1024;
        Path sourceFile = createTestPayload("kill_sender.bin", totalSize);
        String expectedSha = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        byte[] full = Files.readAllBytes(sourceFile);
        int chunkSize = manifest.getChunkSizeBytes();
        byte[] chunk0 = Arrays.copyOfRange(full, 0, chunkSize);
        receiverEngine.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(chunk0)).setIsLastChunk(false)
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(chunk0)).build());

        // KILL SENDER: Sender engine discarded
        senderEngine = null;

        // SENDER RESTARTS: Reads durable session journal
        long startMs = System.currentTimeMillis();
        PeerTransferEngine restartedSender = new PeerTransferEngine(
                senderOpJournal, senderSessionJournal, stagingManager,
                new TransferPreflight(), new DestinationConflictResolver(),
                new BandwidthLimiter(), new TransferQueueManager());

        Optional<TransferSessionRecord> recoveredSession = senderSessionJournal.getSession(transferId);
        assertTrue(recoveredSession.isPresent());
        TransferManifest recoveredManifest = recoveredSession.get().getManifest();
        assertNotNull(recoveredManifest);

        // Resume using restarted sender
        TransferCompletedReceipt receipt = restartedSender.executeTransferWithManifest(
                recoveredManifest, List.of(sourceFile), destDir, null, Set.of(0L));

        assertTrue(receipt.getSuccess());
        Path target = destDir.resolve("kill_sender.bin");
        assertEquals(expectedSha, FileManifestBuilder.calculateSha256Hex(target));
        log.info("Measurement [Kill Sender]: RecoveryTime={}ms, Completed=true", System.currentTimeMillis() - startMs);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Disconnect Network
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test05_DisconnectNetwork() throws Exception {
        Path sourceFile = createTestPayload("disconnect.bin", 64 * 1024);
        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        // Network disconnection event: pause transfer cleanly
        senderEngine.pauseTransfer(transferId, "Network link dropped (TCP FIN/timeout)");

        TransferSessionRecord session = senderSessionJournal.getSession(transferId).get();
        assertEquals(TransferState.TRANSFER_STATE_PAUSED, session.getState());
        assertEquals(OperationState.WAITING, senderOpJournal.getOperation(manifest.getOperationId().getValue()).get().getState());

        // Destination must NOT have partial files
        assertFalse(Files.exists(destDir.resolve("disconnect.bin")), "Destination must remain pristine");
        log.info("Measurement [Disconnect Network]: State=PAUSED, DestPristine=true");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 6. Reconnect and Resume
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test06_ReconnectAndResume() throws Exception {
        int totalSize = 192 * 1024; // 3 chunks
        Path sourceFile = createTestPayload("reconnect.bin", totalSize);
        String expectedSha = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        // Stream chunk 0
        byte[] full = Files.readAllBytes(sourceFile);
        int chunkSize = manifest.getChunkSizeBytes();
        receiverEngine.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(Arrays.copyOfRange(full, 0, chunkSize)))
                .setIsLastChunk(false).setChunkSha256(FileManifestBuilder.calculateSha256Hex(Arrays.copyOfRange(full, 0, chunkSize))).build());

        // Disconnect
        senderEngine.pauseTransfer(transferId, "Carrier lost");

        // Reconnect event
        long startMs = System.currentTimeMillis();
        TransferResumeState state = receiverEngine.handleResumeOffer(
                TransferResumeOffer.newBuilder().setTransferId(transferId).setOperationId(manifest.getOperationId()).setManifest(manifest).build(), destDir);
        assertTrue(state.getCanResume());

        TransferCompletedReceipt receipt = senderEngine.executeTransferWithManifest(
                manifest, List.of(sourceFile), destDir, null, new HashSet<>(state.getAckedChunkIndicesList()));

        assertTrue(receipt.getSuccess());
        Path target = destDir.resolve("reconnect.bin");
        assertEquals(expectedSha, FileManifestBuilder.calculateSha256Hex(target));
        log.info("Measurement [Reconnect & Resume]: Time={}ms, FinalHashVerified=true", System.currentTimeMillis() - startMs);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Corrupt a Chunk and Retry
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test07_CorruptChunkAndRetry() throws Exception {
        Path sourceFile = createTestPayload("corrupt_test.bin", 64 * 1024);
        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        byte[] validData = Files.readAllBytes(sourceFile);
        String validSha256 = FileManifestBuilder.calculateSha256Hex(validData);

        byte[] corruptedData = Arrays.copyOf(validData, validData.length);
        corruptedData[100] = (byte) (corruptedData[100] ^ 0xFF); // flip bits

        // Send corrupt chunk claiming original SHA-256
        TransferChunk corruptChunk = TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(corruptedData))
                .setIsLastChunk(true)
                .setChunkSha256(validSha256)
                .build();

        TransferChunkAck failAck = receiverEngine.handleIncomingChunk(corruptChunk);
        assertFalse(failAck.getSuccess(), "Receiver must reject corrupt chunk");
        assertTrue(failAck.getRetryRequested(), "Receiver must request retry");

        // Retrying with valid chunk
        TransferChunk validChunk = TransferChunk.newBuilder()
                .setTransferId(transferId)
                .setItemIndex(0)
                .setChunkIndex(0)
                .setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(validData))
                .setIsLastChunk(true)
                .setChunkSha256(validSha256)
                .build();

        TransferChunkAck successAck = receiverEngine.handleIncomingChunk(validChunk);
        assertTrue(successAck.getSuccess(), "Receiver must accept valid retried chunk");

        // Verification and commit
        assertTrue(receiverEngine.verifyReceivedTransfer(transferId, manifest).getVerified());
        TransferCompletedReceipt receipt = receiverEngine.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(receipt.getSuccess());

        Path target = destDir.resolve("corrupt_test.bin");
        assertEquals(validSha256, FileManifestBuilder.calculateSha256Hex(target));
        log.info("Measurement [Corrupt Chunk]: Rejected=true, Retried=true, FinalHashVerified=true");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 8. Fill Destination Disk (Preflight & Rollback)
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test08_FillDestinationDisk() throws Exception {
        // (a) Preflight space exhaustion
        Path sourceFile = createTestPayload("huge_file.bin", 64 * 1024);

        TransferPreflight strictPreflight = new TransferPreflight(1_000_000_000_000_000L); // 1 Petabyte requirement
        PeerTransferEngine lowDiskEngine = new PeerTransferEngine(
                receiverOpJournal, receiverSessionJournal, stagingManager,
                strictPreflight, new DestinationConflictResolver(),
                new BandwidthLimiter(), new TransferQueueManager());

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);

        TransferResponse response = lowDiskEngine.handleIncomingOffer(
                TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        assertFalse(response.getAccepted(), "Must reject offer when disk space insufficient");
        assertEquals(ErrorCode.ERROR_CODE_RESOURCE_EXHAUSTED, response.getError().getCode());

        // (b) Multi-file rollback on staging error
        Path file1 = createTestPayload("multi1.dat", 32 * 1024);
        Path file2 = createTestPayload("multi2.dat", 32 * 1024);
        TransferManifest multiManifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(file1, file2), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String multiTransferId = multiManifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(multiManifest).build(), destDir);

        // Write first item
        byte[] b1 = Files.readAllBytes(file1);
        receiverEngine.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(multiTransferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(b1)).setIsLastChunk(true)
                .setChunkSha256(FileManifestBuilder.calculateSha256Hex(b1)).build());

        // Fail second item verification
        TransferVerifyResult vResult = receiverEngine.verifyReceivedTransfer(multiTransferId, multiManifest);
        assertFalse(vResult.getVerified());

        // Invariant: Zero partial files promoted to destination
        assertFalse(Files.exists(destDir.resolve("multi1.dat")));
        assertFalse(Files.exists(destDir.resolve("multi2.dat")));
        log.info("Measurement [Fill Destination Disk]: PreflightRejection=true, MultiFileRollback=true");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 9. Mutate Source During Transfer
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test09_MutateSourceDuringTransfer() throws Exception {
        Path sourceFile = createTestPayload("mutate_test.txt", 128 * 1024);
        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);

        // Mutate source file by appending bytes
        Files.writeString(sourceFile, "--- MUTATION INJECTION ---", StandardCharsets.UTF_8, StandardOpenOption.APPEND);

        assertThrows(SourceMutationException.class, () -> {
            senderEngine.executeTransferWithManifest(manifest, List.of(sourceFile), destDir, null, null);
        }, "Must throw SourceMutationException when source changes during transfer");

        // Destination must not contain mutated partial content
        assertFalse(Files.exists(destDir.resolve("mutate_test.txt")));
        log.info("Measurement [Mutate Source]: MutationDetected=true, DestinationClean=true");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 10. Duplicate Resume Request
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test10_DuplicateResumeRequest() throws Exception {
        Path sourceFile = createTestPayload("dup_resume.bin", 64 * 1024);
        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        TransferResumeOffer offer = TransferResumeOffer.newBuilder()
                .setTransferId(transferId)
                .setOperationId(manifest.getOperationId())
                .setManifest(manifest)
                .build();

        // 1st resume request
        TransferResumeState state1 = receiverEngine.handleResumeOffer(offer, destDir);
        assertTrue(state1.getCanResume());

        // 2nd duplicate resume request
        TransferResumeState state2 = receiverEngine.handleResumeOffer(offer, destDir);
        assertTrue(state2.getCanResume());

        // Must be identical and idempotent
        assertEquals(state1.getTransferId(), state2.getTransferId());
        assertEquals(state1.getBytesAlreadyStaged(), state2.getBytesAlreadyStaged());
        log.info("Measurement [Duplicate Resume]: Idempotent=true");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 11. Lose Final Acknowledgement (OUTCOME_UNKNOWN Reconciliation)
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test11_LoseFinalAcknowledgement() throws Exception {
        Path sourceFile = createTestPayload("lost_ack.bin", 64 * 1024);
        String expectedSha256 = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();
        String opId = manifest.getOperationId().getValue();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        byte[] data = Files.readAllBytes(sourceFile);
        receiverEngine.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(data)).setIsLastChunk(true)
                .setChunkSha256(expectedSha256).build());

        assertTrue(receiverEngine.verifyReceivedTransfer(transferId, manifest).getVerified());

        // Receiver COMMITS files to destination and stores receipt:
        TransferCompletedReceipt remoteReceipt = receiverEngine.commitReceivedTransfer(transferId, manifest, destDir);
        assertTrue(remoteReceipt.getSuccess());

        // SIMULATE LOST FINAL ACK:
        // Remote commit completed, but ACK packet dropped on the network.
        // Sender MUST mark local state OUTCOME_UNKNOWN and NEVER repeat destructive commit blindly!
        senderOpJournal.updateState(opId, OperationState.OUTCOME_UNKNOWN);
        assertEquals(OperationState.OUTCOME_UNKNOWN, senderOpJournal.getOperation(opId).get().getState());

        // RECONCILIATION FLOW:
        long startMs = System.currentTimeMillis();
        TransferCompletedReceipt reconciledReceipt = senderEngine.reconcileLostAck(opId, transferId, receiverEngine::handleOperationStatusQuery);

        assertNotNull(reconciledReceipt);
        assertTrue(reconciledReceipt.getSuccess());
        assertEquals(OperationState.COMMITTED, senderOpJournal.getOperation(opId).get().getState());
        assertEquals(TransferState.TRANSFER_STATE_COMPLETED, senderSessionJournal.getSession(transferId).get().getState());

        Path target = destDir.resolve("lost_ack.bin");
        assertTrue(Files.exists(target));
        assertEquals(expectedSha256, FileManifestBuilder.calculateSha256Hex(target));
        long duration = System.currentTimeMillis() - startMs;

        log.info("Measurement [Lost ACK]: Reconciled=true, BlindReplayAvoided=true, ReconcileTime={}ms, State=COMMITTED",
                duration);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 12. Restart Both Peers
    // ──────────────────────────────────────────────────────────────────────────
    @Test
    void test12_RestartBothPeers() throws Exception {
        int totalSize = 256 * 1024;
        Path sourceFile = createTestPayload("restart_both.bin", totalSize);
        String expectedSha = FileManifestBuilder.calculateSha256Hex(sourceFile);

        TransferManifest manifest = senderEngine.prepareSend(
                "sender_1", "receiver_1", List.of(sourceFile), DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS);
        String transferId = manifest.getTransferId();

        receiverEngine.handleIncomingOffer(TransferOffer.newBuilder().setManifest(manifest).build(), destDir);

        byte[] full = Files.readAllBytes(sourceFile);
        int chunkSize = manifest.getChunkSizeBytes();
        receiverEngine.handleIncomingChunk(TransferChunk.newBuilder()
                .setTransferId(transferId).setItemIndex(0).setChunkIndex(0).setOffsetBytes(0)
                .setData(com.google.protobuf.ByteString.copyFrom(Arrays.copyOfRange(full, 0, chunkSize)))
                .setIsLastChunk(false).setChunkSha256(FileManifestBuilder.calculateSha256Hex(Arrays.copyOfRange(full, 0, chunkSize))).build());

        // KILL BOTH SENDER AND RECEIVER:
        senderEngine = null;
        receiverEngine = null;

        long restartStart = System.currentTimeMillis();

        // RESTART RECEIVER:
        StagingDirectoryManager recoveredStaging = new StagingDirectoryManager(stagingDir);
        PeerTransferEngine newReceiver = new PeerTransferEngine(
                receiverOpJournal, receiverSessionJournal, recoveredStaging,
                new TransferPreflight(), new DestinationConflictResolver(),
                new BandwidthLimiter(), new TransferQueueManager());

        // RESTART SENDER:
        PeerTransferEngine newSender = new PeerTransferEngine(
                senderOpJournal, senderSessionJournal, recoveredStaging,
                new TransferPreflight(), new DestinationConflictResolver(),
                new BandwidthLimiter(), new TransferQueueManager());

        // SENDER OFFERS RESUME TO RECEIVER:
        TransferResumeState resumeState = newReceiver.handleResumeOffer(
                TransferResumeOffer.newBuilder().setTransferId(transferId).setOperationId(manifest.getOperationId()).setManifest(manifest).build(), destDir);

        assertTrue(resumeState.getCanResume());
        assertTrue(resumeState.getAckedChunkIndicesList().contains(0L));

        // SENDER STREAMS REMAINING CHUNKS:
        TransferCompletedReceipt receipt = newSender.executeTransferWithManifest(
                manifest, List.of(sourceFile), destDir, null, new HashSet<>(resumeState.getAckedChunkIndicesList()));

        assertTrue(receipt.getSuccess());
        Path target = destDir.resolve("restart_both.bin");
        assertEquals(expectedSha, FileManifestBuilder.calculateSha256Hex(target));

        long duration = System.currentTimeMillis() - restartStart;
        log.info("Measurement [Restart Both Peers]: RecoveryDuration={}ms, ResultingHashMatches=true, Committed=true", duration);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────
    private static class InMemoryJournal implements OperationJournal {
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
