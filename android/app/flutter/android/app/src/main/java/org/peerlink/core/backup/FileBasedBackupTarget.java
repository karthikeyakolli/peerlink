package org.peerlink.core.backup;

import org.peerlink.core.model.ContentHash;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Stream;

/**
 * Persistent filesystem-backed BackupTarget.
 *
 * Verifies that the underlying protected bytes remain recoverable
 * from real disk storage rather than relying merely on metadata manifests in SQLite.
 */
public class FileBasedBackupTarget implements BackupTarget {

    private final Path rootDir;
    private final Path manifestsDir;
    private final Path payloadsDir;
    private final boolean blind;

    public FileBasedBackupTarget(Path rootDir) throws IOException {
        this(rootDir, false);
    }

    public FileBasedBackupTarget(Path rootDir, boolean blind) throws IOException {
        this.rootDir = Objects.requireNonNull(rootDir, "rootDir cannot be null").toAbsolutePath().normalize();
        this.manifestsDir = this.rootDir.resolve("manifests");
        this.payloadsDir = this.rootDir.resolve("payloads");
        this.blind = blind;

        Files.createDirectories(this.manifestsDir);
        Files.createDirectories(this.payloadsDir);
    }

    public Path getRootDir() {
        return rootDir;
    }

    @Override
    public synchronized void storePayload(String storageHash, byte[] data) throws IOException {
        Objects.requireNonNull(storageHash, "storageHash cannot be null");
        Objects.requireNonNull(data, "data cannot be null");

        Path finalFile = payloadsDir.resolve(storageHash + ".blob");
        if (Files.exists(finalFile)) {
            // Already present and immutable
            return;
        }

        // Check available capacity before write
        try {
            long usable;
            try {
                usable = Files.getFileStore(payloadsDir).getUsableSpace();
            } catch (Exception | LinkageError e) {
                usable = payloadsDir.toFile().getUsableSpace();
            }
            if (usable > 0 && usable < data.length) {
                throw new IOException("Insufficient disk capacity: required " + data.length + " bytes, usable " + usable + " bytes");
            }
        } catch (IOException e) {
            if (e.getMessage() != null && e.getMessage().contains("Insufficient disk capacity")) {
                throw e;
            }
            // Ignore getFileStore failures on unusual or virtual filesystems
        }

        // Staged write to verify bytes before exposure
        Path stagingFile = payloadsDir.resolve("." + storageHash + ".tmp." + UUID.randomUUID());
        try {
            Files.write(stagingFile, data, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE);

            // Verify stored bytes match expected storage hash on disk
            byte[] readBack = Files.readAllBytes(stagingFile);
            ContentHash computed = ContentHash.computeSha256(readBack);
            if (!computed.getHexString().equalsIgnoreCase(storageHash)) {
                throw new IOException("Storage payload checksum verification failed on disk write for hash " + storageHash);
            }

            // Atomic rename
            try {
                Files.move(stagingFile, finalFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException e) {
                Files.move(stagingFile, finalFile, StandardCopyOption.REPLACE_EXISTING);
            }
        } finally {
            try {
                Files.deleteIfExists(stagingFile);
            } catch (Exception ignored) {}
        }
    }

    @Override
    public synchronized byte[] retrievePayload(String storageHash) throws IOException {
        Objects.requireNonNull(storageHash, "storageHash cannot be null");
        Path file = payloadsDir.resolve(storageHash + ".blob");
        if (!Files.exists(file)) {
            throw new FileNotFoundException("Payload not found on target disk: " + storageHash);
        }
        return Files.readAllBytes(file);
    }

    @Override
    public boolean hasPayload(String storageHash) {
        if (storageHash == null) return false;
        Path file = payloadsDir.resolve(storageHash + ".blob");
        return Files.isRegularFile(file);
    }

    @Override
    public synchronized void deletePayload(String storageHash) throws IOException {
        if (storageHash == null) return;
        Path file = payloadsDir.resolve(storageHash + ".blob");
        Files.deleteIfExists(file);
    }

    @Override
    public synchronized void saveManifest(BackupManifest manifest) throws IOException {
        Objects.requireNonNull(manifest, "manifest cannot be null");
        if (!manifest.verifyIntegrity()) {
            throw new IllegalArgumentException("Cannot save manifest with invalid digest: " + manifest.getBackupId());
        }

        Path finalFile = manifestsDir.resolve(manifest.getBackupId() + ".manifest");
        Path stagingFile = manifestsDir.resolve("." + manifest.getBackupId() + ".tmp." + UUID.randomUUID());

        try (ObjectOutputStream oos = new ObjectOutputStream(Files.newOutputStream(stagingFile, StandardOpenOption.CREATE, StandardOpenOption.WRITE))) {
            oos.writeObject(manifest);
            oos.flush();
        }

        try {
            Files.move(stagingFile, finalFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AtomicMoveNotSupportedException e) {
            Files.move(stagingFile, finalFile, StandardCopyOption.REPLACE_EXISTING);
        } finally {
            try {
                Files.deleteIfExists(stagingFile);
            } catch (Exception ignored) {}
        }
    }

    @Override
    public synchronized Optional<BackupManifest> getManifest(String backupId) {
        if (backupId == null) return Optional.empty();
        Path file = manifestsDir.resolve(backupId + ".manifest");
        if (!Files.isRegularFile(file)) {
            return Optional.empty();
        }

        try (ObjectInputStream ois = new ObjectInputStream(Files.newInputStream(file))) {
            BackupManifest manifest = (BackupManifest) ois.readObject();
            return Optional.of(manifest);
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    @Override
    public synchronized List<BackupManifest> listManifests(String jobId) {
        Objects.requireNonNull(jobId, "jobId cannot be null");
        List<BackupManifest> list = new ArrayList<>();
        if (!Files.isDirectory(manifestsDir)) {
            return list;
        }

        try (Stream<Path> stream = Files.list(manifestsDir)) {
            stream.filter(p -> p.getFileName().toString().endsWith(".manifest"))
                  .forEach(p -> {
                      try (ObjectInputStream ois = new ObjectInputStream(Files.newInputStream(p))) {
                          BackupManifest manifest = (BackupManifest) ois.readObject();
                          if (jobId.equals(manifest.getJobId())) {
                              list.add(manifest);
                          }
                      } catch (Exception ignored) {
                      }
                  });
        } catch (IOException ignored) {}

        list.sort(Comparator.comparingLong(BackupManifest::getSnapshotTimestampUtcMs));
        return list;
    }

    @Override
    public synchronized void deleteManifest(String backupId) throws IOException {
        if (backupId == null) return;
        Path file = manifestsDir.resolve(backupId + ".manifest");
        Files.deleteIfExists(file);
    }

    @Override
    public boolean isBlind() {
        return blind;
    }

    @Override
    public synchronized Set<String> listStoredPayloadHashes() {
        Set<String> hashes = new HashSet<>();
        if (!Files.isDirectory(payloadsDir)) {
            return hashes;
        }

        try (Stream<Path> stream = Files.list(payloadsDir)) {
            stream.filter(p -> p.getFileName().toString().endsWith(".blob"))
                  .forEach(p -> {
                      String name = p.getFileName().toString();
                      hashes.add(name.substring(0, name.length() - ".blob".length()));
                  });
        } catch (IOException ignored) {}

        return hashes;
    }

    @Override
    public synchronized long getStorageUsageBytes() {
        if (!Files.isDirectory(payloadsDir)) {
            return 0L;
        }
        try (Stream<Path> stream = Files.list(payloadsDir)) {
            return stream.filter(p -> p.getFileName().toString().endsWith(".blob"))
                         .mapToLong(p -> {
                             try {
                                 return Files.size(p);
                             } catch (IOException e) {
                                 return 0L;
                             }
                         }).sum();
        } catch (IOException e) {
            return 0L;
        }
    }

    public long getRemainingCapacityBytes() {
        try {
            return Files.getFileStore(rootDir).getUsableSpace();
        } catch (Exception e) {
            try {
                return rootDir.toFile().getUsableSpace();
            } catch (Exception ignored) {
                return Long.MAX_VALUE;
            }
        }
    }
}
