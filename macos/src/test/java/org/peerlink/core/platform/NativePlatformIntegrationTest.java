package org.peerlink.core.platform;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.platform.macos.MacPlatformAdapter;

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
        Files.writeString(sampleFile, "Sample content for macOS integration testing");
    }

    @Test
    void testPlatformTypeDetection() {
        PlatformType current = PlatformType.detectCurrent();
        assertNotNull(current);
        assertNotEquals(PlatformType.UNKNOWN, current, "Current host OS should be detected");
    }

    @Test
    void testMacPlatformIntegration() {
        MacPlatformAdapter macAdapter = new MacPlatformAdapter(true); // dryRunOnly = true
        assertEquals(PlatformType.MACOS, macAdapter.getPlatformType());

        // Capabilities
        assertTrue(macAdapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.FINDER_SHARE_EXTENSION));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.FILE_REVEAL_AND_OPEN));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.SYSTEM_SHARE_SHEET));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.OS_KEYCHAIN_CREDENTIALS));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.SANDBOX_PERMISSIONS));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.OPTIONAL_FILE_PROVIDER));

        // File reveal & open
        assertTrue(macAdapter.revealInFileManager(sampleFile));
        assertTrue(macAdapter.openFileWithDefaultApp(sampleFile));

        // Notifications
        PlatformNotification notification = new PlatformNotification(
                "n-mac-1",
                "Transfer Complete",
                "document.pdf received from Alice",
                PlatformNotification.Priority.NORMAL,
                PlatformNotification.Category.TRANSFER_COMPLETED,
                List.of("Open", "Dismiss"),
                sampleFile.toString()
        );
        assertTrue(macAdapter.postNotification(notification));
        assertTrue(macAdapter.cancelNotification(notification.getId()));

        // File associations and context menus
        assertTrue(macAdapter.registerFileManagerContextMenu());
        assertTrue(macAdapter.registerFileAssociations());
        assertTrue(macAdapter.unregisterFileManagerContextMenu());
        assertTrue(macAdapter.unregisterFileAssociations());

        // Keychain Credential storage
        CredentialStorage creds = macAdapter.getCredentialStorage();
        assertNotNull(creds);
        creds.storeSecret("peerlink.tokens", "device-token-1", "secret-key-xyz");
        assertTrue(creds.hasSecret("peerlink.tokens", "device-token-1"));
        assertEquals(Optional.of("secret-key-xyz"), creds.getSecret("peerlink.tokens", "device-token-1"));
        assertTrue(creds.deleteSecret("peerlink.tokens", "device-token-1"));
        assertFalse(creds.hasSecret("peerlink.tokens", "device-token-1"));

        // Firewall diagnostics
        FirewallDiagnosticsResult fwResult = macAdapter.diagnoseFirewall(8080, "TCP");
        assertNotNull(fwResult);
        assertEquals(8080, fwResult.getPort());
        assertEquals("TCP", fwResult.getTransportProtocol());
        assertTrue(fwResult.isPeerLinkAllowed());

        // Sandbox permission check and request
        assertTrue(macAdapter.checkPermission("com.apple.security.files.user-selected.read-write"));
        assertTrue(macAdapter.requestPermission("custom.permission.entry"));
        assertTrue(macAdapter.checkPermission("custom.permission.entry"));
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
