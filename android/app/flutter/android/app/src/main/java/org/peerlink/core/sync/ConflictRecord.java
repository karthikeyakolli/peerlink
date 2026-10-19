package org.peerlink.core.sync;

/**
 * Represents a detected sync conflict between local and remote versions of an object.
 *
 * <p>Conflicts arise when causal versions are CONCURRENT — neither dominates the other.
 * Timestamps are NOT used to break ties; only the user or an explicit policy can resolve.
 */
public final class ConflictRecord {

    private final ObjectId objectId;
    private final ConflictType conflictType;
    private final SyncObject localVersion;
    private final SyncObject remoteVersion;
    private final long detectedAtUtcMs;
    private volatile ConflictResolution resolution;
    private volatile boolean resolved;

    public ConflictRecord(ObjectId objectId, ConflictType conflictType,
                          SyncObject localVersion, SyncObject remoteVersion) {
        this.objectId = objectId;
        this.conflictType = conflictType;
        this.localVersion = localVersion;
        this.remoteVersion = remoteVersion;
        this.detectedAtUtcMs = System.currentTimeMillis();
        this.resolution = ConflictResolution.DEFERRED;
        this.resolved = false;
    }

    public void resolve(ConflictResolution resolution) {
        this.resolution = resolution;
        this.resolved = resolution != ConflictResolution.DEFERRED;
    }

    public ObjectId getObjectId() { return objectId; }
    public ConflictType getConflictType() { return conflictType; }
    public SyncObject getLocalVersion() { return localVersion; }
    public SyncObject getRemoteVersion() { return remoteVersion; }
    public long getDetectedAtUtcMs() { return detectedAtUtcMs; }
    public ConflictResolution getResolution() { return resolution; }
    public boolean isResolved() { return resolved; }

    @Override
    public String toString() {
        return "Conflict{id=" + objectId + ", type=" + conflictType + ", resolved=" + resolved + "/" + resolution + "}";
    }
}