package org.peerlink.core.access;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * Safely performs bounded byte reads for on-demand remote file retrieval.
 * Protects against resource exhaustion and uncontrolled memory consumption.
 */
public final class BoundedFileReader {

    public static final int DEFAULT_MAX_RETRIEVAL_BYTES = 4 * 1024 * 1024; // 4 MB
    public static final int ABSOLUTE_MAX_RETRIEVAL_BYTES = 16 * 1024 * 1024; // 16 MB

    public record ReadResult(
            byte[] data,
            long totalFileSizeBytes,
            String sha256Hex,
            boolean isComplete
    ) {}

    private BoundedFileReader() {}

    /**
     * Reads up to maxBytesToRead bytes from the given regular file and computes its SHA-256 hash.
     *
     * @param file target file
     * @param requestedMaxBytes max bytes to read (capped at ABSOLUTE_MAX_RETRIEVAL_BYTES)
     * @return ReadResult containing data bytes, total size, hash, and completeness flag
     * @throws IOException on I/O error
     */
    public static ReadResult readBounded(Path file, int requestedMaxBytes) throws IOException {
        if (!Files.isRegularFile(file)) {
            throw new IOException("Target is not a regular file: " + file);
        }

        long totalSize = Files.size(file);
        int effectiveLimit = requestedMaxBytes <= 0 ?
                DEFAULT_MAX_RETRIEVAL_BYTES :
                Math.min(requestedMaxBytes, ABSOLUTE_MAX_RETRIEVAL_BYTES);

        int bytesToRead = (int) Math.min(totalSize, (long) effectiveLimit);
        byte[] buffer = new byte[bytesToRead];

        MessageDigest md;
        try {
            md = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 digest unavailable", e);
        }

        int totalRead = 0;
        try (InputStream in = Files.newInputStream(file)) {
            while (totalRead < bytesToRead) {
                int read = in.read(buffer, totalRead, bytesToRead - totalRead);
                if (read < 0) break;
                totalRead += read;
            }
        }

        if (totalRead < buffer.length) {
            byte[] trimmed = new byte[totalRead];
            System.arraycopy(buffer, 0, trimmed, 0, totalRead);
            buffer = trimmed;
        }

        md.update(buffer);
        String hashHex = bytesToHex(md.digest());
        boolean isComplete = (totalSize == totalRead);

        return new ReadResult(buffer, totalSize, hashHex, isComplete);
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
