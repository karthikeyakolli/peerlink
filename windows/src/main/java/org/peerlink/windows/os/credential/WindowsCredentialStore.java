package org.peerlink.windows.os.credential;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Objects;
import java.util.Optional;

/**
 * Windows Credential Store implementation.
 *
 * Provides DPAPI-backed data protection for sensitive device keys, tokens,
 * and pairing credentials bound to the current Windows user profile.
 *
 * <p>Security Invariant: Unencrypted private keys or IPC tokens are never written
 * to disk in plain text.
 */
public final class WindowsCredentialStore {
    private static final Logger log = LoggerFactory.getLogger(WindowsCredentialStore.class);

    private static final String CREDENTIAL_DIR_NAME = "PeerLink";
    private static final String SUBDIR_NAME = "credentials";
    private static final int GCM_TAG_LENGTH_BITS = 128;
    private static final int GCM_IV_LENGTH_BYTES = 12;

    private final Path storageDirectory;
    private final SecureRandom secureRandom = new SecureRandom();

    public WindowsCredentialStore() {
        this(resolveDefaultStorePath());
    }

    public WindowsCredentialStore(Path storageDirectory) {
        this.storageDirectory = Objects.requireNonNull(storageDirectory, "Storage directory must not be null");
        try {
            Files.createDirectories(this.storageDirectory);
        } catch (IOException e) {
            log.warn("Failed to create credential directory: {}", e.getMessage());
        }
    }

    public static Path resolveDefaultStorePath() {
        String localAppData = System.getenv("LOCALAPPDATA");
        if (localAppData != null && !localAppData.isBlank()) {
            return Path.of(localAppData, CREDENTIAL_DIR_NAME, SUBDIR_NAME);
        }
        String userHome = System.getProperty("user.home", ".");
        return Path.of(userHome, ".peerlink", SUBDIR_NAME);
    }

    /**
     * Protects bytes using Windows DPAPI or user-bound AES-256-GCM encryption.
     */
    public static byte[] protect(byte[] plaintext) {
        if (plaintext == null || plaintext.length == 0) {
            return new byte[0];
        }

        // Try native Windows DPAPI via PowerShell helper if on Windows OS
        if (isWindows()) {
            try {
                return protectWithWindowsDpapi(plaintext);
            } catch (Exception e) {
                log.debug("Native DPAPI protect invocation failed, using user-bound fallback: {}", e.getMessage());
            }
        }

        // Fallback user-bound AES-GCM
        return protectFallback(plaintext);
    }

    /**
     * Unprotects bytes previously encrypted with protect().
     */
    public static byte[] unprotect(byte[] ciphertext) {
        if (ciphertext == null || ciphertext.length == 0) {
            return new byte[0];
        }

        if (isWindows()) {
            try {
                return unprotectWithWindowsDpapi(ciphertext);
            } catch (Exception e) {
                log.debug("Native DPAPI unprotect invocation failed, using user-bound fallback: {}", e.getMessage());
            }
        }

        return unprotectFallback(ciphertext);
    }

    public synchronized void storeCredential(String key, byte[] secret) throws IOException {
        Objects.requireNonNull(key, "Credential key cannot be null");
        Objects.requireNonNull(secret, "Secret cannot be null");

        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        byte[] encrypted = protect(secret);
        Files.write(credPath, encrypted, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
    }

    public synchronized Optional<byte[]> loadCredential(String key) throws IOException {
        Objects.requireNonNull(key, "Credential key cannot be null");
        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        if (!Files.exists(credPath)) {
            return Optional.empty();
        }

        byte[] encrypted = Files.readAllBytes(credPath);
        byte[] decrypted = unprotect(encrypted);
        return Optional.of(decrypted);
    }

    public synchronized boolean deleteCredential(String key) throws IOException {
        Objects.requireNonNull(key, "Credential key cannot be null");
        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        return Files.deleteIfExists(credPath);
    }

    public synchronized boolean hasCredential(String key) {
        if (key == null) return false;
        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        return Files.exists(credPath);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Internal Windows DPAPI & Fallback implementation
    // ──────────────────────────────────────────────────────────────────────────

    private static boolean isWindows() {
        return System.getProperty("os.name", "").toLowerCase().contains("win");
    }

    private static byte[] protectWithWindowsDpapi(byte[] plaintext) throws Exception {
        String base64In = Base64.getEncoder().encodeToString(plaintext);
        String psCommand = String.format(
                "Add-Type -AssemblyName System.Security; " +
                "$b = [Convert]::FromBase64String('%s'); " +
                "$enc = [System.Security.Cryptography.ProtectedData]::Protect($b, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser); " +
                "[Convert]::ToBase64String($enc)",
                base64In);

        ProcessBuilder pb = new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", psCommand);
        Process p = pb.start();
        String output = new String(p.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        int exitCode = p.waitFor();
        if (exitCode != 0 || output.isEmpty()) {
            throw new IOException("PowerShell DPAPI protect returned exit code " + exitCode);
        }
        return Base64.getDecoder().decode(output);
    }

    private static byte[] unprotectWithWindowsDpapi(byte[] ciphertext) throws Exception {
        String base64In = Base64.getEncoder().encodeToString(ciphertext);
        String psCommand = String.format(
                "Add-Type -AssemblyName System.Security; " +
                "$b = [Convert]::FromBase64String('%s'); " +
                "$dec = [System.Security.Cryptography.ProtectedData]::Unprotect($b, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser); " +
                "[Convert]::ToBase64String($dec)",
                base64In);

        ProcessBuilder pb = new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", psCommand);
        Process p = pb.start();
        String output = new String(p.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        int exitCode = p.waitFor();
        if (exitCode != 0 || output.isEmpty()) {
            throw new IOException("PowerShell DPAPI unprotect returned exit code " + exitCode);
        }
        return Base64.getDecoder().decode(output);
    }

    private static byte[] protectFallback(byte[] plaintext) {
        try {
            byte[] iv = new byte[GCM_IV_LENGTH_BYTES];
            new SecureRandom().nextBytes(iv);

            SecretKey key = deriveLocalUserKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));
            byte[] cipherBytes = cipher.doFinal(plaintext);

            byte[] combined = new byte[iv.length + cipherBytes.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(cipherBytes, 0, combined, iv.length, cipherBytes.length);
            return combined;
        } catch (Exception e) {
            throw new RuntimeException("Credential protection failed", e);
        }
    }

    private static byte[] unprotectFallback(byte[] ciphertext) {
        try {
            if (ciphertext.length < GCM_IV_LENGTH_BYTES) {
                throw new IllegalArgumentException("Invalid encrypted payload size");
            }
            byte[] iv = new byte[GCM_IV_LENGTH_BYTES];
            System.arraycopy(ciphertext, 0, iv, 0, iv.length);

            byte[] encrypted = new byte[ciphertext.length - iv.length];
            System.arraycopy(ciphertext, iv.length, encrypted, 0, encrypted.length);

            SecretKey key = deriveLocalUserKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));
            return cipher.doFinal(encrypted);
        } catch (Exception e) {
            throw new RuntimeException("Credential decryption failed", e);
        }
    }

    private static SecretKey deriveLocalUserKey() {
        String seed = System.getProperty("user.name", "default") + ":" + System.getProperty("user.home", ".");
        byte[] keyBytes = new byte[32];
        byte[] seedBytes = seed.getBytes(StandardCharsets.UTF_8);
        for (int i = 0; i < 32; i++) {
            keyBytes[i] = (byte) (seedBytes[i % seedBytes.length] ^ (i * 31));
        }
        return new SecretKeySpec(keyBytes, "AES");
    }

    private static String sanitizeFilename(String key) {
        return key.replaceAll("[^a-zA-Z0-9_.-]", "_");
    }
}
