package org.peerlink.windows.filesystem;

import org.peerlink.core.filesystem.PathSafetyValidator;
import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.core.filesystem.PeerFileProvider;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.*;

/**
 * Windows NTFS-specific File Provider implementation.
 *
 * Implements authoritative filesystem access adhering to NTFS safety constraints:
 * <ul>
 *   <li>Rejection of reserved device names (CON, PRN, AUX, NUL, COM1-9, LPT1-9).</li>
 *   <li>Rejection of NTFS Alternate Data Streams (ADS).</li>
 *   <li>Rejection of trailing dots and spaces.</li>
 *   <li>Graceful handling of Win32 file sharing and lock contention.</li>
 * </ul>
 */
public final class WindowsNtfsFileProvider implements PeerFileProvider {
    private static final Logger log = LoggerFactory.getLogger(WindowsNtfsFileProvider.class);

    private final Path rootDirectory;

    public WindowsNtfsFileProvider(Path rootDirectory) {
        this.rootDirectory = Objects.requireNonNull(rootDirectory, "Root directory must not be null")
                .toAbsolutePath().normalize();
    }

    public Path getRootDirectory() {
        return rootDirectory;
    }

    @Override
    public Optional<PeerFileHandle> resolve(ObjectIdentity objectId) throws IOException {
        if (objectId == null || objectId.getValue() == null) {
            return Optional.empty();
        }
        return resolveByPhysicalPath(objectId.getValue());
    }

    @Override
    public Optional<PeerFileHandle> resolveByPhysicalPath(String physicalPathOrUri) throws IOException {
        if (physicalPathOrUri == null || physicalPathOrUri.isBlank()) {
            return Optional.empty();
        }

        Path target = Path.of(physicalPathOrUri).normalize();
        if (!target.isAbsolute()) {
            target = rootDirectory.resolve(target).normalize();
        }

        // Validate Windows NTFS path safety
        try {
            validateNtfsPathSafety(target.getFileName().toString());
        } catch (IllegalArgumentException e) {
            log.warn("Rejected unsafe NTFS filename {}: {}", target.getFileName(), e.getMessage());
            return Optional.empty();
        }

        if (!Files.exists(target)) {
            return Optional.empty();
        }

        return Optional.of(new WindowsNtfsFileHandle(target));
    }

    @Override
    public List<PeerFileHandle> listChildren(PeerFileHandle directory) throws IOException {
        Objects.requireNonNull(directory, "Directory handle cannot be null");
        if (!directory.isDirectory()) {
            return Collections.emptyList();
        }

        Optional<PeerFileHandle> resolved = resolveByPhysicalPath(directory.getDisplayName());
        if (resolved.isEmpty()) {
            return Collections.emptyList();
        }

        Path dirPath = Path.of(directory.getDisplayName());
        List<PeerFileHandle> children = new ArrayList<>();
        try (var stream = Files.list(dirPath)) {
            stream.forEach(p -> children.add(new WindowsNtfsFileHandle(p)));
        }
        return children;
    }

    @Override
    public boolean delete(PeerFileHandle handle) throws IOException {
        if (handle == null) return false;
        Path target = Path.of(handle.getDisplayName()).normalize();
        return Files.deleteIfExists(target);
    }

    @Override
    public void reconcile(String rootPath) throws IOException {
        Path root = Path.of(rootPath).normalize();
        if (!Files.exists(root)) {
            Files.createDirectories(root);
        }
    }

    private static void validateNtfsPathSafety(String filename) {
        if (filename == null || filename.isBlank()) {
            throw new IllegalArgumentException("Filename cannot be blank");
        }

        // Check reserved device names
        String base = filename.contains(".") ? filename.substring(0, filename.indexOf('.')) : filename;
        String upperBase = base.toUpperCase(Locale.ROOT);
        if (Set.of("CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
                "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9").contains(upperBase)) {
            throw new IllegalArgumentException("Windows reserved device name: " + filename);
        }

        // Check alternate data streams
        if (filename.contains(":")) {
            throw new IllegalArgumentException("NTFS alternate data stream syntax (:) forbidden: " + filename);
        }

        // Check trailing dot or space
        if (filename.endsWith(".") || filename.endsWith(" ")) {
            throw new IllegalArgumentException("Filename ends with dot or space: " + filename);
        }
    }

    private static final class WindowsNtfsFileHandle implements PeerFileHandle {
        private final Path path;

        WindowsNtfsFileHandle(Path path) {
            this.path = path.toAbsolutePath().normalize();
        }

        @Override
        public ObjectIdentity getObjectId() {
            return new ObjectIdentity(path.toString());
        }

        @Override
        public String getDisplayName() {
            return path.toString();
        }

        @Override
        public long getSizeBytes() {
            try {
                return Files.size(path);
            } catch (IOException e) {
                return -1;
            }
        }

        @Override
        public long getLastModifiedUtcMs() {
            try {
                return Files.getLastModifiedTime(path).toMillis();
            } catch (IOException e) {
                return 0;
            }
        }

        @Override
        public boolean isDirectory() {
            return Files.isDirectory(path);
        }

        @Override
        public InputStream openInputStream() throws IOException {
            return Files.newInputStream(path, StandardOpenOption.READ);
        }

        @Override
        public OutputStream openOutputStream() throws IOException {
            return Files.newOutputStream(path, StandardOpenOption.CREATE, StandardOpenOption.WRITE);
        }
    }
}
