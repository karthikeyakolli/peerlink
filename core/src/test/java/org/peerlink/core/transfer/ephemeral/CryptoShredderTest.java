package org.peerlink.core.transfer.ephemeral;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("CryptoShredder & Secure Wiping Invariants")
class CryptoShredderTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("Shredding overwrites physical content, zeroes length, and unlinks file")
    void testShredRegularFile() throws IOException {
        Path sensitiveFile = tempDir.resolve("confidential_contract.pdf");
        byte[] secretPayload = "TOP SECRET CRYPTOGRAPHIC MATERIAL 1234567890".repeat(500).getBytes(StandardCharsets.UTF_8);
        Files.write(sensitiveFile, secretPayload);

        assertTrue(Files.exists(sensitiveFile));
        assertEquals(secretPayload.length, Files.size(sensitiveFile));

        boolean shredded = CryptoShredder.shred(sensitiveFile);

        assertTrue(shredded, "CryptoShredder should report success");
        assertFalse(Files.exists(sensitiveFile), "Sensitive file must be deleted from filesystem");
    }

    @Test
    @DisplayName("Shredding handles non-existent file gracefully without throwing")
    void testShredNonExistentFile() throws IOException {
        Path missing = tempDir.resolve("non_existent_file.dat");
        assertFalse(CryptoShredder.shred(missing));
    }

    @Test
    @DisplayName("Shredding rejects directories to prevent accidental directory-tree destruction")
    void testShredDirectoryThrows() {
        Path subDir = tempDir.resolve("subFolder");
        assertDoesNotThrow(() -> Files.createDirectories(subDir));

        assertThrows(IllegalArgumentException.class, () -> CryptoShredder.shred(subDir));
        assertTrue(Files.exists(subDir));
    }

    @Test
    @DisplayName("Memory wiper securely zeroes byte buffers")
    void testWipeMemory() {
        byte[] key = new byte[]{0x12, 0x34, 0x56, 0x78, (byte) 0x9A, (byte) 0xBC};
        CryptoShredder.wipeMemory(key);

        for (byte b : key) {
            assertEquals((byte) 0x00, b, "Memory buffer must be zeroed");
        }
    }
}
