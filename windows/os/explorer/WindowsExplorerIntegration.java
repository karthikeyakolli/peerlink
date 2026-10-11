package org.peerlink.windows.os.explorer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;

/**
 * Windows Shell and Explorer integration.
 *
 * Provides capabilities to reveal received files in Windows File Explorer,
 * open containing directories, and manage Explorer context menu entries.
 */
public final class WindowsExplorerIntegration {
    private static final Logger log = LoggerFactory.getLogger(WindowsExplorerIntegration.class);

    private WindowsExplorerIntegration() {}

    /**
     * Highlights and selects the specified file or folder in Windows Explorer.
     */
    public static void revealInExplorer(Path path) throws IOException {
        Objects.requireNonNull(path, "Path cannot be null");
        Path absolute = path.toAbsolutePath().normalize();
        if (!Files.exists(absolute)) {
            throw new IOException("File does not exist: " + absolute);
        }

        try {
            new ProcessBuilder("explorer.exe", "/select,\"" + absolute + "\"").start();
        } catch (IOException e) {
            log.error("Failed to reveal file in Windows Explorer {}: {}", absolute, e.getMessage());
            throw e;
        }
    }

    /**
     * Opens the directory containing the specified path.
     */
    public static void openFolder(Path path) throws IOException {
        Objects.requireNonNull(path, "Path cannot be null");
        Path absolute = path.toAbsolutePath().normalize();
        Path dir = Files.isDirectory(absolute) ? absolute : absolute.getParent();
        if (dir == null || !Files.exists(dir)) {
            throw new IOException("Directory does not exist: " + dir);
        }

        try {
            new ProcessBuilder("explorer.exe", "\"" + dir + "\"").start();
        } catch (IOException e) {
            log.error("Failed to open directory in Windows Explorer {}: {}", dir, e.getMessage());
            throw e;
        }
    }

    /**
     * Registers "Share with PeerLink" context menu in Windows registry.
     */
    public static void registerContextMenu(Path peerlinkExecutablePath) throws IOException {
        Objects.requireNonNull(peerlinkExecutablePath, "Executable path cannot be null");
        Path exe = peerlinkExecutablePath.toAbsolutePath().normalize();

        String command = String.format(
                "reg add \"HKCU\\Software\\Classes\\*\\shell\\PeerLink\" /ve /d \"Share with PeerLink\" /f; " +
                "reg add \"HKCU\\Software\\Classes\\*\\shell\\PeerLink\\command\" /ve /d \"\\\"%s\\\" \\\"%%%%1\\\"\" /f",
                exe.toString().replace("\"", "\\\""));

        try {
            Process p = new ProcessBuilder("powershell.exe", "-NoProfile", "-Command", command).start();
            p.waitFor();
            log.info("Registered PeerLink Windows Explorer context menu");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Interrupted while registering Explorer context menu", e);
        }
    }
}
