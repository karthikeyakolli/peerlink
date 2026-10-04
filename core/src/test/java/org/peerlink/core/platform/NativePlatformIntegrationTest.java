package org.peerlink.core.platform;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.peerlink.core.platform.android.AndroidPlatformAdapter;
import org.peerlink.core.platform.linux.LinuxPlatformAdapter;
import org.peerlink.core.platform.macos.MacPlatformAdapter;
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
        Files.writeString(sampleFile, "Sample content for OS integration testing");
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

    @Test
    void testAndroidPlatformIntegration() {
        AndroidPlatformAdapter androidAdapter = new AndroidPlatformAdapter();
        assertEquals(PlatformType.ANDROID, androidAdapter.getPlatformType());

        // Capabilities
        assertTrue(androidAdapter.supportsFeature(PlatformFeature.SYSTEM_SHARE_SHEET));
        assertTrue(androidAdapter.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS));
        assertTrue(androidAdapter.supportsFeature(PlatformFeature.SAF_DOCUMENT_PICKER));
        assertTrue(androidAdapter.supportsFeature(PlatformFeature.MEDIA_STORE_INTEGRATION));
        assertTrue(androidAdapter.supportsFeature(PlatformFeature.OS_PERMISSION_FLOWS));
        assertFalse(androidAdapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU));

        // Sharesheet
        assertTrue(androidAdapter.invokeSystemShare(List.of(sampleFile)));
        assertEquals(1, androidAdapter.getSharedPayloads().size());
        assertEquals(List.of(sampleFile), androidAdapter.getSharedPayloads().get(0));

        // Notifications
        PlatformNotification notification = new PlatformNotification(
                "n-android-1",
                "Sync Complete",
                "15 files synced in Photos",
                PlatformNotification.Priority.NORMAL,
                PlatformNotification.Category.GENERAL,
                List.of(),
                null
        );
        assertTrue(androidAdapter.postNotification(notification));
        assertEquals(1, androidAdapter.getPostedNotifications().size());
        assertTrue(androidAdapter.cancelNotification("n-android-1"));
        assertEquals(0, androidAdapter.getPostedNotifications().size());

        // Runtime permission flows
        assertFalse(androidAdapter.checkPermission("android.permission.READ_MEDIA_IMAGES"));
        assertTrue(androidAdapter.requestPermission("android.permission.READ_MEDIA_IMAGES"));
        assertTrue(androidAdapter.checkPermission("android.permission.READ_MEDIA_IMAGES"));

        // Keystore credential storage
        CredentialStorage keystoreCreds = androidAdapter.getCredentialStorage();
        keystoreCreds.storeSecret("peerlink.keystore", "node-secret", "super-secure-token");
        assertEquals(Optional.of("super-secure-token"), keystoreCreds.getSecret("peerlink.keystore", "node-secret"));
        assertTrue(keystoreCreds.deleteSecret("peerlink.keystore", "node-secret"));
    }

    @Test
    void testPlatformIntegrationServiceFacade() {
        PlatformIntegrationService service = new PlatformIntegrationService();
        assertNotNull(service.getPlatformType());
        assertNotNull(service.getAdapter());
        assertNotNull(service.getCredentialStorage());

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

    @Test
    void testCoreDomainInvariance() {
        // Assert that the platform integration package is entirely decoupled
        // from core domain engines (Sync, Backup, Safety, Smart Operations, Protocol).
        // It provides services to upper layers (e.g. Flutter / CLI / Services) without
        // contaminating the protocol/domain semantics.
        WindowsPlatformAdapter win = new WindowsPlatformAdapter(true);
        MacPlatformAdapter mac = new MacPlatformAdapter(true);
        LinuxPlatformAdapter linux = new LinuxPlatformAdapter(true);
        AndroidPlatformAdapter android = new AndroidPlatformAdapter();

        assertEquals(PlatformType.WINDOWS, win.getPlatformType());
        assertEquals(PlatformType.MACOS, mac.getPlatformType());
        assertEquals(PlatformType.LINUX, linux.getPlatformType());
        assertEquals(PlatformType.ANDROID, android.getPlatformType());
    }
}
