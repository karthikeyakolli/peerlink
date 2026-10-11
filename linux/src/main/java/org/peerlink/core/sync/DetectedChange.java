package org.peerlink.core.sync;

/**
 * A single change detected during scan or watcher notification.
 *
 * <p>Watcher events are HINTS only. Every detected change must be verified by
 * the reconciler against actual filesystem state before being committed.
 */
public record DetectedChange(
        ObjectId objectId,          // null for CREATED (not yet assigned)
        String relativePath,
        ChangeType changeType,
        String newContentHash,      // null for non-content changes
        long newSizeBytes,
        long lastModifiedHintMs,    // hint — NOT authoritative for conflicts
        boolean fromWatcher         // true = hint from FS watcher; false = from periodic scan
) {
    public boolean requiresVerification() { return fromWatcher; }
}