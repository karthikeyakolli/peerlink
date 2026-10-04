package org.peerlink.core.transfer;

import org.peerlink.protocol.v1.ChunkStatus;
import org.peerlink.protocol.v1.TransferCompletedReceipt;
import org.peerlink.protocol.v1.TransferManifest;
import org.peerlink.protocol.v1.TransferState;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Durable record of an active, paused, or completed transfer session.
 */
public final class TransferSessionRecord {
    private final String transferId;
    private final String operationId;
    private final String senderPeerId;
    private final String receiverPeerId;
    private volatile TransferState state;
    private final long totalBytes;
    private volatile long transferredBytes;
    private final int totalItems;
    private final Map<String, ChunkStatus> chunkStates = new ConcurrentHashMap<>();
    private volatile TransferManifest manifest;
    private volatile TransferCompletedReceipt receipt;
    private final long createdAt;
    private volatile long updatedAt;
    private volatile String failureReason;

    public TransferSessionRecord(
            String transferId,
            String operationId,
            String senderPeerId,
            String receiverPeerId,
            TransferState state,
            long totalBytes,
            int totalItems,
            long createdAt) {
        this.transferId = transferId;
        this.operationId = operationId;
        this.senderPeerId = senderPeerId;
        this.receiverPeerId = receiverPeerId;
        this.state = state;
        this.totalBytes = totalBytes;
        this.transferredBytes = 0;
        this.totalItems = totalItems;
        this.createdAt = createdAt;
        this.updatedAt = createdAt;
    }

    public String getTransferId() {
        return transferId;
    }

    public String getOperationId() {
        return operationId;
    }

    public String getSenderPeerId() {
        return senderPeerId;
    }

    public String getReceiverPeerId() {
        return receiverPeerId;
    }

    public TransferState getState() {
        return state;
    }

    public void setState(TransferState state) {
        this.state = state;
        this.updatedAt = System.currentTimeMillis();
    }

    public long getTotalBytes() {
        return totalBytes;
    }

    public long getTransferredBytes() {
        return transferredBytes;
    }

    public void setTransferredBytes(long transferredBytes) {
        this.transferredBytes = transferredBytes;
        this.updatedAt = System.currentTimeMillis();
    }

    public void addTransferredBytes(long bytes) {
        this.transferredBytes += bytes;
        this.updatedAt = System.currentTimeMillis();
    }

    public int getTotalItems() {
        return totalItems;
    }

    public Map<String, ChunkStatus> getChunkStates() {
        return Collections.unmodifiableMap(chunkStates);
    }

    public void setChunkStatus(int itemIndex, long chunkIndex, ChunkStatus status) {
        chunkStates.put(itemIndex + ":" + chunkIndex, status);
        this.updatedAt = System.currentTimeMillis();
    }

    public ChunkStatus getChunkStatus(int itemIndex, long chunkIndex) {
        return chunkStates.getOrDefault(itemIndex + ":" + chunkIndex, ChunkStatus.CHUNK_STATUS_PENDING);
    }

    public Set<Long> getAckedChunkIndices(int itemIndex) {
        Set<Long> acked = new TreeSet<>();
        String prefix = itemIndex + ":";
        for (Map.Entry<String, ChunkStatus> entry : chunkStates.entrySet()) {
            if (entry.getKey().startsWith(prefix) && entry.getValue() == ChunkStatus.CHUNK_STATUS_ACKED) {
                try {
                    acked.add(Long.parseLong(entry.getKey().substring(prefix.length())));
                } catch (NumberFormatException ignored) {}
            }
        }
        return acked;
    }

    public TransferManifest getManifest() {
        return manifest;
    }

    public void setManifest(TransferManifest manifest) {
        this.manifest = manifest;
        this.updatedAt = System.currentTimeMillis();
    }

    public TransferCompletedReceipt getReceipt() {
        return receipt;
    }

    public void setReceipt(TransferCompletedReceipt receipt) {
        this.receipt = receipt;
        this.updatedAt = System.currentTimeMillis();
    }

    public long getCreatedAt() {
        return createdAt;
    }

    public long getUpdatedAt() {
        return updatedAt;
    }

    public String getFailureReason() {
        return failureReason;
    }

    public void setFailureReason(String failureReason) {
        this.failureReason = failureReason;
        this.updatedAt = System.currentTimeMillis();
    }
}
