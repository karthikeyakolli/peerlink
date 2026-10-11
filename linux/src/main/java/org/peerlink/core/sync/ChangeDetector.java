package org.peerlink.core.sync;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;

/**
 * Detects changes between a known manifest state and current observed filesystem state.
 *
 * <p>Design rules:
 * <ul>
 *   <li>Watcher events are HINTS — always verify via periodic scan before applying.</li>
 *   <li>Content hash is the source of truth for content changes, not timestamps.</li>
 *   <li>Timestamps are used only to short-circuit expensive hashing when unchanged.</li>
 *   <li>Duplicate content (same hash, different objectId) is reported but NOT merged.</li>
 *   <li>Periodic reconciliation is always required regardless of watcher health.</li>
 * </ul>
 */
public final class ChangeDetector {

    /**
     * Observed filesystem entry — provided by scanner or watcher.
     */
    public record FsEntry(
            String relativePath,
            String contentHash,
            long sizeBytes,
            long lastModifiedMs,
            boolean isDirectory
    ) {}

    /**
     * Compare current manifest against observed filesystem entries.
     * Returns a list of detected changes that require processing.
     */
    public List<DetectedChange> detect(SyncManifest manifest, List<FsEntry> observed, boolean fromWatcher) {
        List<DetectedChange> changes = new ArrayList<>();

        // Build lookup of observed entries by path
        Map<String, FsEntry> observedByPath = new HashMap<>();
        for (FsEntry e : observed) observedByPath.put(e.relativePath(), e);

        // Build set of known content hashes for duplicate detection
        Map<String, ObjectId> knownHashes = new HashMap<>();
        for (SyncObject obj : manifest.allObjects()) {
            if (obj.getContentHash() != null) {
                knownHashes.put(obj.getContentHash(), obj.getObjectId());
            }
        }

        // Check each known object for changes
        for (SyncObject obj : manifest.allObjects()) {
            FsEntry entry = observedByPath.get(obj.getRelativePath());
            if (entry == null) {
                // Possibly renamed/moved or deleted
                // Check if path disappeared entirely
                changes.add(new DetectedChange(obj.getObjectId(), obj.getRelativePath(),
                        ChangeType.DELETED, null, 0, 0, fromWatcher));
            } else {
                observedByPath.remove(obj.getRelativePath()); // mark as processed
                if (!obj.isDirectory() && entry.contentHash() != null
                        && !entry.contentHash().equals(obj.getContentHash())) {
                    // Content changed
                    ChangeType ct = ChangeType.CONTENT_MODIFIED;
                    // Check for duplicate content (same hash as another object)
                    if (knownHashes.containsKey(entry.contentHash())
                            && !knownHashes.get(entry.contentHash()).equals(obj.getObjectId())) {
                        ct = ChangeType.DUPLICATE_CONTENT;
                    }
                    changes.add(new DetectedChange(obj.getObjectId(), obj.getRelativePath(),
                            ct, entry.contentHash(), entry.sizeBytes(), entry.lastModifiedMs(), fromWatcher));
                } else if (!entry.relativePath().equals(obj.getRelativePath())) {
                    changes.add(new DetectedChange(obj.getObjectId(), entry.relativePath(),
                            ChangeType.METADATA_CHANGED, null, entry.sizeBytes(), entry.lastModifiedMs(), fromWatcher));
                }
            }
        }

        // Remaining observed entries are new
        for (FsEntry entry : observedByPath.values()) {
            // Check for duplicate content
            ChangeType ct = ChangeType.CREATED;
            if (entry.contentHash() != null && knownHashes.containsKey(entry.contentHash())) {
                ct = ChangeType.DUPLICATE_CONTENT;
            }
            changes.add(new DetectedChange(null, entry.relativePath(),
                    ct, entry.contentHash(), entry.sizeBytes(), entry.lastModifiedMs(), fromWatcher));
        }

        return changes;
    }

    /** Compute SHA-256 content hash of byte content (test utility). */
    public static String sha256(byte[] content) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(content);
            StringBuilder sb = new StringBuilder(64);
            for (byte b : digest) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    public static String sha256(String text) {
        return sha256(text.getBytes(StandardCharsets.UTF_8));
    }
}