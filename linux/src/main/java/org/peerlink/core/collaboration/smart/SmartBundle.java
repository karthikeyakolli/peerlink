package org.peerlink.core.collaboration.smart;

import org.peerlink.core.model.ObjectIdentity;

import java.io.Serializable;
import java.util.*;

/**
 * Logical bundle of interdependent objects transferred and verified atomically.
 */
public final class SmartBundle implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String bundleId;
    private final String title;
    private final List<ObjectIdentity> objectIds;
    private final Map<String, String> metadata;
    private final long createdAtUtcMs;

    public SmartBundle(String bundleId, String title, List<ObjectIdentity> objectIds, Map<String, String> metadata) {
        this.bundleId = Objects.requireNonNull(bundleId, "bundleId is required");
        this.title = Objects.requireNonNull(title, "title is required");
        this.objectIds = List.copyOf(Objects.requireNonNull(objectIds, "objectIds is required"));
        this.metadata = metadata == null ? Map.of() : Map.copyOf(metadata);
        this.createdAtUtcMs = System.currentTimeMillis();
    }

    public String getBundleId() { return bundleId; }
    public String getTitle() { return title; }
    public List<ObjectIdentity> getObjectIds() { return objectIds; }
    public Map<String, String> getMetadata() { return metadata; }
    public long getCreatedAtUtcMs() { return createdAtUtcMs; }
}