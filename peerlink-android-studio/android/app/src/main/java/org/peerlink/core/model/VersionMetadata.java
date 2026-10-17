package org.peerlink.core.model;

import java.io.Serializable;
import java.util.*;

/**
 * Causal version metadata representing causality in sync/replication.
 * Critical invariant: Timestamps are metadata hints, NOT conflict truth.
 * Causality is tracked via generation counters and parent version links.
 */
public final class VersionMetadata implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String versionId;
    private final long generation;
    private final Set<String> parentVersionIds;
    private final long physicalTimestampUtcMs;

    public VersionMetadata(String versionId, long generation, Set<String> parentVersionIds, long physicalTimestampUtcMs) {
        this.versionId = Objects.requireNonNull(versionId, "versionId must not be null");
        this.generation = generation;
        this.parentVersionIds = Collections.unmodifiableSet(new HashSet<>(Objects.requireNonNull(parentVersionIds)));
        this.physicalTimestampUtcMs = physicalTimestampUtcMs;
    }

    public static VersionMetadata genesis(String versionId) {
        return new VersionMetadata(versionId, 1L, Collections.emptySet(), System.currentTimeMillis());
    }

    public VersionMetadata createChild(String newVersionId) {
        return new VersionMetadata(newVersionId, this.generation + 1, Set.of(this.versionId), System.currentTimeMillis());
    }

    /**
     * Checks if this version is a direct or known ancestor of another version.
     */
    public boolean isAncestorOf(VersionMetadata other) {
        return other.parentVersionIds.contains(this.versionId);
    }

    /**
     * Detects if two versions are in a concurrent conflict.
     * Conflict occurs when neither version is an ancestor of the other.
     */
    public boolean conflictsWith(VersionMetadata other) {
        if (this.equals(other)) return false;
        return !isAncestorOf(other) && !other.isAncestorOf(this);
    }

    public String getVersionId() {
        return versionId;
    }

    public long getGeneration() {
        return generation;
    }

    public Set<String> getParentVersionIds() {
        return parentVersionIds;
    }

    public long getPhysicalTimestampUtcMs() {
        return physicalTimestampUtcMs;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof VersionMetadata that)) return false;
        return generation == that.generation &&
                Objects.equals(versionId, that.versionId) &&
                Objects.equals(parentVersionIds, that.parentVersionIds);
    }

    @Override
    public int hashCode() {
        return Objects.hash(versionId, generation, parentVersionIds);
    }

    @Override
    public String toString() {
        return "VersionMetadata[id=" + versionId + ", gen=" + generation + ", parents=" + parentVersionIds + "]";
    }
}
