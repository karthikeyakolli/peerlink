package org.peerlink.core.access;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Set;

/**
 * Engine for generating safe content previews with strict security policies.
 *
 * <p>Enforces:
 * <ul>
 *   <li>Executable files are metadata-only by default; previews are strictly rejected.</li>
 *   <li>No automatic execution.</li>
 *   <li>Strict bounded byte reading (default 64KB, max 256KB).</li>
 *   <li>MIME-type detection and safe text/image classification.</li>
 * </ul>
 */
public final class SafePreviewEngine {

    public static final int DEFAULT_MAX_PREVIEW_BYTES = 64 * 1024; // 64 KB
    public static final int ABSOLUTE_MAX_PREVIEW_BYTES = 256 * 1024; // 256 KB

    private static final Set<String> EXECUTABLE_EXTENSIONS = Set.of(
            "exe", "dll", "bat", "cmd", "sh", "bin", "msi", "ps1", "vbs", "com",
            "scr", "jar", "app", "dmg", "elf", "so", "dylib", "pif", "cpl"
    );

    private static final Set<String> TEXT_EXTENSIONS = Set.of(
            "txt", "md", "markdown", "json", "xml", "yaml", "yml", "csv", "tsv",
            "log", "html", "htm", "css", "js", "ts", "dart", "java", "kt", "rs",
            "c", "cpp", "h", "hpp", "py", "rb", "go", "sql", "proto", "properties",
            "env", "ini", "conf", "config"
    );

    private static final Set<String> IMAGE_EXTENSIONS = Set.of(
            "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"
    );

    private static final Set<String> ARCHIVE_EXTENSIONS = Set.of(
            "zip", "tar", "gz", "tgz", "bz2", "7z", "rar"
    );

    public record PreviewResult(
            byte[] data,
            String mimeType,
            boolean isTruncated,
            long originalSizeBytes
    ) {}

    /**
     * Determines whether a file path corresponds to an executable file.
     */
    public static boolean isExecutable(Path path) {
        if (path == null) return false;
        String fileName = path.getFileName().toString().toLowerCase(Locale.ROOT);
        int dot = fileName.lastIndexOf('.');
        if (dot >= 0) {
            String ext = fileName.substring(dot + 1);
            if (EXECUTABLE_EXTENSIONS.contains(ext)) {
                return true;
            }
        }

        // On POSIX filesystems, check executable bit if supported
        try {
            if (Files.isExecutable(path) && !Files.isDirectory(path)) {
                // If it also has no known text/image extension, treat as executable
                if (dot >= 0) {
                    String ext = fileName.substring(dot + 1);
                    if (!TEXT_EXTENSIONS.contains(ext) && !IMAGE_EXTENSIONS.contains(ext)) {
                        return true;
                    }
                }
            }
        } catch (SecurityException ignored) {}

        // Check Windows PE header magic "MZ"
        if (Files.isRegularFile(path)) {
            try (InputStream in = Files.newInputStream(path)) {
                byte[] magic = new byte[2];
                int read = in.read(magic);
                if (read == 2 && magic[0] == 'M' && magic[1] == 'Z') {
                    return true;
                }
            } catch (IOException ignored) {}
        }

        return false;
    }

    /**
     * Determines whether a file is an archive.
     */
    public static boolean isArchive(Path path) {
        if (path == null) return false;
        String fileName = path.getFileName().toString().toLowerCase(Locale.ROOT);
        int dot = fileName.lastIndexOf('.');
        if (dot >= 0) {
            String ext = fileName.substring(dot + 1);
            return ARCHIVE_EXTENSIONS.contains(ext);
        }
        return false;
    }

    /**
     * Checks if a file is safe to preview.
     */
    public static boolean isPreviewable(Path path) {
        if (path == null || !Files.isRegularFile(path)) {
            return false;
        }
        if (isExecutable(path)) {
            return false;
        }
        String fileName = path.getFileName().toString().toLowerCase(Locale.ROOT);
        int dot = fileName.lastIndexOf('.');
        if (dot >= 0) {
            String ext = fileName.substring(dot + 1);
            return TEXT_EXTENSIONS.contains(ext) || IMAGE_EXTENSIONS.contains(ext);
        }
        return false;
    }

    /**
     * Resolves the MIME type of a file.
     */
    public static String detectMimeType(Path path) {
        try {
            String probed = Files.probeContentType(path);
            if (probed != null && !probed.isBlank()) {
                return probed;
            }
        } catch (IOException ignored) {}

        String fileName = path.getFileName().toString().toLowerCase(Locale.ROOT);
        int dot = fileName.lastIndexOf('.');
        if (dot >= 0) {
            String ext = fileName.substring(dot + 1);
            return switch (ext) {
                case "txt", "log" -> "text/plain";
                case "md", "markdown" -> "text/markdown";
                case "json" -> "application/json";
                case "xml" -> "application/xml";
                case "yaml", "yml" -> "application/x-yaml";
                case "csv" -> "text/csv";
                case "html", "htm" -> "text/html";
                case "png" -> "image/png";
                case "jpg", "jpeg" -> "image/jpeg";
                case "gif" -> "image/gif";
                case "webp" -> "image/webp";
                case "svg" -> "image/svg+xml";
                case "zip" -> "application/zip";
                case "tar" -> "application/x-tar";
                case "pdf" -> "application/pdf";
                default -> "application/octet-stream";
            };
        }
        return "application/octet-stream";
    }

    /**
     * Generates a safe preview of the specified file.
     *
     * @param path target file path
     * @param maxBytes requested preview limit
     * @return PreviewResult with bounded data
     * @throws UnsafePreviewException if previewing an executable or unsafe file
     * @throws IOException on I/O failure
     */
    public PreviewResult generatePreview(Path path, int maxBytes) throws UnsafePreviewException, IOException {
        if (!Files.exists(path) || Files.isDirectory(path)) {
            throw new IOException("File does not exist or is a directory: " + path);
        }

        if (isExecutable(path)) {
            throw new UnsafePreviewException("Executable files are metadata-only by default and cannot be previewed: " + path.getFileName());
        }

        if (!isPreviewable(path)) {
            throw new UnsafePreviewException("File format is not marked previewable: " + path.getFileName());
        }

        int limit = (maxBytes <= 0) ? DEFAULT_MAX_PREVIEW_BYTES : Math.min(maxBytes, ABSOLUTE_MAX_PREVIEW_BYTES);
        long fileSize = Files.size(path);
        int toRead = (int) Math.min(fileSize, limit);

        byte[] buffer = new byte[toRead];
        try (InputStream in = new FileInputStream(path.toFile())) {
            int totalRead = 0;
            while (totalRead < toRead) {
                int read = in.read(buffer, totalRead, toRead - totalRead);
                if (read < 0) break;
                totalRead += read;
            }
            if (totalRead < toRead) {
                byte[] trimmed = new byte[totalRead];
                System.arraycopy(buffer, 0, trimmed, 0, totalRead);
                buffer = trimmed;
            }
        }

        boolean truncated = fileSize > buffer.length;
        String mimeType = detectMimeType(path);
        return new PreviewResult(buffer, mimeType, truncated, fileSize);
    }

    public static class UnsafePreviewException extends Exception {
        public UnsafePreviewException(String message) {
            super(message);
        }
    }
}
