package org.peerlink.core.access;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Objects;
import java.util.UUID;

/**
 * Handles safe destination placement for downloaded or retrieved remote content.
 *
 * <p>Security & Isolation Invariants:
 * <ul>
 *   <li>Treats relative destination paths as untrusted input; validates against sandbox root.</li>
 *   <li>Writes content into an isolated temporary staging file (.part) first.</li>
 *   <li>Computes and validates cryptographic SHA-256 integrity before promoting to final destination.</li>
 *   <li>Atomically commits files to destination.</li>
 *   <li>Explicitly strips executable permissions (setExecutable(false)) to isolate received content.</li>
 *   <li>Guarantees received content is NEVER automatically executed.</li>
 * </ul>
 */
public final class SafeDestinationHandler {

    private final Path destinationRoot;
    private final PathSandboxValidator validator;

    public SafeDestinationHandler(Path destinationRoot) {
        this(destinationRoot, new PathSandboxValidator());
    }

    public SafeDestinationHandler(Path destinationRoot, PathSandboxValidator validator) {
        this.destinationRoot = Objects.requireNonNull(destinationRoot, "destinationRoot must not be null");
        this.validator = Objects.requireNonNull(validator, "validator must not be null");
    }

    public Path getDestinationRoot() {
        return destinationRoot;
    }

    /**
     * Safely commits bytes into the destination directory under relativePath.
     *
     * @param relativePath relative destination path
     * @param data file content bytes
     * @param expectedSha256 optional expected SHA-256 hex hash (null/blank to skip check)
     * @return Path to the committed, safe file
     * @throws PathSandboxValidator.PathTraversalException on boundary escape attempt
     * @throws SecurityException on hash mismatch
     * @throws IOException on write/move error
     */
    public Path commitContent(String relativePath, byte[] data, String expectedSha256)
            throws PathSandboxValidator.PathTraversalException, SecurityException, IOException {
        Objects.requireNonNull(data, "data must not be null");
        Path finalTarget = validator.resolveAndValidate(destinationRoot, relativePath);

        // Ensure parent directory exists
        Path parent = finalTarget.getParent();
        if (parent != null && !Files.exists(parent)) {
            Files.createDirectories(parent);
        }

        // Staging file in same directory for atomic move
        Path tempFile = parent != null ?
                parent.resolve(finalTarget.getFileName() + ".part." + UUID.randomUUID()) :
                destinationRoot.resolve(".part." + UUID.randomUUID());

        MessageDigest md;
        try {
            md = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }

        try {
            try (OutputStream out = Files.newOutputStream(tempFile, StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING)) {
                out.write(data);
                md.update(data);
            }

            String actualSha256 = bytesToHex(md.digest());

            if (expectedSha256 != null && !expectedSha256.isBlank()) {
                if (!expectedSha256.trim().equalsIgnoreCase(actualSha256)) {
                    Files.deleteIfExists(tempFile);
                    throw new SecurityException("Cryptographic hash mismatch for retrieved file " + relativePath +
                            ": expected " + expectedSha256 + ", got " + actualSha256);
                }
            }

            // Atomic commit to destination
            try {
                Files.move(tempFile, finalTarget, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException e) {
                Files.move(tempFile, finalTarget, StandardCopyOption.REPLACE_EXISTING);
            }

            // Enforce non-executable permissions
            try {
                finalTarget.toFile().setExecutable(false, false);
            } catch (SecurityException ignored) {}

            return finalTarget;

        } catch (Exception e) {
            Files.deleteIfExists(tempFile);
            if (e instanceof SecurityException se) throw se;
            if (e instanceof IOException ioe) throw ioe;
            throw new IOException("Failed to commit safe destination file: " + e.getMessage(), e);
        }
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
