package org.peerlink.macos.os.keychain;

import org.peerlink.core.platform.CredentialStorage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.SecureRandom;
import java.security.spec.KeySpec;
import java.util.*;

/**
 * macOS Keychain Services credential store.
 * Integrates directly with macOS Keychain Services via /usr/bin/security CLI,
 * with a hardened AES-256-GCM encrypted fallback when Keychain Services are unavailable.
 */
public class MacKeychainStore implements CredentialStorage {

    private static final Logger log = LoggerFactory.getLogger(MacKeychainStore.class);

    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128;
    private static final int PBKDF2_ITERATIONS = 65536;

    private static final Set<PosixFilePermission> SECURE_DIR_PERMS = EnumSet.of(
            PosixFilePermission.OWNER_READ,
            PosixFilePermission.OWNER_WRITE,
            PosixFilePermission.OWNER_EXECUTE
    );

    private static final Set<PosixFilePermission> SECURE_FILE_PERMS = EnumSet.of(
            PosixFilePermission.OWNER_READ,
            PosixFilePermission.OWNER_WRITE
    );

    private final Path fallbackDir;
    private final boolean forceFallback;

    public MacKeychainStore() {
        this(resolveDefaultStorageDir(), false);
    }

    public MacKeychainStore(Path fallbackDir, boolean forceFallback) {
        this.fallbackDir = Objects.requireNonNull(fallbackDir, "fallbackDir must not be null");
        this.forceFallback = forceFallback;
    }

    private static Path resolveDefaultStorageDir() {
        String userHome = System.getProperty("user.home", ".");
        return Paths.get(userHome, "Library", "Application Support", "PeerLink", "credentials");
    }

    public boolean isSecurityCliAvailable() {
        if (forceFallback) {
            return false;
        }
        try {
            Process p = new ProcessBuilder("/usr/bin/security", "default-keychain").start();
            int exitCode = p.waitFor();
            return exitCode == 0;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public void storeSecret(String service, String account, String secret) {
        Objects.requireNonNull(service, "service must not be null");
        Objects.requireNonNull(account, "account must not be null");
        Objects.requireNonNull(secret, "secret must not be null");

        if (isSecurityCliAvailable()) {
            try {
                ProcessBuilder pb = new ProcessBuilder(
                        "/usr/bin/security", "add-generic-password",
                        "-a", account,
                        "-s", service,
                        "-w", secret,
                        "-U"
                );
                Process p = pb.start();
                int exitCode = p.waitFor();
                if (exitCode == 0) {
                    return;
                }
                log.warn("macOS security CLI returned non-zero ({}), falling back to encrypted store", exitCode);
            } catch (Exception e) {
                log.warn("Failed to invoke macOS security CLI, falling back: {}", e.getMessage());
            }
        }

        storeEncryptedFallback(service, account, secret);
    }

    @Override
    public Optional<String> getSecret(String service, String account) {
        Objects.requireNonNull(service, "service must not be null");
        Objects.requireNonNull(account, "account must not be null");

        if (isSecurityCliAvailable()) {
            try {
                ProcessBuilder pb = new ProcessBuilder(
                        "/usr/bin/security", "find-generic-password",
                        "-a", account,
                        "-s", service,
                        "-w"
                );
                Process p = pb.start();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
                    String password = reader.readLine();
                    int exitCode = p.waitFor();
                    if (exitCode == 0 && password != null) {
                        return Optional.of(password.trim());
                    }
                }
            } catch (Exception e) {
                log.warn("Failed to query macOS security CLI: {}", e.getMessage());
            }
        }

        return getEncryptedFallback(service, account);
    }

    @Override
    public boolean deleteSecret(String service, String account) {
        Objects.requireNonNull(service, "service must not be null");
        Objects.requireNonNull(account, "account must not be null");

        boolean deleted = false;
        if (isSecurityCliAvailable()) {
            try {
                ProcessBuilder pb = new ProcessBuilder(
                        "/usr/bin/security", "delete-generic-password",
                        "-a", account,
                        "-s", service
                );
                Process p = pb.start();
                int exitCode = p.waitFor();
                deleted = (exitCode == 0);
            } catch (Exception e) {
                log.warn("Failed to delete via macOS security CLI: {}", e.getMessage());
            }
        }

        boolean fallbackDeleted = deleteEncryptedFallback(service, account);
        return deleted || fallbackDeleted;
    }

    @Override
    public boolean hasSecret(String service, String account) {
        return getSecret(service, account).isPresent();
    }

    private Path getFallbackFilePath(String service, String account) {
        String safeName = Base64.getUrlEncoder().withoutPadding()
                .encodeToString((service + ":" + account).getBytes(StandardCharsets.UTF_8)) + ".cred";
        return fallbackDir.resolve(safeName);
    }

    private void storeEncryptedFallback(String service, String account, String secret) {
        try {
            ensureSecureDirectory(fallbackDir);
            Path filePath = getFallbackFilePath(service, account);

            byte[] salt = new byte[16];
            byte[] iv = new byte[GCM_IV_LENGTH];
            SecureRandom random = new SecureRandom();
            random.nextBytes(salt);
            random.nextBytes(iv);

            byte[] keyBytes = deriveKey(salt);
            SecretKeySpec keySpec = new SecretKeySpec(keyBytes, "AES");
            GCMParameterSpec gcmSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec);
            byte[] ciphertext = cipher.doFinal(secret.getBytes(StandardCharsets.UTF_8));

            // Format: salt (16) || iv (12) || ciphertext
            byte[] payload = new byte[salt.length + iv.length + ciphertext.length];
            System.arraycopy(salt, 0, payload, 0, salt.length);
            System.arraycopy(iv, 0, payload, salt.length, iv.length);
            System.arraycopy(ciphertext, 0, payload, salt.length + iv.length, ciphertext.length);

            Files.write(filePath, payload, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE);
            applyPosixPermissions(filePath, SECURE_FILE_PERMS);
        } catch (Exception e) {
            throw new RuntimeException("Failed to store encrypted secret in macOS fallback", e);
        }
    }

    private Optional<String> getEncryptedFallback(String service, String account) {
        Path filePath = getFallbackFilePath(service, account);
        if (!Files.exists(filePath)) {
            return Optional.empty();
        }

        try {
            byte[] payload = Files.readAllBytes(filePath);
            if (payload.length < 16 + GCM_IV_LENGTH) {
                return Optional.empty();
            }

            byte[] salt = Arrays.copyOfRange(payload, 0, 16);
            byte[] iv = Arrays.copyOfRange(payload, 16, 16 + GCM_IV_LENGTH);
            byte[] ciphertext = Arrays.copyOfRange(payload, 16 + GCM_IV_LENGTH, payload.length);

            byte[] keyBytes = deriveKey(salt);
            SecretKeySpec keySpec = new SecretKeySpec(keyBytes, "AES");
            GCMParameterSpec gcmSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec);
            byte[] plaintext = cipher.doFinal(ciphertext);

            return Optional.of(new String(plaintext, StandardCharsets.UTF_8));
        } catch (Exception e) {
            log.error("Failed to decrypt secret from macOS fallback: {}", e.getMessage());
            return Optional.empty();
        }
    }

    private boolean deleteEncryptedFallback(String service, String account) {
        Path filePath = getFallbackFilePath(service, account);
        try {
            return Files.deleteIfExists(filePath);
        } catch (IOException e) {
            return false;
        }
    }

    private byte[] deriveKey(byte[] salt) throws Exception {
        String passphrase = resolveHardwareSeed();
        KeySpec spec = new PBEKeySpec(passphrase.toCharArray(), salt, PBKDF2_ITERATIONS, 256);
        SecretKeyFactory factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
        return factory.generateSecret(spec).getEncoded();
    }

    private String resolveHardwareSeed() {
        // Seeded with user identifier or fallback
        String user = System.getProperty("user.name", "peerlink-user");
        String home = System.getProperty("user.home", "/Users/peerlink");
        return "peerlink-macos-device-salt:" + user + ":" + home;
    }

    private void ensureSecureDirectory(Path dir) throws IOException {
        if (!Files.exists(dir)) {
            try {
                Files.createDirectories(dir, PosixFilePermissions.asFileAttribute(SECURE_DIR_PERMS));
            } catch (UnsupportedOperationException e) {
                Files.createDirectories(dir);
            }
        }
    }

    private void applyPosixPermissions(Path path, Set<PosixFilePermission> perms) {
        try {
            Files.setPosixFilePermissions(path, perms);
        } catch (Exception ignored) {
        }
    }

    public Path getFallbackDir() {
        return fallbackDir;
    }
}
