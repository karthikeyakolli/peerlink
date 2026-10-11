package org.peerlink.core.platform;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.platform.windows.WindowsPlatformAdapter;

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
        Files.writeString(sampleFile, "Sample content for Windows OS integration testing");
    }

    @Test
    void testPlatformTypeDetection() {
        PlatformType current = PlatformType.detectCurrent();
        assertNotNull(current);
        assertNotEquals(PlatformType.UNKNOWN, current, "Current host OS should be detected");
    }

    @Test
    void testWindowsPlatformIntegration() {
        WindowsPlatformAdapter winAdapter = new WindowsPlatformAdapter(true); // dryRunOnly = true
        assertEquals(PlatformType.WINDOWS, winAdapter.getPlatformType());

        // Capabilities
        assertTrue(winAdapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU));
        assertTrue(winAdapter.supportsFeature(PlatformFeature.FILE_REVEAL_AND_OPEN));
        assertTrue(winAdapter.supportsFeature(PlatformFeature.FILE_ASSOCIATIONS));
        assertTrue(winAdapter.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS));
        assertTrue(winAdapter.supportsFeature(PlatformFeature.DPAPI_CREDENTIALS));
        assertTrue(winAdapter.supportsFeature(PlatformFeature.FIREWALL_DIAGNOSTICS));
        assertFalse(winAdapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION));

        // File reveal & open
        assertTrue(winAdapter.revealInFileManager(sampleFile));
        assertTrue(winAdapter.openFileWithDefaultApp(sampleFile));

        // Notifications
        PlatformNotification notification = new PlatformNotification(
                "n-win-1",
                "Transfer Complete",
                "document.pdf received from Alice",
                PlatformNotification.Priority.NORMAL,
                PlatformNotification.Category.TRANSFER_COMPLETED,
                List.of("Open", "Dismiss"),
                sampleFile.toString()
        );
        assertTrue(winAdapter.postNotification(notification));
        assertTrue(winAdapter.cancelNotification(notification.getId()));

        // File associations and context menus
        assertTrue(winAdapter.registerFileManagerContextMenu());
        assertTrue(winAdapter.registerFileAssociations());
        assertTrue(winAdapter.unregisterFileManagerContextMenu());
        assertTrue(winAdapter.unregisterFileAssociations());

        // DPAPI Credential storage
        CredentialStorage creds = winAdapter.getCredentialStorage();
        assertNotNull(creds);
        creds.storeSecret("peerlink.tokens", "device-token-1", "secret-key-xyz");
        assertTrue(creds.hasSecret("peerlink.tokens", "device-token-1"));
        assertEquals(Optional.of("secret-key-xyz"), creds.getSecret("peerlink.tokens", "device-token-1"));
        assertTrue(creds.deleteSecret("peerlink.tokens", "device-token-1"));
        assertFalse(creds.hasSecret("peerlink.tokens", "device-token-1"));

        // Windows Defender Firewall diagnostics
        FirewallDiagnosticsResult fwResult = winAdapter.diagnoseFirewall(8080, "TCP");
        assertNotNull(fwResult);
        assertEquals(8080, fwResult.getPort());
        assertEquals("TCP", fwResult.getTransportProtocol());
        assertTrue(fwResult.isPeerLinkAllowed());
    }

    @Test
    void testPlatformIntegrationServiceFacade() {
        PlatformIntegrationService service = new PlatformIntegrationService();
        assertNotNull(service.getPlatformType());
        assertNotNull(service.getAdapter());
        assertNotNull(service.getCredentialStorage());
        assertEquals(PlatformType.WINDOWS, service.getPlatformType());

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
