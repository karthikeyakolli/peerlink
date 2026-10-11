package org.peerlink.core.transfer;

import com.google.protobuf.InvalidProtocolBufferException;
import org.peerlink.protocol.v1.ChunkStatus;
import org.peerlink.protocol.v1.TransferCompletedReceipt;
import org.peerlink.protocol.v1.TransferManifest;
import org.peerlink.protocol.v1.TransferState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.*;

/**
 * Authoritative SQLite-backed durable implementation of {@link TransferSessionJournal}.
 * Persists transfer sessions, manifest blobs, chunk statuses, and completion receipts
 * consistent with SQLite WAL mode and the application transaction model.
 */
public class SqliteTransferSessionJournal implements TransferSessionJournal {

    private static final Logger log = LoggerFactory.getLogger(SqliteTransferSessionJournal.class);

    private final Connection connection;

    public SqliteTransferSessionJournal(Connection connection) throws SQLException {
        this.connection = Objects.requireNonNull(connection, "Database connection must not be null");
        initSchema();
    }

    private synchronized void initSchema() throws SQLException {
        try (Statement stmt = connection.createStatement()) {
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS transfer_sessions (
                    transfer_id          TEXT    PRIMARY KEY,
                    operation_id         TEXT    NOT NULL,
                    sender_peer_id       TEXT    NOT NULL,
                    receiver_peer_id     TEXT    NOT NULL,
                    state                TEXT    NOT NULL,
                    total_bytes          INTEGER NOT NULL,
                    transferred_bytes    INTEGER NOT NULL DEFAULT 0,
                    total_items          INTEGER NOT NULL,
                    manifest_blob        BLOB,
                    receipt_blob         BLOB,
                    staging_path         TEXT,
                    destination_path     TEXT,
                    retry_count          INTEGER NOT NULL DEFAULT 0,
                    failure_reason       TEXT,
                    created_at           INTEGER NOT NULL,
                    updated_at           INTEGER NOT NULL
                );
                """);

            stmt.execute("""
                CREATE INDEX IF NOT EXISTS idx_transfer_sessions_op_id
                    ON transfer_sessions(operation_id);
                """);

            stmt.execute("""
                CREATE INDEX IF NOT EXISTS idx_transfer_sessions_state
                    ON transfer_sessions(state);
                """);

            stmt.execute("""
                CREATE TABLE IF NOT EXISTS transfer_chunks (
                    transfer_id          TEXT    NOT NULL,
                    item_index           INTEGER NOT NULL,
                    chunk_index          INTEGER NOT NULL,
                    offset_bytes         INTEGER NOT NULL DEFAULT 0,
                    chunk_size_bytes     INTEGER NOT NULL DEFAULT 0,
                    chunk_sha256         TEXT    NOT NULL DEFAULT '',
                    status               TEXT    NOT NULL,
                    updated_at           INTEGER NOT NULL,
                    PRIMARY KEY (transfer_id, item_index, chunk_index)
                );
                """);

            ensureColumnExists(stmt, "transfer_sessions", "staging_path", "TEXT");
            ensureColumnExists(stmt, "transfer_sessions", "destination_path", "TEXT");
            ensureColumnExists(stmt, "transfer_sessions", "retry_count", "INTEGER NOT NULL DEFAULT 0");
            ensureColumnExists(stmt, "transfer_chunks", "offset_bytes", "INTEGER NOT NULL DEFAULT 0");
            ensureColumnExists(stmt, "transfer_chunks", "chunk_size_bytes", "INTEGER NOT NULL DEFAULT 0");
            ensureColumnExists(stmt, "transfer_chunks", "chunk_sha256", "TEXT NOT NULL DEFAULT ''");
        }
    }

    private static void ensureColumnExists(Statement stmt, String table, String column, String definition) {
        try {
            stmt.execute("ALTER TABLE " + table + " ADD COLUMN " + column + " " + definition + ";");
        } catch (SQLException ignored) {
            // Column already exists
        }
    }

    @Override
    public synchronized void recordSession(TransferSessionRecord session) {
        String sql = """
            INSERT INTO transfer_sessions (
                transfer_id, operation_id, sender_peer_id, receiver_peer_id, state,
                total_bytes, transferred_bytes, total_items, manifest_blob, receipt_blob,
                failure_reason, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(transfer_id) DO UPDATE SET
                state = excluded.state,
                transferred_bytes = excluded.transferred_bytes,
                manifest_blob = COALESCE(excluded.manifest_blob, transfer_sessions.manifest_blob),
                receipt_blob = COALESCE(excluded.receipt_blob, transfer_sessions.receipt_blob),
                failure_reason = excluded.failure_reason,
                updated_at = excluded.updated_at;
            """;

        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setString(1, session.getTransferId());
            stmt.setString(2, session.getOperationId());
            stmt.setString(3, session.getSenderPeerId());
            stmt.setString(4, session.getReceiverPeerId());
            stmt.setString(5, session.getState().name());
            stmt.setLong(6, session.getTotalBytes());
            stmt.setLong(7, session.getTransferredBytes());
            stmt.setInt(8, session.getTotalItems());

            byte[] manifestBytes = session.getManifest() != null ? session.getManifest().toByteArray() : null;
            stmt.setBytes(9, manifestBytes);

            byte[] receiptBytes = session.getReceipt() != null ? session.getReceipt().toByteArray() : null;
            stmt.setBytes(10, receiptBytes);

            stmt.setString(11, session.getFailureReason());
            stmt.setLong(12, session.getCreatedAt());
            stmt.setLong(13, session.getUpdatedAt());

            stmt.executeUpdate();

            // Save any existing chunk states
            for (Map.Entry<String, ChunkStatus> entry : session.getChunkStates().entrySet()) {
                String[] parts = entry.getKey().split(":");
                if (parts.length == 2) {
                    try {
                        int itemIndex = Integer.parseInt(parts[0]);
                        long chunkIndex = Long.parseLong(parts[1]);
                        updateChunkStatus(session.getTransferId(), itemIndex, chunkIndex, entry.getValue());
                    } catch (NumberFormatException ignored) {}
                }
            }
        } catch (SQLException e) {
            log.error("Failed to record transfer session {}: {}", session.getTransferId(), e.getMessage(), e);
            throw new RuntimeException("Database error recording transfer session: " + e.getMessage(), e);
        }
    }

    @Override
    public synchronized Optional<TransferSessionRecord> getSession(String transferId) {
        String sql = "SELECT * FROM transfer_sessions WHERE transfer_id = ?";
        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setString(1, transferId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapSessionRecord(rs));
                }
            }
        } catch (SQLException e) {
            log.error("Failed to query transfer session {}: {}", transferId, e.getMessage(), e);
            throw new RuntimeException("Database error querying transfer session: " + e.getMessage(), e);
        }
        return Optional.empty();
    }

    @Override
    public synchronized Optional<TransferSessionRecord> getSessionByOperationId(String operationId) {
        String sql = "SELECT * FROM transfer_sessions WHERE operation_id = ?";
        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setString(1, operationId);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapSessionRecord(rs));
                }
            }
        } catch (SQLException e) {
            log.error("Failed to query transfer session by opId {}: {}", operationId, e.getMessage(), e);
            throw new RuntimeException("Database error querying transfer session by opId: " + e.getMessage(), e);
        }
        return Optional.empty();
    }

    @Override
    public synchronized void updateSessionState(String transferId, TransferState state) {
        String sql = "UPDATE transfer_sessions SET state = ?, updated_at = ? WHERE transfer_id = ?";
        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setString(1, state.name());
            stmt.setLong(2, System.currentTimeMillis());
            stmt.setString(3, transferId);
            stmt.executeUpdate();
        } catch (SQLException e) {
            log.error("Failed to update session state for {}: {}", transferId, e.getMessage(), e);
            throw new RuntimeException("Database error updating session state: " + e.getMessage(), e);
        }
    }

    @Override
    public synchronized void updateChunkStatus(String transferId, int itemIndex, long chunkIndex, ChunkStatus status) {
        updateChunkMetadata(transferId, itemIndex, chunkIndex, 0, 0, "", status);
    }

    @Override
    public synchronized void updateChunkMetadata(String transferId, int itemIndex, long chunkIndex,
                                                 long offsetBytes, int sizeBytes, String sha256, ChunkStatus status) {
        String sql = """
            INSERT INTO transfer_chunks (transfer_id, item_index, chunk_index, offset_bytes, chunk_size_bytes, chunk_sha256, status, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(transfer_id, item_index, chunk_index) DO UPDATE SET
                offset_bytes = CASE WHEN excluded.offset_bytes > 0 THEN excluded.offset_bytes ELSE transfer_chunks.offset_bytes END,
                chunk_size_bytes = CASE WHEN excluded.chunk_size_bytes > 0 THEN excluded.chunk_size_bytes ELSE transfer_chunks.chunk_size_bytes END,
                chunk_sha256 = CASE WHEN excluded.chunk_sha256 != '' THEN excluded.chunk_sha256 ELSE transfer_chunks.chunk_sha256 END,
                status = excluded.status,
                updated_at = excluded.updated_at;
            """;

        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setString(1, transferId);
            stmt.setInt(2, itemIndex);
            stmt.setLong(3, chunkIndex);
            stmt.setLong(4, offsetBytes);
            stmt.setInt(5, sizeBytes);
            stmt.setString(6, sha256 != null ? sha256 : "");
            stmt.setString(7, status.name());
            stmt.setLong(8, System.currentTimeMillis());
            stmt.executeUpdate();
        } catch (SQLException e) {
            log.error("Failed to update chunk metadata [{}:{}:{}] to {}: {}",
                    transferId, itemIndex, chunkIndex, status, e.getMessage(), e);
            throw new RuntimeException("Database error updating chunk metadata: " + e.getMessage(), e);
        }
    }

    @Override
    public synchronized Set<Long> getAckedChunks(String transferId, int itemIndex) {
        String sql = "SELECT chunk_index FROM transfer_chunks WHERE transfer_id = ? AND item_index = ? AND status = ?";
        Set<Long> acked = new TreeSet<>();
        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setString(1, transferId);
            stmt.setInt(2, itemIndex);
            stmt.setString(3, ChunkStatus.CHUNK_STATUS_ACKED.name());
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    acked.add(rs.getLong("chunk_index"));
                }
            }
        } catch (SQLException e) {
            log.error("Failed to query acked chunks for [{}:{}]: {}", transferId, itemIndex, e.getMessage(), e);
            throw new RuntimeException("Database error querying acked chunks: " + e.getMessage(), e);
        }
        return acked;
    }

    @Override
    public synchronized void recordReceipt(String transferId, TransferCompletedReceipt receipt) {
        String sql = """
            UPDATE transfer_sessions SET
                receipt_blob = ?,
                state = ?,
                transferred_bytes = ?,
                updated_at = ?
            WHERE transfer_id = ?;
            """;

        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            stmt.setBytes(1, receipt.toByteArray());
            stmt.setString(2, TransferState.TRANSFER_STATE_COMPLETED.name());
            stmt.setLong(3, receipt.getTotalBytesTransferred());
            stmt.setLong(4, System.currentTimeMillis());
            stmt.setString(5, transferId);
            stmt.executeUpdate();
        } catch (SQLException e) {
            log.error("Failed to record completion receipt for {}: {}", transferId, e.getMessage(), e);
            throw new RuntimeException("Database error recording completion receipt: " + e.getMessage(), e);
        }
    }

    @Override
    public synchronized List<TransferSessionRecord> getActiveSessions() {
        String sql = """
            SELECT * FROM transfer_sessions
            WHERE state IN (
                'TRANSFER_STATE_TRANSFERRING',
                'TRANSFER_STATE_PREPARING',
                'TRANSFER_STATE_CONNECTING',
                'TRANSFER_STATE_VERIFYING',
                'TRANSFER_STATE_COMMITTING'
            )
            ORDER BY created_at DESC;
            """;

        List<TransferSessionRecord> list = new ArrayList<>();
        try (PreparedStatement stmt = connection.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                list.add(mapSessionRecord(rs));
            }
        } catch (SQLException e) {
            log.error("Failed to list active transfer sessions: {}", e.getMessage(), e);
            throw new RuntimeException("Database error listing active transfer sessions", e);
        }
        return list;
    }

    @Override
    public synchronized List<TransferSessionRecord> getIncompleteSessions() {
        String sql = """
            SELECT * FROM transfer_sessions
            WHERE state NOT IN (
                'TRANSFER_STATE_COMPLETED',
                'TRANSFER_STATE_CANCELLED',
                'TRANSFER_STATE_FAILED'
            )
            ORDER BY created_at DESC;
            """;

        List<TransferSessionRecord> list = new ArrayList<>();
        try (PreparedStatement stmt = connection.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                list.add(mapSessionRecord(rs));
            }
        } catch (SQLException e) {
            log.error("Failed to list incomplete transfer sessions: {}", e.getMessage(), e);
            throw new RuntimeException("Database error listing incomplete transfer sessions", e);
        }
        return list;
    }

    @Override
    public synchronized void removeSession(String transferId) {
        try {
            boolean autoCommit = connection.getAutoCommit();
            connection.setAutoCommit(false);
            try {
                try (PreparedStatement stmt = connection.prepareStatement("DELETE FROM transfer_chunks WHERE transfer_id = ?")) {
                    stmt.setString(1, transferId);
                    stmt.executeUpdate();
                }
                try (PreparedStatement stmt = connection.prepareStatement("DELETE FROM transfer_sessions WHERE transfer_id = ?")) {
                    stmt.setString(1, transferId);
                    stmt.executeUpdate();
                }
                connection.commit();
            } catch (SQLException ex) {
                connection.rollback();
                throw ex;
            } finally {
                connection.setAutoCommit(autoCommit);
            }
        } catch (SQLException e) {
            log.error("Failed to remove transfer session {}: {}", transferId, e.getMessage(), e);
            throw new RuntimeException("Database error removing transfer session", e);
        }
    }

    private TransferSessionRecord mapSessionRecord(ResultSet rs) throws SQLException {
        String transferId = rs.getString("transfer_id");
        String opId = rs.getString("operation_id");
        String senderPeerId = rs.getString("sender_peer_id");
        String receiverPeerId = rs.getString("receiver_peer_id");
        String stateStr = rs.getString("state");
        long totalBytes = rs.getLong("total_bytes");
        long transferredBytes = rs.getLong("transferred_bytes");
        int totalItems = rs.getInt("total_items");
        long createdAt = rs.getLong("created_at");

        TransferState state;
        try {
            state = TransferState.valueOf(stateStr);
        } catch (IllegalArgumentException e) {
            state = TransferState.TRANSFER_STATE_UNSPECIFIED;
        }

        TransferSessionRecord record = new TransferSessionRecord(
                transferId, opId, senderPeerId, receiverPeerId, state, totalBytes, totalItems, createdAt);
        record.setTransferredBytes(transferredBytes);
        record.setFailureReason(rs.getString("failure_reason"));

        byte[] manifestBlob = rs.getBytes("manifest_blob");
        if (manifestBlob != null && manifestBlob.length > 0) {
            try {
                record.setManifest(TransferManifest.parseFrom(manifestBlob));
            } catch (InvalidProtocolBufferException e) {
                log.warn("Corrupt manifest blob in session {}: {}", transferId, e.getMessage());
            }
        }

        byte[] receiptBlob = rs.getBytes("receipt_blob");
        if (receiptBlob != null && receiptBlob.length > 0) {
            try {
                record.setReceipt(TransferCompletedReceipt.parseFrom(receiptBlob));
            } catch (InvalidProtocolBufferException e) {
                log.warn("Corrupt receipt blob in session {}: {}", transferId, e.getMessage());
            }
        }

        // Load chunk states
        String chunksSql = "SELECT item_index, chunk_index, status FROM transfer_chunks WHERE transfer_id = ?";
        try (PreparedStatement chunkStmt = connection.prepareStatement(chunksSql)) {
            chunkStmt.setString(1, transferId);
            try (ResultSet chunkRs = chunkStmt.executeQuery()) {
                while (chunkRs.next()) {
                    int itemIdx = chunkRs.getInt("item_index");
                    long chunkIdx = chunkRs.getLong("chunk_index");
                    String statusStr = chunkRs.getString("status");
                    try {
                        record.setChunkStatus(itemIdx, chunkIdx, ChunkStatus.valueOf(statusStr));
                    } catch (IllegalArgumentException ignored) {}
                }
            }
        }

        return record;
    }
}
