package org.peerlink.core.sync;

import java.util.List;

/**
 * Result of a sync dry-run — what WOULD happen without actually applying changes.
 *
 * <p>A dry-run must be complete and accurate. It surfaces:
 * <ul>
 *   <li>Objects that would be sent to remote.</li>
 *   <li>Objects that would be received from remote.</li>
 *   <li>Conflicts that would be raised.</li>
 *   <li>Deletions that would be propagated.</li>
 *   <li>Mass-change warnings.</li>
 * </ul>
 */
public record SyncDryRunResult(
        List<SyncObject> wouldSendToRemote,
        List<SyncObject> wouldReceiveFromRemote,
        List<ConflictRecord> wouldConflict,
        List<Tombstone> wouldPropagateDeletions,
        List<String> massChangeWarnings,
        long estimatedBytesToTransfer,
        boolean massChangeProtectionTriggered
) {
    public boolean isClean() {
        return wouldConflict.isEmpty() && !massChangeProtectionTriggered;
    }
}