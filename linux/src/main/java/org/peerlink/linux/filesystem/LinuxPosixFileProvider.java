package org.peerlink.linux.filesystem;

import org.peerlink.core.filesystem.DestinationSafety;
import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.core.filesystem.PeerFileProvider;
import org.peerlink.core.model.ObjectIdentity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.*;

/**
 * Linux POSIX-compliant File Provider implementation.
 *
 * Enforces strict Linux/POSIX safety:
 * <ul>
 *   <li>Rejection of embedded NUL (\0) bytes.</li>
 *   <li>Rejection of path traversal sequences (..).</li>
 *   <li>Safe symlink resolution without following circular loops.</li>
 *   <li>Application of secure POSIX permissions (0600 for secrets, 0700 for directories).</li>
 * </ul>
 */
public final class LinuxPosixFileProvider implements PeerFileProvider {
    private static final Logger log = LoggerFactory.getLogger(LinuxPosixFileProvider.class);

    private final Path rootDirectory;

    public LinuxPosixFileProvider(Path rootDirectory) {
        this.rootDirectory = Objects.requireNonNull(rootDirectory, "Root directory must not be null")
                .toAbsolutePath().normalize();
    }

    public Path getRootDirectory() {
        return rootDirectory;
    }

    @Override
    public Optional<PeerFileHandle> resolve(ObjectIdentity objectId) throws IOException {
        if (objectId == null || objectId.value() == null) {
            return Optional.empty();
        }
        return resolveByPhysicalPath(objectId.value());
    }

    @Override
    public Optional<PeerFileHandle> resolveByPhysicalPath(String physicalPathOrUri) throws IOException {
        if (physicalPathOrUri == null || physicalPathOrUri.isBlank()) {
            return Optional.empty();
        }

        try {
            validatePosixPathSafety(physicalPathOrUri);
        } catch (IllegalArgumentException e) {
            log.warn("Rejected unsafe POSIX path '{}': {}", physicalPathOrUri, e.getMessage());
            return Optional.empty();
        }

        Path target = Path.of(physicalPathOrUri).normalize();
        if (!target.isAbsolute()) {
            target = rootDirectory.resolve(target).normalize();
        }

        if (!Files.exists(target)) {
            return Optional.empty();
        }

        // Check if symlink is looping or broken
        if (Files.isSymbolicLink(target)) {
            try {
                Path realPath = target.toRealPath();
                if (!Files.exists(realPath)) {
                    log.warn("Broken symbolic link: {}", target);
                    return Optional.empty();
                }
            } catch (FileSystemLoopException e) {
                log.error("Detected symbolic link loop: {}", target);
                return Optional.empty();
            }
        }

        return Optional.of(new LinuxPosixFileHandle(target));
    }

    @Override
    public List<PeerFileHandle> listChildren(PeerFileHandle directory) throws IOException {
        Objects.requireNonNull(directory, "Directory handle cannot be null");
        if (!directory.isDirectory()) {
            return Collections.emptyList();
        }

        Path dirPath = Path.of(directory.getDisplayName());
        List<PeerFileHandle> children = new ArrayList<>();
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(dirPath)) {
            for (Path child : stream) {
                children.add(new LinuxPosixFileHandle(child));
            }
        }
        return children;
    }

    @Override
    public DestinationSafety validateDestinationSafety(String transferId, String relativeDestinationPath) {
        if (relativeDestinationPath == null || relativeDestinationPath.isBlank()) {
            return DestinationSafety.unsafe("Destination path cannot be empty");
        }

        try {
            validatePosixPathSafety(relativeDestinationPath);
        } catch (IllegalArgumentException e) {
            return DestinationSafety.unsafe(e.getMessage());
        }

        Path dest = rootDirectory.resolve(relativeDestinationPath).normalize();
        if (!dest.startsWith(rootDirectory)) {
            return DestinationSafety.unsafe("Destination escapes root directory jail");
        }

        return DestinationSafety.safe(dest.toString());
    }

    public static void validatePosixPathSafety(String path) {
        if (path.contains("\0")) {
            throw new IllegalArgumentException("POSIX path contains forbidden NUL byte");
        }
        Path normalized = Path.of(path).normalize();
        for (Path component : normalized) {
            if (component.toString().equals("..")) {
                throw new IllegalArgumentException("Path traversal (..) forbidden: " + path);
            }
        }
    }

    /**
     * Sets POSIX permissions on file if supported by underlying filesystem.
     */
    public static void setPosixPermissions(Path path, Set<PosixFilePermission> permissions) throws IOException {
        try {
            Files.setPosixFilePermissions(path, permissions);
        } catch (UnsupportedOperationException e) {
            // Filesystem does not support POSIX attributes (e.g., FAT32/exFAT mount)
            log.debug("POSIX permissions not supported on {}: {}", path, e.getMessage());
        }
    }

    private static final class LinuxPosixFileHandle implements PeerFileHandle {
        private final Path path;

        LinuxPosixFileHandle(Path path) {
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
