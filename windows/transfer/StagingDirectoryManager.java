package org.peerlink.core.transfer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.DosFileAttributeView;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages isolated staging directories for receiving incoming transfer payloads.
 *
 * <p>Crucial Security & Architecture Invariants:
 * <ul>
 *   <li>NEVER write unverified final content directly into the destination directory. All incoming bytes
 *       land strictly in a temporary staging path until SHA-256 validation passes.</li>
 *   <li>NEVER mark files executable (received files are strictly data).</li>
 *   <li>Purges corrupted staging artifacts immediately upon hash mismatch or cancellation.</li>
 *   <li>Promotes to destination atomically via {@link StandardCopyOption#ATOMIC_MOVE} (with fallback to replace).</li>
 * </ul>
 */
public final class StagingDirectoryManager {
    private static final Logger log = LoggerFactory.getLogger(StagingDirectoryManager.class);

    private static final boolean SUPPORTS_POSIX =
            FileSystems.getDefault().supportedFileAttributeViews().contains("posix");

    private final Path stagingRoot;
    private final Map<Path, FileChannel> openChannels = new ConcurrentHashMap<>();

    public StagingDirectoryManager(Path stagingRoot) {
        this.stagingRoot = stagingRoot;
        try {
            Files.createDirectories(stagingRoot);
        } catch (IOException e) {
            throw new RuntimeException("Cannot initialize staging root: " + stagingRoot, e);
        }
    }

    /**
     * Get the staging directory for a specific transfer session using an opaque, isolated internal name.
     */
    public Path getTransferStagingDir(String transferId) {
        String opaqueDir = org.peerlink.core.filesystem.PathSafetyValidator.deriveOpaqueStagingName(transferId);
        Path dir = stagingRoot.resolve(opaqueDir).normalize();
        if (!dir.startsWith(stagingRoot.toAbsolutePath().normalize())) {
            throw new SecurityException("Staging directory escaped staging root: " + dir);
        }
        return dir;
    }

    /**
     * Prepare a clean staging directory for an incoming transfer.
     */
    public Path prepareStagingDir(String transferId) throws IOException {
        Path dir = getTransferStagingDir(transferId);
        if (Files.exists(dir)) {
            cleanupStaging(transferId);
        }
        return Files.createDirectories(dir);
    }

    /**
     * Get the path to a staged partial file for a specific item index.
     */
    public Path getStagedPartPath(String transferId, int itemIndex) {
        if (itemIndex < 0) {
            throw new IllegalArgumentException("Item index cannot be negative: " + itemIndex);
        }
        Path dir = getTransferStagingDir(transferId);
        Path part = dir.resolve(itemIndex + ".part").normalize();
        if (!part.startsWith(dir)) {
            throw new SecurityException("Staged part path escaped staging directory");
        }
        return part;
    }

    /**
     * Write a received chunk to the staged partial file at the given offset.
     * Validates optional chunk SHA-256 and guards against size overruns.
     * Fully exhausts FileChannel writes in a loop to handle partial I/O correctly.
     */
    public synchronized void writeChunk(
            String transferId,
            int itemIndex,
            long chunkIndex,
            long offsetBytes,
            byte[] data,
            String expectedChunkSha256) throws IOException, CorruptChunkException {
        writeChunk(transferId, itemIndex, chunkIndex, offsetBytes, data, expectedChunkSha256, -1);
    }

    public synchronized void writeChunk(
            String transferId,
            int itemIndex,
            long chunkIndex,
            long offsetBytes,
            byte[] data,
            String expectedChunkSha256,
            long declaredFileSizeBytes) throws IOException, CorruptChunkException {

        if (offsetBytes < 0) {
            throw new IllegalArgumentException("Offset bytes cannot be negative: " + offsetBytes);
        }
        if (data == null) {
            throw new IllegalArgumentException("Chunk data cannot be null");
        }
        if (declaredFileSizeBytes >= 0 && offsetBytes + data.length > declaredFileSizeBytes) {
            throw new IllegalArgumentException(String.format(
                    "Size overrun detected: offset %d + data length %d exceeds declared file size %d for item %d",
                    offsetBytes, data.length, declaredFileSizeBytes, itemIndex));
        }

        if (expectedChunkSha256 != null && !expectedChunkSha256.isBlank()) {
            String computedDigest = FileManifestBuilder.calculateSha256Hex(data);
            if (!computedDigest.equalsIgnoreCase(expectedChunkSha256)) {
                log.error("Corrupt chunk detected for transfer [{}] item [{}] chunk [{}]: expected={}, computed={}",
                        transferId, itemIndex, chunkIndex, expectedChunkSha256, computedDigest);
                throw new CorruptChunkException(transferId, itemIndex, chunkIndex, expectedChunkSha256, computedDigest);
            }
        }

        Path partPath = getStagedPartPath(transferId, itemIndex);
        if (Files.isSymbolicLink(partPath)) {
            throw new SecurityException("Staged part path is a forbidden symbolic link: " + partPath);
        }

        FileChannel channel = openChannels.get(partPath);
        if (channel == null || !channel.isOpen()) {
            if (!Files.exists(partPath.getParent())) {
                Files.createDirectories(partPath.getParent());
            }
            channel = FileChannel.open(partPath, StandardOpenOption.CREATE, StandardOpenOption.READ, StandardOpenOption.WRITE);
            openChannels.put(partPath, channel);
        }

        // Exhaust ByteBuffer in loop to ensure full write against partial FileChannel I/O returns
        java.nio.ByteBuffer buffer = java.nio.ByteBuffer.wrap(data);
        long curOffset = offsetBytes;
        while (buffer.hasRemaining()) {
            int written = channel.write(buffer, curOffset);
            if (written < 0) {
                throw new IOException("Unexpected negative return from FileChannel.write on " + partPath);
            }
            curOffset += written;
        }

        // Durability flush: persist chunk bytes to OS page cache / disk before acknowledging
        channel.force(false);
    }

    public synchronized void truncateStagedFile(String transferId, int itemIndex, long validLength) throws IOException {
        Path partPath = getStagedPartPath(transferId, itemIndex);
        closeChannel(partPath);
        if (Files.exists(partPath)) {
            try (FileChannel fc = FileChannel.open(partPath, StandardOpenOption.WRITE)) {
                fc.truncate(validLength);
                fc.force(true);
            }
        }
    }

    public synchronized void writeChunk(String transferId, int itemIndex, long offsetBytes, byte[] data)
            throws IOException {
        try {
            writeChunk(transferId, itemIndex, 0, offsetBytes, data, null, -1);
        } catch (CorruptChunkException impossible) {
            throw new IOException(impossible);
        }
    }

    private void closeChannel(Path partPath) {
        FileChannel ch = openChannels.remove(partPath);
        if (ch != null && ch.isOpen()) {
            try {
                ch.force(false);
                ch.close();
            } catch (IOException ignored) {
            }
        }
    }

    public synchronized long getStagedFileSize(String transferId, int itemIndex) {
        Path partPath = getStagedPartPath(transferId, itemIndex);
        closeChannel(partPath);
        if (Files.exists(partPath)) {
            try {
                return Files.size(partPath);
            } catch (IOException e) {
                return -1;
            }
        }
        return 0;
    }

    public synchronized boolean hasStagedPart(String transferId, int itemIndex) {
        return Files.exists(getStagedPartPath(transferId, itemIndex));
    }

    /**
     * Verify that the staged item matches the expected SHA-256 digest.
     * Flushes and closes any active open FileChannel handle prior to hashing.
     */
    public String verifyStagedItem(String transferId, int itemIndex, String expectedSha256, String relativePath)
            throws HashMismatchException, IOException {

        Path partPath = getStagedPartPath(transferId, itemIndex);
        closeChannel(partPath);

        if (!Files.exists(partPath)) {
            // For a 0-byte file that received no chunks, create an empty file if needed
            Files.createFile(partPath);
        }

        String computedSha256 = FileManifestBuilder.calculateSha256Hex(partPath);

        if (!computedSha256.equalsIgnoreCase(expectedSha256)) {
            log.error("Integrity verification failed for item [{}]: expected={}, computed={}",
                    relativePath, expectedSha256, computedSha256);
            // Purge corrupted staging artifact immediately
            Files.deleteIfExists(partPath);
            throw new HashMismatchException(relativePath, expectedSha256, computedSha256);
        }

        log.debug("Integrity check passed for item [{}] ({})", relativePath, computedSha256);
        return computedSha256;
    }

    /**
     * Atomically commit a verified staged file to its final destination.
     */
    public synchronized void commitItem(String transferId, int itemIndex, Path finalDestination)
            throws IOException {
        Path partPath = getStagedPartPath(transferId, itemIndex);
        closeChannel(partPath);

        if (!Files.exists(partPath)) {
            throw new NoSuchFileException("Staged file not found for commit: " + partPath);
        }

        if (Files.isSymbolicLink(finalDestination)) {
            throw new SecurityException("Target destination cannot be a symbolic link: " + finalDestination);
        }

        if (finalDestination.getParent() != null) {
            Files.createDirectories(finalDestination.getParent());
        }

        try {
            // Attempt atomic filesystem move
            Files.move(partPath, finalDestination, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (AtomicMoveNotSupportedException e) {
            // Fallback for cross-device/filesystem moves
            Files.move(partPath, finalDestination, StandardCopyOption.REPLACE_EXISTING);
        }

        // Security check: strip execute permissions on POSIX systems
        if (SUPPORTS_POSIX) {
            try {
                Files.setPosixFilePermissions(finalDestination,
                        java.nio.file.attribute.PosixFilePermissions.fromString("rw-r--r--"));
            } catch (Exception ignored) {
                // Non-POSIX systems ignore
            }
        }

        log.info("Committed verified item to final destination: {}", finalDestination);
    }

    /**
     * Cleanup staging directory for a transfer.
     */
    public synchronized void cleanupStaging(String transferId) {
        Path dir = getTransferStagingDir(transferId);

        openChannels.keySet().removeIf(p -> {
            if (p.startsWith(dir)) {
                FileChannel ch = openChannels.get(p);
                if (ch != null && ch.isOpen()) {
                    try { ch.close(); } catch (IOException ignored) {}
                }
                return true;
            }
            return false;
        });

        if (!Files.exists(dir)) {
            return;
        }

        try {
            Files.walkFileTree(dir, new SimpleFileVisitor<Path>() {
                @Override
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                    Files.deleteIfExists(file);
                    return FileVisitResult.CONTINUE;
                }

                @Override
                public FileVisitResult postVisitDirectory(Path d, IOException exc) throws IOException {
                    Files.deleteIfExists(d);
                    return FileVisitResult.CONTINUE;
                }
            });
        } catch (IOException e) {
            log.warn("Failed to cleanly delete staging dir {}: {}", dir, e.getMessage());
        }
    }
}
