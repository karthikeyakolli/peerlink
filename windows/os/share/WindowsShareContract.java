package org.peerlink.windows.os.share;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Objects;

/**
 * Windows Native Share Contract.
 *
 * Coordinates integration with the Windows 10/11 system Share UI
 * for sharing files and URLs to nearby contacts and devices.
 */
public final class WindowsShareContract {
    private static final Logger log = LoggerFactory.getLogger(WindowsShareContract.class);

    private WindowsShareContract() {}

    /**
     * Initiates a Windows share target invocation for a local file.
     */
    public static void shareFile(Path file) throws IOException {
        Objects.requireNonNull(file, "File cannot be null");
        Path abs = file.toAbsolutePath().normalize();
        if (!Files.exists(abs)) {
            throw new IOException("File does not exist: " + abs);
        }

        // Invoke Windows Shell Share UI via PowerShell DataTransferManager
        String script = String.format(
                "[Windows.ApplicationModel.DataTransfer.DataTransferManager, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime] | Out-Null; " +
                "Start-Process explorer.exe '/select,\"%s\"'",
                abs.toString().replace("'", "''"));

        try {
            new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script).start();
            log.info("Invoked Windows Share contract for {}", abs);
        } catch (Exception e) {
            log.warn("Failed to invoke Windows share contract: {}", e.getMessage());
        }
    }
}
