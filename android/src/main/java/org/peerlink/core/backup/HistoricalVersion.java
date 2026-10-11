package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.Serializable;
import java.util.Objects;

/**
 * Immutable historical version record representing a file at a specific backup point in time.
 * Invariant: objectId != contentHash.
 * A changed file preserves its objectId while advancing versionSequence.
 */
public final class HistoricalVersion implements Serializable {
    private static final long serialVersionUID = 1L;

    private final ObjectIdentity objectId;
    private final String relativePath;
    private final ContentHash contentHash;
    private final long sizeBytes;
    private final long versionSequence;
    private final long capturedAtUtcMs;
    private final boolean deleted;
    private final String storageHash;
    private final boolean encrypted;
    private final boolean protectedVersion;

    public HistoricalVersion(ObjectIdentity objectId,
                             String relativePath,
                             ContentHash contentHash,
                             long sizeBytes,
                             long versionSequence,
                             long capturedAtUtcMs,
                             boolean deleted,
                             String storageHash,
                             boolean encrypted,
                             boolean protectedVersion) {
        this.objectId = Objects.requireNonNull(objectId, "objectId cannot be null");
        this.relativePath = Objects.requireNonNull(relativePath, "relativePath cannot be null");
        this.contentHash = contentHash;
        this.sizeBytes = sizeBytes;
        this.versionSequence = versionSequence;
        this.capturedAtUtcMs = capturedAtUtcMs;
        this.deleted = deleted;
        this.storageHash = Objects.requireNonNull(storageHash, "storageHash cannot be null");
        this.encrypted = encrypted;
        this.protectedVersion = protectedVersion;
    }

    public HistoricalVersion withProtected(boolean isProtected) {
        return new HistoricalVersion(objectId, relativePath, contentHash, sizeBytes,
                versionSequence, capturedAtUtcMs, deleted, storageHash, encrypted, isProtected);
    }

    public ObjectIdentity getObjectId() { return objectId; }
    public String getRelativePath() { return relativePath; }
    public ContentHash getContentHash() { return contentHash; }
    public long getSizeBytes() { return sizeBytes; }
    public long getVersionSequence() { return versionSequence; }
    public long getCapturedAtUtcMs() { return capturedAtUtcMs; }
    public boolean isDeleted() { return deleted; }
    public String getStorageHash() { return storageHash; }
    public boolean isEncrypted() { return encrypted; }
    public boolean isProtected() { return protectedVersion; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof HistoricalVersion that)) return false;
        return sizeBytes == that.sizeBytes &&
                versionSequence == that.versionSequence &&
                capturedAtUtcMs == that.capturedAtUtcMs &&
                deleted == that.deleted &&
                encrypted == that.encrypted &&
                protectedVersion == that.protectedVersion &&
                Objects.equals(objectId, that.objectId) &&
                Objects.equals(relativePath, that.relativePath) &&
                Objects.equals(contentHash, that.contentHash) &&
                Objects.equals(storageHash, that.storageHash);
    }

    @Override
    public int hashCode() {
        return Objects.hash(objectId, relativePath, contentHash, sizeBytes,
                versionSequence, capturedAtUtcMs, deleted, storageHash, encrypted, protectedVersion);
    }
}