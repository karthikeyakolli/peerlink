package org.peerlink.core.access;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Validates and resolves requested relative paths strictly within a share's root boundary.
 *
 * <p>Protects against:
 * <ul>
 *   <li>Directory traversal ("..", "..\\", "../")</li>
 *   <li>Windows drive prefix injection ("C:", "D:\\")</li>
 *   <li>UNC network shares ("\\server\share")</li>
 *   <li>NTFS Alternate Data Streams (":$DATA")</li>
 *   <li>Null byte poison characters ("\0")</li>
 *   <li>Symlink / junction / reparse point escaping beyond the share boundary</li>
 * </ul>
 */
public final class PathSandboxValidator {

    private final boolean allowSymlinksWithinRoot;

    public PathSandboxValidator() {
        this(true); // Allow symlinks only if target stays strictly within the root
    }

    public PathSandboxValidator(boolean allowSymlinksWithinRoot) {
        this.allowSymlinksWithinRoot = allowSymlinksWithinRoot;
    }

    /**
     * Resolves and validates a relative path against the shared root directory.
     *
     * @param shareRoot the authoritative root directory for the share
     * @param requestedRelativePath the client-supplied relative path
     * @return the safe, resolved canonical path
     * @throws PathTraversalException if any traversal or boundary escape is detected
     */
    public Path resolveAndValidate(Path shareRoot, String requestedRelativePath) throws PathTraversalException {
        if (shareRoot == null) {
            throw new PathTraversalException("Share root cannot be null");
        }

        // Canonicalize root
        Path canonicalRoot;
        try {
            if (Files.exists(shareRoot)) {
                canonicalRoot = shareRoot.toRealPath();
            } else {
                canonicalRoot = shareRoot.toAbsolutePath().normalize();
            }
        } catch (IOException e) {
            canonicalRoot = shareRoot.toAbsolutePath().normalize();
        }

        if (requestedRelativePath == null || requestedRelativePath.isBlank() || ".".equals(requestedRelativePath.trim())) {
            return canonicalRoot;
        }

        String raw = requestedRelativePath.trim();

        // 1. Detect poison null bytes
        if (raw.indexOf('\0') >= 0) {
            throw new PathTraversalException("Null byte detected in path: " + raw);
        }

        // 2. Detect Windows drive specifiers (e.g. C:, D:)
        if (raw.length() >= 2 && Character.isLetter(raw.charAt(0)) && raw.charAt(1) == ':') {
            throw new PathTraversalException("Absolute drive letter prohibited in relative path: " + raw);
        }

        // 3. Detect UNC prefixes
        if (raw.startsWith("\\\\") || raw.startsWith("//")) {
            throw new PathTraversalException("UNC network paths prohibited in relative path: " + raw);
        }

        // 4. Detect NTFS Alternate Data Streams (colon after filename)
        if (raw.indexOf(':') >= 0) {
            throw new PathTraversalException("Alternate data streams prohibited in relative path: " + raw);
        }

        // 5. Detect leading root slashes
        if (raw.startsWith("/") || raw.startsWith("\\")) {
            // Strip leading slashes to prevent root-relative escaping
            raw = raw.replaceAll("^[\\\\/]+", "");
        }

        // 6. Split and inspect path components for ".."
        Path normalizedRelative = Paths.get(raw).normalize();
        for (Path part : normalizedRelative) {
            String partStr = part.toString();
            if ("..".equals(partStr)) {
                throw new PathTraversalException("Parent directory traversal prohibited: " + raw);
            }
        }

        // 7. Resolve against root
        Path resolved = canonicalRoot.resolve(normalizedRelative).normalize();

        // 8. Canonical check: resolved path must strictly start with canonicalRoot
        if (!resolved.startsWith(canonicalRoot)) {
            throw new PathTraversalException("Resolved path escaped root directory: " + raw);
        }

        // 9. Symlink / Junction / Reparse point inspection
        if (Files.exists(resolved, LinkOption.NOFOLLOW_LINKS)) {
            try {
                Path realResolved = resolved.toRealPath();
                if (!realResolved.startsWith(canonicalRoot)) {
                    throw new PathTraversalException("Symlink target escapes share boundary: " + raw + " -> " + realResolved);
                }
                if (Files.isSymbolicLink(resolved) && !allowSymlinksWithinRoot) {
                    throw new PathTraversalException("Symlinks are disallowed by policy: " + raw);
                }
                return realResolved;
            } catch (IOException e) {
                throw new PathTraversalException("Failed to resolve real path: " + raw, e);
            }
        } else {
            // Verify existing ancestors do not escape through symlinks/junctions
            Path existingAncestor = resolved.getParent();
            while (existingAncestor != null && !Files.exists(existingAncestor, LinkOption.NOFOLLOW_LINKS)) {
                existingAncestor = existingAncestor.getParent();
            }
            if (existingAncestor != null) {
                try {
                    Path realAncestor = existingAncestor.toRealPath();
                    if (!realAncestor.startsWith(canonicalRoot)) {
                        throw new PathTraversalException("Ancestor symlink escapes share boundary: " + raw + " -> " + realAncestor);
                    }
                    if (Files.isSymbolicLink(existingAncestor) && !allowSymlinksWithinRoot) {
                        throw new PathTraversalException("Symlinks are disallowed by policy: " + raw);
                    }
                } catch (IOException e) {
                    throw new PathTraversalException("Failed to resolve real path of ancestor: " + raw, e);
                }
            }
        }

        return resolved;
    }

    /**
     * Exception thrown when a path traversal, symlink escape, or invalid character is detected.
     */
    public static class PathTraversalException extends Exception {
        public PathTraversalException(String message) {
            super(message);
        }

        public PathTraversalException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
