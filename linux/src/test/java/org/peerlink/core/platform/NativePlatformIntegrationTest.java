package org.peerlink.core.platform;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.platform.linux.LinuxPlatformAdapter;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class NativePlatformIntegrationTest {

    @TempDir
    Path tempDir;

    private Path sampleFile;

    @BeforeEach
    void setUp() throws IOException {
        sampleFile = tempDir.resolve("document.pdf");
        Files.writeString(sampleFile, "Sample content for OS integration testing");
    }

    @Test
    void testPlatformTypeDetection() {
        PlatformType current = PlatformType.detectCurrent();
        assertNotNull(current);
        assertNotEquals(PlatformType.UNKNOWN, current, "Current host OS should be detected");
    }

    @Test
    void testLinuxPlatformIntegration() {
        LinuxPlatformAdapter linuxAdapter = new LinuxPlatformAdapter(true);
        assertEquals(PlatformType.LINUX, linuxAdapter.getPlatformType());

        // Capabilities
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.FILE_MANAGER_ACTIONS));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.XDG_INTEGRATION));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.DBUS_INTEGRATION));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.FREEDESKTOP_SECRET_SERVICE));
        assertFalse(linuxAdapter.supportsFeature(PlatformFeature.DPAPI_CREDENTIALS));

        // Desktop environment detection
        String de = linuxAdapter.getDesktopEnvironment();
        assertNotNull(de);

        // Actions & XDG
        assertTrue(linuxAdapter.revealInFileManager(sampleFile));
        assertTrue(linuxAdapter.openFileWithDefaultApp(sampleFile));
        assertTrue(linuxAdapter.registerFileManagerContextMenu());
        assertTrue(linuxAdapter.registerFileAssociations());

        // Notifications
        PlatformNotification notification = new PlatformNotification(
                "n-linux-1",
                "Security Alert",
                "Untrusted peer attempted connection",
                PlatformNotification.Priority.CRITICAL,
                PlatformNotification.Category.SECURITY_ALERT,
                List.of("Block"),
                null
        );
        assertTrue(linuxAdapter.postNotification(notification));

        // Secret Service storage
        CredentialStorage secrets = linuxAdapter.getCredentialStorage();
        secrets.storeSecret("peerlink-secrets", "account1", "passphrase-token");
        assertEquals(Optional.of("passphrase-token"), secrets.getSecret("peerlink-secrets", "account1"));
        assertTrue(secrets.deleteSecret("peerlink-secrets", "account1"));
    }
}
