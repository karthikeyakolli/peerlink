package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.Serializable;
import java.util.Objects;

/**
 * Historical version discovery record.
 * Represents a point-in-time state of an object in a specific backup snapshot.
 */
public record HistoricalVersionInfo(
        String backupId,
        String jobId,
        long snapshotTimestampUtcMs,
        ObjectIdentity objectId,
        String relativePath,
        ContentHash contentHash,
        long sizeBytes,
        long versionSequence,
        boolean deleted,
        String storageHash,
        boolean encrypted,
        boolean protectedVersion
) implements Serializable {
    private static final long serialVersionUID = 1L;

    public HistoricalVersionInfo {
        Objects.requireNonNull(backupId, "backupId cannot be null");
        Objects.requireNonNull(jobId, "jobId cannot be null");
        Objects.requireNonNull(objectId, "objectId cannot be null");
        Objects.requireNonNull(relativePath, "relativePath cannot be null");
        Objects.requireNonNull(storageHash, "storageHash cannot be null");
    }
}
