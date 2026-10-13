package org.peerlink.core.sync;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Complete snapshot of the sync state for a single peer's sync root.
 *
 * <p>Contains:
 * <ul>
 *   <li>All tracked {@link SyncObject}s (keyed by stable {@link ObjectId}).</li>
 *   <li>Path-to-ObjectId index for fast lookup by current path.</li>
 *   <li>All live {@link Tombstone}s for deleted objects.</li>
 *   <li>The {@link CausalVersion} of this manifest itself.</li>
 * </ul>
 *
 * <p>Watcher events are hints — the manifest must be reconciled periodically
 * against the actual filesystem state to detect missed events.
 */
public final class SyncManifest {

    private final String localPeerId;
    private final Map<ObjectId, SyncObject> objects = new ConcurrentHashMap<>();
    private final Map<String, ObjectId> pathIndex = new ConcurrentHashMap<>();  // relativePath → objectId
    private final Map<ObjectId, Tombstone> tombstones = new ConcurrentHashMap<>();
    private volatile CausalVersion manifestCausalVersion;

    public SyncManifest(String localPeerId) {
        this.localPeerId = localPeerId;
        this.manifestCausalVersion = CausalVersion.empty();
    }

    // ── Object tracking ──────────────────────────────────────────────────────

    public void trackObject(SyncObject obj) {
        objects.put(obj.getObjectId(), obj);
        pathIndex.put(obj.getRelativePath(), obj.getObjectId());
        manifestCausalVersion = manifestCausalVersion.merge(obj.getCausalVersion());
    }

    public void updatePath(ObjectId id, String oldPath, String newPath) {
        pathIndex.remove(oldPath);
        pathIndex.put(newPath, id);
    }

    public Optional<SyncObject> findById(ObjectId id) {
        return Optional.ofNullable(objects.get(id));
    }

    public Optional<SyncObject> findByPath(String relativePath) {
        ObjectId id = pathIndex.get(relativePath);
        if (id == null) return Optional.empty();
        return Optional.ofNullable(objects.get(id));
    }

    public void recordDeletion(SyncObject obj, String deletingPeerId) {
        long now = System.currentTimeMillis();
        Tombstone t = new Tombstone(obj.getObjectId(), obj.getRelativePath(),
                obj.getCausalVersion(), deletingPeerId, now);
        recordTombstone(t);
        manifestCausalVersion = manifestCausalVersion.increment(deletingPeerId);
    }

    public void recordTombstone(Tombstone tombstone) {
        tombstones.put(tombstone.getObjectId(), tombstone);
        SyncObject existing = objects.remove(tombstone.getObjectId());
        if (existing != null) {
            pathIndex.remove(existing.getRelativePath());
        }
        manifestCausalVersion = manifestCausalVersion.merge(tombstone.getDeletionCausalVersion());
    }

    public void applyOrTrackObject(SyncObject obj) {
        SyncObject existing = objects.get(obj.getObjectId());
        if (existing != null && !existing.getRelativePath().equals(obj.getRelativePath())) {
            pathIndex.remove(existing.getRelativePath());
        }
        objects.put(obj.getObjectId(), obj);
        pathIndex.put(obj.getRelativePath(), obj.getObjectId());
        tombstones.remove(obj.getObjectId());
        manifestCausalVersion = manifestCausalVersion.merge(obj.getCausalVersion());
    }

    public void removeObject(ObjectId id) {
        SyncObject removed = objects.remove(id);
        if (removed != null) {
            pathIndex.remove(removed.getRelativePath());
        }
    }

    // ── Tombstone management ─────────────────────────────────────────────────

    public Optional<Tombstone> getTombstone(ObjectId id) {
        return Optional.ofNullable(tombstones.get(id));
    }

    public boolean hasTombstone(ObjectId id) { return tombstones.containsKey(id); }

    public void gcTombstone(ObjectId id) {
        Tombstone t = tombstones.get(id);
        if (t != null && t.isSafeToGarbageCollect()) {
            tombstones.remove(id);
        }
    }

    // ── Accessors ────────────────────────────────────────────────────────────

    public Collection<SyncObject> allObjects() { return Collections.unmodifiableCollection(objects.values()); }
    public Collection<Tombstone> allTombstones() { return Collections.unmodifiableCollection(tombstones.values()); }
    public CausalVersion getManifestCausalVersion() { return manifestCausalVersion; }
    public String getLocalPeerId() { return localPeerId; }
    public int objectCount() { return objects.size(); }
    public int tombstoneCount() { return tombstones.size(); }
}