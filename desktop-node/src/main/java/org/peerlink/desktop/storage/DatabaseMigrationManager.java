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
    public static final int CURRENT_SCHEMA_VERSION = 3;

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
