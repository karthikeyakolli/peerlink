package org.peerlink.desktop.runtime;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Objects;

/**
 * Desktop Local Node configuration.
 * Manages storage path and authenticated local IPC secret.
 */
public final class NodeConfiguration {
    public static final int DEFAULT_IPC_PORT = 50051;
    public static final int DEFAULT_P2P_PORT = 50052;
    public static final String DEFAULT_HOST = "127.0.0.1";

    private final Path dataDirectory;
    private final int ipcPort;
    private final String ipcAuthToken;
    private final int p2pPort;

    public NodeConfiguration(Path dataDirectory, int ipcPort, String ipcAuthToken) {
        this(dataDirectory, ipcPort, ipcAuthToken, DEFAULT_P2P_PORT);
    }

    public NodeConfiguration(Path dataDirectory, int ipcPort, String ipcAuthToken, int p2pPort) {
        this.dataDirectory = Objects.requireNonNull(dataDirectory);
        this.ipcPort = ipcPort;
        if (ipcAuthToken == null || ipcAuthToken.isBlank()) {
            throw new IllegalArgumentException("ipcAuthToken must not be blank");
        }
        this.ipcAuthToken = ipcAuthToken;
        this.p2pPort = p2pPort;
    }

    public int getP2pPort() {
        return p2pPort;
    }

    public static NodeConfiguration loadOrCreate(Path dataDir, int port) throws IOException {
        return loadOrCreate(dataDir, port, null);
    }

    public static NodeConfiguration loadOrCreate(Path dataDir, int port, String tokenOverride) throws IOException {
        Files.createDirectories(dataDir);
        Path tokenFile = dataDir.resolve("ipc_auth.token");
        String token;
        if (tokenOverride != null && !tokenOverride.isBlank()) {
            token = tokenOverride.trim();
            writeRestrictedToken(tokenFile, token);
        } else if (Files.exists(tokenFile)) {
            token = Files.readString(tokenFile).trim();
            if (token.isBlank()) {
                byte[] randomBytes = new byte[32];
                new SecureRandom().nextBytes(randomBytes);
                token = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
                writeRestrictedToken(tokenFile, token);
            }
        } else {
            byte[] randomBytes = new byte[32];
            new SecureRandom().nextBytes(randomBytes);
            token = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
            writeRestrictedToken(tokenFile, token);
        }
        return new NodeConfiguration(dataDir, port, token);
    }

    private static void writeRestrictedToken(Path tokenFile, String token) throws IOException {
        Files.writeString(tokenFile, token);
        try {
            java.nio.file.attribute.PosixFileAttributeView posix =
                    Files.getFileAttributeView(tokenFile, java.nio.file.attribute.PosixFileAttributeView.class);
            if (posix != null) {
                posix.setPermissions(java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"));
            }
        } catch (UnsupportedOperationException ignored) {
            // Windows / non-POSIX: dataDir is within user private profile
        }
    }

    public char[] getKeystorePassphrase() throws IOException {
        Path seedFile = dataDirectory.resolve(".keystore_seed");
        if (Files.exists(seedFile)) {
            return Files.readString(seedFile).trim().toCharArray();
        }
        byte[] seed = new byte[32];
        new SecureRandom().nextBytes(seed);
        String seedStr = Base64.getUrlEncoder().withoutPadding().encodeToString(seed);
        writeRestrictedToken(seedFile, seedStr);
        return seedStr.toCharArray();
    }

    public String getMaskedIpcToken() {
        if (ipcAuthToken == null || ipcAuthToken.length() < 8) {
            return "***";
        }
        return ipcAuthToken.substring(0, 4) + "..." + ipcAuthToken.substring(ipcAuthToken.length() - 4);
    }

    @Override
    public String toString() {
        return "NodeConfiguration{" +
                "dataDirectory=" + dataDirectory +
                ", ipcPort=" + ipcPort +
                ", ipcAuthToken=" + getMaskedIpcToken() +
                '}';
    }

    public Path getDataDirectory() { return dataDirectory; }
    public int getIpcPort() { return ipcPort; }
    public String getIpcAuthToken() { return ipcAuthToken; }
    public Path getDatabasePath() { return dataDirectory.resolve("peerlink_local.db"); }
}
