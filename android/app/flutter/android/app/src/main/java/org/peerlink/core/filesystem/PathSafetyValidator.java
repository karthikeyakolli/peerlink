package org.peerlink.core.filesystem;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.Normalizer;
import java.util.*;
import java.util.regex.Pattern;

/**
 * Authoritative filesystem and path safety validator.
 * Enforces:
 * - Rejection of absolute paths, drive letters, UNC shares, and traversal segments (.., .).
 * - Rejection of Windows reserved device names (CON, PRN, AUX, NUL, COM1-9, LPT1-9).
 * - Rejection of forbidden characters (<, >, :, ", |, ?, *), control characters, and null bytes.
 * - Rejection of alternate data streams (colon in filename).
 * - Rejection of trailing dots and spaces that Windows strips.
 * - Unicode NFC normalization.
 * - Symlink and reparse point isolation within designated boundaries.
 * - Opaque, safe internal staging directory naming.
 */
public final class PathSafetyValidator {

    private static final int MAX_RELATIVE_PATH_LENGTH = 1024;
    private static final int MAX_FILENAME_LENGTH = 255;

    private static final Pattern DRIVE_LETTER_PATTERN = Pattern.compile("^[a-zA-Z]:.*");
    private static final Pattern RESERVED_WINDOWS_NAMES = Pattern.compile(
            "^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\\..*)?$", Pattern.CASE_INSENSITIVE);
    private static final Pattern FORBIDDEN_CHARS_PATTERN = Pattern.compile("[<>:\"|?*\\x00-\\x1F\\x7F]");

    private PathSafetyValidator() {}

    /**
     * Validates and normalizes a relative path transmitted across the network.
     *
     * @param rawRelativePath The unverified relative path from the manifest
     * @return Cleaned, NFC-normalized relative path using '/' separators
     * @throws SecurityException or IllegalArgumentException if the path violates safety rules
     */
    public static String validateRelativePath(String rawRelativePath) {
        if (rawRelativePath == null || rawRelativePath.isBlank()) {
            throw new IllegalArgumentException("Relative path cannot be null or blank");
        }

        if (rawRelativePath.length() > MAX_RELATIVE_PATH_LENGTH) {
            throw new IllegalArgumentException("Relative path exceeds maximum length of " + MAX_RELATIVE_PATH_LENGTH);
        }

        // 1. Normalize Unicode to NFC
        String normalized = Normalizer.normalize(rawRelativePath, Normalizer.Form.NFC);

        // 2. Normalize path separators to '/'
        normalized = normalized.replace('\\', '/');

        // 3. Reject absolute paths, UNC shares, and drive letters
        if (normalized.startsWith("/") || normalized.startsWith("//")) {
            throw new SecurityException("Absolute path is forbidden in network manifest: " + rawRelativePath);
        }
        if (DRIVE_LETTER_PATTERN.matcher(normalized).matches()) {
            throw new SecurityException("Drive letter prefix is forbidden in relative path: " + rawRelativePath);
        }

        // 4. Validate individual segments
        String[] segments = normalized.split("/", -1);
        StringBuilder sanitized = new StringBuilder();

        for (int i = 0; i < segments.length; i++) {
            String seg = segments[i];

            if (seg.isEmpty()) {
                // Reject empty segments (caused by '//' or trailing '/')
                if (i == segments.length - 1 && normalized.endsWith("/")) {
                    // Trailing slash represents directory; ignore trailing empty segment
                    continue;
                }
                throw new SecurityException("Consecutive slashes are forbidden in relative path: " + rawRelativePath);
            }

            if (".".equals(seg) || "..".equals(seg)) {
                throw new SecurityException("Path traversal element ('" + seg + "') detected in: " + rawRelativePath);
            }

            if (seg.length() > MAX_FILENAME_LENGTH) {
                throw new IllegalArgumentException("Path component exceeds maximum length of " + MAX_FILENAME_LENGTH + ": " + seg);
            }

            // Check for forbidden characters and control characters
            if (FORBIDDEN_CHARS_PATTERN.matcher(seg).find()) {
                throw new SecurityException("Path component contains forbidden characters or control codes: " + seg);
            }

            // Reject trailing dots and spaces (causes silent stripping / collisions on Windows)
            if (seg.endsWith(".") || seg.endsWith(" ")) {
                throw new SecurityException("Path component cannot end with a dot or space: '" + seg + "'");
            }

            // Reject Windows reserved device names
            if (RESERVED_WINDOWS_NAMES.matcher(seg).matches()) {
                throw new SecurityException("Path component matches reserved device name: " + seg);
            }

            if (sanitized.length() > 0) {
                sanitized.append('/');
            }
            sanitized.append(seg);
        }

        if (sanitized.length() == 0) {
            throw new IllegalArgumentException("Sanitized relative path is empty");
        }

        return sanitized.toString();
    }

    /**
     * Resolves an incoming relative path safely within a destination root.
     * Ensures destination path stays strictly inside destinationRoot and does not follow symlinks outside.
     */
    public static Path resolveSafeDestination(Path destinationRoot, String rawRelativePath) {
        if (destinationRoot == null) {
            throw new IllegalArgumentException("Destination root cannot be null");
        }

        String validatedRelPath = validateRelativePath(rawRelativePath);
        Path normalizedRoot = destinationRoot.toAbsolutePath().normalize();

        // Check if destinationRoot itself is a symlink pointing outside
        if (Files.isSymbolicLink(normalizedRoot)) {
            try {
                normalizedRoot = normalizedRoot.toRealPath();
            } catch (IOException e) {
                throw new SecurityException("Cannot resolve destination root symlink: " + normalizedRoot, e);
            }
        }

        Path target = normalizedRoot.resolve(validatedRelPath).normalize();

        // Boundary verification
        if (!target.startsWith(normalizedRoot)) {
            throw new SecurityException("Path traversal attempt: target " + target + " is outside " + normalizedRoot);
        }

        // Verify intermediate existing directories are not symlinks/junctions pointing outside
        Path curr = target.getParent();
        while (curr != null && !curr.equals(normalizedRoot)) {
            if (Files.exists(curr, LinkOption.NOFOLLOW_LINKS)) {
                if (Files.isSymbolicLink(curr)) {
                    throw new SecurityException("Intermediate directory contains a symlink, which is prohibited: " + curr);
                }
            }
            curr = curr.getParent();
        }

        return target;
    }

    /**
     * Derives an opaque, deterministic, collision-resistant staging directory name
     * from an incoming transfer identifier.
     * Never uses unsanitized remote values as directory names.
     */
    public static String deriveOpaqueStagingName(String transferId) {
        if (transferId == null || transferId.isBlank()) {
            throw new IllegalArgumentException("Transfer ID cannot be null or blank");
        }

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(transferId.getBytes(StandardCharsets.UTF_8));
            return "stg_" + HexFormat.of().formatHex(hash, 0, 16);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    /**
     * Checks for duplicate and case-colliding relative paths in a manifest items collection.
     */
    public static void validateNoCollisions(List<String> relativePaths) {
        if (relativePaths == null) return;

        Set<String> exactSet = new HashSet<>();
        Set<String> lowerSet = new HashSet<>();

        for (String p : relativePaths) {
            String norm = validateRelativePath(p);
            if (!exactSet.add(norm)) {
                throw new IllegalArgumentException("Duplicate item path in manifest: " + norm);
            }
            if (!lowerSet.add(norm.toLowerCase(Locale.ROOT))) {
                throw new IllegalArgumentException("Case-colliding item path in manifest: " + norm);
            }
        }
    }
}
