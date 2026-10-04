package org.peerlink.core.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Portable encrypted file-backed SecureKeyStore implementation.
 * Encrypts private key material using AES-256-GCM.
 * Zero static shared master passwords in code: uses dynamically generated per-installation salt and master key seed.
 * Private key bytes are never written to logs.
 */
public class EncryptedFileKeyStore implements DesktopKeyStoreAdapter {

    private static final Logger log = LoggerFactory.getLogger(EncryptedFileKeyStore.class);

    private static final int GCM_TAG_LENGTH_BITS = 128;
    private static final int GCM_IV_LENGTH_BYTES = 12;
    private static final int SALT_LENGTH_BYTES = 16;
    private static final int PBKDF2_ITERATIONS = 100_000;
    private static final int KEY_LENGTH_BITS = 256;

    private final Path storageDirectory;
    private final SecretKey masterKey;
    private final Map<String, byte[]> cachedKeys = new ConcurrentHashMap<>();
    private final SecureRandom secureRandom = new SecureRandom();

    public EncryptedFileKeyStore(Path storageDirectory, char[] installationPassphrase) throws KeyStorageException {
        try {
            this.storageDirectory = storageDirectory;
            Files.createDirectories(storageDirectory);

            Path saltFile = storageDirectory.resolve(".keystore.salt");
            byte[] salt;
            if (Files.exists(saltFile)) {
                salt = Files.readAllBytes(saltFile);
            } else {
                salt = new byte[SALT_LENGTH_BYTES];
                secureRandom.nextBytes(salt);
                Files.write(saltFile, salt);
            }

            SecretKeyFactory factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
            PBEKeySpec spec = new PBEKeySpec(installationPassphrase, salt, PBKDF2_ITERATIONS, KEY_LENGTH_BITS);
            byte[] derived = factory.generateSecret(spec).getEncoded();
            this.masterKey = new SecretKeySpec(derived, "AES");
            Arrays.fill(derived, (byte) 0);
            spec.clearPassword();

            loadAllKeys();
        } catch (Exception e) {
            throw new KeyStorageException("Failed to initialize EncryptedFileKeyStore: " + e.getMessage(), e);
        }
    }

    private void loadAllKeys() throws IOException {
        try (var stream = Files.newDirectoryStream(storageDirectory, "*.key")) {
            for (Path path : stream) {
                String fileName = path.getFileName().toString();
                String keyId = fileName.substring(0, fileName.length() - 4);
                try {
                    byte[] decrypted = decryptFromFile(path);
                    cachedKeys.put(keyId, decrypted);
                } catch (Exception e) {
                    log.warn("Corrupted or unreadable key file skipped: {}", fileName);
                }
            }
        }
    }

    @Override
    public synchronized void storePrivateKey(String keyId, byte[] privateKeyBytes) throws KeyStorageException {
        if (keyId == null || keyId.isBlank() || privateKeyBytes == null || privateKeyBytes.length == 0) {
            throw new KeyStorageException("Invalid keyId or privateKeyBytes");
        }

        try {
            byte[] iv = new byte[GCM_IV_LENGTH_BYTES];
            secureRandom.nextBytes(iv);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, masterKey, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));
            byte[] ciphertext = cipher.doFinal(privateKeyBytes);

            ByteBuffer buffer = ByteBuffer.allocate(iv.length + ciphertext.length);
            buffer.put(iv);
            buffer.put(ciphertext);

            Path targetFile = storageDirectory.resolve(keyId + ".key");
            Path tempFile = storageDirectory.resolve(keyId + ".key.tmp");

            Files.write(tempFile, buffer.array());
            Files.move(tempFile, targetFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);

            cachedKeys.put(keyId, privateKeyBytes.clone());
            log.info("Securely stored private key with ID: {}", keyId);
        } catch (Exception e) {
            throw new KeyStorageException("Failed to store private key [" + keyId + "]: " + e.getMessage(), e);
        }
    }

    @Override
    public byte[] getPrivateKey(String keyId) throws KeyStorageException {
        byte[] key = cachedKeys.get(keyId);
        if (key == null) {
            Path targetFile = storageDirectory.resolve(keyId + ".key");
            if (Files.exists(targetFile)) {
                try {
                    key = decryptFromFile(targetFile);
                    cachedKeys.put(keyId, key);
                } catch (Exception e) {
                    throw new KeyStorageException("Failed to decrypt private key [" + keyId + "]: " + e.getMessage(), e);
                }
            }
        }

        if (key == null) {
            throw new KeyStorageException("Key not found in store: " + keyId);
        }
        return key.clone();
    }

    private byte[] decryptFromFile(Path path) throws Exception {
        byte[] raw = Files.readAllBytes(path);
        if (raw.length < GCM_IV_LENGTH_BYTES + (GCM_TAG_LENGTH_BITS / 8)) {
            throw new IOException("Key file truncated: " + path.getFileName());
        }

        ByteBuffer buffer = ByteBuffer.wrap(raw);
        byte[] iv = new byte[GCM_IV_LENGTH_BYTES];
        buffer.get(iv);
        byte[] ciphertext = new byte[buffer.remaining()];
        buffer.get(ciphertext);

        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, masterKey, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));
        return cipher.doFinal(ciphertext);
    }

    @Override
    public boolean hasKey(String keyId) {
        return cachedKeys.containsKey(keyId) || Files.exists(storageDirectory.resolve(keyId + ".key"));
    }

    @Override
    public synchronized void deleteKey(String keyId) throws KeyStorageException {
        byte[] removed = cachedKeys.remove(keyId);
        if (removed != null) {
            Arrays.fill(removed, (byte) 0);
        }
        try {
            Files.deleteIfExists(storageDirectory.resolve(keyId + ".key"));
        } catch (IOException e) {
            throw new KeyStorageException("Failed to delete key file for [" + keyId + "]: " + e.getMessage(), e);
        }
    }

    @Override
    public String getStorageMechanismName() {
        return "AES-256-GCM Encrypted File Keystore";
    }

    @Override
    public void close() {
        for (byte[] k : cachedKeys.values()) {
            Arrays.fill(k, (byte) 0);
        }
        cachedKeys.clear();
    }
}
