package org.peerlink.core.transfer;

import org.peerlink.protocol.v1.ChunkStatus;
import org.peerlink.protocol.v1.TransferCompletedReceipt;
import org.peerlink.protocol.v1.TransferState;

import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Journal interface for durable persistence of transfer sessions, manifests, chunk statuses, and receipts.
 */
public interface TransferSessionJournal {
    /**
     * Record a new transfer session.
     */
    void recordSession(TransferSessionRecord session);

    /**
     * Get a transfer session by transfer ID.
     */
    Optional<TransferSessionRecord> getSession(String transferId);

    /**
     * Get a transfer session by operation ID.
     */
    Optional<TransferSessionRecord> getSessionByOperationId(String operationId);

    /**
     * Update the transfer state of an existing session.
     */
    void updateSessionState(String transferId, TransferState state);

    /**
     * Update status of an individual chunk.
     */
    void updateChunkStatus(String transferId, int itemIndex, long chunkIndex, ChunkStatus status);

    /**
     * Get the set of ACKed chunk indices for a specific item index.
     */
    Set<Long> getAckedChunks(String transferId, int itemIndex);

    /**
     * Store the completion receipt for a successfully committed transfer.
     */
    void recordReceipt(String transferId, TransferCompletedReceipt receipt);

    /**
     * Retrieve all active transfer sessions.
     */
    List<TransferSessionRecord> getActiveSessions();

    /**
     * Retrieve all incomplete or pending transfer sessions (e.g. for startup recovery).
     */
    List<TransferSessionRecord> getIncompleteSessions();

    /**
     * Delete or purge a transfer session record.
     */
    void removeSession(String transferId);
}
