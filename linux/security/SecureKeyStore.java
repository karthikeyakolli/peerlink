package org.peerlink.core.security;

/**
 * Secure key storage abstraction.
 * Enforces zero private keys in logs, memory sanitization, and hardware or OS-level storage isolation.
 */
public interface SecureKeyStore extends AutoCloseable {
    void storePrivateKey(String keyId, byte[] privateKeyBytes) throws KeyStorageException;
    byte[] getPrivateKey(String keyId) throws KeyStorageException;
    boolean hasKey(String keyId);
    void deleteKey(String keyId) throws KeyStorageException;
}
