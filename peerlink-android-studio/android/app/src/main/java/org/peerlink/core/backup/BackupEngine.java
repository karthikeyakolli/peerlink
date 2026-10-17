package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;

import java.io.IOException;
import java.nio.file.*;
import java.security.GeneralSecurityException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Stream;

/**
 * Backup Engine.
 *
 * INVARIANTS:
 * - Unidirectional (source -> backup target). Receive-only by default.
 * - Does not perform bidirectional sync.
 * - Restore creates a NEW current version. Never rewrite history.
 * - Blind backup: target stores only ciphertext; does not possess decryption keys.
 * - Transport encryption and storage encryption are conceptually separate.
 * - Active operation / recovery locks protect snapshots from retention pruning during in-flight operations.
 */
public final class BackupEngine {

    private final BackupTarget target;
    private final Set<String> protectedSnapshots = ConcurrentHashMap.newKeySet();
    private final Set<String> activeRecoveryLocks = ConcurrentHashMap.newKeySet();
    private final Map<String, ObjectIdentity> pathToIdentity = new ConcurrentHashMap<>();
    private final Map<ObjectIdentity, Long> objectVersionSequences = new ConcurrentHashMap<>();
    private final java.util.concurrent.atomic.AtomicLong lastSnapshotTimestamp = new java.util.concurrent.atomic.AtomicLong();

    public BackupEngine(BackupTarget target) {
        this.target = Objects.requireNonNull(target, "target cannot be null");
    }

    private long nextMonotonicTimestamp() {
        long now = System.currentTimeMillis();
        return lastSnapshotTimestamp.updateAndGet(prev -> Math.max(now, prev + 1));
    }

    public BackupTarget getTarget() {
        return target;
    }

    public void protectSnapshot(String backupId) {
        protectedSnapshots.add(backupId);
    }

    public void unprotectSnapshot(String backupId) {
        protectedSnapshots.remove(backupId);
    }

    public boolean isSnapshotProtected(String backupId) {
        return protectedSnapshots.contains(backupId);
    }

    public void acquireRecoveryLock(String backupId) {
        Objects.requireNonNull(backupId, "backupId cannot be null");
        activeRecoveryLocks.add(backupId);
    }

    public void releaseRecoveryLock(String backupId) {
        if (backupId != null) {
            activeRecoveryLocks.remove(backupId);
        }
    }

    public boolean isRecoveryLocked(String backupId) {
        return backupId != null && activeRecoveryLocks.contains(backupId);
    }

    public Set<String> getActiveRecoveryLocks() {
        return Set.copyOf(activeRecoveryLocks);
    }

    public BackupManifest performBackup(BackupJobConfig config, BackupType type) throws IOException {
        Objects.requireNonNull(config, "config cannot be null");

        Path sourceDir = config.getSourceDirectory();
        if (!Files.exists(sourceDir)) {
            throw new NoSuchFileException("Source directory does not exist: " + sourceDir);
        }

        List<BackupManifest> existing = target.listManifests(config.getJobId());
        BackupManifest baseline = existing.isEmpty() ? null : existing.get(existing.size() - 1);

        String backupId = "bkp_" + UUID.randomUUID().toString().replace("-", "");
        long timestamp = nextMonotonicTimestamp();
        String parentId = (type != BackupType.FULL && baseline != null) ? baseline.getBackupId() : null;

        Map<ObjectIdentity, HistoricalVersion> items = new HashMap<>();

        // Scan files in source
        List<Path> files = new ArrayList<>();
        try (Stream<Path> stream = Files.walk(sourceDir)) {
            stream.filter(Files::isRegularFile).forEach(p -> {
                String rel = sourceDir.relativize(p).toString().replace('\\', '/');
                if (shouldInclude(rel, config)) {
                    files.add(p);
                }
            });
        }

        Set<String> scannedRelPaths = new HashSet<>();

        for (Path file : files) {
            if (!Files.isReadable(file)) {
                throw new AccessDeniedException("Source file permission denied: " + file);
            }

            String relPath = sourceDir.relativize(file).toString().replace('\\', '/');
            scannedRelPaths.add(relPath);

            byte[] content = Files.readAllBytes(file);
            ContentHash contentHash = ContentHash.computeSha256(content);

            ObjectIdentity objectId = pathToIdentity.computeIfAbsent(relPath, k -> ObjectIdentity.generate());
            long currentSeq = objectVersionSequences.getOrDefault(objectId, 0L);

            // Check if identical to previous baseline
            if (baseline != null && type != BackupType.FULL) {
                Optional<HistoricalVersion> prev = baseline.getItemByPath(relPath);
                if (prev.isPresent() && !prev.get().isDeleted() && contentHash.equals(prev.get().getContentHash())) {
                    // Content unchanged! Reuse previous storageHash without storing redundant payload
                    HistoricalVersion reused = new HistoricalVersion(
                            objectId, relPath, contentHash, content.length,
                            prev.get().getVersionSequence(), timestamp, false,
                            prev.get().getStorageHash(), config.isBlindBackup(), prev.get().isProtected()
                    );
                    items.put(objectId, reused);
                    continue;
                }
            }

            // New or changed file: advance sequence
            long newSeq = currentSeq + 1;
            objectVersionSequences.put(objectId, newSeq);

            // Prepare storage payload
            byte[] storageData;
            if (config.isBlindBackup()) {
                if (config.getBlindEncryptionKey() == null) {
                    throw new IllegalStateException("Blind backup requires encryption key");
                }
                try {
                    storageData = BlindPayloadCipher.encrypt(content, config.getBlindEncryptionKey());
                } catch (GeneralSecurityException e) {
                    throw new IOException("Blind payload encryption failed", e);
                }
            } else {
                storageData = content;
            }

            ContentHash storageHash = ContentHash.computeSha256(storageData);
            target.storePayload(storageHash.getHexString(), storageData);

            HistoricalVersion newVersion = new HistoricalVersion(
                    objectId, relPath, contentHash, content.length,
                    newSeq, timestamp, false,
                    storageHash.getHexString(), config.isBlindBackup(), false
            );
            items.put(objectId, newVersion);
        }

        // Track deletions if incremental
        if (baseline != null && type != BackupType.FULL) {
            for (HistoricalVersion prev : baseline.getItems().values()) {
                if (!prev.isDeleted() && !scannedRelPaths.contains(prev.getRelativePath())) {
                    // File was deleted in source
                    long delSeq = objectVersionSequences.getOrDefault(prev.getObjectId(), prev.getVersionSequence()) + 1;
                    objectVersionSequences.put(prev.getObjectId(), delSeq);

                    HistoricalVersion deletedRecord = new HistoricalVersion(
                            prev.getObjectId(), prev.getRelativePath(), null, 0,
                            delSeq, timestamp, true,
                            "tombstone_" + prev.getStorageHash(), config.isBlindBackup(), prev.isProtected()
                    );
                    items.put(prev.getObjectId(), deletedRecord);
                }
            }
        }

        BackupManifest manifest = new BackupManifest(backupId, config.getJobId(), type,
                timestamp, parentId, items, config.isBlindBackup());
        target.saveManifest(manifest);
        return manifest;
    }

    public BackupManifest performPartialBackup(BackupJobConfig config, Set<String> targetRelativePaths) throws IOException {
        Objects.requireNonNull(config, "config cannot be null");
        Objects.requireNonNull(targetRelativePaths, "targetRelativePaths cannot be null");

        Path sourceDir = config.getSourceDirectory();
        String backupId = "bkp_" + UUID.randomUUID().toString().replace("-", "");
        long timestamp = nextMonotonicTimestamp();

        Map<ObjectIdentity, HistoricalVersion> items = new HashMap<>();

        Path canonicalSource = sourceDir.toAbsolutePath().normalize();
        for (String relPath : targetRelativePaths) {
            if (relPath == null || relPath.isBlank() || relPath.contains("\0") || relPath.contains(":")
                    || relPath.startsWith("/") || relPath.startsWith("\\")
                    || (relPath.length() >= 2 && Character.isLetter(relPath.charAt(0)) && relPath.charAt(1) == ':')) {
                throw new SecurityException("Illegal path traversal sequence in partial backup: " + relPath);
            }

            Path normalizedRel = Path.of(relPath).normalize();
            for (Path part : normalizedRel) {
                if ("..".equals(part.toString())) {
                    throw new SecurityException("Parent directory traversal prohibited: " + relPath);
                }
            }

            Path file = canonicalSource.resolve(normalizedRel).normalize();
            if (!file.startsWith(canonicalSource)) {
                throw new SecurityException("Partial backup path escaped source directory: " + relPath);
            }

            if (!Files.exists(file) || !Files.isRegularFile(file)) continue;
            if (!Files.isReadable(file)) {
                throw new AccessDeniedException("Source file permission denied: " + file);
            }

            byte[] content = Files.readAllBytes(file);
            ContentHash contentHash = ContentHash.computeSha256(content);
            ObjectIdentity objectId = pathToIdentity.computeIfAbsent(relPath, k -> ObjectIdentity.generate());
            long newSeq = objectVersionSequences.getOrDefault(objectId, 0L) + 1;
            objectVersionSequences.put(objectId, newSeq);

            byte[] storageData;
            if (config.isBlindBackup()) {
                try {
                    storageData = BlindPayloadCipher.encrypt(content, config.getBlindEncryptionKey());
                } catch (GeneralSecurityException e) {
                    throw new IOException("Encryption error", e);
                }
            } else {
                storageData = content;
            }

            ContentHash storageHash = ContentHash.computeSha256(storageData);
            target.storePayload(storageHash.getHexString(), storageData);

            HistoricalVersion version = new HistoricalVersion(objectId, relPath, contentHash,
                    content.length, newSeq, timestamp, false, storageHash.getHexString(), config.isBlindBackup(), false);
            items.put(objectId, version);
        }

        BackupManifest manifest = new BackupManifest(backupId, config.getJobId(), BackupType.FULL,
                timestamp, null, items, config.isBlindBackup());
        target.saveManifest(manifest);
        return manifest;
    }

    public void simulateInterruptedBackup(BackupJobConfig config, Path fileToFailOn) throws IOException {
        Path sourceDir = config.getSourceDirectory();
        List<Path> files = new ArrayList<>();
        try (Stream<Path> stream = Files.walk(sourceDir)) {
            stream.filter(Files::isRegularFile).forEach(files::add);
        }

        for (Path f : files) {
            if (f.equals(fileToFailOn)) {
                throw new IOException("Simulated network/power interruption during transfer of " + f.getFileName());
            }
            byte[] content = Files.readAllBytes(f);
            ContentHash h = ContentHash.computeSha256(content);
            target.storePayload(h.getHexString(), content);
        }
    }

    public VersionGarbageCollector.GcResult runRetention(String jobId, RetentionPolicy policy) throws IOException {
        List<BackupManifest> manifests = target.listManifests(jobId);
        RetentionPrunePlan plan = policy.evaluate(manifests, protectedSnapshots, activeRecoveryLocks, System.currentTimeMillis());
        return VersionGarbageCollector.collect(target, jobId, plan);
    }

    public BackupVerificationReport verifyBackup(String backupId, boolean deep, byte[] decryptionKey) throws IOException {
        BackupManifest manifest = target.getManifest(backupId)
                .orElseThrow(() -> new NoSuchElementException("Manifest not found: " + backupId));
        return BackupVerifier.verify(target, manifest, deep, decryptionKey);
    }

    public RestorePlan planRestore(String backupId, Path targetDir, RestoreConflictPolicy policy, Set<String> selectedPaths) throws IOException {
        BackupManifest manifest = target.getManifest(backupId)
                .orElseThrow(() -> new NoSuchElementException("Manifest not found: " + backupId));
        return RestorePlanner.plan(manifest, targetDir, policy, selectedPaths);
    }

    public RestoreDryRunResult dryRunRestore(RestorePlan plan) {
        return RestorePlanner.dryRun(plan);
    }

    public RestoreExecutionResult executeRestore(RestorePlan plan, byte[] blindDecryptionKey, long currentSeq) throws IOException {
        acquireRecoveryLock(plan.backupId());
        try {
            return RestoreExecutor.execute(plan, target, blindDecryptionKey, currentSeq);
        } finally {
            releaseRecoveryLock(plan.backupId());
        }
    }

    // ── Version Discovery APIs ───────────────────────────────────────────────

    public List<HistoricalVersionInfo> discoverVersions(String jobId, String relativePath) {
        Objects.requireNonNull(jobId, "jobId cannot be null");
        Objects.requireNonNull(relativePath, "relativePath cannot be null");
        List<BackupManifest> manifests = target.listManifests(jobId);
        List<HistoricalVersionInfo> history = new ArrayList<>();

        for (BackupManifest manifest : manifests) {
            manifest.getItemByPath(relativePath).ifPresent(v -> {
                boolean isProtected = v.isProtected() || isSnapshotProtected(manifest.getBackupId());
                history.add(new HistoricalVersionInfo(
                        manifest.getBackupId(), manifest.getJobId(), manifest.getSnapshotTimestampUtcMs(),
                        v.getObjectId(), v.getRelativePath(), v.getContentHash(), v.getSizeBytes(),
                        v.getVersionSequence(), v.isDeleted(), v.getStorageHash(), v.isEncrypted(), isProtected
                ));
            });
        }

        history.sort(Comparator.comparingLong(HistoricalVersionInfo::versionSequence));
        return Collections.unmodifiableList(history);
    }

    public List<HistoricalVersionInfo> discoverVersionsByObjectId(String jobId, ObjectIdentity objectId) {
        Objects.requireNonNull(jobId, "jobId cannot be null");
        Objects.requireNonNull(objectId, "objectId cannot be null");
        List<BackupManifest> manifests = target.listManifests(jobId);
        List<HistoricalVersionInfo> history = new ArrayList<>();

        for (BackupManifest manifest : manifests) {
            manifest.getItem(objectId).ifPresent(v -> {
                boolean isProtected = v.isProtected() || isSnapshotProtected(manifest.getBackupId());
                history.add(new HistoricalVersionInfo(
                        manifest.getBackupId(), manifest.getJobId(), manifest.getSnapshotTimestampUtcMs(),
                        v.getObjectId(), v.getRelativePath(), v.getContentHash(), v.getSizeBytes(),
                        v.getVersionSequence(), v.isDeleted(), v.getStorageHash(), v.isEncrypted(), isProtected
                ));
            });
        }

        history.sort(Comparator.comparingLong(HistoricalVersionInfo::versionSequence));
        return Collections.unmodifiableList(history);
    }

    public Map<String, List<HistoricalVersionInfo>> discoverAllFileHistories(String jobId) {
        Objects.requireNonNull(jobId, "jobId cannot be null");
        List<BackupManifest> manifests = target.listManifests(jobId);
        Map<String, List<HistoricalVersionInfo>> map = new LinkedHashMap<>();

        for (BackupManifest manifest : manifests) {
            for (HistoricalVersion v : manifest.getItems().values()) {
                boolean isProtected = v.isProtected() || isSnapshotProtected(manifest.getBackupId());
                map.computeIfAbsent(v.getRelativePath(), k -> new ArrayList<>())
                   .add(new HistoricalVersionInfo(
                           manifest.getBackupId(), manifest.getJobId(), manifest.getSnapshotTimestampUtcMs(),
                           v.getObjectId(), v.getRelativePath(), v.getContentHash(), v.getSizeBytes(),
                           v.getVersionSequence(), v.isDeleted(), v.getStorageHash(), v.isEncrypted(), isProtected
                   ));
            }
        }

        map.values().forEach(list -> list.sort(Comparator.comparingLong(HistoricalVersionInfo::versionSequence)));
        return Collections.unmodifiableMap(map);
    }

    public List<String> listSnapshotsContaining(String jobId, String relativePath) {
        Objects.requireNonNull(jobId, "jobId cannot be null");
        Objects.requireNonNull(relativePath, "relativePath cannot be null");
        return target.listManifests(jobId).stream()
                .filter(m -> m.getItemByPath(relativePath).filter(v -> !v.isDeleted()).isPresent())
                .map(BackupManifest::getBackupId)
                .toList();
    }

    private boolean shouldInclude(String relPath, BackupJobConfig config) {
        for (String excl : config.getExcludePaths()) {
            if (relPath.startsWith(excl) || relPath.contains("/" + excl + "/")) return false;
        }
        if (config.getIncludeExtensions().isEmpty()) return true;
        for (String ext : config.getIncludeExtensions()) {
            if (relPath.endsWith(ext)) return true;
        }
        return false;
    }
}