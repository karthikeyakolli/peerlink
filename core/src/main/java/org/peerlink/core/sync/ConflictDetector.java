package org.peerlink.core.sync;

import java.util.*;

/**
 * Detects sync conflicts by comparing local and remote object states using causal versions.
 *
 * <p>Rules:
 * <ul>
 *   <li>Timestamps are NOT the conflict authority. Only causal (vector clock) ordering is used.</li>
 *   <li>CONCURRENT causal versions → conflict must be surfaced to user or policy.</li>
 *   <li>DOMINATES → winning side's change is applied without conflict.</li>
 *   <li>EQUAL → no action needed (already converged).</li>
 * </ul>
 */
public final class ConflictDetector {

    /**
     * Detect conflicts between local and remote manifest states.
     * Returns a list of ConflictRecords that require resolution.
     */
    public List<ConflictRecord> detect(SyncManifest local, SyncManifest remote) {
        List<ConflictRecord> conflicts = new ArrayList<>();
        Set<ObjectId> conflictedObjectIds = new HashSet<>();

        for (SyncObject remoteObj : remote.allObjects()) {
            local.findById(remoteObj.getObjectId()).ifPresent(localObj -> {
                CausalVersion.Relation rel = localObj.getCausalVersion().relatedTo(remoteObj.getCausalVersion());

                if (rel == CausalVersion.Relation.CONCURRENT) {
                    // Determine conflict type
                    ConflictType type = classifyConflict(localObj, remoteObj, local, remote);
                    conflicts.add(new ConflictRecord(localObj.getObjectId(), type, localObj, remoteObj));
                    conflictedObjectIds.add(localObj.getObjectId());
                }
                // DOMINATES, DOMINATED_BY, EQUAL → no conflict (resolved by causality)
            });

            // Check: remote object exists but local has a tombstone (delete vs modify)
            local.getTombstone(remoteObj.getObjectId()).ifPresent(tombstone -> {
                CausalVersion.Relation rel = tombstone.getDeletionCausalVersion()
                        .relatedTo(remoteObj.getCausalVersion());
                if (rel == CausalVersion.Relation.CONCURRENT) {
                    // One peer deleted, other continued modifying — concurrent
                    conflicts.add(new ConflictRecord(remoteObj.getObjectId(),
                            ConflictType.DELETE_VS_MODIFY, null, remoteObj));
                    conflictedObjectIds.add(remoteObj.getObjectId());
                }
            });

            // Path collision 1: BOTH_CREATED_SAME_PATH (different objectIds at same relativePath)
            local.findByPath(remoteObj.getRelativePath()).ifPresent(localObj -> {
                if (!localObj.getObjectId().equals(remoteObj.getObjectId())
                        && !conflictedObjectIds.contains(localObj.getObjectId())) {
                    conflicts.add(new ConflictRecord(localObj.getObjectId(),
                            ConflictType.BOTH_CREATED_SAME_PATH, localObj, remoteObj));
                    conflictedObjectIds.add(localObj.getObjectId());
                    conflictedObjectIds.add(remoteObj.getObjectId());
                }
            });

            // Path collision 2: TOMBSTONE_VS_NEW_OBJECT (local deleted an old file, remote created new object at same path)
            if (local.findByPath(remoteObj.getRelativePath()).isEmpty()
                    && !conflictedObjectIds.contains(remoteObj.getObjectId())) {
                for (Tombstone lt : local.allTombstones()) {
                    if (lt.getDeletedAtRelativePath().equals(remoteObj.getRelativePath())
                            && !lt.getObjectId().equals(remoteObj.getObjectId())) {
                        conflicts.add(new ConflictRecord(remoteObj.getObjectId(),
                                ConflictType.TOMBSTONE_VS_NEW_OBJECT, null, remoteObj));
                        conflictedObjectIds.add(remoteObj.getObjectId());
                        break;
                    }
                }
            }
        }

        // Check: remote has tombstone for something local still has
        for (Tombstone remoteTombstone : remote.allTombstones()) {
            local.findById(remoteTombstone.getObjectId()).ifPresent(localObj -> {
                if (!conflictedObjectIds.contains(localObj.getObjectId())) {
                    CausalVersion.Relation rel = localObj.getCausalVersion()
                            .relatedTo(remoteTombstone.getDeletionCausalVersion());
                    if (rel == CausalVersion.Relation.CONCURRENT) {
                        conflicts.add(new ConflictRecord(localObj.getObjectId(),
                                ConflictType.DELETE_VS_MODIFY, localObj, null));
                        conflictedObjectIds.add(localObj.getObjectId());
                    }
                }
            });

            // Path collision 3: remote tombstone at same path as active local object with different objectId
            local.findByPath(remoteTombstone.getDeletedAtRelativePath()).ifPresent(localObj -> {
                if (!localObj.getObjectId().equals(remoteTombstone.getObjectId())
                        && !conflictedObjectIds.contains(localObj.getObjectId())) {
                    conflicts.add(new ConflictRecord(localObj.getObjectId(),
                            ConflictType.TOMBSTONE_VS_NEW_OBJECT, localObj, null));
                    conflictedObjectIds.add(localObj.getObjectId());
                }
            });
        }

        return conflicts;
    }

    private ConflictType classifyConflict(SyncObject local, SyncObject remote,
                                           SyncManifest localManifest, SyncManifest remoteManifest) {
        boolean pathDiffers = !local.getRelativePath().equals(remote.getRelativePath());
        boolean contentDiffers = local.getContentHash() != null && remote.getContentHash() != null
                && !local.getContentHash().equals(remote.getContentHash());

        if (pathDiffers && !contentDiffers) return ConflictType.CONCURRENT_RENAME;
        if (pathDiffers) return ConflictType.CONCURRENT_MOVE;
        return ConflictType.CONCURRENT_CONTENT_EDIT;
    }
}