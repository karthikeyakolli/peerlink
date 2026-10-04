package org.peerlink.core.backup;

import java.nio.file.Path;
import java.util.Objects;
import java.util.Set;

public final class BackupJobConfig {
    private final String jobId;
    private final String name;
    private final Path sourceDirectory;
    private final String targetPeerId;
    private final RetentionPolicy retentionPolicy;
    private final boolean blindBackup;
    private final byte[] blindEncryptionKey; // Held strictly by client
    private final Set<String> includeExtensions;
    private final Set<String> excludePaths;

    public BackupJobConfig(String jobId,
                           String name,
                           Path sourceDirectory,
                           String targetPeerId,
                           RetentionPolicy retentionPolicy,
                           boolean blindBackup,
                           byte[] blindEncryptionKey,
                           Set<String> includeExtensions,
                           Set<String> excludePaths) {
        this.jobId = Objects.requireNonNull(jobId, "jobId cannot be null");
        this.name = Objects.requireNonNull(name, "name cannot be null");
        this.sourceDirectory = Objects.requireNonNull(sourceDirectory, "sourceDirectory cannot be null");
        this.targetPeerId = targetPeerId;
        this.retentionPolicy = retentionPolicy != null ? retentionPolicy : RetentionPolicy.keepLastN(5);
        this.blindBackup = blindBackup;
        this.blindEncryptionKey = blindEncryptionKey != null ? blindEncryptionKey.clone() : null;
        this.includeExtensions = includeExtensions != null ? Set.copyOf(includeExtensions) : Set.of();
        this.excludePaths = excludePaths != null ? Set.copyOf(excludePaths) : Set.of();
    }

    public String getJobId() { return jobId; }
    public String getName() { return name; }
    public Path getSourceDirectory() { return sourceDirectory; }
    public String getTargetPeerId() { return targetPeerId; }
    public RetentionPolicy getRetentionPolicy() { return retentionPolicy; }
    public boolean isBlindBackup() { return blindBackup; }
    public byte[] getBlindEncryptionKey() { return blindEncryptionKey != null ? blindEncryptionKey.clone() : null; }
    public Set<String> getIncludeExtensions() { return includeExtensions; }
    public Set<String> getExcludePaths() { return excludePaths; }
}