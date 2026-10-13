package org.peerlink.core.sync;

import java.util.Objects;

/**
 * Represents a single sync-tracked object (file or directory).
 *
 * <p>Key invariants:
 * <ul>
 *   <li>{@link ObjectId} is stable across renames, moves, and content changes.</li>
 *   <li>{@code contentHash} is the hash of current bytes — changes when content changes.</li>
 *   <li>{@code objectId != contentHash} — equal content does NOT merge logical objects.</li>
 *   <li>Deleted objects become {@link Tombstone}s; they are not simply removed.</li>
 *   <li>A restore creates a new content version, not a undo of the tombstone.</li>
 *   <li>Local cache/placeholder deletion does NOT delete source content unless separately authorized.</li>
 * </ul>
 */
public final class SyncObject {

    private final ObjectId objectId;
    private volatile String relativePath;       // current path relative to sync root
    private volatile String contentHash;        // SHA-256 hex of current content; null if directory
    private volatile long sizeBytes;
    private volatile long lastModifiedHintMs;   // hint only — NOT used for conflict authority
    private volatile boolean isDirectory;

    private volatile ContentVersion contentVersion;
    private volatile MetadataVersion metadataVersion;
    private volatile CausalVersion causalVersion;

    private volatile boolean deleted;           // soft-deleted — tombstone exists

    public SyncObject(ObjectId objectId, String relativePath, String contentHash,
                      long sizeBytes, long lastModifiedHintMs, boolean isDirectory,
                      ContentVersion contentVersion, MetadataVersion metadataVersion,
                      CausalVersion causalVersion) {
        this.objectId = Objects.requireNonNull(objectId, "objectId");
        this.relativePath = Objects.requireNonNull(relativePath, "relativePath");
        this.contentHash = contentHash;
        this.sizeBytes = sizeBytes;
        this.lastModifiedHintMs = lastModifiedHintMs;
        this.isDirectory = isDirectory;
        this.contentVersion = Objects.requireNonNull(contentVersion, "contentVersion");
        this.metadataVersion = Objects.requireNonNull(metadataVersion, "metadataVersion");
        this.causalVersion = Objects.requireNonNull(causalVersion, "causalVersion");
        this.deleted = false;
    }

    // ── Content change (file bytes changed) ─────────────────────────────────
    public synchronized void applyContentChange(String newContentHash, long newSizeBytes,
                                                 long lastModifiedHint, String localPeerId) {
        this.contentHash = newContentHash;
        this.sizeBytes = newSizeBytes;
        this.lastModifiedHintMs = lastModifiedHint;
        this.contentVersion = contentVersion.next();
        this.causalVersion = causalVersion.increment(localPeerId);
    }

    // ── Metadata change (rename/move) ────────────────────────────────────────
    public synchronized void applyMetadataChange(String newRelativePath, long lastModifiedHint,
                                                   String localPeerId) {
        this.relativePath = newRelativePath;
        this.lastModifiedHintMs = lastModifiedHint;
        this.metadataVersion = metadataVersion.next();
        this.causalVersion = causalVersion.increment(localPeerId);
    }

    // ── Soft deletion (creates tombstone externally) ─────────────────────────
    public synchronized void markDeleted(String localPeerId) {
        this.deleted = true;
        this.causalVersion = causalVersion.increment(localPeerId);
    }

    // ── Restore (new content version, NOT undo of tombstone) ─────────────────
    public synchronized void restore(String newContentHash, long newSizeBytes,
                                      long lastModifiedHint, String localPeerId) {
        this.deleted = false;
        this.contentHash = newContentHash;
        this.sizeBytes = newSizeBytes;
        this.lastModifiedHintMs = lastModifiedHint;
        this.contentVersion = contentVersion.next();
        this.causalVersion = causalVersion.increment(localPeerId);
    }

    // ── Conflict resolution clock merge ─────────────────────────────────────
    public synchronized void resolveWithMergedClock(CausalVersion otherClock, String localPeerId) {
        this.causalVersion = this.causalVersion.merge(otherClock).increment(localPeerId);
        this.contentVersion = this.contentVersion.next();
    }

    public synchronized SyncObject copy() {
        SyncObject c = new SyncObject(objectId, relativePath, contentHash, sizeBytes,
                lastModifiedHintMs, isDirectory, contentVersion, metadataVersion, causalVersion);
        c.deleted = this.deleted;
        return c;
    }

    // ── Accessors ────────────────────────────────────────────────────────────
    public ObjectId getObjectId() { return objectId; }
    public String getRelativePath() { return relativePath; }
    public String getContentHash() { return contentHash; }
    public long getSizeBytes() { return sizeBytes; }
    public long getLastModifiedHintMs() { return lastModifiedHintMs; }
    public boolean isDirectory() { return isDirectory; }
    public ContentVersion getContentVersion() { return contentVersion; }
    public MetadataVersion getMetadataVersion() { return metadataVersion; }
    public CausalVersion getCausalVersion() { return causalVersion; }
    public boolean isDeleted() { return deleted; }

    @Override
    public String toString() {
        return "SyncObject{id=" + objectId + ", path=" + relativePath
                + ", cv=" + contentVersion + ", causal=" + causalVersion + ", deleted=" + deleted + "}";
    }
}