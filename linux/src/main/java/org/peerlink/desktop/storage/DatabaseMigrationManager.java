package org.peerlink.desktop.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Versioned SQLite schema migration manager.
 *
 * <p>Migrations are applied in ascending version order. Each migration is
 * idempotent at the schema level — once a version is applied and recorded in
 * the {@code schema_version} table, it is never re-applied.
 *
 * <p>Invariants:
 * <ul>
 *   <li>Version 0 is the baseline empty schema (implicit — no migration runs for it).</li>
 *   <li>Each migration is atomic: it runs inside a single transaction. If it
 *       throws, the transaction is rolled back and the database is unchanged.</li>
 *   <li>Applied versions are persisted in {@code schema_version} table before
 *       the migration transaction commits. The version table is created on
 *       first use if it doesn't exist.</li>
 *   <li>Migration code must not assume any particular current schema beyond what
 *       previous migrations have defined.</li>
 * </ul>
 *
 * <p>To add a new migration: create a new {@link Migration} instance and add it
 * to the {@link #migrations()} list below. Increment the version by 1.
 */
public final class DatabaseMigrationManager {
    private static final Logger log = LoggerFactory.getLogger(DatabaseMigrationManager.class);

    /** The target schema version this code requires. */
    public static final int CURRENT_SCHEMA_VERSION = 5;

    /**
     * A single schema migration step.
     */
    public record Migration(int version, String description, String sql) {}

    /**
     * All declared migrations in order. New migrations must be appended at the end.
     * Never change or delete existing migrations.
     */
    public static List<Migration> migrations() {
        List<Migration> list = new ArrayList<>();

        // Version 1 — core operational tables
        list.add(new Migration(1, "Core operational tables", """
            CREATE TABLE IF NOT EXISTS schema_version (
                version     INTEGER PRIMARY KEY,
                description TEXT    NOT NULL,
                applied_at  INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS operations (
                operation_id    TEXT    PRIMARY KEY,
                intent          TEXT    NOT NULL,
                actor_peer_id   TEXT    NOT NULL,
                target_object_ids TEXT  NOT NULL DEFAULT '',
                state           TEXT    NOT NULL,
                journal_stage   TEXT    NOT NULL DEFAULT 'INTENT',
                idempotency_key TEXT    NOT NULL,
                created_at      INTEGER NOT NULL,
                updated_at      INTEGER NOT NULL,
                interrupted_at  INTEGER,
                notes           TEXT    NOT NULL DEFAULT ''
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_operations_idempotency
                ON operations(idempotency_key);

            CREATE INDEX IF NOT EXISTS idx_operations_state
                ON operations(state);

            CREATE TABLE IF NOT EXISTS device_identity (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS node_metadata (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """));

        // Version 2 — object index foundation
        list.add(new Migration(2, "Object index foundation", """
            CREATE TABLE IF NOT EXISTS object_index (
                object_id       TEXT    PRIMARY KEY,
                content_hash    TEXT,
                local_path      TEXT,
                size_bytes      INTEGER,
                media_type      TEXT,
                indexed_at      INTEGER NOT NULL,
                last_seen_at    INTEGER NOT NULL,
                index_state     TEXT    NOT NULL DEFAULT 'ACTIVE'
            );

            CREATE INDEX IF NOT EXISTS idx_object_index_hash
                ON object_index(content_hash)
                WHERE content_hash IS NOT NULL;

            CREATE INDEX IF NOT EXISTS idx_object_index_state
                ON object_index(index_state);
            """));

        // Version 3 — transfer sessions, chunk statuses, and offline queue
        list.add(new Migration(3, "Transfer sessions, chunks, and queue", """
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
                failure_reason       TEXT,
                created_at           INTEGER NOT NULL,
                updated_at           INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_transfer_sessions_op_id
                ON transfer_sessions(operation_id);

            CREATE INDEX IF NOT EXISTS idx_transfer_sessions_state
                ON transfer_sessions(state);

            CREATE TABLE IF NOT EXISTS transfer_chunks (
                transfer_id          TEXT    NOT NULL,
                item_index           INTEGER NOT NULL,
                chunk_index          INTEGER NOT NULL,
                status               TEXT    NOT NULL,
                updated_at           INTEGER NOT NULL,
                PRIMARY KEY (transfer_id, item_index, chunk_index)
            );

            CREATE TABLE IF NOT EXISTS transfer_queue (
                transfer_id          TEXT    PRIMARY KEY,
                operation_id         TEXT    NOT NULL,
                target_peer_id       TEXT    NOT NULL,
                priority             INTEGER NOT NULL DEFAULT 0,
                is_offline           INTEGER NOT NULL DEFAULT 0,
                queued_at            INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_transfer_queue_target
                ON transfer_queue(target_peer_id);
            """));

        // Version 4 — transfer session staging and chunk integrity metadata
        list.add(new Migration(4, "Transfer session staging and chunk integrity metadata", """
            ALTER TABLE transfer_sessions ADD COLUMN staging_path TEXT;
            ALTER TABLE transfer_sessions ADD COLUMN destination_path TEXT;
            ALTER TABLE transfer_sessions ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0;
            ALTER TABLE transfer_chunks ADD COLUMN offset_bytes INTEGER NOT NULL DEFAULT 0;
            ALTER TABLE transfer_chunks ADD COLUMN chunk_size_bytes INTEGER NOT NULL DEFAULT 0;
            ALTER TABLE transfer_chunks ADD COLUMN chunk_sha256 TEXT NOT NULL DEFAULT '';
            """));

        // Version 5 — normalized relational models: operation targets & effects,
        // trusted peers, object versions, shares, workspaces, backup versions, scan results, recovery journal
        list.add(new Migration(5, "Normalized relational storage and durable recovery models", """
            CREATE TABLE IF NOT EXISTS operation_targets (
                operation_id   TEXT    NOT NULL,
                object_id      TEXT    NOT NULL,
                target_order   INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (operation_id, object_id),
                FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_operation_targets_obj
                ON operation_targets(object_id);

            CREATE TABLE IF NOT EXISTS operation_effects (
                effect_id      TEXT    PRIMARY KEY,
                operation_id   TEXT    NOT NULL,
                effect_type    TEXT    NOT NULL,
                target_path    TEXT    NOT NULL,
                content_hash   TEXT,
                bytes_affected INTEGER NOT NULL DEFAULT 0,
                verified_at    INTEGER NOT NULL,
                details        TEXT    NOT NULL DEFAULT '',
                FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_operation_effects_op
                ON operation_effects(operation_id);

            CREATE TABLE IF NOT EXISTS trusted_peers (
                peer_id           TEXT    PRIMARY KEY,
                device_id         TEXT,
                display_name      TEXT,
                public_key_hex    TEXT    NOT NULL,
                trust_level       TEXT    NOT NULL,
                paired_at         INTEGER NOT NULL,
                is_revoked        INTEGER NOT NULL DEFAULT 0,
                revocation_reason TEXT,
                revoked_at        INTEGER
            );

            CREATE INDEX IF NOT EXISTS idx_trusted_peers_level
                ON trusted_peers(trust_level);

            CREATE TABLE IF NOT EXISTS object_versions (
                object_id           TEXT    NOT NULL,
                version_seq         INTEGER NOT NULL,
                content_hash        TEXT    NOT NULL,
                vector_clock_json   TEXT    NOT NULL DEFAULT '{}',
                is_tombstone        INTEGER NOT NULL DEFAULT 0,
                modified_by_peer_id TEXT    NOT NULL,
                created_at          INTEGER NOT NULL,
                PRIMARY KEY (object_id, version_seq),
                FOREIGN KEY (object_id) REFERENCES object_index(object_id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_object_versions_hash
                ON object_versions(content_hash);

            CREATE TABLE IF NOT EXISTS shares (
                share_id          TEXT    PRIMARY KEY,
                owner_peer_id     TEXT    NOT NULL,
                share_type        TEXT    NOT NULL,
                display_label     TEXT    NOT NULL,
                created_at        INTEGER NOT NULL,
                expires_at        INTEGER NOT NULL DEFAULT 0,
                grace_period_ms   INTEGER NOT NULL DEFAULT 0,
                one_time          INTEGER NOT NULL DEFAULT 0,
                is_consumed       INTEGER NOT NULL DEFAULT 0,
                is_revoked        INTEGER NOT NULL DEFAULT 0,
                guest_allowed     INTEGER NOT NULL DEFAULT 0,
                auth_secret       TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS share_allowed_peers (
                share_id          TEXT    NOT NULL,
                peer_id           TEXT    NOT NULL,
                PRIMARY KEY (share_id, peer_id),
                FOREIGN KEY (share_id) REFERENCES shares(share_id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS workspaces (
                workspace_id      TEXT    PRIMARY KEY,
                name              TEXT    NOT NULL,
                owner_peer_id     TEXT    NOT NULL,
                root_directory    TEXT,
                policy_epoch      INTEGER NOT NULL DEFAULT 1,
                created_at        INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS workspace_members (
                workspace_id      TEXT    NOT NULL,
                peer_id           TEXT    NOT NULL,
                role              TEXT    NOT NULL,
                joined_at         INTEGER NOT NULL,
                invited_by        TEXT    NOT NULL,
                is_revoked        INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (workspace_id, peer_id),
                FOREIGN KEY (workspace_id) REFERENCES workspaces(workspace_id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS backup_snapshots (
                snapshot_id        TEXT    PRIMARY KEY,
                job_id             TEXT    NOT NULL,
                backup_type        TEXT    NOT NULL,
                target_peer_id     TEXT    NOT NULL,
                manifest_hash      TEXT    NOT NULL,
                parent_snapshot_id TEXT,
                total_files        INTEGER NOT NULL DEFAULT 0,
                total_bytes        INTEGER NOT NULL DEFAULT 0,
                is_blind           INTEGER NOT NULL DEFAULT 0,
                created_at         INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS backup_versions (
                snapshot_id        TEXT    NOT NULL,
                object_id          TEXT    NOT NULL,
                version_seq        INTEGER NOT NULL,
                relative_path      TEXT    NOT NULL,
                content_hash       TEXT,
                storage_hash       TEXT    NOT NULL,
                size_bytes         INTEGER NOT NULL DEFAULT 0,
                is_deleted         INTEGER NOT NULL DEFAULT 0,
                is_protected       INTEGER NOT NULL DEFAULT 0,
                is_encrypted       INTEGER NOT NULL DEFAULT 0,
                captured_at        INTEGER NOT NULL,
                PRIMARY KEY (snapshot_id, object_id, version_seq),
                FOREIGN KEY (snapshot_id) REFERENCES backup_snapshots(snapshot_id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS scan_results (
                content_hash       TEXT    PRIMARY KEY,
                verdict            TEXT    NOT NULL,
                scanner_name       TEXT    NOT NULL,
                threat_name        TEXT,
                duration_ms        INTEGER NOT NULL DEFAULT 0,
                scanned_at         INTEGER NOT NULL,
                details            TEXT    NOT NULL DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS recovery_journal (
                recovery_id        TEXT    PRIMARY KEY,
                operation_id       TEXT    NOT NULL,
                decision           TEXT    NOT NULL,
                evidence_hash      TEXT,
                filesystem_path    TEXT,
                reconciled_at      INTEGER NOT NULL,
                explanation        TEXT    NOT NULL,
                FOREIGN KEY (operation_id) REFERENCES operations(operation_id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_recovery_journal_op
                ON recovery_journal(operation_id);
            """));

        return list;
    }

    /**
     * Apply all pending migrations to {@code connection}.
     * The connection must already have WAL and PRAGMA settings configured.
     *
     * @throws SQLException if a migration fails. In this case the database is
     *         left at the version before the failing migration.
     */
    public void applyMigrations(Connection connection) throws SQLException {
        ensureVersionTableExists(connection);
        int currentVersion = readCurrentVersion(connection);
        log.info("Database schema version: {} (target: {})", currentVersion, CURRENT_SCHEMA_VERSION);

        List<Migration> pending = migrations().stream()
                .filter(m -> m.version() > currentVersion)
                .sorted(Comparator.comparingInt(Migration::version))
                .toList();

        if (pending.isEmpty()) {
            log.debug("Schema is up-to-date at version {}", currentVersion);
            return;
        }

        for (Migration migration : pending) {
            applyMigration(connection, migration);
        }

        log.info("Schema upgraded to version {}", CURRENT_SCHEMA_VERSION);
    }

    private void ensureVersionTableExists(Connection connection) throws SQLException {
        try (Statement stmt = connection.createStatement()) {
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS schema_version (
                    version     INTEGER PRIMARY KEY,
                    description TEXT    NOT NULL,
                    applied_at  INTEGER NOT NULL
                );
                """);
        }
    }

    private int readCurrentVersion(Connection connection) throws SQLException {
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COALESCE(MAX(version), 0) FROM schema_version")) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    private void applyMigration(Connection connection, Migration migration) throws SQLException {
        log.info("Applying schema migration v{}: {}", migration.version(), migration.description());

        boolean autoCommit = connection.getAutoCommit();
        connection.setAutoCommit(false);
        try {
            // Execute all SQL statements in the migration
            for (String statement : splitStatements(migration.sql())) {
                String trimmed = statement.strip();
                if (!trimmed.isEmpty()) {
                    try (Statement stmt = connection.createStatement()) {
                        stmt.execute(trimmed);
                    }
                }
            }

            // Backfill normalized relationships if upgrading to v5
            if (migration.version() == 5) {
                backfillOperationTargets(connection);
            }

            // Record the applied version
            try (PreparedStatement pstmt = connection.prepareStatement(
                    "INSERT OR REPLACE INTO schema_version (version, description, applied_at) VALUES (?, ?, ?)")) {
                pstmt.setInt(1, migration.version());
                pstmt.setString(2, migration.description());
                pstmt.setLong(3, System.currentTimeMillis());
                pstmt.executeUpdate();
            }

            connection.commit();
            log.info("Migration v{} applied successfully", migration.version());

        } catch (SQLException e) {
            log.error("Migration v{} failed — rolling back", migration.version(), e);
            try { connection.rollback(); } catch (SQLException re) { log.error("Rollback failed", re); }
            throw new SQLException("Schema migration v" + migration.version() + " failed: " + e.getMessage(), e);
        } finally {
            connection.setAutoCommit(autoCommit);
        }
    }

    /**
     * Backfills normalized {@code operation_targets} from legacy comma-separated
     * {@code operations.target_object_ids} rows during migration v5.
     */
    private void backfillOperationTargets(Connection connection) {
        String selectSql = "SELECT operation_id, target_object_ids FROM operations WHERE target_object_ids IS NOT NULL AND target_object_ids != ''";
        String insertSql = "INSERT OR IGNORE INTO operation_targets (operation_id, object_id, target_order) VALUES (?, ?, ?)";
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery(selectSql);
             PreparedStatement ps = connection.prepareStatement(insertSql)) {
            while (rs.next()) {
                String opId = rs.getString("operation_id");
                String rawTargets = rs.getString("target_object_ids");
                if (rawTargets != null && !rawTargets.isBlank()) {
                    String[] parts = rawTargets.split(",");
                    for (int i = 0; i < parts.length; i++) {
                        String target = parts[i].trim();
                        if (!target.isEmpty()) {
                            ps.setString(1, opId);
                            ps.setString(2, target);
                            ps.setInt(3, i);
                            ps.addBatch();
                        }
                    }
                }
            }
            ps.executeBatch();
            log.info("Migration v5: backfilled operation_targets from legacy comma-separated values");
        } catch (SQLException e) {
            log.warn("Migration v5: backfill of operation_targets skipped or completed with notice: {}", e.getMessage());
        }
    }

    /**
     * Split a multi-statement SQL string on semicolons, preserving statement
     * content. SQLite does not support multi-statement execution in JDBC.
     */
    private List<String> splitStatements(String sql) {
        List<String> statements = new ArrayList<>();
        for (String part : sql.split(";")) {
            String trimmed = part.strip();
            if (!trimmed.isEmpty()) {
                statements.add(trimmed);
            }
        }
        return statements;
    }

    /**
     * Run SQLite integrity_check and return the result lines.
     * Returns a single-element list containing "ok" if the database is healthy.
     */
    public List<String> runIntegrityCheck(Connection connection) throws SQLException {
        List<String> results = new ArrayList<>();
        try (Statement stmt = connection.createStatement();
             ResultSet rs = stmt.executeQuery("PRAGMA integrity_check")) {
            while (rs.next()) {
                results.add(rs.getString(1));
            }
        }
        return results;
    }

    /**
     * Returns {@code true} if the integrity check result indicates a healthy database.
     */
    public boolean isHealthy(List<String> integrityCheckResult) {
        return integrityCheckResult.size() == 1 && "ok".equalsIgnoreCase(integrityCheckResult.get(0));
    }
}
