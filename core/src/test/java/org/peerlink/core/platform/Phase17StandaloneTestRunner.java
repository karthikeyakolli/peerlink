package org.peerlink.core.platform;

import org.peerlink.core.android.AndroidBackgroundPolicy;
import org.peerlink.core.android.AndroidNodeContext;
import org.peerlink.core.android.AndroidStorageAbstraction.ContentResolverBridge;
import org.peerlink.core.collaboration.clipboard.*;
import org.peerlink.core.collaboration.workspace.*;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.PeerId;
import org.peerlink.core.platform.android.AndroidPlatformAdapter;
import org.peerlink.core.platform.android.AndroidShareIntentIngestor;
import org.peerlink.core.platform.linux.LinuxPlatformAdapter;
import org.peerlink.core.platform.macos.MacPlatformAdapter;
import org.peerlink.core.platform.windows.WindowsPlatformAdapter;
import org.peerlink.core.safety.*;
import org.peerlink.core.security.SecurityVerdict;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Phase 17 Standalone Verification Suite:
 * Workspaces, Platform Integrations (Windows, macOS, Linux, Android),
 * Clipboard Safety, Share Intents & Inbound Content URI Ingestion.
 *
 * Runs in pure Java SE on any host platform.
 */
public class Phase17StandaloneTestRunner {

    private static int testsPassed = 0;
    private static int testsFailed = 0;

    public static void main(String[] args) {
        System.out.println("==========================================================");
        System.out.println(" PeerLink Phase 17 Workspaces & Platform Integrations");
        System.out.println("==========================================================");

        runTest("Test 01: Windows Platform Adapter Feature Query & Detection", Phase17StandaloneTestRunner::testWindowsFeatureQuery);
        runTest("Test 02: Windows File Explorer Reveal & Context Menu Registration", Phase17StandaloneTestRunner::testWindowsExplorerAndContextMenu);
        runTest("Test 03: Windows Defender Firewall Query Execution", Phase17StandaloneTestRunner::testWindowsFirewallDiagnostics);
        runTest("Test 04: Windows DPAPI / In-Memory Credential Isolation", Phase17StandaloneTestRunner::testWindowsCredentialStorage);
        runTest("Test 05: macOS Platform Adapter Finder Reveal & Keychain Storage", Phase17StandaloneTestRunner::testMacPlatformAdapter);
        runTest("Test 06: macOS Sandbox Permissions & Entitlements", Phase17StandaloneTestRunner::testMacSandboxPermissions);
        runTest("Test 07: Linux Platform Adapter Desktop Environment & XDG Integration", Phase17StandaloneTestRunner::testLinuxPlatformAdapter);
        runTest("Test 08: Linux Secret Service & Notification Urgency", Phase17StandaloneTestRunner::testLinuxSecretServiceAndNotifications);
        runTest("Test 09: Android Platform Adapter Capability Set & Document Picker", Phase17StandaloneTestRunner::testAndroidPlatformAdapterCapabilities);
        runTest("Test 10: Android Runtime Permissions & Keystore Secret Storage", Phase17StandaloneTestRunner::testAndroidPermissionsAndKeystore);
        runTest("Test 11: Android Background Policy & Power Save / Doze Constraints", Phase17StandaloneTestRunner::testAndroidBackgroundPolicy);
        runTest("Test 12: Android Share Intent Ingestion: Clean Single File (ACTION_SEND)", Phase17StandaloneTestRunner::testAndroidShareIntentSingleClean);
        runTest("Test 13: Android Share Intent Ingestion: Multiple Files (ACTION_SEND_MULTIPLE)", Phase17StandaloneTestRunner::testAndroidShareIntentMultiple);
        runTest("Test 14: Android Share Intent Permission Denial Rejection", Phase17StandaloneTestRunner::testAndroidShareIntentPermissionDenial);
        runTest("Test 15: Android Share Intent Malicious Payload Quarantined & Deleted", Phase17StandaloneTestRunner::testAndroidShareIntentMalwareQuarantine);
        runTest("Test 16: Android Share Intent Path Traversal & Decompression Bomb Defense", Phase17StandaloneTestRunner::testAndroidShareIntentTraversalAndBomb);
        runTest("Test 17: Workspace Scope Boundary Containment", Phase17StandaloneTestRunner::testWorkspaceScopeContainment);
        runTest("Test 18: Workspace Authorization, Role Hierarchy, and Revocation", Phase17StandaloneTestRunner::testWorkspaceAuthorizationAndRoles);
        runTest("Test 19: Workspace Policy Epoch Invalidation", Phase17StandaloneTestRunner::testWorkspaceEpochInvalidation);
        runTest("Test 20: Clipboard Safety, Sensitivity Gating, 5MB Limit & Loop Prevention", Phase17StandaloneTestRunner::testClipboardSafetyAndLimits);

        System.out.println("==========================================================");
        System.out.printf(" Phase 17 Test Execution Summary: %d PASSED, %d FAILED%n", testsPassed, testsFailed);
        System.out.println("==========================================================");

        if (testsFailed > 0) {
            System.exit(1);
        }
    }

    private static void runTest(String name, TestRunnable test) {
        try {
            test.run();
            System.out.println("[PASS] " + name);
            testsPassed++;
        } catch (Throwable t) {
            System.out.println("[FAIL] " + name + ": " + t.getMessage());
            t.printStackTrace(System.out);
            testsFailed++;
        }
    }

    @FunctionalInterface
    private interface TestRunnable {
        void run() throws Exception;
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("Assertion failed: " + message);
        }
    }

    // ── 1. Windows Platform Adapter Feature Query ─────────────────────────────

    private static void testWindowsFeatureQuery() {
        WindowsPlatformAdapter adapter = new WindowsPlatformAdapter(true);
        check(adapter.getPlatformType() == PlatformType.WINDOWS, "Windows platform type detected");

        // Supported Windows features
        check(adapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU), "FILE_EXPLORER_CONTEXT_MENU supported");
        check(adapter.supportsFeature(PlatformFeature.FILE_REVEAL_AND_OPEN), "FILE_REVEAL_AND_OPEN supported");
        check(adapter.supportsFeature(PlatformFeature.FILE_ASSOCIATIONS), "FILE_ASSOCIATIONS supported");
        check(adapter.supportsFeature(PlatformFeature.SYSTEM_SHARE_SHEET), "SYSTEM_SHARE_SHEET supported");
        check(adapter.supportsFeature(PlatformFeature.SYSTEM_NOTIFICATIONS), "SYSTEM_NOTIFICATIONS supported");
        check(adapter.supportsFeature(PlatformFeature.DPAPI_CREDENTIALS), "DPAPI_CREDENTIALS supported");
        check(adapter.supportsFeature(PlatformFeature.FIREWALL_DIAGNOSTICS), "FIREWALL_DIAGNOSTICS supported");

        // Non-Windows features must be unsupported
        check(!adapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION), "Finder sync unsupported on Windows");
        check(!adapter.supportsFeature(PlatformFeature.SAF_DOCUMENT_PICKER), "Android SAF unsupported on Windows");
        check(!adapter.supportsFeature(PlatformFeature.FREEDESKTOP_SECRET_SERVICE), "Linux Secret Service unsupported on Windows");
        check(!adapter.supportsFeature(PlatformFeature.DBUS_INTEGRATION), "D-Bus unsupported on Windows");
    }

    // ── 2. Windows File Explorer Reveal & Context Menu ────────────────────────

    private static void testWindowsExplorerAndContextMenu() throws Exception {
        Path root = createTempDirectory("phase17_t02_");
        try {
            Path testFile = root.resolve("target.txt");
            Files.writeString(testFile, "Hello Windows Explorer");

            WindowsPlatformAdapter adapter = new WindowsPlatformAdapter(true);
            check(adapter.revealInFileManager(testFile), "Reveal in file manager succeeds");
            check(!adapter.revealInFileManager(null), "Reveal null path returns false");

            check(adapter.registerFileManagerContextMenu(), "Register context menu succeeds");
            check(adapter.unregisterFileManagerContextMenu(), "Unregister context menu succeeds");
            check(adapter.registerFileAssociations(), "Register file associations succeeds");
            check(adapter.unregisterFileAssociations(), "Unregister file associations succeeds");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 3. Windows Defender Firewall Query Execution ──────────────────────────

    private static void testWindowsFirewallDiagnostics() {
        // Run with actual netsh on Windows host (dryRunOnly = false)
        WindowsPlatformAdapter adapter = new WindowsPlatformAdapter(false);
        FirewallDiagnosticsResult result = adapter.diagnoseFirewall(4433, "TCP");

        check(result != null, "Firewall result must not be null");
        check(result.getPort() == 4433, "Port matches queried port");
        check("TCP".equalsIgnoreCase(result.getTransportProtocol()), "Protocol matches queried TCP");
        check(result.getStatus() != null, "Status is populated");

        // On Windows without prior PeerLink rule, status is RULE_MISSING or CONFIGURED if present
        if (result.getStatus() == FirewallDiagnosticsResult.Status.RULE_MISSING) {
            check(result.getSuggestedCommand() != null, "Remediation command suggested");
            check(result.getSuggestedCommand().contains("netsh advfirewall"), "Suggested command is netsh");
        }
    }

    // ── 4. Windows DPAPI / In-Memory Credential Isolation ─────────────────────

    private static void testWindowsCredentialStorage() {
        WindowsPlatformAdapter adapter = new WindowsPlatformAdapter(true);
        CredentialStorage cs = adapter.getCredentialStorage();

        cs.storeSecret("peerlink_tls", "node_alice", "secret_key_data_123");
        check(cs.hasSecret("peerlink_tls", "node_alice"), "Secret exists for alice");
        check(cs.getSecret("peerlink_tls", "node_alice").orElse("").equals("secret_key_data_123"), "Secret retrieved accurately");

        // Isolation
        check(!cs.hasSecret("peerlink_tls", "node_bob"), "No secret for bob");
        check(cs.getSecret("peerlink_tls", "node_bob").isEmpty(), "Bob secret empty");

        // Deletion
        check(cs.deleteSecret("peerlink_tls", "node_alice"), "Secret deleted");
        check(!cs.hasSecret("peerlink_tls", "node_alice"), "Secret no longer present");
    }

    // ── 5. macOS Platform Adapter ─────────────────────────────────────────────

    private static void testMacPlatformAdapter() {
        MacPlatformAdapter adapter = new MacPlatformAdapter(true);
        check(adapter.getPlatformType() == PlatformType.MACOS, "macOS platform type detected");

        // Supported
        check(adapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION), "FINDER_SYNC_INTEGRATION supported");
        check(adapter.supportsFeature(PlatformFeature.FINDER_SHARE_EXTENSION), "FINDER_SHARE_EXTENSION supported");
        check(adapter.supportsFeature(PlatformFeature.OS_KEYCHAIN_CREDENTIALS), "OS_KEYCHAIN_CREDENTIALS supported");
        check(adapter.supportsFeature(PlatformFeature.SANDBOX_PERMISSIONS), "SANDBOX_PERMISSIONS supported");

        // Unsupported
        check(!adapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU), "Windows context menu unsupported on Mac");
        check(!adapter.supportsFeature(PlatformFeature.SAF_DOCUMENT_PICKER), "Android SAF unsupported on Mac");
        check(!adapter.supportsFeature(PlatformFeature.DPAPI_CREDENTIALS), "DPAPI unsupported on Mac");

        // Notifications
        PlatformNotification notif = new PlatformNotification("n1", "Mac Title", "Mac Body", PlatformNotification.Priority.NORMAL);
        check(adapter.postNotification(notif), "macOS notification post succeeds");

        // Keychain
        CredentialStorage kc = adapter.getCredentialStorage();
        kc.storeSecret("keychain_svc", "account_1", "keychain_secret");
        check(kc.getSecret("keychain_svc", "account_1").orElse("").equals("keychain_secret"), "Keychain secret retrieved");
        check(kc.deleteSecret("keychain_svc", "account_1"), "Keychain secret deleted");
    }

    // ── 6. macOS Sandbox Permissions & Entitlements ───────────────────────────

    private static void testMacSandboxPermissions() {
        MacPlatformAdapter adapter = new MacPlatformAdapter(true);

        // Security-scoped bookmark / Apple sandbox entitlement
        check(adapter.checkPermission("com.apple.security.files.user-selected.read-write"), "Apple sandbox entitlement recognized");

        // Custom permission check before and after request
        check(!adapter.checkPermission("custom.sandbox.bookmark"), "Custom permission false initially");
        check(adapter.requestPermission("custom.sandbox.bookmark"), "Permission request succeeds");
        check(adapter.checkPermission("custom.sandbox.bookmark"), "Custom permission true after grant");
    }

    // ── 7. Linux Platform Adapter Desktop Environment & XDG ───────────────────

    private static void testLinuxPlatformAdapter() {
        LinuxPlatformAdapter adapter = new LinuxPlatformAdapter(true);
        check(adapter.getPlatformType() == PlatformType.LINUX, "Linux platform type detected");

        String de = adapter.getDesktopEnvironment();
        check(de != null && !de.isBlank(), "Desktop environment detected: " + de);

        // Supported
        check(adapter.supportsFeature(PlatformFeature.FILE_MANAGER_ACTIONS), "FILE_MANAGER_ACTIONS supported");
        check(adapter.supportsFeature(PlatformFeature.FREEDESKTOP_SECRET_SERVICE), "FREEDESKTOP_SECRET_SERVICE supported");
        check(adapter.supportsFeature(PlatformFeature.DBUS_INTEGRATION), "DBUS_INTEGRATION supported");
        check(adapter.supportsFeature(PlatformFeature.XDG_INTEGRATION), "XDG_INTEGRATION supported");

        // Unsupported
        check(!adapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU), "Windows context menu unsupported on Linux");
        check(!adapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION), "Finder sync unsupported on Linux");
        check(!adapter.supportsFeature(PlatformFeature.SAF_DOCUMENT_PICKER), "Android SAF unsupported on Linux");
    }

    // ── 8. Linux Secret Service & Notification Urgency ────────────────────────

    private static void testLinuxSecretServiceAndNotifications() {
        LinuxPlatformAdapter adapter = new LinuxPlatformAdapter(true);

        // Notification priorities
        PlatformNotification nLow = new PlatformNotification("l1", "Low Priority", "Body", PlatformNotification.Priority.LOW);
        PlatformNotification nNorm = new PlatformNotification("l2", "Normal Priority", "Body", PlatformNotification.Priority.NORMAL);
        PlatformNotification nCrit = new PlatformNotification("l3", "Critical Alert", "Body", PlatformNotification.Priority.CRITICAL);

        check(adapter.postNotification(nLow), "Low priority notification posted");
        check(adapter.postNotification(nNorm), "Normal priority notification posted");
        check(adapter.postNotification(nCrit), "Critical priority notification posted");

        // Secret storage
        CredentialStorage ss = adapter.getCredentialStorage();
        ss.storeSecret("freedesktop_svc", "account_lx", "linux_secret_val");
        check(ss.getSecret("freedesktop_svc", "account_lx").orElse("").equals("linux_secret_val"), "Secret Service secret retrieved");
        check(ss.deleteSecret("freedesktop_svc", "account_lx"), "Secret Service secret deleted");
    }

    // ── 9. Android Platform Adapter Capability Set ────────────────────────────

    private static void testAndroidPlatformAdapterCapabilities() {
        AndroidPlatformAdapter adapter = new AndroidPlatformAdapter();
        check(adapter.getPlatformType() == PlatformType.ANDROID, "Android platform type detected");

        // Supported Android features
        check(adapter.supportsFeature(PlatformFeature.SYSTEM_SHARE_SHEET), "SYSTEM_SHARE_SHEET supported on Android");
        check(adapter.supportsFeature(PlatformFeature.SAF_DOCUMENT_PICKER), "SAF_DOCUMENT_PICKER supported on Android");
        check(adapter.supportsFeature(PlatformFeature.MEDIA_STORE_INTEGRATION), "MEDIA_STORE_INTEGRATION supported on Android");
        check(adapter.supportsFeature(PlatformFeature.OS_PERMISSION_FLOWS), "OS_PERMISSION_FLOWS supported on Android");

        // Unsupported desktop features must return false
        check(!adapter.supportsFeature(PlatformFeature.FILE_EXPLORER_CONTEXT_MENU), "Windows context menu unsupported on Android");
        check(!adapter.supportsFeature(PlatformFeature.FINDER_SYNC_INTEGRATION), "macOS Finder sync unsupported on Android");
        check(!adapter.supportsFeature(PlatformFeature.FILE_MANAGER_ACTIONS), "Linux file manager actions unsupported on Android");
        check(!adapter.supportsFeature(PlatformFeature.DBUS_INTEGRATION), "D-Bus unsupported on Android");

        // Registering file manager context menu returns false
        check(!adapter.registerFileManagerContextMenu(), "Registering context menu returns false on Android");
    }

    // ── 10. Android Permissions & Keystore ─────────────────────────────────────

    private static void testAndroidPermissionsAndKeystore() {
        AndroidPlatformAdapter adapter = new AndroidPlatformAdapter();

        // Default ambient permissions
        check(adapter.checkPermission("android.permission.INTERNET"), "Internet permission present");
        check(adapter.checkPermission("android.permission.ACCESS_NETWORK_STATE"), "Network state permission present");

        // Runtime permission request flow
        check(!adapter.checkPermission("android.permission.READ_MEDIA_IMAGES"), "Media permission not yet granted");
        check(adapter.requestPermission("android.permission.READ_MEDIA_IMAGES"), "Media permission requested");
        check(adapter.checkPermission("android.permission.READ_MEDIA_IMAGES"), "Media permission now granted");

        // Android Keystore storage
        CredentialStorage ks = adapter.getCredentialStorage();
        ks.storeSecret("android_app", "node_key", "enc_private_seed");
        check(ks.getSecret("android_app", "node_key").orElse("").equals("enc_private_seed"), "Keystore secret retrieved");
        check(ks.deleteSecret("android_app", "node_key"), "Keystore secret deleted");
    }

    // ── 11. Android Background Policy Constraints ─────────────────────────────

    private static void testAndroidBackgroundPolicy() {
        // Doze mode blocks sync
        AndroidNodeContext dozeCtx = new AndroidNodeContext.Builder()
                .deviceIdleMode(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryCharging(true)
                .build();
        check(!AndroidBackgroundPolicy.canRunBackgroundSync(dozeCtx), "Background sync blocked in Doze mode");

        // Power Save mode blocks sync
        AndroidNodeContext powerSaveCtx = new AndroidNodeContext.Builder()
                .powerSaveMode(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryCharging(false)
                .build();
        check(!AndroidBackgroundPolicy.canRunBackgroundSync(powerSaveCtx), "Background sync blocked in Power Save mode");

        // Healthy Wi-Fi allows sync
        AndroidNodeContext healthyCtx = new AndroidNodeContext.Builder()
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryLevelPercent(80)
                .build();
        check(AndroidBackgroundPolicy.canRunBackgroundSync(healthyCtx), "Background sync allowed on healthy Wi-Fi");

        // Metered with Data Saver blocks sync
        AndroidNodeContext dataSaverCtx = new AndroidNodeContext.Builder()
                .networkType(AndroidNodeContext.NetworkType.CELLULAR_METERED)
                .dataSaverActive(true)
                .build();
        check(!AndroidBackgroundPolicy.canRunBackgroundSync(dataSaverCtx), "Background sync blocked on metered with Data Saver");

        // Foreground Service thresholds
        check(AndroidBackgroundPolicy.requiresForegroundService(6 * 1024 * 1024L, 10), "Large transfer mandates Foreground Service");
        check(!AndroidBackgroundPolicy.requiresForegroundService(1024L, 1), "Small transfer does not mandate Foreground Service");
    }

    // ── 12. Android Share Intent: Single Clean File (ACTION_SEND) ─────────────

    private static void testAndroidShareIntentSingleClean() throws Exception {
        Path root = createTempDirectory("phase17_t12_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(
                    new QuarantineZone(qDir),
                    new SimulatedScanner("SimScanner", true),
                    ScanPolicy.strict(),
                    new ScanCache()
            );

            byte[] pdfBytes = "%PDF-1.7 Clean document content".getBytes(StandardCharsets.UTF_8);
            MockContentResolver resolver = new MockContentResolver();
            resolver.register("content://media/external/files/101", "report.pdf", pdfBytes, true);

            AndroidShareIntentIngestor ingestor = new AndroidShareIntentIngestor(resolver, pipeline);

            AndroidShareIntentIngestor.ShareIngestResult res = ingestor.ingestIntent(
                    AndroidShareIntentIngestor.ACTION_SEND,
                    "application/pdf",
                    List.of("content://media/external/files/101"),
                    "peer_sender",
                    destDir
            );

            check(res.allSucceeded(), "Single share intent must succeed");
            check(res.succeededItems() == 1, "1 item succeeded");
            check(res.failedItems() == 0, "0 items failed");

            Path committed = res.itemResults().get(0).committedPath();
            check(committed != null && Files.exists(committed), "File committed to destination");
            check(Files.readString(committed).equals("%PDF-1.7 Clean document content"), "Payload content matches");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 13. Android Share Intent: Multiple Files (ACTION_SEND_MULTIPLE) ───────

    private static void testAndroidShareIntentMultiple() throws Exception {
        Path root = createTempDirectory("phase17_t13_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(
                    new QuarantineZone(qDir),
                    new SimulatedScanner("SimScanner", true),
                    ScanPolicy.strict(),
                    new ScanCache()
            );

            MockContentResolver resolver = new MockContentResolver();
            resolver.register("content://media/1", "doc1.txt", "Text file 1".getBytes(StandardCharsets.UTF_8), true);
            resolver.register("content://media/2", "doc2.txt", "Text file 2".getBytes(StandardCharsets.UTF_8), true);

            AndroidShareIntentIngestor ingestor = new AndroidShareIntentIngestor(resolver, pipeline);

            AndroidShareIntentIngestor.ShareIngestResult res = ingestor.ingestIntent(
                    AndroidShareIntentIngestor.ACTION_SEND_MULTIPLE,
                    "text/plain",
                    List.of("content://media/1", "content://media/2"),
                    "peer_sender",
                    destDir
            );

            check(res.allSucceeded(), "Multiple share intent must succeed");
            check(res.succeededItems() == 2, "2 items succeeded");
            check(res.failedItems() == 0, "0 items failed");
            check(Files.exists(destDir.resolve("doc1.txt")), "doc1.txt committed");
            check(Files.exists(destDir.resolve("doc2.txt")), "doc2.txt committed");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 14. Android Share Intent: Permission Denial ───────────────────────────

    private static void testAndroidShareIntentPermissionDenial() throws Exception {
        Path root = createTempDirectory("phase17_t14_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(
                    new QuarantineZone(qDir),
                    new SimulatedScanner("SimScanner", true),
                    ScanPolicy.strict(),
                    new ScanCache()
            );

            MockContentResolver resolver = new MockContentResolver();
            // Permission DENIED (canRead = false)
            resolver.register("content://restricted/doc.pdf", "doc.pdf", "Secret".getBytes(StandardCharsets.UTF_8), false);

            AndroidShareIntentIngestor ingestor = new AndroidShareIntentIngestor(resolver, pipeline);

            AndroidShareIntentIngestor.ShareIngestResult res = ingestor.ingestIntent(
                    AndroidShareIntentIngestor.ACTION_SEND,
                    "application/pdf",
                    List.of("content://restricted/doc.pdf"),
                    "peer_sender",
                    destDir
            );

            check(!res.allSucceeded(), "Denied permission must fail ingestion");
            check(res.failedItems() == 1, "1 item failed");
            check(res.itemResults().get(0).reason().contains("PERMISSION_DENIED"), "Reason indicates PERMISSION_DENIED");
            check(!Files.exists(destDir.resolve("doc.pdf")), "File must NOT be committed");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 15. Android Share Intent: Malware Quarantined & Deleted ───────────────

    private static void testAndroidShareIntentMalwareQuarantine() throws Exception {
        Path root = createTempDirectory("phase17_t15_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            // Scanner detects malware
            SimulatedScanner scanner = new SimulatedScanner("BadScanner", true);
            scanner.setDefaultVerdict(SecurityVerdict.MALICIOUS);

            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(
                    new QuarantineZone(qDir),
                    scanner,
                    ScanPolicy.strict(),
                    new ScanCache()
            );

            MockContentResolver resolver = new MockContentResolver();
            resolver.register("content://media/malware.bin", "trojan.bin", "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR".getBytes(StandardCharsets.UTF_8), true);

            AndroidShareIntentIngestor ingestor = new AndroidShareIntentIngestor(resolver, pipeline);

            AndroidShareIntentIngestor.ShareIngestResult res = ingestor.ingestIntent(
                    AndroidShareIntentIngestor.ACTION_SEND,
                    "application/octet-stream",
                    List.of("content://media/malware.bin"),
                    "peer_sender",
                    destDir
            );

            check(!res.allSucceeded(), "Malicious shared file must NOT succeed");
            check(res.failedItems() == 1, "1 item failed");
            check(!Files.exists(destDir.resolve("trojan.bin")), "Malware must NOT be committed to destination");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 16. Android Share Intent: Traversal & Decompression Bomb ──────────────

    private static void testAndroidShareIntentTraversalAndBomb() throws Exception {
        Path root = createTempDirectory("phase17_t16_");
        try {
            Path qDir = root.resolve("quarantine");
            Path destDir = root.resolve("received");
            InboundSafetyPipeline pipeline = new InboundSafetyPipeline(
                    new QuarantineZone(qDir),
                    new SimulatedScanner("SimScanner", true),
                    ScanPolicy.strict(),
                    new ScanCache()
            );

            MockContentResolver resolver = new MockContentResolver();
            // Traversal filename
            resolver.register("content://media/traversal", "../../escape.sh", "echo evil".getBytes(StandardCharsets.UTF_8), true);

            // Zip bomb
            byte[] bombZip = createZipBombPayload(150_000); // Exceeds 100:1 ratio
            resolver.register("content://media/bomb", "bomb.zip", bombZip, true);

            AndroidShareIntentIngestor ingestor = new AndroidShareIntentIngestor(resolver, pipeline);

            // 1. Test traversal rejection
            AndroidShareIntentIngestor.ShareIngestResult travRes = ingestor.ingestIntent(
                    AndroidShareIntentIngestor.ACTION_SEND, "text/plain", List.of("content://media/traversal"), "peer", destDir
            );
            check(!travRes.allSucceeded(), "Path traversal share must fail");
            check(travRes.itemResults().get(0).reason().contains("MALICIOUS_FILENAME"), "Rejected as MALICIOUS_FILENAME");

            // 2. Test zip bomb rejection
            AndroidShareIntentIngestor.ShareIngestResult bombRes = ingestor.ingestIntent(
                    AndroidShareIntentIngestor.ACTION_SEND, "application/zip", List.of("content://media/bomb"), "peer", destDir
            );
            check(!bombRes.allSucceeded(), "Zip bomb share must fail");
            check(bombRes.itemResults().get(0).reason().contains("Decompression bomb"), "Rejected as Decompression bomb");
            check(!Files.exists(destDir.resolve("bomb.zip")), "Zip bomb must NOT be committed");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 17. Workspace Scope Boundary Containment ──────────────────────────────

    private static void testWorkspaceScopeContainment() throws Exception {
        Path root = createTempDirectory("phase17_t17_");
        try {
            Path wsRoot = root.resolve("workspace_alpha");
            Files.createDirectories(wsRoot);

            PeerId owner = new PeerId("peer_owner_id");
            WorkspaceScope scope = new WorkspaceScope("ws_alpha", owner, wsRoot.toFile());

            // Normal resolution inside scope
            Path resolved = scope.resolvePathWithinScope("sub/document.txt");
            check(scope.isPathWithinScope(resolved), "Resolved path is within scope");
            check(resolved.startsWith(scope.getNormalizedRoot()), "Path begins with normalized root");

            // Path traversal escape rejection
            boolean escapeRejected = false;
            try {
                scope.resolvePathWithinScope("../../passwords.txt");
            } catch (SecurityException e) {
                escapeRejected = true;
            }
            check(escapeRejected, "Path traversal escape must throw SecurityException");

            // Null byte injection rejection
            boolean nullByteRejected = false;
            try {
                scope.resolvePathWithinScope("docs\0/secret.txt");
            } catch (SecurityException e) {
                nullByteRejected = true;
            }
            check(nullByteRejected, "Null byte in path must throw SecurityException");

            // External path check
            Path external = root.resolve("outside.txt");
            check(!scope.isPathWithinScope(external), "External path reported as outside scope");
        } finally {
            deleteRecursive(root);
        }
    }

    // ── 18. Workspace Authorization, Role Hierarchy, and Revocation ───────────

    private static void testWorkspaceAuthorizationAndRoles() {
        SharedWorkspace ws = new SharedWorkspace("ws_001", "Core Engineering", "peer_owner");
        check(ws.getPolicyEpoch() == 1, "Initial policy epoch is 1");

        // Invite admin and editor
        ws.inviteMember("peer_owner", "peer_admin", WorkspaceRole.ADMIN);
        ws.inviteMember("peer_admin", "peer_editor", WorkspaceRole.EDITOR);
        ws.inviteMember("peer_admin", "peer_viewer", WorkspaceRole.VIEWER);

        long currentEpoch = ws.getPolicyEpoch();

        // Check authorizations
        check(ws.authorizeAction("peer_editor", WorkspaceAction.WRITE_FILE, currentEpoch), "Editor can WRITE_FILE");
        check(ws.authorizeAction("peer_editor", WorkspaceAction.DELETE_FILE, currentEpoch), "Editor can DELETE_FILE");
        check(!ws.authorizeAction("peer_editor", WorkspaceAction.INVITE_MEMBER, currentEpoch), "Editor CANNOT INVITE_MEMBER");

        check(!ws.authorizeAction("peer_viewer", WorkspaceAction.WRITE_FILE, currentEpoch), "Viewer CANNOT WRITE_FILE");
        check(ws.authorizeAction("peer_viewer", WorkspaceAction.READ_PAYLOAD, currentEpoch), "Viewer can READ_PAYLOAD");
        check(ws.authorizeAction("peer_viewer", WorkspaceAction.VIEW_METADATA, currentEpoch), "Viewer can VIEW_METADATA");

        // Revoke editor
        ws.revokeMember("peer_owner", "peer_editor", "Policy violation");
        long epochAfterRevoke = ws.getPolicyEpoch();

        check(!ws.authorizeAction("peer_editor", WorkspaceAction.WRITE_FILE, epochAfterRevoke), "Revoked editor CANNOT WRITE_FILE");
        check(!ws.authorizeAction("peer_editor", WorkspaceAction.READ_PAYLOAD, epochAfterRevoke), "Revoked editor CANNOT READ_PAYLOAD");

        // Owner protection
        boolean ownerRemoveFailed = false;
        try {
            ws.removeMember("peer_admin", "peer_owner");
        } catch (IllegalStateException e) {
            ownerRemoveFailed = true;
        }
        check(ownerRemoveFailed, "Owner cannot be removed");
    }

    // ── 19. Workspace Policy Epoch Invalidation ───────────────────────────────

    private static void testWorkspaceEpochInvalidation() {
        SharedWorkspace ws = new SharedWorkspace("ws_epoch", "Finance", "peer_owner");
        ws.inviteMember("peer_owner", "peer_contributor", WorkspaceRole.CONTRIBUTOR);

        long validEpoch = ws.getPolicyEpoch(); // 2
        check(ws.authorizeAction("peer_contributor", WorkspaceAction.WRITE_FILE, validEpoch), "Action authorized at epoch 2");

        // Stale epoch (e.g. cached or in-flight before membership update)
        check(!ws.authorizeAction("peer_contributor", WorkspaceAction.WRITE_FILE, validEpoch - 1), "Stale epoch 1 rejected");

        // Role change advances epoch
        ws.changeRole("peer_owner", "peer_contributor", WorkspaceRole.VIEWER);
        long newEpoch = ws.getPolicyEpoch(); // 3
        check(newEpoch > validEpoch, "Epoch advanced after role change");

        // Old epoch 2 is now strictly invalidated
        check(!ws.authorizeAction("peer_contributor", WorkspaceAction.VIEW_METADATA, validEpoch), "Previously valid epoch 2 now rejected");
        // Authorized with new epoch 3
        check(ws.authorizeAction("peer_contributor", WorkspaceAction.VIEW_METADATA, newEpoch), "Authorized with current epoch 3");
    }

    // ── 20. Clipboard Safety, Sensitivity Gating, 5MB Limit & Loop Guard ──────

    private static void testClipboardSafetyAndLimits() throws Exception {
        ClipboardManager clip = new ClipboardManager("peer_node_1", ClipboardSyncMode.TEXT);

        // 1. Sensitivity inspection: Private keys
        boolean privKeyBlocked = false;
        try {
            clip.publishLocalText("-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0...\n-----END RSA PRIVATE KEY-----");
        } catch (SecurityException e) {
            privKeyBlocked = true;
            check(e.getMessage().contains("PRIVATE_KEY"), "Blocked category is PRIVATE_KEY");
        }
        check(privKeyBlocked, "Private key broadcast must be blocked");

        // 2. Sensitivity inspection: JWT tokens
        boolean jwtBlocked = false;
        try {
            clip.publishLocalText("Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotBroadcastThisToken");
        } catch (SecurityException e) {
            jwtBlocked = true;
            check(e.getMessage().contains("JWT_AUTH_TOKEN"), "Blocked category is JWT_AUTH_TOKEN");
        }
        check(jwtBlocked, "JWT auth token broadcast must be blocked");

        // 3. Size limit: Exceeds 5 MB
        boolean sizeLimitBlocked = false;
        try {
            byte[] bigPayload = new byte[5 * 1024 * 1024 + 1024];
            Arrays.fill(bigPayload, (byte) 'A');
            clip.publishLocalText(new String(bigPayload, StandardCharsets.UTF_8));
        } catch (IOException e) {
            sizeLimitBlocked = true;
            check(e.getMessage().contains("5 MB"), "Exception mentions 5 MB limit");
        }
        check(sizeLimitBlocked, "Oversized clipboard text (>5MB) must be blocked");

        // 4. Clean text publish
        Optional<ClipboardItem> published = clip.publishLocalText("Clean snippet for pairing");
        check(published.isPresent(), "Clean snippet published");
        ClipboardItem item = published.get();

        // 5. Loop prevention: Self-originating echo dropped
        boolean echoAccepted = clip.receiveRemoteItem(item);
        check(!echoAccepted, "Self-originating item must be dropped by loop guard");

        // 6. Mode OFF drops all items
        clip.setMode(ClipboardSyncMode.OFF);
        Optional<ClipboardItem> offPub = clip.publishLocalText("Text when OFF");
        check(offPub.isEmpty(), "Publish when OFF returns empty");
        boolean offRecv = clip.receiveRemoteItem(new ClipboardItem(
                "remote_id", ClipboardItemType.TEXT, "Remote".getBytes(StandardCharsets.UTF_8),
                ContentHash.computeSha256("Remote".getBytes(StandardCharsets.UTF_8)),
                "peer_node_2", 1, System.currentTimeMillis(), 300000
        ));
        check(!offRecv, "Receive when OFF returns false");
    }

    // ── Test Helpers ──────────────────────────────────────────────────────────

    private static Path createTempDirectory(String prefix) throws IOException {
        return Files.createTempDirectory(prefix);
    }

    private static void deleteRecursive(Path path) {
        if (path == null || !Files.exists(path)) return;
        try {
            Files.walk(path)
                    .sorted(Comparator.reverseOrder())
                    .forEach(p -> {
                        try {
                            Files.deleteIfExists(p);
                        } catch (IOException ignored) {}
                    });
        } catch (IOException ignored) {}
    }

    private static byte[] createZipBombPayload(int uncompressedSize) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            ZipEntry entry = new ZipEntry("repetitive.txt");
            zos.putNextEntry(entry);
            byte[] zeros = new byte[uncompressedSize];
            Arrays.fill(zeros, (byte) 0x30);
            zos.write(zeros);
            zos.closeEntry();
        }
        return baos.toByteArray();
    }

    private static class MockContentResolver implements ContentResolverBridge {
        private final Map<String, byte[]> dataMap = new HashMap<>();
        private final Map<String, String> nameMap = new HashMap<>();
        private final Map<String, Boolean> readPermMap = new HashMap<>();

        public void register(String uri, String displayName, byte[] data, boolean canRead) {
            dataMap.put(uri, data);
            nameMap.put(uri, displayName);
            readPermMap.put(uri, canRead);
        }

        @Override
        public InputStream openInputStream(String uri) throws IOException {
            byte[] d = dataMap.get(uri);
            if (d == null) throw new FileNotFoundException("Mock URI not found: " + uri);
            return new ByteArrayInputStream(d);
        }

        @Override
        public OutputStream openOutputStream(String uri) {
            return new ByteArrayOutputStream();
        }

        @Override
        public boolean delete(String uri) {
            dataMap.remove(uri);
            return true;
        }

        @Override
        public boolean exists(String uri) {
            return dataMap.containsKey(uri);
        }

        @Override
        public long getLength(String uri) {
            byte[] d = dataMap.get(uri);
            return d != null ? d.length : 0;
        }

        @Override
        public String getDisplayName(String uri) {
            return nameMap.get(uri);
        }

        @Override
        public long getLastModified(String uri) {
            return System.currentTimeMillis();
        }

        @Override
        public boolean isDirectory(String uri) {
            return false;
        }

        @Override
        public List<String> listChildren(String treeUri) {
            return Collections.emptyList();
        }

        @Override
        public boolean checkReadPermission(String uri) {
            return readPermMap.getOrDefault(uri, true);
        }

        @Override
        public boolean checkWritePermission(String uri) {
            return true;
        }
    }
}
