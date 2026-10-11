package org.peerlink.desktop.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Object index repository — the derived local index of known PeerLink objects.
 *
 * <p>This is a <em>derived</em> view: the filesystem is truth for actual bytes,
 * and the operation journal is truth for in-flight operations. The object index
 * accelerates lookup and provides metadata caching.
 *
 * <p>An object index entry can be invalidated at any time; the engine must be
 * able to reconstruct it from a targeted rescan. Stale entries do not represent
 * an authoritative state.
 *
 * <p>Index states:
 * <ul>
 *   <li>ACTIVE — entry is believed current.</li>
 *   <li>STALE — path or hash may have changed; rescan required.</li>
 *   <li>DELETED — object is known to have been removed.</li>
 * </ul>
 */
public final class ObjectIndexRepository {
    private static final Logger log = LoggerFactory.getLogger(ObjectIndexRepository.class);

    /** Index lifecycle state. */
    public enum IndexState { ACTIVE, STALE, DELETED }

    /**
     * An indexed object entry.
     */
    public record ObjectIndexEntry(
            String objectId,
            String contentHash,   // nullable — may not be hashed yet
            String localPath,     // nullable — remote objects may not have a local path
            Long   sizeBytes,     // nullable
            String mediaType,     // nullable
            long   indexedAtUtcMs,
            long   lastSeenAtUtcMs,
            IndexState indexState
    ) {}

    private final Connection connection;
    private final Object lock;

    public ObjectIndexRepository(Connection connection) {
        this(connection, connection);
    }

    public ObjectIndexRepository(Connection connection, Object lock) {
        this.connection = java.util.Objects.requireNonNull(connection, "connection cannot be null");
        this.lock = lock != null ? lock : connection;
    }

    /**
     * Upsert an object index entry. Creates or updates the entry based on objectId.
     */
    public void upsertObject(ObjectIndexEntry entry) {
        synchronized (lock) {
            String sql = """
            INSERT INTO object_index
                (object_id, content_hash, local_path, size_bytes, media_type,
                 indexed_at, last_seen_at, index_state)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(object_id) DO UPDATE SET
                content_hash  = excluded.content_hash,
                local_path    = excluded.local_path,
                size_bytes    = excluded.size_bytes,
                media_type    = excluded.media_type,
                last_seen_at  = excluded.last_seen_at,
                index_state   = excluded.index_state;
            """;
            try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
                pstmt.setString(1, entry.objectId());
                pstmt.setString(2, entry.contentHash());
                pstmt.setString(3, entry.localPath());
                if (entry.sizeBytes() != null) pstmt.setLong(4, entry.sizeBytes());
                else pstmt.setNull(4, Types.INTEGER);
                pstmt.setString(5, entry.mediaType());
                pstmt.setLong(6, entry.indexedAtUtcMs());
                pstmt.setLong(7, entry.lastSeenAtUtcMs());
                pstmt.setString(8, entry.indexState().name());
                pstmt.executeUpdate();
            } catch (SQLException e) {
                throw new RuntimeException("Failed to upsert object index entry: " + entry.objectId(), e);
            }
        }
    }

    /**
     * Batch upsert object index entries within a single transaction.
     * Guarantees high-throughput indexing for large library rescans.
     */
    public void upsertObjectsBatch(List<ObjectIndexEntry> entries) {
        if (entries == null || entries.isEmpty()) return;
        synchronized (lock) {
            String sql = """
            INSERT INTO object_index
                (object_id, content_hash, local_path, size_bytes, media_type,
                 indexed_at, last_seen_at, index_state)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(object_id) DO UPDATE SET
                content_hash  = excluded.content_hash,
                local_path    = excluded.local_path,
                size_bytes    = excluded.size_bytes,
                media_type    = excluded.media_type,
                last_seen_at  = excluded.last_seen_at,
                index_state   = excluded.index_state;
            """;
            boolean initialAutoCommit = true;
            try {
                initialAutoCommit = connection.getAutoCommit();
                if (initialAutoCommit) {
                    connection.setAutoCommit(false);
                }
                try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
                    for (ObjectIndexEntry entry : entries) {
                        pstmt.setString(1, entry.objectId());
                        pstmt.setString(2, entry.contentHash());
                        pstmt.setString(3, entry.localPath());
                        if (entry.sizeBytes() != null) pstmt.setLong(4, entry.sizeBytes());
                        else pstmt.setNull(4, Types.INTEGER);
                        pstmt.setString(5, entry.mediaType());
                        pstmt.setLong(6, entry.indexedAtUtcMs());
                        pstmt.setLong(7, entry.lastSeenAtUtcMs());
                        pstmt.setString(8, entry.indexState().name());
                        pstmt.addBatch();
                    }
                    pstmt.executeBatch();
                }
                if (initialAutoCommit) {
                    connection.commit();
                }
            } catch (SQLException e) {
                if (initialAutoCommit) {
                    try { connection.rollback(); } catch (SQLException ignored) {}
                }
                throw new RuntimeException("Failed to batch upsert " + entries.size() + " objects into index", e);
            } finally {
                if (initialAutoCommit) {
                    try { connection.setAutoCommit(true); } catch (SQLException ignored) {}
                }
            }
        }
    }

    /** Look up an object by its stable ID. */
    public Optional<ObjectIndexEntry> findById(String objectId) {
        synchronized (lock) {
            String sql = "SELECT * FROM object_index WHERE object_id = ?";
            try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
                pstmt.setString(1, objectId);
                try (ResultSet rs = pstmt.executeQuery()) {
                    if (rs.next()) return Optional.of(map(rs));
                }
            } catch (SQLException e) {
                throw new RuntimeException("Failed to query object index by id: " + objectId, e);
            }
            return Optional.empty();
        }
    }

    /** Find objects by content hash (multiple objects may share a hash). */
    public List<ObjectIndexEntry> findByContentHash(String contentHash) {
        synchronized (lock) {
            List<ObjectIndexEntry> results = new ArrayList<>();
            String sql = "SELECT * FROM object_index WHERE content_hash = ? AND index_state = 'ACTIVE'";
            try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
                pstmt.setString(1, contentHash);
                try (ResultSet rs = pstmt.executeQuery()) {
                    while (rs.next()) results.add(map(rs));
                }
            } catch (SQLException e) {
                throw new RuntimeException("Failed to query object index by hash: " + contentHash, e);
            }
            return results;
        }
    }

    /** Mark an object as STALE — its path or hash may have changed. */
    public void markStale(String objectId) {
        synchronized (lock) {
            updateState(objectId, IndexState.STALE);
        }
    }

    /** Mark an object as DELETED. */
    public void markDeleted(String objectId) {
        synchronized (lock) {
            updateState(objectId, IndexState.DELETED);
        }
    }

    /** Count of ACTIVE index entries. */
    public int activeCount() {
        synchronized (lock) {
            try (Statement stmt = connection.createStatement();
                 ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM object_index WHERE index_state = 'ACTIVE'")) {
                return rs.next() ? rs.getInt(1) : 0;
            } catch (SQLException e) {
                throw new RuntimeException("Failed to count active objects", e);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ──────────────────────────────────────────────────────────────────────────

    private void updateState(String objectId, IndexState state) {
        String sql = "UPDATE object_index SET index_state = ?, last_seen_at = ? WHERE object_id = ?";
        try (PreparedStatement pstmt = connection.prepareStatement(sql)) {
            pstmt.setString(1, state.name());
            pstmt.setLong(2, System.currentTimeMillis());
            pstmt.setString(3, objectId);
            pstmt.executeUpdate();
        } catch (SQLException e) {
            throw new RuntimeException("Failed to update index state for: " + objectId, e);
        }
    }

    private ObjectIndexEntry map(ResultSet rs) throws SQLException {
        long sizeRaw = rs.getLong("size_bytes");
        Long sizeBytes = rs.wasNull() ? null : sizeRaw;
        return new ObjectIndexEntry(
                rs.getString("object_id"),
                rs.getString("content_hash"),
                rs.getString("local_path"),
                sizeBytes,
                rs.getString("media_type"),
                rs.getLong("indexed_at"),
                rs.getLong("last_seen_at"),
                IndexState.valueOf(rs.getString("index_state"))
        );
    }
}
