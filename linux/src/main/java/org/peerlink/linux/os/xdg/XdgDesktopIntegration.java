package org.peerlink.linux.os.xdg;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;

/**
 * Linux XDG Desktop Integration.
 *
 * Implements XDG Base Directory Specification, Desktop Entry (.desktop) creation,
 * MIME type handlers, and Freedesktop File Manager D-Bus interaction.
 */
public final class XdgDesktopIntegration {
    private static final Logger log = LoggerFactory.getLogger(XdgDesktopIntegration.class);

    private static final String APP_ID = "org.peerlink.peerlink";
    private static final String APP_NAME = "PeerLink";

    private XdgDesktopIntegration() {}

    public static Path getXdgConfigHome() {
        String env = System.getenv("XDG_CONFIG_HOME");
        if (env != null && !env.isBlank()) {
            return Path.of(env);
        }
        return Path.of(System.getProperty("user.home", "."), ".config");
    }

    public static Path getXdgDataHome() {
        String env = System.getenv("XDG_DATA_HOME");
        if (env != null && !env.isBlank()) {
            return Path.of(env);
        }
        return Path.of(System.getProperty("user.home", "."), ".local", "share");
    }

    public static Path getXdgCacheHome() {
        String env = System.getenv("XDG_CACHE_HOME");
        if (env != null && !env.isBlank()) {
            return Path.of(env);
        }
        return Path.of(System.getProperty("user.home", "."), ".cache");
    }

    public static Path getXdgRuntimeDir() {
        String env = System.getenv("XDG_RUNTIME_DIR");
        if (env != null && !env.isBlank()) {
            return Path.of(env);
        }
        return Path.of(System.getProperty("java.io.tmpdir", "/tmp"));
    }

    /**
     * Generates standard Linux Desktop Entry content.
     */
    public static String generateDesktopEntry(Path executablePath, Path iconPath) {
        String exe = executablePath != null ? executablePath.toAbsolutePath().toString() : "peerlink";
        String icon = iconPath != null ? iconPath.toAbsolutePath().toString() : "peerlink";

        return String.join("\n",
                "[Desktop Entry]",
                "Name=" + APP_NAME,
                "Comment=Privacy-first distributed personal data platform",
                "Exec=\"" + exe + "\" %u",
                "Icon=" + icon,
                "Terminal=false",
                "Type=Application",
                "Categories=Network;FileTransfer;",
                "MimeType=x-scheme-handler/peerlink;application/x-peerlink;",
                "StartupNotify=true",
                "StartupWMClass=" + APP_ID,
                ""
        );
    }

    /**
     * Installs .desktop file to $XDG_DATA_HOME/applications/peerlink.desktop
     */
    public static void installDesktopEntry(Path executablePath, Path iconPath) throws IOException {
        Path appsDir = getXdgDataHome().resolve("applications");
        Files.createDirectories(appsDir);
        Path targetFile = appsDir.resolve("peerlink.desktop");
        String content = generateDesktopEntry(executablePath, iconPath);
        Files.writeString(targetFile, content);
        log.info("Installed Linux Desktop Entry to: {}", targetFile);

        // Update desktop database if tool available
        try {
            new ProcessBuilder("update-desktop-database", appsDir.toString()).start().waitFor();
        } catch (Exception ignored) {}
    }

    /**
     * Reveals the specified file in the default Linux file manager via D-Bus or xdg-open.
     */
    public static void revealInFileManager(Path path) throws IOException {
        Objects.requireNonNull(path, "Path cannot be null");
        Path absolute = path.toAbsolutePath().normalize();
        if (!Files.exists(absolute)) {
            throw new IOException("File does not exist: " + absolute);
        }

        Path dir = Files.isDirectory(absolute) ? absolute : absolute.getParent();
        if (dir == null) dir = absolute;

        try {
            // Attempt Freedesktop D-Bus FileManager1.ShowItems
            String dbusCmd = String.format(
                    "gdbus call --session --dest org.freedesktop.FileManager1 " +
                    "--object-path /org/freedesktop/FileManager1 " +
                    "--method org.freedesktop.FileManager1.ShowItems \"['file://%s']\" \"\"",
                    absolute.toString().replace("\"", "\\\""));

            Process p = new ProcessBuilder("sh", "-c", dbusCmd).start();
            if (p.waitFor() == 0) {
                return;
            }
        } catch (Exception ignored) {}

        // Fallback: xdg-open containing folder
        try {
            new ProcessBuilder("xdg-open", dir.toString()).start();
        } catch (Exception e) {
            log.warn("Failed to open file manager via xdg-open: {}", e.getMessage());
        }
    }
}
