package org.peerlink.core.android;

import org.peerlink.core.security.KeyStorageException;
import org.peerlink.core.security.SecureKeyStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.*;
import java.nio.file.*;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Objects;

/**
 * Android SecureKeyStore implementation.
 * Encrypts Ed25519 private keys at rest using an AES-256-GCM master key managed
 * by AndroidKeyStore (TEE/StrongBox) or a software master key in tests.
 *
 * Truthful security architecture:
 * - Signing is performed by portable Ed25519 software in memory.
 * - Private key material is encrypted at rest using AES-256-GCM.
 * - Invariant: Never silently regenerate or ignore corrupt ciphertext.
 */
public class AndroidKeyStoreSecureKeyStore implements SecureKeyStore {
    private static final Logger log = LoggerFactory.getLogger(AndroidKeyStoreSecureKeyStore.class);
    private static final String CIPHER_ALGO = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH_BITS = 128;
    private static final int GCM_IV_LENGTH_BYTES = 12;

    public interface MasterKeyProvider {
        SecretKey getOrCreateMasterKey(String alias) throws Exception;
        boolean isMasterKeyHardwareBacked(String alias);
        String getSecurityLevel(String alias);
    }

    private final Path keyDir;
    private final MasterKeyProvider masterKeyProvider;
    private final String masterKeyAlias;
    private final SecureRandom secureRandom = new SecureRandom();

    public AndroidKeyStoreSecureKeyStore(File baseDir, MasterKeyProvider masterKeyProvider, String masterKeyAlias) {
        Objects.requireNonNull(baseDir, "baseDir must not be null");
        this.keyDir = baseDir.toPath().resolve("keys");
        this.masterKeyProvider = Objects.requireNonNull(masterKeyProvider, "masterKeyProvider must not be null");
        this.masterKeyAlias = Objects.requireNonNull(masterKeyAlias, "masterKeyAlias must not be null");

        if (!Files.exists(keyDir)) {
            try {
                Files.createDirectories(keyDir);
            } catch (IOException e) {
                throw new RuntimeException("Failed to create key storage directory: " + keyDir, e);
            }
        }
    }

    @Override
    public synchronized void storePrivateKey(String keyId, byte[] privateKeyBytes) throws KeyStorageException {
        Objects.requireNonNull(keyId, "keyId must not be null");
        Objects.requireNonNull(privateKeyBytes, "privateKeyBytes must not be null");

        Path targetFile = keyDir.resolve(sanitizeKeyId(keyId) + ".enc");
        Path tempFile = keyDir.resolve(sanitizeKeyId(keyId) + ".tmp");

        try {
            SecretKey masterKey = masterKeyProvider.getOrCreateMasterKey(masterKeyAlias);
            Cipher cipher = Cipher.getInstance(CIPHER_ALGO);
            // In Android KeyStore, encryption requires the Keystore provider to generate the IV
            cipher.init(Cipher.ENCRYPT_MODE, masterKey);
            byte[] iv = cipher.getIV();
            byte[] cipherText = cipher.doFinal(privateKeyBytes);

            try (DataOutputStream dos = new DataOutputStream(Files.newOutputStream(tempFile, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING))) {
                dos.writeInt(0x50454552); // Magic 'PEER'
                dos.writeInt(1);          // Format version 1
                dos.writeUTF(keyId);
                dos.writeInt(iv.length);
                dos.write(iv);
                dos.writeInt(cipherText.length);
                dos.write(cipherText);
            }

            try {
                Files.move(tempFile, targetFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (AtomicMoveNotSupportedException e) {
                Files.move(tempFile, targetFile, StandardCopyOption.REPLACE_EXISTING);
            }

            log.info("Encrypted and stored private key [{}] at rest (Master key: {}, HW: {})",
                    keyId, masterKeyAlias, masterKeyProvider.isMasterKeyHardwareBacked(masterKeyAlias));
        } catch (Exception e) {
            try {
                Files.deleteIfExists(tempFile);
            } catch (IOException ignored) {}
            throw new KeyStorageException("Failed to encrypt and store private key [" + keyId + "]", e);
        }
    }

    @Override
    public synchronized byte[] getPrivateKey(String keyId) throws KeyStorageException {
        Objects.requireNonNull(keyId, "keyId must not be null");
        Path targetFile = keyDir.resolve(sanitizeKeyId(keyId) + ".enc");

        if (!Files.exists(targetFile)) {
            return null;
        }

        try (DataInputStream dis = new DataInputStream(Files.newInputStream(targetFile))) {
            int magic = dis.readInt();
            if (magic != 0x50454552) {
                throw new KeyStorageException("Corrupt private key file format for [" + keyId + "]: invalid magic header");
            }
            int version = dis.readInt();
            if (version != 1) {
                throw new KeyStorageException("Unsupported private key file format version: " + version);
            }
            String storedKeyId = dis.readUTF();
            if (!keyId.equals(storedKeyId)) {
                throw new KeyStorageException("Key ID mismatch: expected " + keyId + " but stored " + storedKeyId);
            }
            int ivLen = dis.readInt();
            if (ivLen != GCM_IV_LENGTH_BYTES) {
                throw new KeyStorageException("Corrupt IV length: " + ivLen);
            }
            byte[] iv = new byte[ivLen];
            dis.readFully(iv);

            int cipherLen = dis.readInt();
            if (cipherLen <= 0 || cipherLen > 1024 * 64) {
                throw new KeyStorageException("Invalid ciphertext length: " + cipherLen);
            }
            byte[] cipherText = new byte[cipherLen];
            dis.readFully(cipherText);

            SecretKey masterKey = masterKeyProvider.getOrCreateMasterKey(masterKeyAlias);
            Cipher cipher = Cipher.getInstance(CIPHER_ALGO);
            cipher.init(Cipher.DECRYPT_MODE, masterKey, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));

            return cipher.doFinal(cipherText);
        } catch (Exception e) {
            throw new KeyStorageException("Failed to decrypt private key [" + keyId + "] - possible corruption or invalid key", e);
        }
    }

    @Override
    public synchronized boolean hasKey(String keyId) {
        if (keyId == null) return false;
        Path targetFile = keyDir.resolve(sanitizeKeyId(keyId) + ".enc");
        return Files.exists(targetFile);
    }

    @Override
    public synchronized void deleteKey(String keyId) throws KeyStorageException {
        if (keyId == null) return;
        Path targetFile = keyDir.resolve(sanitizeKeyId(keyId) + ".enc");
        try {
            Files.deleteIfExists(targetFile);
        } catch (IOException e) {
            throw new KeyStorageException("Failed to delete key [" + keyId + "]", e);
        }
    }

    public boolean isMasterKeyHardwareBacked() {
        return masterKeyProvider.isMasterKeyHardwareBacked(masterKeyAlias);
    }

    public String getSecurityLevel() {
        return masterKeyProvider.getSecurityLevel(masterKeyAlias);
    }

    private String sanitizeKeyId(String keyId) {
        return keyId.replaceAll("[^a-zA-Z0-9_-]", "_");
    }

    @Override
    public void close() {
        // No persistent resources to close
    }

    /**
     * Software master key provider for JVM unit tests or test environments where AndroidKeyStore is absent.
     */
    public static class SoftwareMasterKeyProvider implements MasterKeyProvider {
        private final SecretKey softwareKey;

        public SoftwareMasterKeyProvider() {
            byte[] raw = new byte[32];
            new SecureRandom().nextBytes(raw);
            this.softwareKey = new SecretKeySpec(raw, "AES");
        }

        public SoftwareMasterKeyProvider(byte[] fixedSeed) {
            byte[] raw = Arrays.copyOf(fixedSeed, 32);
            this.softwareKey = new SecretKeySpec(raw, "AES");
        }

        @Override
        public SecretKey getOrCreateMasterKey(String alias) {
            return softwareKey;
        }

        @Override
        public boolean isMasterKeyHardwareBacked(String alias) {
            return false;
        }

        @Override
        public String getSecurityLevel(String alias) {
            return "SOFTWARE_TEST_HARNESS";
        }
    }
}
