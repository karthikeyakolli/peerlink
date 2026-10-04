package org.peerlink.core.backup;

import org.peerlink.core.model.ObjectIdentity;

import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;

/**
 * Immutable snapshot manifest of a completed backup run.
 */
public final class BackupManifest implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String backupId;
    private final String jobId;
    private final BackupType type;
    private final long snapshotTimestampUtcMs;
    private final String parentBackupId;
    private final Map<ObjectIdentity, HistoricalVersion> items;
    private final Map<String, ObjectIdentity> pathIndex;
    private final long totalFiles;
    private final long totalBytes;
    private final boolean blind;
    private final String manifestDigest;

    public BackupManifest(String backupId,
                          String jobId,
                          BackupType type,
                          long snapshotTimestampUtcMs,
                          String parentBackupId,
                          Map<ObjectIdentity, HistoricalVersion> items,
                          boolean blind) {
        this.backupId = Objects.requireNonNull(backupId, "backupId cannot be null");
        this.jobId = Objects.requireNonNull(jobId, "jobId cannot be null");
        this.type = Objects.requireNonNull(type, "type cannot be null");
        this.snapshotTimestampUtcMs = snapshotTimestampUtcMs;
        this.parentBackupId = parentBackupId;
        this.items = Map.copyOf(items);

        Map<String, ObjectIdentity> paths = new HashMap<>();
        long fileCount = 0;
        long byteCount = 0;
        for (HistoricalVersion v : this.items.values()) {
            paths.put(v.getRelativePath(), v.getObjectId());
            if (!v.isDeleted()) {
                fileCount++;
                byteCount += v.getSizeBytes();
            }
        }
        this.pathIndex = Map.copyOf(paths);
        this.totalFiles = fileCount;
        this.totalBytes = byteCount;
        this.blind = blind;
        this.manifestDigest = computeDigest(this.backupId, this.jobId, this.snapshotTimestampUtcMs, this.items);
    }

    private static String computeDigest(String backupId, String jobId, long timestamp, Map<ObjectIdentity, HistoricalVersion> items) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(backupId.getBytes(StandardCharsets.UTF_8));
            md.update(jobId.getBytes(StandardCharsets.UTF_8));
            md.update(String.valueOf(timestamp).getBytes(StandardCharsets.UTF_8));
            List<HistoricalVersion> sorted = new ArrayList<>(items.values());
            sorted.sort(Comparator.comparing(HistoricalVersion::getRelativePath));
            for (HistoricalVersion h : sorted) {
                md.update(h.getRelativePath().getBytes(StandardCharsets.UTF_8));
                md.update(h.getStorageHash().getBytes(StandardCharsets.UTF_8));
                md.update(String.valueOf(h.getVersionSequence()).getBytes(StandardCharsets.UTF_8));
            }
            return HexFormat.of().formatHex(md.digest());
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    public String getBackupId() { return backupId; }
    public String getJobId() { return jobId; }
    public BackupType getType() { return type; }
    public long getSnapshotTimestampUtcMs() { return snapshotTimestampUtcMs; }
    public String getParentBackupId() { return parentBackupId; }
    public Map<ObjectIdentity, HistoricalVersion> getItems() { return items; }
    public long getTotalFiles() { return totalFiles; }
    public long getTotalBytes() { return totalBytes; }
    public boolean isBlind() { return blind; }
    public String getManifestDigest() { return manifestDigest; }

    public Optional<HistoricalVersion> getItem(ObjectIdentity id) {
        return Optional.ofNullable(items.get(id));
    }

    public Optional<HistoricalVersion> getItemByPath(String relativePath) {
        ObjectIdentity id = pathIndex.get(relativePath);
        if (id == null) return Optional.empty();
        return Optional.ofNullable(items.get(id));
    }

    public List<HistoricalVersion> getActiveItems() {
        return items.values().stream().filter(i -> !i.isDeleted()).toList();
    }

    public List<HistoricalVersion> getDeletedItems() {
        return items.values().stream().filter(HistoricalVersion::isDeleted).toList();
    }

    public boolean hasProtectedItems() {
        return items.values().stream().anyMatch(HistoricalVersion::isProtected);
    }
}