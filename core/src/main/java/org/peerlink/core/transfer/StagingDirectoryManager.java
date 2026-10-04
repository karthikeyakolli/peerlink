package org.peerlink.core.transfer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.DosFileAttributeView;

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

    private final Path stagingRoot;

    public StagingDirectoryManager(Path stagingRoot) {
        this.stagingRoot = stagingRoot;
        try {
            Files.createDirectories(stagingRoot);
        } catch (IOException e) {
            throw new RuntimeException("Cannot initialize staging root: " + stagingRoot, e);
        }
    }

    /**
     * Get the staging directory for a specific transfer session.
     */
    public Path getTransferStagingDir(String transferId) {
        return stagingRoot.resolve(transferId);
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
        return getTransferStagingDir(transferId).resolve(itemIndex + ".part");
    }

    /**
     * Write a received chunk to the staged partial file at the given offset.
     * Optionally validates chunk SHA-256 before writing to disk.
     *
     * @throws CorruptChunkException if chunkSha256 is present and does not match computed digest
     */
    public synchronized void writeChunk(
            String transferId,
            int itemIndex,
            long chunkIndex,
            long offsetBytes,
            byte[] data,
            String expectedChunkSha256) throws IOException, CorruptChunkException {

        if (expectedChunkSha256 != null && !expectedChunkSha256.isBlank()) {
            String computedDigest = FileManifestBuilder.calculateSha256Hex(data);
            if (!computedDigest.equalsIgnoreCase(expectedChunkSha256)) {
                log.error("Corrupt chunk detected for transfer [{}] item [{}] chunk [{}]: expected={}, computed={}",
                        transferId, itemIndex, chunkIndex, expectedChunkSha256, computedDigest);
                throw new CorruptChunkException(transferId, itemIndex, chunkIndex, expectedChunkSha256, computedDigest);
            }
        }

        Path partPath = getStagedPartPath(transferId, itemIndex);
        if (!Files.exists(partPath.getParent())) {
            Files.createDirectories(partPath.getParent());
        }

        try (RandomAccessFile raf = new RandomAccessFile(partPath.toFile(), "rw")) {
            raf.seek(offsetBytes);
            raf.write(data);
        }
    }

    public synchronized void writeChunk(String transferId, int itemIndex, long offsetBytes, byte[] data)
            throws IOException {
        try {
            writeChunk(transferId, itemIndex, 0, offsetBytes, data, null);
        } catch (CorruptChunkException impossible) {
            throw new IOException(impossible);
        }
    }

    public synchronized long getStagedFileSize(String transferId, int itemIndex) {
        Path partPath = getStagedPartPath(transferId, itemIndex);
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
     *
     * @param transferId The transfer session ID
     * @param itemIndex The index of the item in the manifest
     * @param expectedSha256 Expected SHA-256 hexadecimal string
     * @param relativePath Relative path for diagnostic reporting
     * @return Calculated SHA-256 string
     * @throws HashMismatchException if the checksum does not match
     * @throws IOException if the staged file cannot be read
     */
    public String verifyStagedItem(String transferId, int itemIndex, String expectedSha256, String relativePath)
            throws HashMismatchException, IOException {

        Path partPath = getStagedPartPath(transferId, itemIndex);
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
        if (!Files.exists(partPath)) {
            throw new NoSuchFileException("Staged file not found for commit: " + partPath);
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
        try {
            if (Files.getFileStore(finalDestination).supportsFileAttributeView("posix")) {
                Files.setPosixFilePermissions(finalDestination,
                        java.nio.file.attribute.PosixFilePermissions.fromString("rw-r--r--"));
            }
        } catch (Exception ignored) {
            // Windows / non-POSIX systems ignore
        }

        log.info("Committed verified item to final destination: {}", finalDestination);
    }

    /**
     * Cleanup staging directory for a transfer.
     */
    public synchronized void cleanupStaging(String transferId) {
        Path dir = getTransferStagingDir(transferId);
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
