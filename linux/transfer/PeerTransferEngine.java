package org.peerlink.core.transfer;

import com.google.protobuf.ByteString;
import org.peerlink.core.operation.JournalStage;
import org.peerlink.core.operation.OperationIntent;
import org.peerlink.core.operation.OperationJournal;
import org.peerlink.core.operation.OperationRecord;
import org.peerlink.core.operation.OperationState;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Consumer;

/**
 * Resumable, recoverable, and fault-tolerant transfer engine for PeerLink.
 *
 * <p>Phase 07 Capabilities:
 * <ul>
 *   <li>Chunking with optional per-chunk SHA-256 validation</li>
 *   <li>Failed chunk retries up to N attempts</li>
 *   <li>Pause and Resume with selective retransmission of un-ACKed chunks</li>
 *   <li>Source mutation detection mid-transfer</li>
 *   <li>Crash recovery and operation reconciliation via durable manifests and receipts</li>
 *   <li>Strict OUTCOME_UNKNOWN handling: if final ACK is lost after remote commit, query operation ID
 *       and NEVER blindly replay committing or destructive actions</li>
 *   <li>Dynamic bandwidth throttling via token-bucket rate limiter</li>
 *   <li>Multi-file transactional staging and atomic commit/rollback</li>
 * </ul>
 */
public final class PeerTransferEngine {
    private static final Logger log = LoggerFactory.getLogger(PeerTransferEngine.class);

    private final OperationJournal journal;
    private final TransferSessionJournal sessionJournal;
    private final StagingDirectoryManager stagingManager;
    private final TransferPreflight preflight;
    private final DestinationConflictResolver conflictResolver;
    private final FileManifestBuilder manifestBuilder;
    private final BandwidthLimiter bandwidthLimiter;
    private final TransferQueueManager queueManager;

    private final Map<String, TransferProgressTracker> activeTransfers = new ConcurrentHashMap<>();
    private final Map<String, TransferManifest> activeManifests = new ConcurrentHashMap<>();
    private final Map<String, List<Path>> activeSourcePaths = new ConcurrentHashMap<>();
    private final Map<String, Path> activeDestinations = new ConcurrentHashMap<>();

    private volatile int maxChunkRetries = 3;
    private volatile boolean computeChunkHashes = true;

    public PeerTransferEngine(
            OperationJournal journal,
            Path stagingRoot) {
        this(journal, new InMemoryTransferSessionJournal(), new StagingDirectoryManager(stagingRoot),
                new TransferPreflight(), new DestinationConflictResolver(), new BandwidthLimiter(),
                new TransferQueueManager());
    }

    public PeerTransferEngine(
            OperationJournal journal,
            StagingDirectoryManager stagingManager,
            TransferPreflight preflight,
            DestinationConflictResolver conflictResolver) {
        this(journal, new InMemoryTransferSessionJournal(), stagingManager, preflight, conflictResolver,
                new BandwidthLimiter(), new TransferQueueManager());
    }

    public PeerTransferEngine(
            OperationJournal journal,
            TransferSessionJournal sessionJournal,
            StagingDirectoryManager stagingManager,
            TransferPreflight preflight,
            DestinationConflictResolver conflictResolver,
            BandwidthLimiter bandwidthLimiter,
            TransferQueueManager queueManager) {
        this.journal = journal;
        this.sessionJournal = sessionJournal;
        this.stagingManager = stagingManager;
        this.preflight = preflight;
        this.conflictResolver = conflictResolver;
        this.manifestBuilder = new FileManifestBuilder();
        this.bandwidthLimiter = bandwidthLimiter;
        this.queueManager = queueManager;
    }

    public void setBandwidthLimit(long bytesPerSecond) {
        bandwidthLimiter.setRateLimit(bytesPerSecond);
    }

    public BandwidthLimiter getBandwidthLimiter() {
        return bandwidthLimiter;
    }

    public TransferQueueManager getQueueManager() {
        return queueManager;
    }

    public TransferSessionJournal getSessionJournal() {
        return sessionJournal;
    }

    public void setMaxChunkRetries(int maxRetries) {
        this.maxChunkRetries = Math.max(0, maxRetries);
    }

    public void setComputeChunkHashes(boolean computeChunkHashes) {
        this.computeChunkHashes = computeChunkHashes;
    }

    /**
     * Prepare a new outgoing transfer session (Sender side).
     */
    public TransferManifest prepareSend(
            String senderPeerId,
            String receiverPeerId,
            List<Path> sourcePaths,
            DuplicateDestinationPolicy duplicatePolicy) throws IOException {

        String transferId = "xfer_" + UUID.randomUUID().toString().replace("-", "");
        String operationId = "op_send_" + UUID.randomUUID().toString().replace("-", "");

        TransferManifest manifest = manifestBuilder.buildManifest(
                transferId,
                operationId,
                senderPeerId,
                receiverPeerId,
                sourcePaths,
                duplicatePolicy);

        long now = System.currentTimeMillis();

        // 1. Authoritative Operation Journal
        OperationRecord record = new OperationRecord(
                operationId,
                OperationIntent.SEND,
                senderPeerId,
                manifest.getItemsList().stream().map(TransferItem::getRelativePath).toList(),
                OperationState.CREATED,
                "idemp_" + transferId,
                now,
                now
        );
        journal.recordOperation(record);
        journal.recordJournalStage(operationId, JournalStage.INTENT);

        // 2. Transfer Session Journal
        TransferSessionRecord session = new TransferSessionRecord(
                transferId,
                operationId,
                senderPeerId,
                receiverPeerId,
                TransferState.TRANSFER_STATE_PREPARING,
                manifest.getTotalBytes(),
                manifest.getItemsCount(),
                now
        );
        session.setManifest(manifest);
        sessionJournal.recordSession(session);

        activeManifests.put(transferId, manifest);
        activeSourcePaths.put(transferId, new ArrayList<>(sourcePaths));
        return manifest;
    }

    /**
     * Process an incoming TransferOffer (Receiver side).
     */
    public TransferResponse handleIncomingOffer(TransferOffer offer, Path destinationDir) {
        TransferManifest manifest = offer.getManifest();
        String transferId = manifest.getTransferId();
        String opId = manifest.getOperationId().getValue();

        log.info("Evaluating incoming transfer offer: transferId={}, opId={}, items={}, totalBytes={}",
                transferId, opId, manifest.getItemsCount(), manifest.getTotalBytes());

        long now = System.currentTimeMillis();

        // 1. Record incoming operation in operation journal
        OperationRecord opRecord = new OperationRecord(
                opId,
                OperationIntent.SEND,
                manifest.getSenderPeerId().getValue(),
                manifest.getItemsList().stream().map(TransferItem::getRelativePath).toList(),
                OperationState.CREATED,
                "idemp_recv_" + transferId,
                now,
                now
        );
        journal.recordOperation(opRecord);
        journal.recordJournalStage(opId, JournalStage.INTENT);

        // 2. Transfer Session Journal
        TransferSessionRecord session = new TransferSessionRecord(
                transferId,
                opId,
                manifest.getSenderPeerId().getValue(),
                manifest.getReceiverPeerId().getValue(),
                TransferState.TRANSFER_STATE_PREPARING,
                manifest.getTotalBytes(),
                manifest.getItemsCount(),
                now
        );
        session.setManifest(manifest);
        sessionJournal.recordSession(session);

        // 3. Resource Preflight Check
        try {
            preflight.checkDestination(destinationDir, manifest);
            journal.updateState(opId, OperationState.VALIDATED);
        } catch (PreflightException e) {
            log.error("Transfer offer rejected due to preflight failure: {}", e.getMessage());
            journal.updateState(opId, OperationState.FAILED);
            journal.appendNote(opId, "Preflight failed: " + e.getMessage());
            session.setState(TransferState.TRANSFER_STATE_FAILED);
            session.setFailureReason("Preflight failed: " + e.getMessage());
            return TransferResponse.newBuilder()
                    .setTransferId(transferId)
                    .setAccepted(false)
                    .setRejectionReason(e.getMessage())
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_RESOURCE_EXHAUSTED)
                            .setHumanSummary(e.getMessage())
                            .build())
                    .build();
        }

        // 4. Prepare clean staging directory
        try {
            stagingManager.prepareStagingDir(transferId);
        } catch (IOException e) {
            log.error("Failed to prepare staging directory for transfer {}: {}", transferId, e.getMessage());
            journal.updateState(opId, OperationState.FAILED);
            session.setState(TransferState.TRANSFER_STATE_FAILED);
            return TransferResponse.newBuilder()
                    .setTransferId(transferId)
                    .setAccepted(false)
                    .setRejectionReason("Cannot create staging directory: " + e.getMessage())
                    .build();
        }

        journal.updateState(opId, OperationState.AUTHORIZED);
        session.setState(TransferState.TRANSFER_STATE_CONNECTING);
        activeManifests.put(transferId, manifest);
        activeDestinations.put(transferId, destinationDir);

        return TransferResponse.newBuilder()
                .setTransferId(transferId)
                .setAccepted(true)
                .build();
    }

    /**
     * Receive and store a transfer chunk into isolated staging (Receiver side).
     * Validates optional chunk hash. If corrupted, requests chunk retry.
     */
    public TransferChunkAck handleIncomingChunk(TransferChunk chunk) throws IOException {
        String transferId = chunk.getTransferId();
        TransferProgressTracker tracker = activeTransfers.get(transferId);

        if (tracker != null && tracker.isCancelled()) {
            throw new IllegalStateException("Transfer was cancelled: " + tracker.getCancelReason());
        }

        byte[] data = chunk.getData().toByteArray();

        try {
            stagingManager.writeChunk(
                    transferId,
                    chunk.getItemIndex(),
                    chunk.getChunkIndex(),
                    chunk.getOffsetBytes(),
                    data,
                    chunk.getChunkSha256()
            );

            sessionJournal.updateChunkStatus(
                    transferId, chunk.getItemIndex(), chunk.getChunkIndex(), ChunkStatus.CHUNK_STATUS_ACKED);

            if (tracker != null) {
                tracker.addBytes(data.length);
            }

            return TransferChunkAck.newBuilder()
                    .setTransferId(transferId)
                    .setItemIndex(chunk.getItemIndex())
                    .setChunkIndex(chunk.getChunkIndex())
                    .setBytesReceived(data.length)
                    .setSuccess(true)
                    .setRetryRequested(false)
                    .build();

        } catch (CorruptChunkException e) {
            log.warn("Corrupt chunk detected: transfer={}, item={}, chunk={}",
                    transferId, chunk.getItemIndex(), chunk.getChunkIndex());

            sessionJournal.updateChunkStatus(
                    transferId, chunk.getItemIndex(), chunk.getChunkIndex(), ChunkStatus.CHUNK_STATUS_FAILED);

            return TransferChunkAck.newBuilder()
                    .setTransferId(transferId)
                    .setItemIndex(chunk.getItemIndex())
                    .setChunkIndex(chunk.getChunkIndex())
                    .setBytesReceived(0)
                    .setSuccess(false)
                    .setRetryRequested(true)
                    .setErrorMessage(e.getMessage())
                    .build();
        }
    }

    /**
     * Handle incoming Resume Offer from sender (Receiver side).
     * Inspects existing staged partial files and session journal to report ACKed chunks.
     */
    public TransferResumeState handleResumeOffer(TransferResumeOffer offer, Path destinationDir) {
        String transferId = offer.getTransferId();
        log.info("Handling resume offer for transfer: {}", transferId);

        Optional<TransferSessionRecord> sessionOpt = sessionJournal.getSession(transferId);
        TransferManifest manifest = activeManifests.get(transferId);
        if (manifest == null && sessionOpt.isPresent()) {
            manifest = sessionOpt.get().getManifest();
        }
        if (manifest == null && offer.hasManifest()) {
            manifest = offer.getManifest();
        }

        if (manifest == null) {
            return TransferResumeState.newBuilder()
                    .setTransferId(transferId)
                    .setCanResume(false)
                    .setMessage("Unknown transfer session for resume")
                    .build();
        }

        TransferResumeState.Builder stateBuilder = TransferResumeState.newBuilder()
                .setTransferId(transferId)
                .setOperationId(offer.getOperationId())
                .setCanResume(true);

        long totalStagedBytes = 0;

        for (int i = 0; i < manifest.getItemsCount(); i++) {
            TransferItem item = manifest.getItems(i);
            if (item.getIsDirectory()) continue;

            Set<Long> acked = sessionJournal.getAckedChunks(transferId, i);
            long stagedSize = stagingManager.getStagedFileSize(transferId, i);
            if (stagedSize > 0) {
                totalStagedBytes += stagedSize;
            }

            for (Long chunkIdx : acked) {
                stateBuilder.addAckedChunkIndices(chunkIdx);
            }
        }

        stateBuilder.setBytesAlreadyStaged(totalStagedBytes);
        stateBuilder.setCurrentState(TransferState.TRANSFER_STATE_TRANSFERRING);

        // Ensure active manifests and destinations are wired for resumption
        activeManifests.put(transferId, manifest);
        activeDestinations.put(transferId, destinationDir);

        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_TRANSFERRING);
        journal.updateState(offer.getOperationId().getValue(), OperationState.EXECUTING);

        return stateBuilder.build();
    }

    /**
     * Pause an in-flight transfer cleanly (Sender or Receiver side).
     */
    public void pauseTransfer(String transferId, String reason) {
        TransferProgressTracker tracker = activeTransfers.get(transferId);
        if (tracker != null) {
            tracker.pause(reason);
        }

        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_PAUSED);
        TransferManifest manifest = activeManifests.get(transferId);
        if (manifest != null) {
            String opId = manifest.getOperationId().getValue();
            journal.updateState(opId, OperationState.WAITING);
            journal.appendNote(opId, "Paused: " + reason);
        }
        log.info("Transfer {} paused: {}", transferId, reason);
    }

    /**
     * Handle Operation Status Query (Reconciliation / OUTCOME_UNKNOWN handling).
     *
     * <p>CRITICAL INVARIANT:
     * If final ACK was lost after commit, receiver returns is_committed=true with the original receipt.
     * Sender marks local state committed and NEVER blindly repeats destructive/committing actions!
     */
    public TransferOperationStatusResponse handleOperationStatusQuery(TransferOperationStatusQuery query) {
        String opId = query.getOperationId().getValue();
        String transferId = query.getTransferId();

        log.info("Handling operation status query: opId={}, transferId={}", opId, transferId);

        Optional<TransferSessionRecord> sessionOpt = sessionJournal.getSessionByOperationId(opId);
        if (sessionOpt.isEmpty() && !transferId.isBlank()) {
            sessionOpt = sessionJournal.getSession(transferId);
        }

        TransferOperationStatusResponse.Builder builder = TransferOperationStatusResponse.newBuilder()
                .setOperationId(query.getOperationId())
                .setTransferId(transferId);

        if (sessionOpt.isPresent()) {
            TransferSessionRecord session = sessionOpt.get();
            if (session.getState() == TransferState.TRANSFER_STATE_COMPLETED && session.getReceipt() != null) {
                return builder.setState(TransferState.TRANSFER_STATE_COMPLETED)
                        .setIsCommitted(true)
                        .setReceipt(session.getReceipt())
                        .build();
            } else if (session.getState() == TransferState.TRANSFER_STATE_FAILED) {
                return builder.setState(TransferState.TRANSFER_STATE_FAILED)
                        .setIsCommitted(false)
                        .setErrorMessage(session.getFailureReason() != null ? session.getFailureReason() : "Operation failed")
                        .build();
            } else if (session.getState() == TransferState.TRANSFER_STATE_CANCELLED) {
                return builder.setState(TransferState.TRANSFER_STATE_CANCELLED)
                        .setIsCommitted(false)
                        .setErrorMessage("Operation was cancelled")
                        .build();
            }
        }

        // Check authoritative operation journal
        Optional<OperationRecord> opRec = journal.getOperation(opId);
        if (opRec.isPresent()) {
            OperationRecord rec = opRec.get();
            boolean committed = (rec.getState() == OperationState.COMMITTED);
            builder.setState(committed ? TransferState.TRANSFER_STATE_COMPLETED : TransferState.TRANSFER_STATE_TRANSFERRING);
            builder.setIsCommitted(committed);
            return builder.build();
        }

        return builder.setState(TransferState.TRANSFER_STATE_FAILED)
                .setIsCommitted(false)
                .setErrorMessage("Operation ID not found")
                .build();
    }

    /**
     * Verify all received items against manifest SHA-256 hashes (Receiver side).
     * Multi-file transaction semantics: ALL items must pass verification.
     * If any item fails, staging is cleaned up and entire operation fails.
     */
    public TransferVerifyResult verifyReceivedTransfer(String transferId, TransferManifest manifest) {
        String opId = manifest.getOperationId().getValue();
        journal.recordJournalStage(opId, JournalStage.VERIFY);

        TransferProgressTracker tracker = activeTransfers.get(transferId);
        if (tracker != null) {
            tracker.updateState(TransferState.TRANSFER_STATE_VERIFYING);
        }
        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_VERIFYING);

        for (int i = 0; i < manifest.getItemsCount(); i++) {
            TransferItem item = manifest.getItems(i);
            if (item.getIsDirectory()) continue;

            try {
                stagingManager.verifyStagedItem(transferId, i, item.getSha256Hex(), item.getRelativePath());
            } catch (HashMismatchException e) {
                log.error("Integrity verification failed for item {}: {}", item.getRelativePath(), e.getMessage());
                journal.updateState(opId, OperationState.FAILED);
                journal.appendNote(opId, "Integrity check failed: " + e.getMessage());
                sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_FAILED);

                if (tracker != null) tracker.fail(e.getMessage());
                // Atomic multi-file rollback: cleanup staging completely
                stagingManager.cleanupStaging(transferId);

                return TransferVerifyResult.newBuilder()
                        .setTransferId(transferId)
                        .setItemIndex(i)
                        .setVerified(false)
                        .setExpectedSha256(e.getExpectedHash())
                        .setComputedSha256(e.getComputedHash())
                        .setDetails(e.getMessage())
                        .build();
            } catch (IOException e) {
                log.error("Failed to read staged file during verification: {}", e.getMessage(), e);
                journal.updateState(opId, OperationState.FAILED);
                sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_FAILED);
                if (tracker != null) tracker.fail(e.getMessage());
                stagingManager.cleanupStaging(transferId);
                return TransferVerifyResult.newBuilder()
                        .setTransferId(transferId)
                        .setItemIndex(i)
                        .setVerified(false)
                        .setDetails("Staging read error: " + e.getMessage())
                        .build();
            }
        }

        return TransferVerifyResult.newBuilder()
                .setTransferId(transferId)
                .setVerified(true)
                .setDetails("All items passed SHA-256 cryptographic verification")
                .build();
    }

    /**
     * Commit verified files from staging to final destination directory (Receiver side).
     * Stores durable completion receipt for crash recovery and lost-ACK queries.
     */
    public TransferCompletedReceipt commitReceivedTransfer(
            String transferId,
            TransferManifest manifest,
            Path destinationRoot) throws IOException {

        String opId = manifest.getOperationId().getValue();
        journal.recordJournalStage(opId, JournalStage.COMMIT);

        TransferProgressTracker tracker = activeTransfers.get(transferId);
        if (tracker != null) {
            tracker.updateState(TransferState.TRANSFER_STATE_COMMITTING);
        }
        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_COMMITTING);

        long totalCommitted = 0;

        for (int i = 0; i < manifest.getItemsCount(); i++) {
            TransferItem item = manifest.getItems(i);
            Path finalDest = conflictResolver.resolveDestination(
                    destinationRoot, item.getRelativePath(), manifest.getDuplicatePolicy());

            if (item.getIsDirectory()) {
                Files.createDirectories(finalDest);
            } else {
                stagingManager.commitItem(transferId, i, finalDest);
                totalCommitted += item.getFileSizeBytes();
            }
        }

        // Cleanup staging
        stagingManager.cleanupStaging(transferId);

        // Update journals to final COMMITTED state
        journal.updateState(opId, OperationState.COMMITTED);
        journal.recordJournalStage(opId, JournalStage.FINALIZE);

        TransferCompletedReceipt receipt = TransferCompletedReceipt.newBuilder()
                .setTransferId(transferId)
                .setOperationId(manifest.getOperationId())
                .setCompletionTimestampUtcMs(System.currentTimeMillis())
                .setTotalBytesTransferred(totalCommitted)
                .setSuccess(true)
                .setFinalDestinationPath(destinationRoot.toAbsolutePath().toString())
                .build();

        sessionJournal.recordReceipt(transferId, receipt);

        if (tracker != null) {
            tracker.setDestinationPath(destinationRoot.toAbsolutePath().toString());
            tracker.complete();
        }

        return receipt;
    }

    /**
     * Cancel an ongoing transfer session.
     */
    public void cancelTransfer(String transferId, String reason) {
        TransferProgressTracker tracker = activeTransfers.get(transferId);
        if (tracker != null) {
            tracker.cancel(reason);
        }

        sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_CANCELLED);
        TransferManifest manifest = activeManifests.get(transferId);
        if (manifest != null) {
            String opId = manifest.getOperationId().getValue();
            try {
                journal.updateState(opId, OperationState.CANCELLED);
                journal.appendNote(opId, "Cancelled: " + reason);
            } catch (Exception e) {
                log.warn("Could not mark operation {} cancelled in journal: {}", opId, e.getMessage());
            }
        }

        stagingManager.cleanupStaging(transferId);
        log.info("Transfer {} cancelled: {}", transferId, reason);
    }

    /**
     * Execute an end-to-end reliable file transfer with fault-tolerance and verification.
     */
    public TransferCompletedReceipt executeTransfer(
            List<Path> sourcePaths,
            Path destinationRoot,
            DuplicateDestinationPolicy duplicatePolicy,
            String senderPeerId,
            String receiverPeerId,
            Consumer<TransferProgress> progressCallback) throws Exception {

        TransferManifest manifest = prepareSend(senderPeerId, receiverPeerId, sourcePaths, duplicatePolicy);
        return executeTransferWithManifest(manifest, sourcePaths, destinationRoot, progressCallback, null);
    }

    /**
     * Execute transfer given an existing prepared or resumed manifest.
     */
    public TransferCompletedReceipt executeTransferWithManifest(
            TransferManifest manifest,
            List<Path> sourcePaths,
            Path destinationRoot,
            Consumer<TransferProgress> progressCallback,
            Set<Long> alreadyAckedChunks) throws Exception {

        String transferId = manifest.getTransferId();
        String opId = manifest.getOperationId().getValue();

        TransferProgressTracker tracker = new TransferProgressTracker(
                transferId, manifest.getTotalBytes(), manifest.getItemsCount(), progressCallback);
        activeTransfers.put(transferId, tracker);
        tracker.start();

        try {
            // 1. Offer & Preflight on receiver (if fresh transfer)
            if (alreadyAckedChunks == null) {
                TransferOffer offer = TransferOffer.newBuilder()
                        .setManifest(manifest)
                        .setTimestampUtcMs(System.currentTimeMillis())
                        .build();

                TransferResponse response = handleIncomingOffer(offer, destinationRoot);
                if (!response.getAccepted()) {
                    tracker.fail("Transfer offer rejected: " + response.getRejectionReason());
                    throw new PreflightException(
                            PreflightException.PreflightErrorCode.DESTINATION_UNAVAILABLE,
                            "Transfer offer rejected: " + response.getRejectionReason());
                }
            }

            // 2. Transferring Chunks
            tracker.updateState(TransferState.TRANSFER_STATE_TRANSFERRING);
            sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_TRANSFERRING);
            journal.updateState(opId, OperationState.EXECUTING);
            journal.recordJournalStage(opId, JournalStage.EXECUTE);

            int chunkSizeBytes = manifest.getChunkSizeBytes();
            byte[] buffer = new byte[chunkSizeBytes];

            Set<Long> ackedSet = (alreadyAckedChunks != null) ? alreadyAckedChunks : Collections.emptySet();

            for (int i = 0; i < manifest.getItemsCount(); i++) {
                if (tracker.isCancelled()) {
                    throw new IllegalStateException("Transfer cancelled during transmission: " + tracker.getCancelReason());
                }
                if (tracker.isPaused()) {
                    log.info("Transfer {} is paused; exiting chunk loop cleanly", transferId);
                    return null;
                }

                TransferItem item = manifest.getItems(i);
                tracker.setCurrentItem(i, item.getRelativePath());

                if (item.getIsDirectory()) {
                    continue;
                }

                Path sourceFile = findSourceFileForRelativePath(sourcePaths, item.getRelativePath());

                // Detect source mutation before/during transmission
                validateSourceFile(sourceFile, item);

                long fileSize = item.getFileSizeBytes();
                long offset = 0;
                long chunkIndex = 0;

                if (fileSize == 0) {
                    if (!ackedSet.contains(0L)) {
                        sendChunkWithRetry(transferId, i, 0, 0, new byte[0], true, item.getSha256Hex());
                    }
                } else {
                    try (InputStream in = Files.newInputStream(sourceFile)) {
                        int read;
                        while ((read = in.read(buffer)) != -1) {
                            if (tracker.isCancelled()) {
                                throw new IllegalStateException("Transfer cancelled: " + tracker.getCancelReason());
                            }
                            if (tracker.isPaused()) {
                                log.info("Transfer {} is paused; exiting chunk loop cleanly", transferId);
                                return null;
                            }

                            // Check source mutation during file read
                            validateSourceFile(sourceFile, item);

                            if (!ackedSet.contains(chunkIndex)) {
                                byte[] chunkData = Arrays.copyOf(buffer, read);

                                // Bandwidth throttling
                                bandwidthLimiter.consume(read);

                                boolean isLast = (offset + read >= fileSize);
                                String chunkSha = computeChunkHashes ? FileManifestBuilder.calculateSha256Hex(chunkData) : "";

                                sendChunkWithRetry(transferId, i, chunkIndex, offset, chunkData, isLast, chunkSha);
                            }

                            offset += read;
                            chunkIndex++;
                        }
                    }
                }
            }

            // 3. Verification
            tracker.updateState(TransferState.TRANSFER_STATE_RECEIVED);
            TransferVerifyResult verifyResult = verifyReceivedTransfer(transferId, manifest);
            if (!verifyResult.getVerified()) {
                throw new HashMismatchException(
                        "Item " + verifyResult.getItemIndex(),
                        verifyResult.getExpectedSha256(),
                        verifyResult.getComputedSha256());
            }

            // 4. Atomic Commit
            TransferCompletedReceipt receipt = commitReceivedTransfer(transferId, manifest, destinationRoot);
            log.info("Transfer {} completed successfully: {} bytes committed to {}",
                    transferId, receipt.getTotalBytesTransferred(), receipt.getFinalDestinationPath());
            return receipt;

        } catch (Exception e) {
            log.error("Transfer {} encountered error: {}", transferId, e.getMessage());
            if (!tracker.isPaused()) {
                tracker.fail(e.getMessage());
                sessionJournal.updateSessionState(transferId, TransferState.TRANSFER_STATE_FAILED);
                stagingManager.cleanupStaging(transferId);
            }
            throw e;
        } finally {
            if (!tracker.isPaused()) {
                activeTransfers.remove(transferId);
                activeManifests.remove(transferId);
                activeSourcePaths.remove(transferId);
                activeDestinations.remove(transferId);
            }
        }
    }

    private void sendChunkWithRetry(
            String transferId,
            int itemIndex,
            long chunkIndex,
            long offsetBytes,
            byte[] chunkData,
            boolean isLastChunk,
            String chunkSha256) throws Exception {

        int attempts = 0;
        while (attempts <= maxChunkRetries) {
            attempts++;
            TransferChunk chunk = TransferChunk.newBuilder()
                    .setTransferId(transferId)
                    .setItemIndex(itemIndex)
                    .setChunkIndex(chunkIndex)
                    .setOffsetBytes(offsetBytes)
                    .setData(ByteString.copyFrom(chunkData))
                    .setIsLastChunk(isLastChunk)
                    .setChunkSha256(chunkSha256)
                    .build();

            TransferChunkAck ack = handleIncomingChunk(chunk);
            if (ack.getSuccess()) {
                return;
            }

            log.warn("Chunk failed: item={}, chunk={}, attempt={}/{}, err={}",
                    itemIndex, chunkIndex, attempts, maxChunkRetries + 1, ack.getErrorMessage());

            if (attempts > maxChunkRetries) {
                throw new IOException("Failed to send chunk [" + itemIndex + ":" + chunkIndex + "] after "
                        + attempts + " attempts: " + ack.getErrorMessage());
            }
        }
    }

    /**
     * Detects if source file mutated (size or modified timestamp changed) mid-transfer.
     */
    private void validateSourceFile(Path sourceFile, TransferItem expectedItem) throws SourceMutationException {
        if (!Files.exists(sourceFile)) {
            throw new SourceMutationException(expectedItem.getRelativePath(), "Source file was deleted during transfer");
        }

        try {
            long currentSize = Files.size(sourceFile);
            if (currentSize != expectedItem.getFileSizeBytes()) {
                throw new SourceMutationException(expectedItem.getRelativePath(),
                        "Size changed from " + expectedItem.getFileSizeBytes() + " to " + currentSize + " bytes");
            }

            FileTime modifiedTime = Files.getLastModifiedTime(sourceFile);
            if (modifiedTime.toMillis() != expectedItem.getModifiedTimeUtcMs()) {
                throw new SourceMutationException(expectedItem.getRelativePath(),
                        "Modification timestamp changed from " + expectedItem.getModifiedTimeUtcMs() + " to " + modifiedTime.toMillis());
            }
        } catch (IOException e) {
            throw new SourceMutationException(expectedItem.getRelativePath(), "Cannot read file attributes: " + e.getMessage());
        }
    }

    /**
     * Resume a paused or interrupted transfer session.
     * Retransmits ONLY missing/un-ACKed chunks!
     *
     * @return Resulting TransferCompletedReceipt upon successful completion
     */
    public TransferCompletedReceipt resumeTransfer(
            String transferId,
            Path destinationDir,
            Consumer<TransferProgress> progressCallback) throws Exception {

        TransferManifest manifest = activeManifests.get(transferId);
        List<Path> sourcePaths = activeSourcePaths.get(transferId);

        if (manifest == null || sourcePaths == null) {
            Optional<TransferSessionRecord> sessionOpt = sessionJournal.getSession(transferId);
            if (sessionOpt.isPresent()) {
                manifest = sessionOpt.get().getManifest();
            }
            if (manifest == null) {
                throw new IllegalStateException("Cannot resume transfer: manifest not found for " + transferId);
            }
        }

        // 1. Create Resume Offer
        TransferResumeOffer offer = TransferResumeOffer.newBuilder()
                .setTransferId(transferId)
                .setOperationId(manifest.getOperationId())
                .setManifest(manifest)
                .setResumeTimestampUtcMs(System.currentTimeMillis())
                .build();

        // 2. Query receiver for current staging state & ACKed chunks
        TransferResumeState resumeState = handleResumeOffer(offer, destinationDir);
        if (!resumeState.getCanResume()) {
            throw new IllegalStateException("Receiver rejected resume offer: " + resumeState.getMessage());
        }

        Set<Long> ackedChunks = new HashSet<>(resumeState.getAckedChunkIndicesList());
        log.info("Resuming transfer {}: receiver already has {} acked chunks", transferId, ackedChunks.size());

        // 3. Continue transmission transmitting ONLY missing chunks
        activeManifests.put(transferId, manifest);
        if (sourcePaths != null) {
            activeSourcePaths.put(transferId, sourcePaths);
        }

        return executeTransferWithManifest(manifest, activeSourcePaths.get(transferId), destinationDir, progressCallback, ackedChunks);
    }

    /**
     * Reconcile an operation whose final ACK was lost after commit.
     * Marks sender operation as COMMITTED without re-committing or duplicating files!
     */
    public TransferCompletedReceipt reconcileLostAck(
            String operationId,
            String transferId,
            java.util.function.Function<TransferOperationStatusQuery, TransferOperationStatusResponse> remoteQueryRpc) {
        log.info("Reconciling operation status for lost ACK: opId={}, transferId={}", operationId, transferId);

        TransferOperationStatusQuery query = TransferOperationStatusQuery.newBuilder()
                .setOperationId(OperationId.newBuilder().setValue(operationId).build())
                .setTransferId(transferId)
                .build();

        TransferOperationStatusResponse response = remoteQueryRpc.apply(query);

        if (response.getIsCommitted() && response.hasReceipt()) {
            TransferCompletedReceipt receipt = response.getReceipt();
            journal.updateState(operationId, OperationState.COMMITTED);
            sessionJournal.recordReceipt(transferId, receipt);
            log.info("Reconciled operation {} as COMMITTED using remote receipt", operationId);
            return receipt;
        } else {
            throw new IllegalStateException("Cannot reconcile operation " + operationId + ": remote reports is_committed=false");
        }
    }

    public TransferCompletedReceipt reconcileLostAck(String operationId, String transferId) {
        return reconcileLostAck(operationId, transferId, this::handleOperationStatusQuery);
    }

    private Path findSourceFileForRelativePath(List<Path> sourcePaths, String relativePath) {
        for (Path root : sourcePaths) {
            Path normalized = root.toAbsolutePath().normalize();
            if (Files.isRegularFile(normalized)) {
                if (normalized.getFileName().toString().equals(relativePath)) {
                    return normalized;
                }
            } else if (Files.isDirectory(normalized)) {
                String dirName = normalized.getFileName().toString();
                if (relativePath.startsWith(dirName + "/") || relativePath.equals(dirName)) {
                    String sub = relativePath.substring(dirName.length());
                    if (sub.startsWith("/")) sub = sub.substring(1);
                    Path candidate = normalized.resolve(sub);
                    if (Files.exists(candidate)) {
                        return candidate;
                    }
                }
            }
        }
        throw new IllegalArgumentException("Cannot locate source file for relative path: " + relativePath);
    }

    public TransferProgressTracker getActiveTransferTracker(String transferId) {
        return activeTransfers.get(transferId);
    }

    public StagingDirectoryManager getStagingManager() {
        return stagingManager;
    }
}
