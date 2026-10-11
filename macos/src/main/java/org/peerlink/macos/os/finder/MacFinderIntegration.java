package org.peerlink.macos.os.finder;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Objects;

/**
 * macOS Finder and standard directory integration.
 * Resolves standard macOS paths (~/Library/Application Support, Caches, Preferences, Logs)
 * and controls Finder reveal and open actions via /usr/bin/open.
 */
public class MacFinderIntegration {

    private static final Logger log = LoggerFactory.getLogger(MacFinderIntegration.class);

    private final Path userHome;

    public MacFinderIntegration() {
        this(Paths.get(System.getProperty("user.home", ".")));
    }

    public MacFinderIntegration(Path userHome) {
        this.userHome = Objects.requireNonNull(userHome, "userHome must not be null");
    }

    /**
     * Resolves the macOS Application Support directory: ~/Library/Application Support/PeerLink
     */
    public Path getApplicationSupportDirectory() {
        return userHome.resolve("Library").resolve("Application Support").resolve("PeerLink");
    }

    /**
     * Resolves the macOS Caches directory: ~/Library/Caches/PeerLink
     */
    public Path getCachesDirectory() {
        return userHome.resolve("Library").resolve("Caches").resolve("PeerLink");
    }

    /**
     * Resolves the macOS Preferences directory: ~/Library/Preferences
     */
    public Path getPreferencesDirectory() {
        return userHome.resolve("Library").resolve("Preferences");
    }

    /**
     * Resolves the macOS Logs directory: ~/Library/Logs/PeerLink
     */
    public Path getLogsDirectory() {
        return userHome.resolve("Library").resolve("Logs").resolve("PeerLink");
    }

    /**
     * Reveals an item in Finder by highlighting it.
     */
    public boolean revealInFinder(Path path) {
        if (path == null) {
            return false;
        }

        try {
            ProcessBuilder pb = new ProcessBuilder("/usr/bin/open", "-R", path.toAbsolutePath().toString());
            Process p = pb.start();
            return p.waitFor() == 0;
        } catch (Exception e) {
            log.warn("Failed to reveal item in Finder: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Opens a file or URL with the default macOS application.
     */
    public boolean openWithDefaultApp(Path path) {
        if (path == null || !Files.exists(path)) {
            return false;
        }

        try {
            ProcessBuilder pb = new ProcessBuilder("/usr/bin/open", path.toAbsolutePath().toString());
            Process p = pb.start();
            return p.waitFor() == 0;
        } catch (Exception e) {
            log.warn("Failed to open item with default macOS application: {}", e.getMessage());
            return false;
        }
    }
}
