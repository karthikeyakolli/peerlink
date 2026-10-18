package org.peerlink.macos.filesystem;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.FileSystemException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.text.Normalizer;

import static org.junit.jupiter.api.Assertions.*;

public class MacApfsFileProviderTest {

    @TempDir
    Path tempDir;

    private MacApfsFileProvider provider;

    @BeforeEach
    void setUp() {
        provider = new MacApfsFileProvider(tempDir);
    }

    @Test
    void testApfsUnicodeNfcNormalization() {
        // 'e' followed by combining acute accent U+0301 (NFD format)
        String nfdString = "cafe\u0301.txt";
        String normalized = provider.sanitizeApfsPath(nfdString);

        // In NFC, this becomes cafe with precomposed acute accent: U+00E9
        assertTrue(Normalizer.isNormalized(normalized, Normalizer.Form.NFC));
        assertEquals("café.txt", normalized);
    }

    @Test
    void testColonRejection() {
        // macOS APFS rejects colons in filenames
        assertThrows(IllegalArgumentException.class, () -> provider.sanitizeApfsPath("file:name.txt"));
        assertThrows(IllegalArgumentException.class, () -> provider.sanitizeApfsPath("folder:sub/file.txt"));
    }

    @Test
    void testNulByteRejection() {
        assertThrows(SecurityException.class, () -> provider.sanitizeApfsPath("file\0name.txt"));
    }

    @Test
    void testPathTraversalRejection() {
        assertThrows(SecurityException.class, () -> provider.sanitizeApfsPath("../secret.pem"));
        assertThrows(SecurityException.class, () -> provider.sanitizeApfsPath("docs/../../secret.pem"));
        assertThrows(SecurityException.class, () -> provider.sanitizeApfsPath("/etc/passwd"));
    }

    @Test
    void testValidPathResolution() {
        Path resolved = provider.resolvePath("transfers/image.png");
        assertNotNull(resolved);
        assertTrue(resolved.startsWith(tempDir));
        assertEquals(tempDir.resolve("transfers/image.png").normalize(), resolved);
    }

    @Test
    void testSecureDirectoryAndFileCreation() throws IOException {
        Path secDir = provider.resolvePath("keys");
        provider.createSecureDirectory(secDir);
        assertTrue(Files.exists(secDir));
        assertTrue(Files.isDirectory(secDir));

        Path secFile = provider.resolvePath("keys/identity.key");
        byte[] content = "private-key-bytes".getBytes();
        provider.createSecureFile(secFile, content);

        assertTrue(Files.exists(secFile));
        assertArrayEquals(content, Files.readAllBytes(secFile));
    }

    @Test
    void testSymlinkSafety() throws IOException {
        Path targetFile = provider.resolvePath("target.txt");
        Files.writeString(targetFile, "target content");

        Path linkFile = provider.resolvePath("link.txt");
        try {
            Files.createSymbolicLink(linkFile, targetFile);
            assertTrue(provider.verifySymlinkSafety(linkFile));
        } catch (UnsupportedOperationException | FileSystemException ignored) {
            // Some environments lack symlink creation privileges
        }
    }
}
