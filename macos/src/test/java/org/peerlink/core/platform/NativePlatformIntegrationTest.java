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
        Files.writeString(sampleFile, "Sample content for macOS OS integration testing");
    }

    @Test
    void testPlatformTypeDetection() {
        PlatformType current = PlatformType.detectCurrent();
        assertNotNull(current);
        assertNotEquals(PlatformType.UNKNOWN, current, "Current host OS should be detected");
    }

    @Test
    void testMacPlatformIntegration() {
        MacPlatformAdapter macAdapter = new MacPlatformAdapter(true);
        assertEquals(PlatformType.MACOS, macAdapter.getPlatformType());

        // Capabilities
        assertTrue(macAdapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.FINDER_SHARE_EXTENSION));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.OS_KEYCHAIN_CREDENTIALS));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.SANDBOX_PERMISSIONS));
        assertTrue(macAdapter.supportsFeature(PlatformFeature.OPTIONAL_FILE_PROVIDER));
        assertFalse(macAdapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU));

        // Finder reveal and open
        assertTrue(macAdapter.revealInFileManager(sampleFile));
        assertTrue(macAdapter.openFileWithDefaultApp(sampleFile));

        // Notifications
        PlatformNotification notification = new PlatformNotification(
                "n-mac-1",
                "New Shared Space",
                "You were added to 'Project Apollo'",
                PlatformNotification.Priority.HIGH,
                PlatformNotification.Category.GENERAL,
                List.of("View"),
                null
        );
        assertTrue(macAdapter.postNotification(notification));
        assertTrue(macAdapter.cancelNotification(notification.getId()));

        // Keychain storage
        CredentialStorage keychain = macAdapter.getCredentialStorage();
        keychain.storeSecret("peerlink.keychain", "master_key", "aes-256-gcm-secret");
        assertTrue(keychain.hasSecret("peerlink.keychain", "master_key"));
        assertEquals(Optional.of("aes-256-gcm-secret"), keychain.getSecret("peerlink.keychain", "master_key"));
        assertTrue(keychain.deleteSecret("peerlink.keychain", "master_key"));

        // Sandbox permissions
        String bookmarkPerm = "com.apple.security.files.user-selected.read-write";
        assertTrue(macAdapter.checkPermission(bookmarkPerm));
        assertFalse(macAdapter.checkPermission("custom.user.entitlement"));
        assertTrue(macAdapter.requestPermission("custom.user.entitlement"));
        assertTrue(macAdapter.checkPermission("custom.user.entitlement"));
    }

    @Test
    void testPlatformIntegrationServiceFacade() {
        PlatformIntegrationService service = new PlatformIntegrationService();
        assertNotNull(service.getPlatformType());
        assertNotNull(service.getAdapter());
        assertNotNull(service.getCredentialStorage());
        assertEquals(PlatformType.MACOS, service.getPlatformType());

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
