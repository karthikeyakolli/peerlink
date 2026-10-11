package org.peerlink.core.sync;

/** Classification of a sync conflict. */
public enum ConflictType {
    CONCURRENT_CONTENT_EDIT,     // both peers modified the same file independently
    DELETE_VS_MODIFY,            // one peer deleted, another modified
    CONCURRENT_RENAME,           // both peers renamed the same object differently
    CONCURRENT_MOVE,             // both peers moved the object to different locations
    BOTH_CREATED_SAME_PATH,      // two peers created different objects at the same path
    TOMBSTONE_VS_NEW_OBJECT      // deleted object vs new object with same path
}