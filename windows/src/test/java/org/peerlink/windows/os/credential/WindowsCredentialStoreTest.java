package org.peerlink.windows.os.credential;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

class WindowsCredentialStoreTest {

    @TempDir
    Path tempDir;

    private WindowsCredentialStore store;

    @BeforeEach
    void setUp() {
        store = new WindowsCredentialStore(tempDir);
    }

    @Test
    void testStoreAndLoadCredentialRoundtrip() throws IOException {
        String key = "peerlink-device-secret-key";
        byte[] secret = "super-confidential-ed25519-seed".getBytes(StandardCharsets.UTF_8);

        store.storeCredential(key, secret);
        assertTrue(store.hasCredential(key));

        Optional<byte[]> loaded = store.loadCredential(key);
        assertTrue(loaded.isPresent());
        assertArrayEquals(secret, loaded.get());
    }

    @Test
    void testLoadNonExistentCredentialReturnsEmpty() throws IOException {
        Optional<byte[]> result = store.loadCredential("non-existent-key");
        assertFalse(result.isPresent());
        assertFalse(store.hasCredential("non-existent-key"));
    }

    @Test
    void testDeleteCredential() throws IOException {
        String key = "temporary-session-token";
        byte[] secret = "token-data-12345".getBytes(StandardCharsets.UTF_8);

        store.storeCredential(key, secret);
        assertTrue(store.hasCredential(key));

        boolean deleted = store.deleteCredential(key);
        assertTrue(deleted);
        assertFalse(store.hasCredential(key));

        Optional<byte[]> loaded = store.loadCredential(key);
        assertFalse(loaded.isPresent());
    }

    @Test
    void testProtectAndUnprotectStaticRoundtrip() {
        byte[] original = "arbitrary-bytes-for-dpapi-or-fallback".getBytes(StandardCharsets.UTF_8);
        byte[] encrypted = WindowsCredentialStore.protect(original);

        assertNotNull(encrypted);
        assertNotEquals(0, encrypted.length);
        // Ciphertext should not match original plaintext
        assertFalse(java.util.Arrays.equals(original, encrypted));

        byte[] decrypted = WindowsCredentialStore.unprotect(encrypted);
        assertArrayEquals(original, decrypted);
    }

    @Test
    void testNullAndEmptyInputsHandledSafely() {
        assertArrayEquals(new byte[0], WindowsCredentialStore.protect(null));
        assertArrayEquals(new byte[0], WindowsCredentialStore.protect(new byte[0]));
        assertArrayEquals(new byte[0], WindowsCredentialStore.unprotect(null));
        assertArrayEquals(new byte[0], WindowsCredentialStore.unprotect(new byte[0]));
    }
}
