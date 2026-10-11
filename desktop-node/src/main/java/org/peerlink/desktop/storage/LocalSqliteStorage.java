package org.peerlink.desktop.storage;

import org.peerlink.core.operation.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;

/**
 * SQLite-backed authoritative Local Node storage.
 *
 * <p>This class owns the JDBC connection, applies schema migrations on open,
 * and implements {@link OperationJournal} with full Phase 05 semantics:
 * <ul>
 *   <li>WAL mode with NORMAL synchronous — crash-safe, concurrent-read-friendly.</li>
 *   <li>Foreign-key enforcement enabled.</li>
 *   <li>Idempotency key uniqueness enforced at the database level (unique index).</li>
 *   <li>Terminal-state guard: a terminal state cannot be overwritten by a non-terminal
 *       state at the SQL layer via a conditional UPDATE.</li>
 *   <li>{@link #markInterruptedOperationsUnknown} is called during startup recovery
 *       to prevent blind replay of uncertain work.</li>
 * </ul>
 *
 * <p>Thread safety: all public methods are {@code synchronized} on the instance.
 * For the Phase 05 scope a single-connection single-lock model is correct and
 * simple. Concurrent readers may be added later using a connection pool.
 *
 * <p>Invariant: actual file bytes are <b>never</b> stored in SQLite. Only
 * metadata, operation journal, and index state live here.
 */
public final class LocalSqliteStorage implements OperationJournal, org.peerlink.core.transfer.TransferSessionJournal, org.peerlink.core.identity.IdentityMetadataStore, Closeable {
    private static final Logger log = LoggerFactory.getLogger(LocalSqliteStorage.class);

    private final Connection connection;
    private final Path dbPath;
    private final DatabaseMigrationManager migrations = new DatabaseMigrationManager();
    private final ObjectIndexRepository objectIndex;
    private final org.peerlink.core.transfer.SqliteTransferSessionJournal transferJournal;

    // ──────────────────────────────────────────────────────────────────────────
    // Construction & initialization
    // ──────────────────────────────────────────────────────────────────────────

    public LocalSqliteStorage(Path dbPath) throws SQLException {
        this.dbPath = ensureParentDir(dbPath);

        String url = "jdbc:sqlite:" + dbPath.toAbsolutePath();
        this.connection = DriverManager.getConnection(url);
        initPragmas();
        migrations.applyMigrations(connection);
        this.objectIndex = new ObjectIndexRepository(this.connection, this);
        this.transferJournal = new org.peerlink.core.transfer.SqliteTransferSessionJournal(this.connection);
        log.info("LocalSqliteStorage ready at {} (schema v{})",
                dbPath, DatabaseMigrationManager.CURRENT_SCHEMA_VERSION);
    }

    // Wrap IOException from Files.createDirectories — callers only expect SQLException
    // Constructor is used in synchronized context; runtime is acceptable here.
    private static Path ensureParentDir(Path dbPath) {
        try {
            if (dbPath.getParent() != null) {
                Files.createDirectories(dbPath.getParent());
            }
        } catch (Exception e) {
            throw new RuntimeException("Cannot create database directory: " + dbPath.getParent(), e);
        }
        return dbPath;
    }

    private void initPragmas() throws SQLException {
        try (Statement stmt = connection.createStatement()) {
            stmt.execute("PRAGMA journal_mode = WAL;");
            stmt.execute("PRAGMA synchronous = NORMAL;");
            stmt.execute("PRAGMA foreign_keys = ON;");
            stmt.execute("PRAGMA temp_store = MEMORY;");
            stmt.execute("PRAGMA cache_size = -8000;"); // 8 MB page cache
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // OperationJournal — write operations
    // ──────────────────────────────────────────────────────────────────────────

    @Override
    public synchronized void recordOperation(OperationRecord record) {
        // Check for duplicate idempotency key first
        Optional<String> existing = findOperationByIdempotencyKey(record.getIdempotencyKey());
        if (existing.isPresent() && !existing.get().equals(record.getOperationId())) {
            throw new DuplicateOperationException(record.getIdempotencyKey(), existing.get());
        }

        String sql = """
            INSERT INTO operations
                (operation_id, intent, actor_peer_id, target_object_ids, state, journal_stage,
                 idempotency_key, created_at, updated_at, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '')
            ON CONFLICT(operation_id) DO NOTHING;
            """;
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, record.getOperationId());
            pstmt.setString(2, record.getIntent().name());
            pstmt.setString(3, record.getActorPeerId());
            pstmt.setString(4, String.join(",", record.getTargetObjectIds()));
            pstmt.setString(5, record.getState().name());
            pstmt.setString(6, JournalStage.INTENT.name());
            pstmt.setString(7, record.getIdempotencyKey());
            pstmt.setLong(8, record.getCreatedAtUtcMs());
            pstmt.setLong(9, record.getUpdatedAtUtcMs());
            pstmt.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record operation: " + record.getOperationId(), e);
        }
    }

    @Override
    public synchronized void updateState(String operationId, OperationState newState) {
        // Only allow overwrite if current state is non-terminal, OR if new state is
        // OUTCOME_UNKNOWN / RECOVERY_REQUIRED (which can overwrite EXECUTING on crash).
        String sql;
        if (newState == OperationState.OUTCOME_UNKNOWN || newState == OperationState.RECOVERY_REQUIRED) {
            // These transitions are always allowed — they represent crash handling
            sql = "UPDATE operations SET state = ?, updated_at = ? WHERE operation_id = ?";
        } else if (newState.isTerminal()) {
            // Terminal → terminal: allow only if currently non-terminal
            sql = "UPDATE operations SET state = ?, updated_at = ? WHERE operation_id = ? AND state NOT IN "
                    + terminalStateList();
        } else {
            // Non-terminal: only advance from non-terminal states
            sql = "UPDATE operations SET state = ?, updated_at = ? WHERE operation_id = ? AND state NOT IN "
                    + terminalStateList();
        }

        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, newState.name());
            pstmt.setLong(2, System.currentTimeMillis());
            pstmt.setString(3, operationId);
            int rows = pstmt.executeUpdate();
            if (rows == 0) {
                // Either not found or terminal guard blocked it — check which
                Optional<OperationRecord> existing = getOperation(operationId);
                if (existing.isEmpty()) {
                    log.warn("updateState: operation not found [{}]", operationId);
                } else {
                    throw new IllegalStateTransitionException(operationId, existing.get().getState(), newState);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update operation state: " + operationId, e);
        }
    }

    @Override
    public synchronized void recordJournalStage(String operationId, JournalStage stage) {
        String sql = "UPDATE operations SET journal_stage = ?, updated_at = ? WHERE operation_id = ?";
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, stage.name());
            pstmt.setLong(2, System.currentTimeMillis());
            pstmt.setString(3, operationId);
            pstmt.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record journal stage for: " + operationId, e);
        }
    }

    @Override
    public synchronized void appendNote(String operationId, String note) {
        // Notes are appended with a timestamp prefix and separated by newlines
        String timestamp = java.time.Instant.now().toString();
        String entry = "[" + timestamp + "] " + note;
        String sql = """
            UPDATE operations
            SET notes = CASE WHEN notes = '' THEN ? ELSE notes || char(10) || ? END,
                updated_at = ?
            WHERE operation_id = ?
            """;
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, entry);
            pstmt.setString(2, entry);
            pstmt.setLong(3, System.currentTimeMillis());
            pstmt.setString(4, operationId);
            pstmt.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to append note to operation: " + operationId, e);
        }
    }

    @Override
    public synchronized void markInterruptedOperationsUnknown(String reason) {
        // Operations in EXECUTING state when the process died have an uncertain outcome
        long now = System.currentTimeMillis();
        String note = "Process restart: " + reason;

        // First, capture interrupted_at timestamp
        String markInterrupted = """
            UPDATE operations
            SET state = 'OUTCOME_UNKNOWN',
                interrupted_at = ?,
                updated_at = ?
            WHERE state = 'EXECUTING'
            """;
        try (PreparedStatement pstmt = connection.prepareStatement(markInterrupted)) {
            pstmt.setLong(1, now);
            pstmt.setLong(2, now);
            int rows = pstmt.executeUpdate();
            if (rows > 0) {
                log.warn("Marked {} EXECUTING operation(s) as OUTCOME_UNKNOWN on restart: {}", rows, reason);
                // Append a note to each
                String appendNote = """
                    UPDATE operations
                    SET notes = CASE WHEN notes = '' THEN ? ELSE notes || char(10) || ? END
                    WHERE state = 'OUTCOME_UNKNOWN' AND interrupted_at = ?
                    """;
                try (PreparedStatement notePstmt = connection.prepareStatement(appendNote)) {
                    String entry = "[" + java.time.Instant.ofEpochMilli(now) + "] " + note;
                    notePstmt.setString(1, entry);
                    notePstmt.setString(2, entry);
                    notePstmt.setLong(3, now);
                    notePstmt.executeUpdate();
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to mark interrupted operations unknown", e);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // OperationJournal — read operations
    // ──────────────────────────────────────────────────────────────────────────

    @Override
    public synchronized Optional<OperationRecord> getOperation(String operationId) {
        String sql = "SELECT * FROM operations WHERE operation_id = ?";
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, operationId);
            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapResultSet(rs));
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query operation: " + operationId, e);
        }
        return Optional.empty();
    }

    @Override
    public synchronized List<OperationRecord> listIncompleteOperations() {
        return queryOperationsByStates(
                "state NOT IN " + terminalStateList()
        );
    }

    @Override
    public synchronized List<OperationRecord> listInterruptedOperations() {
        return queryOperationsByStates("state = 'EXECUTING'");
    }

    @Override
    public synchronized List<OperationRecord> listUnknownOutcomeOperations() {
        return queryOperationsByStates("state = 'OUTCOME_UNKNOWN'");
    }

    @Override
    public synchronized Optional<String> findOperationByIdempotencyKey(String idempotencyKey) {
        String sql = "SELECT operation_id FROM operations WHERE idempotency_key = ? LIMIT 1";
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, idempotencyKey);
            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(rs.getString("operation_id"));
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query by idempotency key: " + idempotencyKey, e);
        }
        return Optional.empty();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Node metadata
    // ──────────────────────────────────────────────────────────────────────────

    public synchronized void setMetadata(String key, String value) {
        String sql = "INSERT OR REPLACE INTO node_metadata (key, value) VALUES (?, ?)";
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, key);
            pstmt.setString(2, value);
            pstmt.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to set metadata key: " + key, e);
        }
    }

    public synchronized Optional<String> getMetadata(String key) {
        String sql = "SELECT value FROM node_metadata WHERE key = ?";
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, key);
            try (ResultSet rs = pstmt.executeQuery()) {
                if (rs.next()) return Optional.of(rs.getString("value"));
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to get metadata key: " + key, e);
        }
        return Optional.empty();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Integrity
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Run SQLite PRAGMA integrity_check. Returns true if the database passes.
     */
    public synchronized boolean checkIntegrity() throws SQLException {
        List<String> result = migrations.runIntegrityCheck(connection);
        boolean healthy = migrations.isHealthy(result);
        if (!healthy) {
            log.error("SQLite integrity_check FAILED for {}: {}", dbPath, result);
        }
        return healthy;
    }

    /**
     * Returns the current database schema version.
     */
    public synchronized int schemaVersion() throws SQLException {
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COALESCE(MAX(version), 0) FROM schema_version")) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    /**
     * Returns the approximate database file size in bytes.
     */
    public long databaseFileSizeBytes() {
        try { return Files.size(dbPath); } catch (Exception e) { return -1L; }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Accessors
    // ──────────────────────────────────────────────────────────────────────────

    /** Returns the filesystem path to the SQLite database file. */
    public Path databasePath() {
        return dbPath;
    }

    /** Returns the object index repository instance. */
    public ObjectIndexRepository getObjectIndex() {
        return objectIndex;
    }

    /** Returns the raw SQLite JDBC connection. */
    public Connection getConnection() {
        return connection;
    }

    /** Returns the total count of recorded operations in the journal. */
    public synchronized int countTotalOperations() {
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM operations")) {
            return rs.next() ? rs.getInt(1) : 0;
        } catch (SQLException e) {
            throw new RuntimeException("Failed to count total operations", e);
        }
    }

    /** Returns the count of active (non-terminal) operations. */
    public synchronized int countOpenOperations() {
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM operations WHERE state NOT IN " + terminalStateList())) {
            return rs.next() ? rs.getInt(1) : 0;
        } catch (SQLException e) {
            throw new RuntimeException("Failed to count open operations", e);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ──────────────────────────────────────────────────────────────────────────

    @Override
    public synchronized void close() {
        try {
            if (connection != null && !connection.isClosed()) {
                // Checkpoint WAL before closing — merge changes into main db file
                try (Statement stmt = connection.createStatement()) {
                    stmt.execute("PRAGMA wal_checkpoint(TRUNCATE);");
                }
                connection.close();
                log.info("LocalSqliteStorage closed cleanly: {}", dbPath);
            }
        } catch (SQLException e) {
            log.warn("Failed to close SQLite connection cleanly: {}", e.getMessage(), e);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ──────────────────────────────────────────────────────────────────────────

    private List<OperationRecord> queryOperationsByStates(String whereClause) {
        List<OperationRecord> list = new ArrayList<>();
        String sql = "SELECT * FROM operations WHERE " + whereClause + " ORDER BY created_at ASC";
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                list.add(mapResultSet(rs));
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to list operations [" + whereClause + "]", e);
        }
        return list;
    }

    private OperationRecord mapResultSet(ResultSet rs) throws SQLException {
        String targets = rs.getString("target_object_ids");
        List<String> targetList = (targets == null || targets.isEmpty())
                ? List.of()
                : Arrays.asList(targets.split(","));
        return new OperationRecord(
                rs.getString("operation_id"),
                OperationIntent.valueOf(rs.getString("intent")),
                rs.getString("actor_peer_id"),
                targetList,
                OperationState.valueOf(rs.getString("state")),
                rs.getString("idempotency_key"),
                rs.getLong("created_at"),
                rs.getLong("updated_at")
        );
    }

    /**
     * Returns the SQL IN-list literal for all terminal states.
     * Kept in sync with {@link OperationState#isTerminal()}.
     */
    private static String terminalStateList() {
        return "('COMMITTED','FAILED','CANCELLED','OUTCOME_UNKNOWN','RECOVERY_REQUIRED')";
    }

    // ──────────────────────────────────────────────────────────────────────────
    // IdentityMetadataStore implementation
    // ──────────────────────────────────────────────────────────────────────────

    @Override
    public synchronized Optional<Map<String, String>> loadIdentityMetadata() {
        String sql = "SELECT key, value FROM device_identity";
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            Map<String, String> map = new HashMap<>();
            while (rs.next()) {
                map.put(rs.getString("key"), rs.getString("value"));
            }
            return map.isEmpty() ? Optional.empty() : Optional.of(map);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to load identity metadata from SQLite", e);
        }
    }

    @Override
    public synchronized void saveIdentityMetadata(Map<String, String> metadata) {
        String sql = "INSERT OR REPLACE INTO device_identity (key, value) VALUES (?, ?)";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            for (Map.Entry<String, String> entry : metadata.entrySet()) {
                ps.setString(1, entry.getKey());
                ps.setString(2, entry.getValue());
                ps.addBatch();
            }
            ps.executeBatch();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to save identity metadata to SQLite", e);
        }
    }

    @Override
    public synchronized boolean hasIdentityMetadata() {
        String sql = "SELECT 1 FROM device_identity WHERE key = 'peer_id' LIMIT 1";
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            return rs.next();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to check identity metadata presence", e);
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TransferSessionJournal implementation (delegating to SqliteTransferSessionJournal)
    // ──────────────────────────────────────────────────────────────────────────

    public org.peerlink.core.transfer.TransferSessionJournal getTransferSessionJournal() {
        return this.transferJournal;
    }

    @Override
    public synchronized void recordSession(org.peerlink.core.transfer.TransferSessionRecord session) {
        transferJournal.recordSession(session);
    }

    @Override
    public synchronized Optional<org.peerlink.core.transfer.TransferSessionRecord> getSession(String transferId) {
        return transferJournal.getSession(transferId);
    }

    @Override
    public synchronized Optional<org.peerlink.core.transfer.TransferSessionRecord> getSessionByOperationId(String operationId) {
        return transferJournal.getSessionByOperationId(operationId);
    }

    @Override
    public synchronized void updateSessionState(String transferId, org.peerlink.protocol.v1.TransferState state) {
        transferJournal.updateSessionState(transferId, state);
    }

    @Override
    public synchronized void updateChunkStatus(String transferId, int itemIndex, long chunkIndex, org.peerlink.protocol.v1.ChunkStatus status) {
        transferJournal.updateChunkStatus(transferId, itemIndex, chunkIndex, status);
    }

    @Override
    public synchronized void updateChunkMetadata(String transferId, int itemIndex, long chunkIndex,
                                                 long offsetBytes, int sizeBytes, String sha256,
                                                 org.peerlink.protocol.v1.ChunkStatus status) {
        transferJournal.updateChunkMetadata(transferId, itemIndex, chunkIndex, offsetBytes, sizeBytes, sha256, status);
    }

    @Override
    public synchronized Set<Long> getAckedChunks(String transferId, int itemIndex) {
        return transferJournal.getAckedChunks(transferId, itemIndex);
    }

    @Override
    public synchronized void recordReceipt(String transferId, org.peerlink.protocol.v1.TransferCompletedReceipt receipt) {
        transferJournal.recordReceipt(transferId, receipt);
    }

    @Override
    public synchronized List<org.peerlink.core.transfer.TransferSessionRecord> getActiveSessions() {
        return transferJournal.getActiveSessions();
    }

    @Override
    public synchronized List<org.peerlink.core.transfer.TransferSessionRecord> getIncompleteSessions() {
        return transferJournal.getIncompleteSessions();
    }

    @Override
    public synchronized void removeSession(String transferId) {
        transferJournal.removeSession(transferId);
    }
}

