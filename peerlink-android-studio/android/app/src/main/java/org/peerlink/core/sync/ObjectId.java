package org.peerlink.core.sync;

import java.util.UUID;

/**
 * Stable, persistent identity for a sync object.
 *
 * <p>Invariant: objectId != contentHash.
 * Two files with identical content are NOT the same logical object.
 * A file whose content changes keeps the same objectId.
 * objectId is assigned at first observation and never changes for the lifetime
 * of the object (including renames, moves, and content edits).
 */
public record ObjectId(String value) {
    public ObjectId {
        if (value == null || value.isBlank()) throw new IllegalArgumentException("objectId cannot be blank");
    }
    public static ObjectId generate() { return new ObjectId("obj_" + UUID.randomUUID().toString().replace("-", "")); }
    @Override public String toString() { return value; }
}