package org.peerlink.linux.os.secrets;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.*;

/**
 * Linux Credential Store implementation.
 *
 * Provides secret storage backed by Freedesktop Secret Service (org.freedesktop.secrets / secret-tool)
 * or user-bound AES-256-GCM encryption with strict POSIX 0600 file permissions.
 */
public final class LinuxSecretStore {
    private static final Logger log = LoggerFactory.getLogger(LinuxSecretStore.class);

    private static final String APP_NAME = "peerlink";
    private static final String CREDENTIAL_SUBDIR = "credentials";
    private static final int GCM_TAG_LENGTH_BITS = 128;
    private static final int GCM_IV_LENGTH_BYTES = 12;

    private final Path storageDirectory;
    private final SecureRandom secureRandom = new SecureRandom();

    public LinuxSecretStore() {
        this(resolveDefaultStorePath());
    }

    public LinuxSecretStore(Path storageDirectory) {
        this.storageDirectory = Objects.requireNonNull(storageDirectory, "Storage directory must not be null");
        try {
            Files.createDirectories(this.storageDirectory);
            applyPosixPermissions(this.storageDirectory, PosixFilePermissions.fromString("rwx------"));
        } catch (IOException e) {
            log.warn("Failed to create credential directory: {}", e.getMessage());
        }
    }

    public static Path resolveDefaultStorePath() {
        String xdgConfig = System.getenv("XDG_CONFIG_HOME");
        if (xdgConfig != null && !xdgConfig.isBlank()) {
            return Path.of(xdgConfig, APP_NAME, CREDENTIAL_SUBDIR);
        }
        String userHome = System.getProperty("user.home", ".");
        return Path.of(userHome, ".config", APP_NAME, CREDENTIAL_SUBDIR);
    }

    public synchronized void storeCredential(String key, byte[] secret) throws IOException {
        Objects.requireNonNull(key, "Credential key cannot be null");
        Objects.requireNonNull(secret, "Secret cannot be null");

        // Try secret-tool CLI if available
        if (isLinux() && tryStoreSecretTool(key, secret)) {
            return;
        }

        // Fallback: AES-GCM encrypted file with 0600 permissions
        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        byte[] encrypted = protect(secret);
        Files.write(credPath, encrypted, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        applyPosixPermissions(credPath, PosixFilePermissions.fromString("rw-------"));
    }

    public synchronized Optional<byte[]> loadCredential(String key) throws IOException {
        Objects.requireNonNull(key, "Credential key cannot be null");

        // Try secret-tool CLI
        if (isLinux()) {
            Optional<byte[]> fromSecretTool = tryLoadSecretTool(key);
            if (fromSecretTool.isPresent()) {
                return fromSecretTool;
            }
        }

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

        if (isLinux()) {
            tryDeleteSecretTool(key);
        }

        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        return Files.deleteIfExists(credPath);
    }

    public synchronized boolean hasCredential(String key) {
        if (key == null) return false;
        Path credPath = storageDirectory.resolve(sanitizeFilename(key) + ".cred");
        return Files.exists(credPath);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // AES-256-GCM encryption with user + machine-id bound key
    // ──────────────────────────────────────────────────────────────────────────

    public static byte[] protect(byte[] plaintext) {
        if (plaintext == null || plaintext.length == 0) return new byte[0];
        try {
            SecretKey key = deriveLinuxKey();
            byte[] iv = new byte[GCM_IV_LENGTH_BYTES];
            new SecureRandom().nextBytes(iv);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));
            byte[] ciphertext = cipher.doFinal(plaintext);

            byte[] combined = new byte[iv.length + ciphertext.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(ciphertext, 0, combined, iv.length, ciphertext.length);
            return combined;
        } catch (Exception e) {
            throw new RuntimeException("Linux credential encryption failed: " + e.getMessage(), e);
        }
    }

    public static byte[] unprotect(byte[] ciphertext) {
        if (ciphertext == null || ciphertext.length == 0) return new byte[0];
        if (ciphertext.length < GCM_IV_LENGTH_BYTES) {
            throw new IllegalArgumentException("Invalid ciphertext length");
        }
        try {
            SecretKey key = deriveLinuxKey();
            byte[] iv = Arrays.copyOfRange(ciphertext, 0, GCM_IV_LENGTH_BYTES);
            byte[] encryptedData = Arrays.copyOfRange(ciphertext, GCM_IV_LENGTH_BYTES, ciphertext.length);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv));
            return cipher.doFinal(encryptedData);
        } catch (Exception e) {
            throw new RuntimeException("Linux credential decryption failed: " + e.getMessage(), e);
        }
    }

    private static SecretKey deriveLinuxKey() throws Exception {
        String user = System.getProperty("user.name", "unknown");
        String home = System.getProperty("user.home", ".");
        String machineId = getLinuxMachineId();

        String combinedSeed = "peerlink-linux-key-seed:" + user + ":" + home + ":" + machineId;
        MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
        byte[] keyBytes = sha256.digest(combinedSeed.getBytes(StandardCharsets.UTF_8));
        return new SecretKeySpec(keyBytes, "AES");
    }

    private static String getLinuxMachineId() {
        for (String path : List.of("/etc/machine-id", "/var/lib/dbus/machine-id")) {
            try {
                Path p = Path.of(path);
                if (Files.exists(p)) {
                    return Files.readString(p).trim();
                }
            } catch (Exception ignored) {}
        }
        return "fallback-machine-id";
    }

    private static boolean isLinux() {
        return System.getProperty("os.name", "").toLowerCase().contains("linux");
    }

    private static boolean tryStoreSecretTool(String key, byte[] secret) {
        try {
            ProcessBuilder pb = new ProcessBuilder(
                    "secret-tool", "store", "--label=PeerLink", "service", APP_NAME, "key", key);
            Process p = pb.start();
            try (OutputStream os = p.getOutputStream()) {
                os.write(secret);
                os.flush();
            }
            return p.waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    private static Optional<byte[]> tryLoadSecretTool(String key) {
        try {
            ProcessBuilder pb = new ProcessBuilder(
                    "secret-tool", "lookup", "service", APP_NAME, "key", key);
            Process p = pb.start();
            byte[] output = p.getInputStream().readAllBytes();
            if (p.waitFor() == 0 && output.length > 0) {
                return Optional.of(output);
            }
        } catch (Exception ignored) {}
        return Optional.empty();
    }

    private static void tryDeleteSecretTool(String key) {
        try {
            new ProcessBuilder("secret-tool", "clear", "service", APP_NAME, "key", key).start().waitFor();
        } catch (Exception ignored) {}
    }

    private static void applyPosixPermissions(Path path, Set<PosixFilePermission> permissions) {
        try {
            Files.setPosixFilePermissions(path, permissions);
        } catch (Exception ignored) {}
    }

    private static String sanitizeFilename(String input) {
        return input.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
