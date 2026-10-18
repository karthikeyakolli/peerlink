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
        Files.writeString(sampleFile, "Sample content for Linux OS integration testing");
    }

    @Test
    void testPlatformTypeDetection() {
        PlatformType current = PlatformType.detectCurrent();
        assertNotNull(current);
        assertNotEquals(PlatformType.UNKNOWN, current, "Current host OS should be detected");
    }

    @Test
    void testLinuxPlatformIntegration() {
        LinuxPlatformAdapter linuxAdapter = new LinuxPlatformAdapter(true); // dryRunOnly = true
        assertEquals(PlatformType.LINUX, linuxAdapter.getPlatformType());

        // Capabilities
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.FILE_MANAGER_ACTIONS));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.FILE_REVEAL_AND_OPEN));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.FILE_ASSOCIATIONS));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.FREEDESKTOP_SECRET_SERVICE));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.DBUS_INTEGRATION));
        assertTrue(linuxAdapter.supportsFeature(PlatformFeature.XDG_INTEGRATION));

        // File reveal & open
        assertTrue(linuxAdapter.revealInFileManager(sampleFile));
        assertTrue(linuxAdapter.openFileWithDefaultApp(sampleFile));

        // Notifications
        PlatformNotification notification = new PlatformNotification(
                "n-linux-1",
                "Transfer Complete",
                "document.pdf received from Alice",
                PlatformNotification.Priority.NORMAL,
                PlatformNotification.Category.TRANSFER_COMPLETED,
                List.of("Open", "Dismiss"),
                sampleFile.toString()
        );
        assertTrue(linuxAdapter.postNotification(notification));
        assertTrue(linuxAdapter.cancelNotification(notification.getId()));

        // File associations and context menus
        assertTrue(linuxAdapter.registerFileManagerContextMenu());
        assertTrue(linuxAdapter.registerFileAssociations());
        assertTrue(linuxAdapter.unregisterFileManagerContextMenu());
        assertTrue(linuxAdapter.unregisterFileAssociations());

        // Secret Service Credential storage
        CredentialStorage creds = linuxAdapter.getCredentialStorage();
        assertNotNull(creds);
        creds.storeSecret("peerlink.tokens", "device-token-1", "secret-key-xyz");
        assertTrue(creds.hasSecret("peerlink.tokens", "device-token-1"));
        assertEquals(Optional.of("secret-key-xyz"), creds.getSecret("peerlink.tokens", "device-token-1"));
        assertTrue(creds.deleteSecret("peerlink.tokens", "device-token-1"));
        assertFalse(creds.hasSecret("peerlink.tokens", "device-token-1"));

        // Firewall diagnostics
        FirewallDiagnosticsResult fwResult = linuxAdapter.diagnoseFirewall(8080, "TCP");
        assertNotNull(fwResult);
        assertEquals(8080, fwResult.getPort());
        assertEquals("TCP", fwResult.getTransportProtocol());
        assertTrue(fwResult.isPeerLinkAllowed());
    }

    @Test
    void testPlatformIntegrationServiceFacade() {
        // Fallback adapter testing
        PlatformIntegrationService fallbackService = new PlatformIntegrationService(
                new PlatformIntegrationService.FallbackPlatformAdapter());
        assertEquals(PlatformType.UNKNOWN, fallbackService.getPlatformType());
        assertFalse(fallbackService.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS));
        assertFalse(fallbackService.sendNotification(new PlatformNotification(
                "id", "t", "b", null, null, null, null)));
        assertFalse(fallbackService.revealInFileManager(sampleFile));
        assertFalse(fallbackService.openFile(sampleFile));
        assertFalse(fallbackService.share(List.of(sampleFile)));

        FirewallDiagnosticsResult fw = fallbackService.checkFirewall(8080, "TCP");
        assertEquals(FirewallDiagnosticsResult.Status.NOT_APPLICABLE, fw.getStatus());

        // Fallback credential store works cleanly in memory
        CredentialStorage fallbackCreds = fallbackService.getCredentialStorage();
        fallbackCreds.storeSecret("svc", "acc", "val");
        assertEquals(Optional.of("val"), fallbackCreds.getSecret("svc", "acc"));
        assertTrue(fallbackCreds.deleteSecret("svc", "acc"));
    }
}
