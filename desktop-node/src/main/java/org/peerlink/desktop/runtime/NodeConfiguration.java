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
    public static final String DEFAULT_HOST = "127.0.0.1";

    private final Path dataDirectory;
    private final int ipcPort;
    private final String ipcAuthToken;

    public NodeConfiguration(Path dataDirectory, int ipcPort, String ipcAuthToken) {
        this.dataDirectory = Objects.requireNonNull(dataDirectory);
        this.ipcPort = ipcPort;
        this.ipcAuthToken = Objects.requireNonNull(ipcAuthToken);
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
            Files.writeString(tokenFile, token);
        } else if (Files.exists(tokenFile)) {
            token = Files.readString(tokenFile).trim();
        } else {
            byte[] randomBytes = new byte[32];
            new SecureRandom().nextBytes(randomBytes);
            token = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
            Files.writeString(tokenFile, token);
        }
        return new NodeConfiguration(dataDir, port, token);
    }

    public Path getDataDirectory() { return dataDirectory; }
    public int getIpcPort() { return ipcPort; }
    public String getIpcAuthToken() { return ipcAuthToken; }
    public Path getDatabasePath() { return dataDirectory.resolve("peerlink_local.db"); }
}
