package org.peerlink.core.sync;

/**
 * Deletion marker for a sync object.
 *
 * <p>Tombstones are permanent records of deletion. They exist to prevent
 * a re-syncing peer from treating a deleted object as a new addition.
 *
 * <p>Rules:
 * <ul>
 *   <li>A deletion ALWAYS produces a tombstone — objects are never silently removed.</li>
 *   <li>Tombstones can only be garbage-collected after ALL participating peers have
 *       acknowledged the deletion at or beyond its causal version (safe convergence).</li>
 *   <li>A restore creates a new {@link SyncObject} version — tombstone is NOT undone.</li>
 *   <li>A local cache/placeholder deletion DOES NOT delete the source tombstone or
 *       the object on remote peers unless separately authorized.</li>
 * </ul>
 */
public final class Tombstone {

    private final ObjectId objectId;
    private final String deletedAtRelativePath;
    private final CausalVersion deletionCausalVersion;
    private final String deletingPeerId;
    private final long deletedAtUtcMs;
    private volatile boolean safeToGarbageCollect;

    public Tombstone(ObjectId objectId, String deletedAtRelativePath,
                     CausalVersion deletionCausalVersion, String deletingPeerId, long deletedAtUtcMs) {
        this.objectId = objectId;
        this.deletedAtRelativePath = deletedAtRelativePath;
        this.deletionCausalVersion = deletionCausalVersion;
        this.deletingPeerId = deletingPeerId;
        this.deletedAtUtcMs = deletedAtUtcMs;
        this.safeToGarbageCollect = false;
    }

    /** Mark this tombstone safe to GC after all peers have acknowledged convergence. */
    public void markSafeToGarbageCollect() { this.safeToGarbageCollect = true; }

    public ObjectId getObjectId() { return objectId; }
    public String getDeletedAtRelativePath() { return deletedAtRelativePath; }
    public CausalVersion getDeletionCausalVersion() { return deletionCausalVersion; }
    public String getDeletingPeerId() { return deletingPeerId; }
    public long getDeletedAtUtcMs() { return deletedAtUtcMs; }
    public boolean isSafeToGarbageCollect() { return safeToGarbageCollect; }

    @Override
    public String toString() {
        return "Tombstone{id=" + objectId + ", path=" + deletedAtRelativePath
                + ", causal=" + deletionCausalVersion + ", gcSafe=" + safeToGarbageCollect + "}";
    }
}