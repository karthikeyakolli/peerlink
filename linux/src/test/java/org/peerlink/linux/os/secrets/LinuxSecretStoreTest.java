package org.peerlink.linux.os.secrets;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class LinuxSecretStoreTest {

    @TempDir
    Path tempDir;

    private LinuxSecretStore store;

    @BeforeEach
    void setUp() {
        store = new LinuxSecretStore(tempDir);
    }

    @Test
    void testStoreAndLoadCredentialRoundtrip() throws IOException {
        String key = "linux-peerlink-node-key";
        byte[] secret = "super-secret-ed25519-private-seed".getBytes(StandardCharsets.UTF_8);

        store.storeCredential(key, secret);
        assertTrue(store.hasCredential(key));

        Optional<byte[]> loaded = store.loadCredential(key);
        assertTrue(loaded.isPresent());
        assertArrayEquals(secret, loaded.get());
    }

    @Test
    void testLoadNonExistentReturnsEmpty() throws IOException {
        Optional<byte[]> result = store.loadCredential("non-existent-token");
        assertFalse(result.isPresent());
        assertFalse(store.hasCredential("non-existent-token"));
    }

    @Test
    void testDeleteCredential() throws IOException {
        String key = "session-token-to-delete";
        byte[] secret = "temporary-session-data".getBytes(StandardCharsets.UTF_8);

        store.storeCredential(key, secret);
        assertTrue(store.hasCredential(key));

        boolean deleted = store.deleteCredential(key);
        assertTrue(deleted);
        assertFalse(store.hasCredential(key));

        Optional<byte[]> loaded = store.loadCredential(key);
        assertFalse(loaded.isPresent());
    }

    @Test
    void testProtectAndUnprotectRoundtrip() {
        byte[] original = "arbitrary-linux-secret-payload".getBytes(StandardCharsets.UTF_8);
        byte[] encrypted = LinuxSecretStore.protect(original);

        assertNotNull(encrypted);
        assertNotEquals(0, encrypted.length);
        assertFalse(java.util.Arrays.equals(original, encrypted));

        byte[] decrypted = LinuxSecretStore.unprotect(encrypted);
        assertArrayEquals(original, decrypted);
    }

    @Test
    void testEmptyAndNullHandledSafely() {
        assertArrayEquals(new byte[0], LinuxSecretStore.protect(null));
        assertArrayEquals(new byte[0], LinuxSecretStore.protect(new byte[0]));
        assertArrayEquals(new byte[0], LinuxSecretStore.unprotect(null));
        assertArrayEquals(new byte[0], LinuxSecretStore.unprotect(new byte[0]));
    }
}
