package org.peerlink.core.transfer;

import org.peerlink.protocol.v1.ChunkStatus;
import org.peerlink.protocol.v1.TransferCompletedReceipt;
import org.peerlink.protocol.v1.TransferState;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Thread-safe in-memory implementation of TransferSessionJournal.
 */
public class InMemoryTransferSessionJournal implements TransferSessionJournal {
    private final Map<String, TransferSessionRecord> sessionsByTransferId = new ConcurrentHashMap<>();
    private final Map<String, String> transferIdByOpId = new ConcurrentHashMap<>();

    @Override
    public void recordSession(TransferSessionRecord session) {
        sessionsByTransferId.put(session.getTransferId(), session);
        transferIdByOpId.put(session.getOperationId(), session.getTransferId());
    }

    @Override
    public Optional<TransferSessionRecord> getSession(String transferId) {
        return Optional.ofNullable(sessionsByTransferId.get(transferId));
    }

    @Override
    public Optional<TransferSessionRecord> getSessionByOperationId(String operationId) {
        String transferId = transferIdByOpId.get(operationId);
        if (transferId == null) {
            return Optional.empty();
        }
        return getSession(transferId);
    }

    @Override
    public void updateSessionState(String transferId, TransferState state) {
        TransferSessionRecord session = sessionsByTransferId.get(transferId);
        if (session != null) {
            session.setState(state);
        }
    }

    @Override
    public void updateChunkStatus(String transferId, int itemIndex, long chunkIndex, ChunkStatus status) {
        TransferSessionRecord session = sessionsByTransferId.get(transferId);
        if (session != null) {
            session.setChunkStatus(itemIndex, chunkIndex, status);
        }
    }

    @Override
    public Set<Long> getAckedChunks(String transferId, int itemIndex) {
        TransferSessionRecord session = sessionsByTransferId.get(transferId);
        if (session != null) {
            return session.getAckedChunkIndices(itemIndex);
        }
        return Collections.emptySet();
    }

    @Override
    public void recordReceipt(String transferId, TransferCompletedReceipt receipt) {
        TransferSessionRecord session = sessionsByTransferId.get(transferId);
        if (session != null) {
            session.setReceipt(receipt);
            session.setState(TransferState.TRANSFER_STATE_COMPLETED);
        }
    }

    @Override
    public List<TransferSessionRecord> getActiveSessions() {
        return sessionsByTransferId.values().stream()
                .filter(s -> s.getState() == TransferState.TRANSFER_STATE_TRANSFERRING ||
                             s.getState() == TransferState.TRANSFER_STATE_PREPARING ||
                             s.getState() == TransferState.TRANSFER_STATE_CONNECTING ||
                             s.getState() == TransferState.TRANSFER_STATE_VERIFYING ||
                             s.getState() == TransferState.TRANSFER_STATE_COMMITTING)
                .toList();
    }

    @Override
    public List<TransferSessionRecord> getIncompleteSessions() {
        return sessionsByTransferId.values().stream()
                .filter(s -> s.getState() != TransferState.TRANSFER_STATE_COMPLETED &&
                             s.getState() != TransferState.TRANSFER_STATE_CANCELLED &&
                             s.getState() != TransferState.TRANSFER_STATE_FAILED)
                .toList();
    }

    @Override
    public void removeSession(String transferId) {
        TransferSessionRecord removed = sessionsByTransferId.remove(transferId);
        if (removed != null) {
            transferIdByOpId.remove(removed.getOperationId());
        }
    }
}
