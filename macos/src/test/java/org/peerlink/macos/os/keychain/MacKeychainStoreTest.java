package org.peerlink.macos.os.keychain;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class MacKeychainStoreTest {

    @TempDir
    Path tempDir;

    private MacKeychainStore store;

    @BeforeEach
    void setUp() {
        // Force fallback mode for isolated reproducible unit tests across all environments
        store = new MacKeychainStore(tempDir, true);
    }

    @Test
    void testStoreAndRetrieveSecret() {
        String service = "org.peerlink.auth";
        String account = "device-identity-key";
        String secret = "ecdsa-private-key-material-12345";

        assertFalse(store.hasSecret(service, account));
        store.storeSecret(service, account, secret);

        assertTrue(store.hasSecret(service, account));
        Optional<String> retrieved = store.getSecret(service, account);
        assertTrue(retrieved.isPresent());
        assertEquals(secret, retrieved.get());
    }

    @Test
    void testDeleteSecret() {
        String service = "org.peerlink.tokens";
        String account = "relay-session-token";
        String secret = "token-abc-xyz";

        store.storeSecret(service, account, secret);
        assertTrue(store.hasSecret(service, account));

        boolean deleted = store.deleteSecret(service, account);
        assertTrue(deleted);
        assertFalse(store.hasSecret(service, account));
        assertEquals(Optional.empty(), store.getSecret(service, account));
    }

    @Test
    void testOverwriteSecret() {
        String service = "org.peerlink.creds";
        String account = "node1";

        store.storeSecret(service, account, "old-secret");
        assertEquals(Optional.of("old-secret"), store.getSecret(service, account));

        store.storeSecret(service, account, "new-secret");
        assertEquals(Optional.of("new-secret"), store.getSecret(service, account));
    }
}
