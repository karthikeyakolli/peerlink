package org.peerlink.core.security;

import java.util.Arrays;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Ephemeral thread-safe in-memory SecureKeyStore for testing and isolated runs.
 * Sanitizes keys upon deletion or close.
 */
public class InMemorySecureKeyStore implements SecureKeyStore {

    private final Map<String, byte[]> keys = new ConcurrentHashMap<>();

    @Override
    public void storePrivateKey(String keyId, byte[] privateKeyBytes) throws KeyStorageException {
        if (keyId == null || keyId.isBlank() || privateKeyBytes == null || privateKeyBytes.length == 0) {
            throw new KeyStorageException("Invalid keyId or privateKeyBytes");
        }
        keys.put(keyId, privateKeyBytes.clone());
    }

    @Override
    public byte[] getPrivateKey(String keyId) throws KeyStorageException {
        byte[] key = keys.get(keyId);
        if (key == null) {
            throw new KeyStorageException("Key not found: " + keyId);
        }
        return key.clone();
    }

    @Override
    public boolean hasKey(String keyId) {
        return keys.containsKey(keyId);
    }

    @Override
    public void deleteKey(String keyId) throws KeyStorageException {
        byte[] removed = keys.remove(keyId);
        if (removed != null) {
            Arrays.fill(removed, (byte) 0);
        }
    }

    @Override
    public void close() {
        for (byte[] k : keys.values()) {
            Arrays.fill(k, (byte) 0);
        }
        keys.clear();
    }
}
