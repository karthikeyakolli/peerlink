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

    public LocalSqliteStorage(Connection connection, Path dbPath) throws SQLException {
        this.dbPath = dbPath;
        this.connection = Objects.requireNonNull(connection, "connection cannot be null");
        initPragmas();
        migrations.applyMigrations(connection);
        this.objectIndex = new ObjectIndexRepository(this.connection, this);
        this.transferJournal = new org.peerlink.core.transfer.SqliteTransferSessionJournal(this.connection);
        log.info("LocalSqliteStorage ready with custom connection at {} (schema v{})",
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

        // Normalized operation targets
        String targetSql = "INSERT OR IGNORE INTO operation_targets (operation_id, object_id, target_order) VALUES (?, ?, ?)";
        try (PreparedStatement targetPs = connection.prepareStatement(targetSql)) {
            int order = 0;
            for (String targetObjId : record.getTargetObjectIds()) {
                targetPs.setString(1, record.getOperationId());
                targetPs.setString(2, targetObjId);
                targetPs.setInt(3, order++);
                targetPs.addBatch();
            }
            targetPs.executeBatch();
        } catch (SQLException e) {
            log.warn("Failed to record operation_targets for operation: " + record.getOperationId(), e);
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

    public synchronized List<String> getOperationTargets(String operationId) {
        List<String> targets = new ArrayList<>();
        String sql = "SELECT object_id FROM operation_targets WHERE operation_id = ? ORDER BY target_order ASC";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, operationId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    targets.add(rs.getString("object_id"));
                }
            }
        } catch (SQLException e) {
            // Table might not exist or error, fall back to empty
        }
        return targets;
    }

    private OperationRecord mapResultSet(ResultSet rs) throws SQLException {
        String opId = rs.getString("operation_id");
        List<String> targetList = getOperationTargets(opId);
        if (targetList.isEmpty()) {
            String targets = rs.getString("target_object_ids");
            targetList = (targets == null || targets.isEmpty())
                    ? List.of()
                    : Arrays.asList(targets.split(","));
        }
        return new OperationRecord(
                opId,
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

    // ──────────────────────────────────────────────────────────────────────────
    // Phase 19: Normalized Models & Durability Boundaries
    // ──────────────────────────────────────────────────────────────────────────

    // ── 1. Operation Effects (Distinguishing requested intent from verified effects) ──

    public synchronized void recordOperationEffect(String effectId, String operationId, String effectType,
                                                  String targetPath, String contentHash, long bytesAffected,
                                                  String details) {
        String sql = """
            INSERT INTO operation_effects (effect_id, operation_id, effect_type, target_path, content_hash, bytes_affected, verified_at, details)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, effectId);
            ps.setString(2, operationId);
            ps.setString(3, effectType);
            ps.setString(4, targetPath);
            ps.setString(5, contentHash);
            ps.setLong(6, bytesAffected);
            ps.setLong(7, System.currentTimeMillis());
            ps.setString(8, details != null ? details : "");
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record operation effect: " + effectId, e);
        }
    }

    public synchronized List<Map<String, Object>> listOperationEffects(String operationId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT * FROM operation_effects WHERE operation_id = ? ORDER BY verified_at ASC";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, operationId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("effect_id", rs.getString("effect_id"));
                    map.put("operation_id", rs.getString("operation_id"));
                    map.put("effect_type", rs.getString("effect_type"));
                    map.put("target_path", rs.getString("target_path"));
                    map.put("content_hash", rs.getString("content_hash"));
                    map.put("bytes_affected", rs.getLong("bytes_affected"));
                    map.put("verified_at", rs.getLong("verified_at"));
                    map.put("details", rs.getString("details"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to list operation effects for: " + operationId, e);
        }
        return list;
    }

    // ── 2. Device Identity & Trust Metadata ───────────────────────────────────

    public synchronized void recordTrustedPeer(String peerId, String deviceId, String displayName,
                                              String pubKeyHex, String trustLevel, long pairedAt) {
        String sql = """
            INSERT INTO trusted_peers (peer_id, device_id, display_name, public_key_hex, trust_level, paired_at, is_revoked)
            VALUES (?, ?, ?, ?, ?, ?, 0)
            ON CONFLICT(peer_id) DO UPDATE SET
                device_id = excluded.device_id,
                display_name = excluded.display_name,
                public_key_hex = excluded.public_key_hex,
                trust_level = excluded.trust_level;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, peerId);
            ps.setString(2, deviceId);
            ps.setString(3, displayName);
            ps.setString(4, pubKeyHex);
            ps.setString(5, trustLevel);
            ps.setLong(6, pairedAt);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record trusted peer: " + peerId, e);
        }
    }

    public synchronized void revokeTrustedPeer(String peerId, String reason) {
        String sql = """
            UPDATE trusted_peers
            SET is_revoked = 1,
                trust_level = 'TRUST_LEVEL_REVOKED',
                revocation_reason = ?,
                revoked_at = ?
            WHERE peer_id = ?;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, reason);
            ps.setLong(2, System.currentTimeMillis());
            ps.setString(3, peerId);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to revoke trusted peer: " + peerId, e);
        }
    }

    public synchronized Optional<Map<String, Object>> getTrustedPeer(String peerId) {
        String sql = "SELECT * FROM trusted_peers WHERE peer_id = ?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, peerId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("peer_id", rs.getString("peer_id"));
                    map.put("device_id", rs.getString("device_id"));
                    map.put("display_name", rs.getString("display_name"));
                    map.put("public_key_hex", rs.getString("public_key_hex"));
                    map.put("trust_level", rs.getString("trust_level"));
                    map.put("paired_at", rs.getLong("paired_at"));
                    map.put("is_revoked", rs.getInt("is_revoked") == 1);
                    map.put("revocation_reason", rs.getString("revocation_reason"));
                    map.put("revoked_at", rs.getLong("revoked_at"));
                    return Optional.of(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query trusted peer: " + peerId, e);
        }
        return Optional.empty();
    }

    // ── 3. Object Versions & Causal Lineage ───────────────────────────────────

    public synchronized void recordObjectVersion(String objectId, long versionSeq, String contentHash,
                                                String vectorClockJson, boolean isTombstone,
                                                String modifiedByPeerId, long createdAt) {
        String sql = """
            INSERT INTO object_versions (object_id, version_seq, content_hash, vector_clock_json, is_tombstone, modified_by_peer_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, objectId);
            ps.setLong(2, versionSeq);
            ps.setString(3, contentHash);
            ps.setString(4, vectorClockJson != null ? vectorClockJson : "{}");
            ps.setInt(5, isTombstone ? 1 : 0);
            ps.setString(6, modifiedByPeerId);
            ps.setLong(7, createdAt);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record object version: " + objectId + "@" + versionSeq, e);
        }
    }

    public synchronized List<Map<String, Object>> listObjectVersions(String objectId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT * FROM object_versions WHERE object_id = ? ORDER BY version_seq ASC";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, objectId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("object_id", rs.getString("object_id"));
                    map.put("version_seq", rs.getLong("version_seq"));
                    map.put("content_hash", rs.getString("content_hash"));
                    map.put("vector_clock_json", rs.getString("vector_clock_json"));
                    map.put("is_tombstone", rs.getInt("is_tombstone") == 1);
                    map.put("modified_by_peer_id", rs.getString("modified_by_peer_id"));
                    map.put("created_at", rs.getLong("created_at"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to list object versions for: " + objectId, e);
        }
        return list;
    }

    // ── 4. Shares & Allowed Peers ─────────────────────────────────────────────

    public synchronized void recordShare(String shareId, String ownerPeerId, String shareType,
                                        String displayLabel, long createdAt, long expiresAt,
                                        long gracePeriodMs, boolean oneTime, boolean isConsumed,
                                        boolean isRevoked, boolean guestAllowed, String authSecret,
                                        Set<String> allowedPeers) {
        String sql = """
            INSERT INTO shares (share_id, owner_peer_id, share_type, display_label, created_at, expires_at,
                                grace_period_ms, one_time, is_consumed, is_revoked, guest_allowed, auth_secret)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(share_id) DO UPDATE SET
                display_label = excluded.display_label,
                is_consumed = excluded.is_consumed,
                is_revoked = excluded.is_revoked;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, shareId);
            ps.setString(2, ownerPeerId);
            ps.setString(3, shareType);
            ps.setString(4, displayLabel);
            ps.setLong(5, createdAt);
            ps.setLong(6, expiresAt);
            ps.setLong(7, gracePeriodMs);
            ps.setInt(8, oneTime ? 1 : 0);
            ps.setInt(9, isConsumed ? 1 : 0);
            ps.setInt(10, isRevoked ? 1 : 0);
            ps.setInt(11, guestAllowed ? 1 : 0);
            ps.setString(12, authSecret);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record share: " + shareId, e);
        }

        if (allowedPeers != null && !allowedPeers.isEmpty()) {
            String peerSql = "INSERT OR IGNORE INTO share_allowed_peers (share_id, peer_id) VALUES (?, ?)";
            try (PreparedStatement ps = connection.prepareStatement(peerSql)) {
                for (String peerId : allowedPeers) {
                    ps.setString(1, shareId);
                    ps.setString(2, peerId);
                    ps.addBatch();
                }
                ps.executeBatch();
            } catch (SQLException e) {
                log.warn("Failed to record share allowed peers for share: " + shareId, e);
            }
        }
    }

    public synchronized Optional<Map<String, Object>> getShare(String shareId) {
        String sql = "SELECT * FROM shares WHERE share_id = ?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, shareId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("share_id", rs.getString("share_id"));
                    map.put("owner_peer_id", rs.getString("owner_peer_id"));
                    map.put("share_type", rs.getString("share_type"));
                    map.put("display_label", rs.getString("display_label"));
                    map.put("created_at", rs.getLong("created_at"));
                    map.put("expires_at", rs.getLong("expires_at"));
                    map.put("grace_period_ms", rs.getLong("grace_period_ms"));
                    map.put("one_time", rs.getInt("one_time") == 1);
                    map.put("is_consumed", rs.getInt("is_consumed") == 1);
                    map.put("is_revoked", rs.getInt("is_revoked") == 1);
                    map.put("guest_allowed", rs.getInt("guest_allowed") == 1);
                    map.put("auth_secret", rs.getString("auth_secret"));
                    map.put("allowed_peers", getShareAllowedPeers(shareId));
                    return Optional.of(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query share: " + shareId, e);
        }
        return Optional.empty();
    }

    public synchronized Set<String> getShareAllowedPeers(String shareId) {
        Set<String> peers = new HashSet<>();
        String sql = "SELECT peer_id FROM share_allowed_peers WHERE share_id = ?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, shareId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    peers.add(rs.getString("peer_id"));
                }
            }
        } catch (SQLException e) {
            // Table might not exist or error
        }
        return peers;
    }

    // ── 5. Workspaces & Membership ────────────────────────────────────────────

    public synchronized void recordWorkspace(String workspaceId, String name, String ownerPeerId,
                                            String rootDirectory, long policyEpoch, long createdAt) {
        String sql = """
            INSERT INTO workspaces (workspace_id, name, owner_peer_id, root_directory, policy_epoch, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(workspace_id) DO UPDATE SET
                name = excluded.name,
                root_directory = excluded.root_directory,
                policy_epoch = excluded.policy_epoch;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, workspaceId);
            ps.setString(2, name);
            ps.setString(3, ownerPeerId);
            ps.setString(4, rootDirectory);
            ps.setLong(5, policyEpoch);
            ps.setLong(6, createdAt);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record workspace: " + workspaceId, e);
        }
    }

    public synchronized void addWorkspaceMember(String workspaceId, String peerId, String role,
                                               long joinedAt, String invitedBy) {
        String sql = """
            INSERT INTO workspace_members (workspace_id, peer_id, role, joined_at, invited_by, is_revoked)
            VALUES (?, ?, ?, ?, ?, 0)
            ON CONFLICT(workspace_id, peer_id) DO UPDATE SET
                role = excluded.role,
                is_revoked = 0;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, workspaceId);
            ps.setString(2, peerId);
            ps.setString(3, role);
            ps.setLong(4, joinedAt);
            ps.setString(5, invitedBy);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to add workspace member: " + peerId, e);
        }
    }

    public synchronized Optional<Map<String, Object>> getWorkspace(String workspaceId) {
        String sql = "SELECT * FROM workspaces WHERE workspace_id = ?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, workspaceId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("workspace_id", rs.getString("workspace_id"));
                    map.put("name", rs.getString("name"));
                    map.put("owner_peer_id", rs.getString("owner_peer_id"));
                    map.put("root_directory", rs.getString("root_directory"));
                    map.put("policy_epoch", rs.getLong("policy_epoch"));
                    map.put("created_at", rs.getLong("created_at"));
                    return Optional.of(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query workspace: " + workspaceId, e);
        }
        return Optional.empty();
    }

    public synchronized List<Map<String, Object>> listWorkspaceMembers(String workspaceId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT * FROM workspace_members WHERE workspace_id = ? ORDER BY joined_at ASC";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, workspaceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("workspace_id", rs.getString("workspace_id"));
                    map.put("peer_id", rs.getString("peer_id"));
                    map.put("role", rs.getString("role"));
                    map.put("joined_at", rs.getLong("joined_at"));
                    map.put("invited_by", rs.getString("invited_by"));
                    map.put("is_revoked", rs.getInt("is_revoked") == 1);
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to list workspace members for: " + workspaceId, e);
        }
        return list;
    }

    // ── 6. Backup Snapshots & Versions ────────────────────────────────────────

    public synchronized void recordBackupSnapshot(String snapshotId, String jobId, String backupType,
                                                 String targetPeerId, String manifestHash,
                                                 String parentSnapshotId, int totalFiles, long totalBytes,
                                                 boolean isBlind, long createdAt) {
        String sql = """
            INSERT INTO backup_snapshots (snapshot_id, job_id, backup_type, target_peer_id, manifest_hash,
                                          parent_snapshot_id, total_files, total_bytes, is_blind, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(snapshot_id) DO NOTHING;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, snapshotId);
            ps.setString(2, jobId);
            ps.setString(3, backupType);
            ps.setString(4, targetPeerId);
            ps.setString(5, manifestHash);
            ps.setString(6, parentSnapshotId);
            ps.setInt(7, totalFiles);
            ps.setLong(8, totalBytes);
            ps.setInt(9, isBlind ? 1 : 0);
            ps.setLong(10, createdAt);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record backup snapshot: " + snapshotId, e);
        }
    }

    public synchronized void recordBackupVersion(String snapshotId, String objectId, long versionSeq,
                                                String relativePath, String contentHash, String storageHash,
                                                long sizeBytes, boolean isDeleted, boolean isProtected,
                                                boolean isEncrypted, long capturedAt) {
        String sql = """
            INSERT INTO backup_versions (snapshot_id, object_id, version_seq, relative_path, content_hash,
                                         storage_hash, size_bytes, is_deleted, is_protected, is_encrypted, captured_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, snapshotId);
            ps.setString(2, objectId);
            ps.setLong(3, versionSeq);
            ps.setString(4, relativePath);
            ps.setString(5, contentHash);
            ps.setString(6, storageHash);
            ps.setLong(7, sizeBytes);
            ps.setInt(8, isDeleted ? 1 : 0);
            ps.setInt(9, isProtected ? 1 : 0);
            ps.setInt(10, isEncrypted ? 1 : 0);
            ps.setLong(11, capturedAt);
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record backup version for snapshot: " + snapshotId, e);
        }
    }

    public synchronized Optional<Map<String, Object>> getBackupSnapshot(String snapshotId) {
        String sql = "SELECT * FROM backup_snapshots WHERE snapshot_id = ?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, snapshotId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("snapshot_id", rs.getString("snapshot_id"));
                    map.put("job_id", rs.getString("job_id"));
                    map.put("backup_type", rs.getString("backup_type"));
                    map.put("target_peer_id", rs.getString("target_peer_id"));
                    map.put("manifest_hash", rs.getString("manifest_hash"));
                    map.put("parent_snapshot_id", rs.getString("parent_snapshot_id"));
                    map.put("total_files", rs.getInt("total_files"));
                    map.put("total_bytes", rs.getLong("total_bytes"));
                    map.put("is_blind", rs.getInt("is_blind") == 1);
                    map.put("created_at", rs.getLong("created_at"));
                    return Optional.of(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query backup snapshot: " + snapshotId, e);
        }
        return Optional.empty();
    }

    public synchronized List<Map<String, Object>> listBackupVersions(String snapshotId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT * FROM backup_versions WHERE snapshot_id = ? ORDER BY relative_path ASC, version_seq ASC";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, snapshotId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("snapshot_id", rs.getString("snapshot_id"));
                    map.put("object_id", rs.getString("object_id"));
                    map.put("version_seq", rs.getLong("version_seq"));
                    map.put("relative_path", rs.getString("relative_path"));
                    map.put("content_hash", rs.getString("content_hash"));
                    map.put("storage_hash", rs.getString("storage_hash"));
                    map.put("size_bytes", rs.getLong("size_bytes"));
                    map.put("is_deleted", rs.getInt("is_deleted") == 1);
                    map.put("is_protected", rs.getInt("is_protected") == 1);
                    map.put("is_encrypted", rs.getInt("is_encrypted") == 1);
                    map.put("captured_at", rs.getLong("captured_at"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to list backup versions for: " + snapshotId, e);
        }
        return list;
    }

    // ── 7. Scanner Results Cache ──────────────────────────────────────────────

    public synchronized void recordScanResult(String contentHash, String verdict, String scannerName,
                                             String threatName, long durationMs, long scannedAt, String details) {
        String sql = """
            INSERT INTO scan_results (content_hash, verdict, scanner_name, threat_name, duration_ms, scanned_at, details)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(content_hash) DO UPDATE SET
                verdict = excluded.verdict,
                scanner_name = excluded.scanner_name,
                threat_name = excluded.threat_name,
                duration_ms = excluded.duration_ms,
                scanned_at = excluded.scanned_at,
                details = excluded.details;
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, contentHash);
            ps.setString(2, verdict);
            ps.setString(3, scannerName);
            ps.setString(4, threatName);
            ps.setLong(5, durationMs);
            ps.setLong(6, scannedAt);
            ps.setString(7, details != null ? details : "");
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record scan result: " + contentHash, e);
        }
    }

    public synchronized Optional<Map<String, Object>> getScanResult(String contentHash) {
        String sql = "SELECT * FROM scan_results WHERE content_hash = ?";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, contentHash);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("content_hash", rs.getString("content_hash"));
                    map.put("verdict", rs.getString("verdict"));
                    map.put("scanner_name", rs.getString("scanner_name"));
                    map.put("threat_name", rs.getString("threat_name"));
                    map.put("duration_ms", rs.getLong("duration_ms"));
                    map.put("scanned_at", rs.getLong("scanned_at"));
                    map.put("details", rs.getString("details"));
                    return Optional.of(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to query scan result: " + contentHash, e);
        }
        return Optional.empty();
    }

    // ── 8. Recovery Journal ───────────────────────────────────────────────────

    public synchronized void recordRecoveryEntry(String recoveryId, String operationId, String decision,
                                                String evidenceHash, String filesystemPath,
                                                long reconciledAt, String explanation) {
        String sql = """
            INSERT INTO recovery_journal (recovery_id, operation_id, decision, evidence_hash, filesystem_path, reconciled_at, explanation)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """;
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, recoveryId);
            ps.setString(2, operationId);
            ps.setString(3, decision);
            ps.setString(4, evidenceHash);
            ps.setString(5, filesystemPath);
            ps.setLong(6, reconciledAt);
            ps.setString(7, explanation != null ? explanation : "");
            ps.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to record recovery entry: " + recoveryId, e);
        }
    }

    public synchronized List<Map<String, Object>> listRecoveryEntries(String operationId) {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT * FROM recovery_journal WHERE operation_id = ? ORDER BY reconciled_at ASC";
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setString(1, operationId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("recovery_id", rs.getString("recovery_id"));
                    map.put("operation_id", rs.getString("operation_id"));
                    map.put("decision", rs.getString("decision"));
                    map.put("evidence_hash", rs.getString("evidence_hash"));
                    map.put("filesystem_path", rs.getString("filesystem_path"));
                    map.put("reconciled_at", rs.getLong("reconciled_at"));
                    map.put("explanation", rs.getString("explanation"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException("Failed to list recovery entries for: " + operationId, e);
        }
        return list;
    }
}

