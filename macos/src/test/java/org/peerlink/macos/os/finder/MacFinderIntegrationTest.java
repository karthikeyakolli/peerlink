package org.peerlink.macos.os.finder;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.macos.os.notifications.MacNotificationManager;

import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

public class MacFinderIntegrationTest {

    @TempDir
    Path tempHome;

    private MacFinderIntegration finder;
    private MacNotificationManager notificationManager;

    @BeforeEach
    void setUp() {
        finder = new MacFinderIntegration(tempHome);
        notificationManager = new MacNotificationManager(true); // dryRunOnly
    }

    @Test
    void testStandardDirectoryResolution() {
        Path appSupport = finder.getApplicationSupportDirectory();
        assertTrue(appSupport.endsWith("Library/Application Support/PeerLink") ||
                   appSupport.endsWith("Library\\Application Support\\PeerLink"));

        Path caches = finder.getCachesDirectory();
        assertTrue(caches.endsWith("Library/Caches/PeerLink") ||
                   caches.endsWith("Library\\Caches\\PeerLink"));

        Path prefs = finder.getPreferencesDirectory();
        assertTrue(prefs.endsWith("Library/Preferences") ||
                   prefs.endsWith("Library\\Preferences"));

        Path logs = finder.getLogsDirectory();
        assertTrue(logs.endsWith("Library/Logs/PeerLink") ||
                   logs.endsWith("Library\\Logs\\PeerLink"));
    }

    @Test
    void testNotificationManagerDryRun() {
        assertTrue(notificationManager.postNotification("PeerLink Transfer", "Received file photo.jpg", "Alice"));
        assertFalse(notificationManager.postNotification(null, "message", "sub"));
        assertFalse(notificationManager.postNotification("title", null, "sub"));
    }
}
