package org.peerlink.core.chaos;

import org.peerlink.core.transfer.FileManifestBuilder;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;

/**
 * Verifier for cryptographic hash validation during chaos testing.
 */
public final class ChaosHashVerifier {

    public static String computeSha256(Path path) throws IOException {
        return FileManifestBuilder.calculateSha256Hex(path);
    }

    public static boolean verifyFilesMatch(Path path1, Path path2) throws IOException {
        if (!Files.exists(path1) || !Files.exists(path2)) {
            return false;
        }
        if (Files.size(path1) != Files.size(path2)) {
            return false;
        }
        String sha1 = computeSha256(path1);
        String sha2 = computeSha256(path2);
        return Objects.equals(sha1.toLowerCase(), sha2.toLowerCase());
    }

    public static boolean verifyContentEquals(Path file, byte[] expectedBytes) throws IOException {
        byte[] actual = Files.readAllBytes(file);
        return java.util.Arrays.equals(actual, expectedBytes);
    }
}
