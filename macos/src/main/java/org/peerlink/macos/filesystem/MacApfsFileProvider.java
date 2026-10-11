package org.peerlink.macos.filesystem;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.text.Normalizer;
import java.util.EnumSet;
import java.util.Objects;
import java.util.Set;

/**
 * macOS and APFS-aware filesystem provider.
 * Enforces Unicode Normalization Form C (NFC) for APFS, rejects invalid macOS characters (such as colons ':'),
 * validates against path traversal and embedded NUL bytes, protects against symlink loops,
 * and sets strict POSIX permissions (0700 for directories, 0600 for sensitive files).
 */
public class MacApfsFileProvider {

    private static final Logger log = LoggerFactory.getLogger(MacApfsFileProvider.class);

    private static final Set<PosixFilePermission> OWNER_DIR_PERMS = EnumSet.of(
            PosixFilePermission.OWNER_READ,
            PosixFilePermission.OWNER_WRITE,
            PosixFilePermission.OWNER_EXECUTE
    );

    private static final Set<PosixFilePermission> OWNER_FILE_PERMS = EnumSet.of(
            PosixFilePermission.OWNER_READ,
            PosixFilePermission.OWNER_WRITE
    );

    private final Path rootDir;

    public MacApfsFileProvider(Path rootDir) {
        this.rootDir = Objects.requireNonNull(rootDir, "rootDir must not be null").toAbsolutePath().normalize();
    }

    /**
     * Validates and normalizes a relative path string according to APFS rules:
     * - Rejects NUL bytes ('\0') and colons (':')
     * - Normalizes Unicode to NFC Form
     * - Rejects path traversal ('..')
     * - Rejects absolute paths
     */
    public String sanitizeApfsPath(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            throw new IllegalArgumentException("Path must not be null or blank");
        }

        // Rejects embedded NUL bytes
        if (relativePath.indexOf('\0') != -1) {
            throw new SecurityException("NUL byte detected in path: " + relativePath);
        }

        // Rejects colon ':' which is the classic macOS path separator and invalid in POSIX filenames
        if (relativePath.indexOf(':') != -1) {
            throw new IllegalArgumentException("Invalid APFS filename: colon (':') is forbidden in macOS paths");
        }

        // Normalize Unicode to Form C (canonical composition) for APFS
        String normalizedUnicode = Normalizer.normalize(relativePath, Normalizer.Form.NFC);

        // Normalize slashes
        String cleanPath = normalizedUnicode.replace('\\', '/');

        // Check for path traversal components
        String[] parts = cleanPath.split("/");
        for (String part : parts) {
            if ("..".equals(part)) {
                throw new SecurityException("Path traversal attempt detected: " + relativePath);
            }
        }

        if (cleanPath.startsWith("/")) {
            throw new SecurityException("Absolute paths are not permitted in relative resolution: " + relativePath);
        }

        return cleanPath;
    }

    /**
     * Resolves a sanitized relative path against the configured root directory.
     * Ensures the resolved path cannot escape the root boundary.
     */
    public Path resolvePath(String relativePath) {
        String sanitized = sanitizeApfsPath(relativePath);
        Path resolved = rootDir.resolve(sanitized).normalize();

        if (!resolved.startsWith(rootDir)) {
            throw new SecurityException("Resolved path escaped root directory: " + resolved);
        }

        return resolved;
    }

    /**
     * Creates a directory with strict POSIX permissions (0700).
     */
    public Path createSecureDirectory(Path dir) throws IOException {
        if (!Files.exists(dir)) {
            try {
                Files.createDirectories(dir, PosixFilePermissions.asFileAttribute(OWNER_DIR_PERMS));
            } catch (UnsupportedOperationException e) {
                // Non-POSIX filesystem fallback
                Files.createDirectories(dir);
                setPosixAttributesFallback(dir, true);
            }
        } else {
            applyPosixPermissions(dir, OWNER_DIR_PERMS);
        }
        return dir;
    }

    /**
     * Creates or updates a secure file with strict POSIX permissions (0600).
     */
    public Path createSecureFile(Path file, byte[] content) throws IOException {
        Path parent = file.getParent();
        if (parent != null && !Files.exists(parent)) {
            createSecureDirectory(parent);
        }

        try {
            Files.write(file, content, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING,
                    StandardOpenOption.WRITE);
            applyPosixPermissions(file, OWNER_FILE_PERMS);
        } catch (UnsupportedOperationException e) {
            setPosixAttributesFallback(file, false);
        }

        return file;
    }

    /**
     * Traverses a path safely, checking for symlink loops.
     */
    public boolean verifySymlinkSafety(Path path) throws IOException {
        if (!Files.exists(path, LinkOption.NOFOLLOW_LINKS)) {
            return false;
        }

        try {
            Path realPath = path.toRealPath();
            return realPath.startsWith(rootDir);
        } catch (FileSystemLoopException e) {
            log.warn("Symlink cycle detected: {}", path, e);
            throw e;
        }
    }

    private void applyPosixPermissions(Path path, Set<PosixFilePermission> perms) {
        try {
            Files.setPosixFilePermissions(path, perms);
        } catch (UnsupportedOperationException | IOException e) {
            setPosixAttributesFallback(path, perms.contains(PosixFilePermission.OWNER_EXECUTE));
        }
    }

    private void setPosixAttributesFallback(Path path, boolean executable) {
        try {
            path.toFile().setReadable(true, true);
            path.toFile().setWritable(true, true);
            path.toFile().setExecutable(executable, true);
        } catch (Exception ignored) {
        }
    }

    public Path getRootDir() {
        return rootDir;
    }
}
