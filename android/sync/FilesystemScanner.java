package org.peerlink.core.sync;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;

/**
 * Filesystem scanner for PeerLink sync roots.
 *
 * <p>Principles:
 * <ul>
 *   <li>Filesystem watcher notifications are HINTS only.</li>
 *   <li>Startup scanning and periodic reconciliation provide the true filesystem baseline.</li>
 *   <li>Missed watcher events, offline edits, and bulk moves are discovered via scanning.</li>
 *   <li>SHA-256 content hashes are calculated safely using streamed chunks.</li>
 *   <li>Selective sync filters (patterns, max size) are respected.</li>
 * </ul>
 */
public final class FilesystemScanner {

    private final SelectiveSyncFilter filter;

    public FilesystemScanner() {
        this(SelectiveSyncFilter.acceptAll());
    }

    public FilesystemScanner(SelectiveSyncFilter filter) {
        this.filter = filter != null ? filter : SelectiveSyncFilter.acceptAll();
    }

    /**
     * Recursively scans the sync root directory and returns observed filesystem entries.
     *
     * @param rootDir the directory root to scan
     * @return list of observed FsEntry records
     * @throws IOException on unrecoverable I/O failure
     */
    public List<ChangeDetector.FsEntry> scan(Path rootDir) throws IOException {
        if (!Files.exists(rootDir) || !Files.isDirectory(rootDir)) {
            return Collections.emptyList();
        }

        List<ChangeDetector.FsEntry> entries = new ArrayList<>();
        Path normalizedRoot = rootDir.toAbsolutePath().normalize();

        Files.walkFileTree(normalizedRoot, new SimpleFileVisitor<Path>() {
            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) {
                if (dir.equals(normalizedRoot)) {
                    return FileVisitResult.CONTINUE;
                }
                String relPath = normalizedRoot.relativize(dir.toAbsolutePath().normalize())
                        .toString().replace('\\', '/');

                if (!filter.accepts(relPath, 0L, true)) {
                    return FileVisitResult.SKIP_SUBTREE;
                }

                entries.add(new ChangeDetector.FsEntry(
                        relPath, null, 0L, attrs.lastModifiedTime().toMillis(), true));
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) {
                String relPath = normalizedRoot.relativize(file.toAbsolutePath().normalize())
                        .toString().replace('\\', '/');
                long size = attrs.size();

                if (!filter.accepts(relPath, size, false)) {
                    return FileVisitResult.CONTINUE;
                }

                String hash = null;
                try {
                    hash = computeSha256(file);
                } catch (IOException ignored) {
                    // Skip unreadable files safely
                    return FileVisitResult.CONTINUE;
                }

                entries.add(new ChangeDetector.FsEntry(
                        relPath, hash, size, attrs.lastModifiedTime().toMillis(), false));
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFileFailed(Path file, IOException exc) {
                return FileVisitResult.CONTINUE;
            }
        });

        // Sort deterministically by relative path
        entries.sort(Comparator.comparing(ChangeDetector.FsEntry::relativePath));
        return entries;
    }

    /**
     * Compute SHA-256 of a file stream safely in 64KB blocks.
     */
    public static String computeSha256(Path file) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            try (InputStream is = Files.newInputStream(file)) {
                byte[] buffer = new byte[65536];
                int read;
                while ((read = is.read(buffer)) != -1) {
                    digest.update(buffer, 0, read);
                }
            }
            byte[] hashBytes = digest.digest();
            StringBuilder sb = new StringBuilder(64);
            for (byte b : hashBytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }
    }
}
