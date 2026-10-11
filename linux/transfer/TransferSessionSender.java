package org.peerlink.core.transfer;

import com.google.protobuf.ByteString;
import org.peerlink.core.transport.PeerSession;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

/**
 * Sender-side transfer protocol engine operating exclusively over an authenticated PeerSession.
 * Reads and prepares local content, transmits protocol messages across the active session/transport,
 * verifies acknowledgements returned by the remote receiver, and handles network retries.
 * Does NOT invoke receiver-side handlers or access the receiver filesystem directly.
 */
public class TransferSessionSender {

    private static final Logger log = LoggerFactory.getLogger(TransferSessionSender.class);

    private static final int DEFAULT_CHUNK_TIMEOUT_MS = 5000;
    private static final int DEFAULT_OFFER_TIMEOUT_MS = 10000;
    private static final int DEFAULT_COMMIT_TIMEOUT_MS = 15000;

    private final PeerSession session;
    private final TransferSessionCoordinator coordinator;
    private final BandwidthLimiter bandwidthLimiter;
    private final int maxChunkRetries;

    public TransferSessionSender(PeerSession session,
                                 TransferSessionCoordinator coordinator,
                                 BandwidthLimiter bandwidthLimiter,
                                 int maxChunkRetries) {
        this.session = session;
        this.coordinator = coordinator;
        this.bandwidthLimiter = bandwidthLimiter != null ? bandwidthLimiter : new BandwidthLimiter(0);
        this.maxChunkRetries = Math.max(1, maxChunkRetries);
    }

    public TransferCompletedReceipt send(
            TransferManifest manifest,
            List<Path> sourcePaths,
            Consumer<TransferProgress> progressCallback) throws Exception {

        String transferId = manifest.getTransferId();
        String remotePeerId = session.getRemotePeer().getPeerId().getValue();

        // 1. Session State and Identity Verification
        if (session.getState() != SessionState.SESSION_STATE_ESTABLISHED) {
            throw new IllegalStateException("Cannot initiate send: PeerSession is not established (" + session.getState() + ")");
        }

        if (!manifest.getRecipientPeerId().equals(remotePeerId)) {
            throw new IllegalArgumentException(String.format(
                    "Recipient Peer ID in manifest (%s) does not match authenticated remote peer (%s)",
                    manifest.getRecipientPeerId(), remotePeerId));
        }

        TransferProgressTracker tracker = new TransferProgressTracker(
                transferId, manifest.getTotalBytes(), manifest.getItemsCount(), progressCallback);
        tracker.start();

        try {
            // 2. Offer & Preflight Negotiation over Session
            log.info("Sending TransferOffer [{}] to peer [{}]", transferId, remotePeerId);
            TransferOffer offer = TransferOffer.newBuilder()
                    .setManifest(manifest)
                    .setTimestampUtcMs(System.currentTimeMillis())
                    .build();

            CompletableFuture<TransferResponse> offerFuture = coordinator.registerPendingOffer(transferId);
            TransferWireMessage offerWire = TransferWireMessage.newBuilder().setOffer(offer).build();
            session.sendPayloadAsync(offerWire.toByteArray());

            TransferResponse response = offerFuture.get(DEFAULT_OFFER_TIMEOUT_MS, TimeUnit.MILLISECONDS);
            if (!response.getAccepted()) {
                tracker.fail("Transfer offer rejected: " + response.getRejectionReason());
                throw new PreflightException(
                        PreflightException.PreflightErrorCode.DESTINATION_UNAVAILABLE,
                        "Transfer offer rejected by receiver: " + response.getRejectionReason());
            }

            // 3. Chunks Transmission
            tracker.updateState(TransferState.TRANSFER_STATE_TRANSFERRING);
            int chunkSizeBytes = manifest.getChunkSizeBytes();
            byte[] buffer = new byte[chunkSizeBytes];

            for (int i = 0; i < manifest.getItemsCount(); i++) {
                if (tracker.isCancelled()) {
                    throw new IllegalStateException("Transfer cancelled during transmission: " + tracker.getCancelReason());
                }

                TransferItem item = manifest.getItems(i);
                tracker.setCurrentItem(i, item.getRelativePath());

                if (item.getIsDirectory()) {
                    continue;
                }

                Path sourceFile = findSourceFileForRelativePath(sourcePaths, item.getRelativePath());
                validateSourceFile(sourceFile, item);

                long fileSize = item.getFileSizeBytes();
                long offset = 0;
                long chunkIndex = 0;

                try (FileInputStream fis = new FileInputStream(sourceFile.toFile())) {
                    while (offset < fileSize) {
                        int toRead = (int) Math.min(chunkSizeBytes, fileSize - offset);
                        int read = fis.read(buffer, 0, toRead);
                        if (read <= 0) {
                            break;
                        }

                        byte[] chunkData = new byte[read];
                        System.arraycopy(buffer, 0, chunkData, 0, read);

                        bandwidthLimiter.consume(read);
                        boolean isLast = (offset + read >= fileSize);
                        String chunkSha = FileManifestBuilder.calculateSha256Hex(chunkData);

                        sendChunkWithRetry(transferId, i, chunkIndex, offset, chunkData, isLast, chunkSha);

                        offset += read;
                        chunkIndex++;
                        tracker.addBytes(read);
                    }
                }
            }

            // 4. Signal Commit to Receiver over Session
            log.info("All chunks sent for transfer [{}]. Signaling commit to peer [{}]", transferId, remotePeerId);
            TransferCommitSignal commit = TransferCommitSignal.newBuilder()
                    .setTransferId(transferId)
                    .setTimestampUtcMs(System.currentTimeMillis())
                    .build();

            CompletableFuture<TransferCompletedReceipt> receiptFuture = coordinator.registerPendingReceipt(transferId);
            TransferWireMessage commitWire = TransferWireMessage.newBuilder().setCommit(commit).build();
            session.sendPayloadAsync(commitWire.toByteArray());

            TransferCompletedReceipt receipt = receiptFuture.get(DEFAULT_COMMIT_TIMEOUT_MS, TimeUnit.MILLISECONDS);
            if (!receipt.getSuccess()) {
                tracker.fail(receipt.getErrorMessage());
                throw new IOException("Remote receiver reported transfer failure: " + receipt.getErrorMessage());
            }

            tracker.complete();
            log.info("Transfer [{}] completed successfully over session [{}]. Committed {} bytes.",
                    transferId, session.getSessionId().getValue(), receipt.getTotalBytesTransferred());
            return receipt;

        } catch (Exception e) {
            tracker.fail(e.getMessage());
            throw e;
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

            CompletableFuture<TransferChunkAck> ackFuture = coordinator.registerPendingChunkAck(
                    transferId, itemIndex, chunkIndex);

            TransferWireMessage chunkWire = TransferWireMessage.newBuilder().setChunk(chunk).build();
            session.sendPayloadAsync(chunkWire.toByteArray());

            try {
                TransferChunkAck ack = ackFuture.get(DEFAULT_CHUNK_TIMEOUT_MS, TimeUnit.MILLISECONDS);
                if (ack.getSuccess()) {
                    return;
                }

                log.warn("Chunk NACK received: item={}, chunk={}, attempt={}/{}, err={}",
                        itemIndex, chunkIndex, attempts, maxChunkRetries, ack.getErrorMessage());
            } catch (Exception e) {
                log.warn("Chunk timeout or send error: item={}, chunk={}, attempt={}/{}, msg={}",
                        itemIndex, chunkIndex, attempts, maxChunkRetries, e.getMessage());
            }

            if (attempts > maxChunkRetries) {
                throw new IOException("Failed to send chunk [" + itemIndex + ":" + chunkIndex +
                        "] after " + attempts + " attempts over session " + session.getSessionId().getValue());
            }

            // Brief backoff before retransmit
            Thread.sleep(50L * attempts);
        }
    }

    private Path findSourceFileForRelativePath(List<Path> sourcePaths, String relativePath) throws IOException {
        for (Path sp : sourcePaths) {
            if (Files.isRegularFile(sp)) {
                if (sp.getFileName().toString().equals(relativePath)) {
                    return sp;
                }
            } else if (Files.isDirectory(sp)) {
                Path candidate = sp.resolve(relativePath);
                if (Files.exists(candidate)) {
                    return candidate;
                }
            }
        }
        throw new IOException("Cannot locate source file for relative path: " + relativePath);
    }

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
}
