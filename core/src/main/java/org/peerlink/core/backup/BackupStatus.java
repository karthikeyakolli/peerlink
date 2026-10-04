package org.peerlink.core.backup;

public enum BackupStatus {
    PENDING,
    IN_PROGRESS,
    COMPLETED,
    FAILED,
    CANCELLED,
    VERIFYING,
    PRUNING
}