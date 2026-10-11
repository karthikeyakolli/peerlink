package org.peerlink.desktop.runtime;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.awt.Desktop;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Utility to reveal files or directories in the native Windows shell (Explorer) or default desktop file manager.
 */
public final class RevealInFolderUtil {
    private static final Logger log = LoggerFactory.getLogger(RevealInFolderUtil.class);

    private RevealInFolderUtil() {}

    /**
     * Reveals the specified file or directory in the native OS desktop shell.
     * On Windows, highlights the specific file using {@code explorer.exe /select,"path"}.
     *
     * @param targetPath Target file or directory to reveal
     * @return true if the process launched successfully, false otherwise
     */
    public static boolean revealInFolder(Path targetPath) {
        if (targetPath == null || !Files.exists(targetPath)) {
            log.warn("Cannot reveal nonexistent path: {}", targetPath);
            return false;
        }

        String os = System.getProperty("os.name", "").toLowerCase();
        Path absolute = targetPath.toAbsolutePath().normalize();

        if (os.contains("win")) {
            try {
                // Windows Explorer select syntax
                String command = String.format("explorer.exe /select,\"%s\"", absolute);
                new ProcessBuilder("explorer.exe", "/select," + absolute).start();
                log.info("Opened Windows Explorer highlighting: {}", absolute);
                return true;
            } catch (IOException e) {
                log.warn("Failed to launch explorer.exe with /select: {}", e.getMessage());
            }
        }

        // Generic Java Desktop API fallback
        if (Desktop.isDesktopSupported() && Desktop.getDesktop().isSupported(Desktop.Action.OPEN)) {
            try {
                File fileToOpen = Files.isDirectory(absolute) ? absolute.toFile() : absolute.getParent().toFile();
                Desktop.getDesktop().open(fileToOpen);
                log.info("Opened desktop folder via Desktop API: {}", fileToOpen);
                return true;
            } catch (Exception e) {
                log.error("Failed to open file via Desktop API: {}", e.getMessage(), e);
            }
        }

        return false;
    }
}
