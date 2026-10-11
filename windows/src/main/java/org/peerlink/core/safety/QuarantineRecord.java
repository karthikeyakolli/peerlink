package org.peerlink.core.safety;

import org.peerlink.core.model.ContentHash;

import java.nio.file.Path;
import java.util.Objects;

public record QuarantineRecord(
        String quarantineId,
        Path stagedFile,
        String originalRelativePath,
        ContentHash expectedHash,
        long sizeBytes,
        String sourcePeerId,
        long receivedAtUtcMs,
        QuarantineStatus status
) {
    public enum QuarantineStatus {
        STAGED,
        VERIFIED,
        HELD_SUSPICIOUS,
        QUARANTINED_MALICIOUS,
        COMMITTED,
        REJECTED_DELETED
    }

    public QuarantineRecord withStatus(QuarantineStatus newStatus) {
        return new QuarantineRecord(quarantineId, stagedFile, originalRelativePath,
                expectedHash, sizeBytes, sourcePeerId, receivedAtUtcMs, newStatus);
    }
}