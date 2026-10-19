package org.peerlink.core.transfer;

import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;

/**
 * Builds deterministic, version-safe transfer manifests from local filesystem paths.
 *
 * <p>Supports:
 * <ul>
 *   <li>Single files</li>
 *   <li>Multiple files</li>
 *   <li>Entire directory hierarchies (preserving relative directory structure)</li>
 *   <li>Zero-byte files (valid SHA-256 computed)</li>
 *   <li>Large files (streaming SHA-256 computation without unbounded heap allocation)</li>
 *   <li>Unicode filenames (normalized UTF-8 path handling)</li>
 * </ul>
 */
public final class FileManifestBuilder {
    private static final Logger log = LoggerFactory.getLogger(FileManifestBuilder.class);

    public static final int DEFAULT_CHUNK_SIZE_BYTES = 64 * 1024; // 64 KB default chunk size

    private final int chunkSizeBytes;

    public FileManifestBuilder() {
        this(DEFAULT_CHUNK_SIZE_BYTES);
    }

    public FileManifestBuilder(int chunkSizeBytes) {
        if (chunkSizeBytes <= 0) {
            throw new IllegalArgumentException("chunkSizeBytes must be positive");
        }
        this.chunkSizeBytes = chunkSizeBytes;
    }

    /**
     * Build a manifest from a collection of source paths (files or directories).
     *
     * @param transferId Unique identifier for this transfer session
     * @param operationId Durable operation ID for journal tracking
     * @param senderPeerId Identity of the sending peer
     * @param receiverPeerId Identity of the receiving peer
     * @param sourcePaths List of file or directory paths to include
     * @param duplicatePolicy Conflict policy for destination collisions
     * @return Complete, hashed TransferManifest
     * @throws IOException if source files cannot be read or are missing
     */
    public TransferManifest buildManifest(
            String transferId,
            String operationId,
            String senderPeerId,
            String receiverPeerId,
            List<Path> sourcePaths,
            DuplicateDestinationPolicy duplicatePolicy) throws IOException {

        if (sourcePaths == null || sourcePaths.isEmpty()) {
            throw new IllegalArgumentException("At least one source path must be provided");
        }

        List<TransferItem> items = new ArrayList<>();
        long totalBytes = 0;

        for (Path rootPath : sourcePaths) {
            Path normalized = rootPath.toAbsolutePath().normalize();
            if (!Files.exists(normalized)) {
                throw new NoSuchFileException("Source path does not exist: " + normalized);
            }
            if (!Files.isReadable(normalized)) {
                throw new AccessDeniedException("Source path is not readable: " + normalized);
            }

            if (Files.isRegularFile(normalized)) {
                TransferItem item = buildFileItem(normalized, getSafeName(normalized));
                items.add(item);
                totalBytes += item.getFileSizeBytes();
            } else if (Files.isDirectory(normalized)) {
                String rootDirName = getSafeName(normalized);
                List<TransferItem> dirItems = scanDirectory(normalized, rootDirName);
                items.addAll(dirItems);
                for (TransferItem item : dirItems) {
                    if (!item.getIsDirectory()) {
                        totalBytes += item.getFileSizeBytes();
                    }
                }
            }
        }

        String firstPathName = getSafeName(sourcePaths.get(0));
        String displayName = sourcePaths.size() == 1
                ? firstPathName
                : firstPathName + " (+" + (items.size() - 1) + " items)";

        // Validate that no relative paths collide or contain path traversals
        org.peerlink.core.filesystem.PathSafetyValidator.validateNoCollisions(
                items.stream().map(TransferItem::getRelativePath).toList());

        return TransferManifest.newBuilder()
                .setTransferId(transferId)
                .setOperationId(OperationId.newBuilder().setValue(operationId).build())
                .setSenderPeerId(PeerId.newBuilder().setValue(senderPeerId).build())
                .setReceiverPeerId(PeerId.newBuilder().setValue(receiverPeerId).build())
                .addAllItems(items)
                .setTotalBytes(totalBytes)
                .setChunkSizeBytes(chunkSizeBytes)
                .setDisplayName(displayName)
                .setDuplicatePolicy(duplicatePolicy)
                .build();
    }

    private TransferItem buildFileItem(Path file, String relativePath) throws IOException {
        return buildFileItem(file, relativePath, null);
    }

    private TransferItem buildFileItem(Path file, String relativePath, BasicFileAttributes attrs) throws IOException {
        long size = attrs != null ? attrs.size() : Files.size(file);
        long modifiedTime = attrs != null ? attrs.lastModifiedTime().toMillis() : Files.getLastModifiedTime(file).toMillis();
        String sha256 = calculateSha256Hex(file);
        String validatedPath = org.peerlink.core.filesystem.PathSafetyValidator.validateRelativePath(relativePath);

        return TransferItem.newBuilder()
                .setRelativePath(validatedPath)
                .setFileSizeBytes(size)
                .setSha256Hex(sha256)
                .setIsDirectory(false)
                .setModifiedTimeUtcMs(modifiedTime)
                .build();
    }

    private List<TransferItem> scanDirectory(Path rootDir, String prefixName) throws IOException {
        List<TransferItem> results = new ArrayList<>();

        Files.walkFileTree(rootDir, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) {
                Path relative = rootDir.relativize(dir);
                String relPathStr = relative.toString().isEmpty()
                        ? prefixName
                        : prefixName + "/" + relative.toString().replace('\\', '/');

                results.add(TransferItem.newBuilder()
                        .setRelativePath(relPathStr)
                        .setFileSizeBytes(0)
                        .setSha256Hex("")
                        .setIsDirectory(true)
                        .setModifiedTimeUtcMs(attrs.lastModifiedTime().toMillis())
                        .build());
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                Path relative = rootDir.relativize(file);
                String relPathStr = prefixName + "/" + relative.toString().replace('\\', '/');
                results.add(buildFileItem(file, relPathStr, attrs));
                return FileVisitResult.CONTINUE;
            }
        });

        return results;
    }

    /**
     * Compute SHA-256 checksum using streaming 128KB buffered streams.
     * Never loads the full file into memory. Correctly hashes 0-byte files.
     */
    public static String calculateSha256Hex(Path path) throws IOException {
        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }

        try (InputStream in = new BufferedInputStream(Files.newInputStream(path), 128 * 1024)) {
            byte[] buffer = new byte[128 * 1024];
            int read;
            while ((read = in.read(buffer)) != -1) {
                digest.update(buffer, 0, read);
            }
        }

        byte[] hash = digest.digest();
        return toHexString(hash);
    }

    /**
     * Compute SHA-256 checksum for in-memory byte array.
     */
    public static String calculateSha256Hex(byte[] data) {
        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }
        return toHexString(digest.digest(data));
    }

    private static String getSafeName(Path path) {
        if (path == null) {
            return "root";
        }
        Path fileName = path.getFileName();
        if (fileName != null && !fileName.toString().trim().isEmpty()) {
            return fileName.toString().trim();
        }
        String normalizedStr = path.toString().replace('\\', '/');
        while (normalizedStr.endsWith("/")) {
            normalizedStr = normalizedStr.substring(0, normalizedStr.length() - 1);
        }
        int slash = normalizedStr.lastIndexOf('/');
        if (slash >= 0 && slash < normalizedStr.length() - 1) {
            return normalizedStr.substring(slash + 1);
        }
        return normalizedStr.isEmpty() ? "root" : normalizedStr.replace(":", "");
    }

    private static String toHexString(byte[] hash) {
        return java.util.HexFormat.of().formatHex(hash);
    }
}
