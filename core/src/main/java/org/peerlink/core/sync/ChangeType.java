package org.peerlink.core.sync;

/** The type of change detected on a sync object. */
public enum ChangeType {
    CONTENT_MODIFIED,    // file bytes changed
    METADATA_CHANGED,    // rename, move, or permission change only
    CREATED,             // new object not previously tracked
    DELETED,             // object removed from filesystem
    DUPLICATE_CONTENT,   // same bytes as another object — NOT merged (objectId != contentHash)
    WATCHER_HINT         // filesystem event received; needs verification via reconciliation
}