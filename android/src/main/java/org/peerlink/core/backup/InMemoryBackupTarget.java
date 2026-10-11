package org.peerlink.core.backup;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory implementation of BackupTarget for portable testing and fast execution.
 */
public class InMemoryBackupTarget implements BackupTarget {
    protected final Map<String, byte[]> payloads = new ConcurrentHashMap<>();
    protected final Map<String, BackupManifest> manifests = new ConcurrentHashMap<>();

    @Override
    public void storePayload(String storageHash, byte[] data) throws IOException {
        payloads.put(storageHash, data.clone());
    }

    @Override
    public byte[] retrievePayload(String storageHash) throws IOException {
        byte[] data = payloads.get(storageHash);
        if (data == null) throw new IOException("Payload not found: " + storageHash);
        return data.clone();
    }

    @Override
    public boolean hasPayload(String storageHash) {
        return payloads.containsKey(storageHash);
    }

    @Override
    public void deletePayload(String storageHash) throws IOException {
        payloads.remove(storageHash);
    }

    @Override
    public void saveManifest(BackupManifest manifest) throws IOException {
        manifests.put(manifest.getBackupId(), manifest);
    }

    @Override
    public Optional<BackupManifest> getManifest(String backupId) {
        return Optional.ofNullable(manifests.get(backupId));
    }

    @Override
    public List<BackupManifest> listManifests(String jobId) {
        return manifests.values().stream()
                .filter(m -> m.getJobId().equals(jobId))
                .sorted(Comparator.comparingLong(BackupManifest::getSnapshotTimestampUtcMs))
                .toList();
    }

    @Override
    public void deleteManifest(String backupId) throws IOException {
        manifests.remove(backupId);
    }

    @Override
    public boolean isBlind() {
        return false;
    }

    @Override
    public Set<String> listStoredPayloadHashes() {
        return Set.copyOf(payloads.keySet());
    }

    @Override
    public long getStorageUsageBytes() {
        return payloads.values().stream().mapToLong(p -> p.length).sum();
    }
}