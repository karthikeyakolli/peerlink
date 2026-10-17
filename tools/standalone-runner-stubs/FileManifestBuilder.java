package org.peerlink.core.transfer;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * Standalone test stub for FileManifestBuilder providing exact SHA-256 calculation.
 */
public final class FileManifestBuilder {

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

        return toHexString(digest.digest());
    }

    public static String calculateSha256Hex(byte[] data) {
        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }
        return toHexString(digest.digest(data));
    }

    private static String toHexString(byte[] hash) {
        return java.util.HexFormat.of().formatHex(hash);
    }
}
