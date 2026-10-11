package org.peerlink.core.backup;

import java.io.IOException;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Destination repository for backups.
 * SEMANTICS:
 * - Receive-only by default (source -> backup target).
 * - Never initiates sync back to source.
 * - Does not possess bidirectional sync logic.
 */
public interface BackupTarget {
    void storePayload(String storageHash, byte[] data) throws IOException;
    byte[] retrievePayload(String storageHash) throws IOException;
    boolean hasPayload(String storageHash);
    void deletePayload(String storageHash) throws IOException;

    void saveManifest(BackupManifest manifest) throws IOException;
    Optional<BackupManifest> getManifest(String backupId);
    List<BackupManifest> listManifests(String jobId);
    void deleteManifest(String backupId) throws IOException;

    boolean isBlind();
    Set<String> listStoredPayloadHashes();
    long getStorageUsageBytes();
}