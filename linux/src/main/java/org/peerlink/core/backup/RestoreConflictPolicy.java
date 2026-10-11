package org.peerlink.core.backup;

public enum RestoreConflictPolicy {
    OVERWRITE_WITH_NEW_VERSION,
    FAIL_ON_CONFLICT,
    RESTORE_TO_ALTERNATIVE_PATH
}