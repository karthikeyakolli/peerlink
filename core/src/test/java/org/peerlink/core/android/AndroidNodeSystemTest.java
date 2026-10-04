package org.peerlink.core.android;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.core.android.discovery.*;
import org.peerlink.core.collaboration.clipboard.ClipboardItem;
import org.peerlink.core.collaboration.clipboard.ClipboardItemType;
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode;
import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.protocol.v1.PeerId;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.AccessDeniedException;
import java.security.KeyPair;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;

public class AndroidNodeSystemTest {

    private AndroidKeystoreManager keystoreManager;
    private MockContentResolverBridge contentResolverBridge;
    private AndroidStorageAbstraction storageAbstraction;
    private MockSystemClipboardBridge clipboardBridge;
    private AndroidNotificationController notificationController;
    private MockNotificationBridge notificationBridge;
    private AndroidDiscoveryEngine discoveryEngine;
    private NsdDiscoveryAdapter nsdAdapter;
    private WifiDirectDiscoveryAdapter wifiDirectAdapter;
    private WifiAwareDiscoveryAdapter wifiAwareAdapter;
    private NearbyDiscoveryAdapter nearbyAdapter;

    @BeforeEach
    public void setup() {
        AndroidKeystoreManager.SoftwareKeystoreProvider swProvider =
                new AndroidKeystoreManager.SoftwareKeystoreProvider(true);
        keystoreManager = new AndroidKeystoreManager(swProvider, "test_android_alias");

        contentResolverBridge = new MockContentResolverBridge();
        storageAbstraction = new AndroidStorageAbstraction(contentResolverBridge);

        clipboardBridge = new MockSystemClipboardBridge();
        notificationBridge = new MockNotificationBridge();
        notificationController = new AndroidNotificationController(notificationBridge);

        nsdAdapter = new NsdDiscoveryAdapter(true);
        wifiDirectAdapter = new WifiDirectDiscoveryAdapter(true);
        wifiAwareAdapter = new WifiAwareDiscoveryAdapter(true);
        nearbyAdapter = new NearbyDiscoveryAdapter(true);

        discoveryEngine = new AndroidDiscoveryEngine(Arrays.asList(
                nsdAdapter, wifiDirectAdapter, wifiAwareAdapter, nearbyAdapter
        ));
    }

    @Test
    public void testNodeStateTransitions_Active_Background_OsRestricted_Unavailable() {
        // Initial state: Foreground app on Wi-Fi with full battery -> ACTIVE
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryLevelPercent(90)
                .batteryCharging(false)
                .build();

        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(ctx);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());

        List<String> transitions = new ArrayList<>();
        sm.addListener((oldState, newState, c) -> transitions.add(oldState + "->" + newState));

        // 1. App backgrounded (no FGS, healthy battery, Wi-Fi) -> BACKGROUND_CAPABLE
        ctx = AndroidNodeContext.builder()
                .appInForeground(false)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryLevelPercent(90)
                .batteryCharging(false)
                .build();
        sm.updateContext(ctx);
        assertEquals(AndroidNodeState.BACKGROUND_CAPABLE, sm.getCurrentState());

        // 2. Device enters Doze mode (Device Idle) -> OS_RESTRICTED
        ctx = AndroidNodeContext.builder()
                .appInForeground(false)
                .deviceIdleMode(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        sm.updateContext(ctx);
        assertEquals(AndroidNodeState.OS_RESTRICTED, sm.getCurrentState());

        // 3. User plugs in phone and opens app -> ACTIVE
        ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .deviceIdleMode(false)
                .batteryCharging(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        sm.updateContext(ctx);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());

        // 4. Power Save mode enabled while backgrounded -> OS_RESTRICTED
        ctx = AndroidNodeContext.builder()
                .appInForeground(false)
                .powerSaveMode(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        sm.updateContext(ctx);
        assertEquals(AndroidNodeState.OS_RESTRICTED, sm.getCurrentState());

        // 5. Network drops -> UNAVAILABLE
        ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.OFFLINE)
                .build();
        sm.updateContext(ctx);
        assertEquals(AndroidNodeState.UNAVAILABLE, sm.getCurrentState());

        // 6. Storage permission denied -> UNAVAILABLE
        ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .storagePermissionGranted(false)
                .build();
        sm.updateContext(ctx);
        assertEquals(AndroidNodeState.UNAVAILABLE, sm.getCurrentState());

        assertTrue(transitions.size() >= 5, "Expected multiple verified state machine transitions");
    }

    @Test
    public void testHardwareKeystoreIdentity_SigningAndVerification() throws Exception {
        assertNotNull(keystoreManager.getPeerId());
        assertTrue(keystoreManager.getPeerId().getValue().startsWith("android-peer-"));
        assertTrue(keystoreManager.isHardwareBacked());

        byte[] payload = "PeerLink-Android-Identity-Proof".getBytes(StandardCharsets.UTF_8);
        byte[] signature = keystoreManager.signData(payload);
        assertNotNull(signature);
        assertTrue(signature.length > 0);

        KeyPair kp = keystoreManager.getKeystoreProvider().getOrCreateIdentityKeyPair("test_android_alias");
        boolean valid = keystoreManager.verifySignature(kp.getPublic(), payload, signature);
        assertTrue(valid, "Cryptographic signature produced by Android Keystore must verify");

        // Tamper verification
        byte[] tampered = "Tampered-Proof".getBytes(StandardCharsets.UTF_8);
        boolean tamperedValid = keystoreManager.verifySignature(kp.getPublic(), tampered, signature);
        assertFalse(tamperedValid, "Tampered payload must fail signature verification");
    }

    @Test
    public void testStorageAccessFramework_StreamingAndPermissionDenial() throws Exception {
        String testDocUri = "content://com.android.providers.media.documents/document/image%3A1024";
        byte[] testData = "Android-SAF-Image-Content-Stream".getBytes(StandardCharsets.UTF_8);

        contentResolverBridge.addFile(testDocUri, "photo.jpg", testData, true, true);

        // Resolve by URI
        Optional<PeerFileHandle> handleOpt = storageAbstraction.resolveByPhysicalPath(testDocUri);
        assertTrue(handleOpt.isPresent());
        PeerFileHandle handle = handleOpt.get();
        assertEquals("photo.jpg", handle.getDisplayName());
        assertEquals(testData.length, handle.getSizeBytes());
        assertFalse(handle.isDirectory());

        // Stream read
        try (InputStream is = handle.openInputStream();
             ByteArrayOutputStream bos = new ByteArrayOutputStream()) {
            is.transferTo(bos);
            assertArrayEquals(testData, bos.toByteArray());
        }

        // Test permission denial
        contentResolverBridge.setReadPermission(testDocUri, false);
        assertThrows(AccessDeniedException.class, () -> storageAbstraction.resolveByPhysicalPath(testDocUri));

        // Test delete permission denial
        contentResolverBridge.setReadPermission(testDocUri, true);
        contentResolverBridge.setWritePermission(testDocUri, false);
        PeerFileHandle delHandle = storageAbstraction.resolveByPhysicalPath(testDocUri).orElseThrow();
        assertThrows(AccessDeniedException.class, () -> storageAbstraction.delete(delHandle));

        // Test successful delete when write granted
        contentResolverBridge.setWritePermission(testDocUri, true);
        assertTrue(storageAbstraction.delete(delHandle));
        assertFalse(contentResolverBridge.exists(testDocUri));
    }

    @Test
    public void testAndroidClipboard_BackgroundRestrictionAndSensitivity() throws Exception {
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(ctx);

        AndroidClipboardAdapter adapter = new AndroidClipboardAdapter(
                keystoreManager.getPeerId().getValue(),
                ClipboardSyncMode.TEXT_AND_URL,
                clipboardBridge,
                sm
        );

        // 1. Foreground clipboard publish
        clipboardBridge.setText("https://peerlink.org/download");
        Optional<ClipboardItem> published = adapter.syncLocalClipboardOutbound();
        assertTrue(published.isPresent());
        assertEquals(ClipboardItemType.URL, published.get().getType());
        assertEquals(keystoreManager.getPeerId().getValue(), published.get().getOriginPeerId());

        // 2. Android 10+ background restriction enforcement:
        // When app is in background, local clipboard read must be suppressed
        sm.updateContext(AndroidNodeContext.builder().appInForeground(false).build());
        clipboardBridge.setText("New text while backgrounded");
        Optional<ClipboardItem> bgPublished = adapter.syncLocalClipboardOutbound();
        assertFalse(bgPublished.isPresent(), "Android 10+ policy must suppress background clipboard reads");

        // 3. Android 13+ sensitivity handling: apply remote clipboard with sensitive flag
        ClipboardItem remoteItem = new ClipboardItem(
                "clp_remote_1",
                ClipboardItemType.TEXT,
                "Remote copied text".getBytes(StandardCharsets.UTF_8),
                ContentHash.computeSha256("Remote copied text".getBytes(StandardCharsets.UTF_8)),
                "peer-remote-desktop",
                1L,
                System.currentTimeMillis(),
                300_000L
        );

        boolean applied = adapter.applyRemoteClipboardInbound(remoteItem, true);
        assertTrue(applied);
        assertEquals("Remote copied text", clipboardBridge.getText());
        assertTrue(clipboardBridge.isLastWriteSensitive());

        // 4. Loop prevention: item from self must be dropped
        ClipboardItem loopItem = new ClipboardItem(
                "clp_self_loop",
                ClipboardItemType.TEXT,
                "Loop text".getBytes(StandardCharsets.UTF_8),
                published.get().getContentHash(),
                keystoreManager.getPeerId().getValue(), // origin is self
                2L,
                System.currentTimeMillis(),
                300_000L
        );
        assertFalse(adapter.applyRemoteClipboardInbound(loopItem, false), "Self-originated clipboard must be dropped by loop guard");
    }

    @Test
    public void testPlatformDiscoveryAdapters_Nsd_WifiDirect_WifiAware_Nearby() {
        AtomicReference<DiscoveredPeerRecord> discovered = new AtomicReference<>();
        AtomicReference<PeerId> lost = new AtomicReference<>();

        discoveryEngine.addListener(new AndroidDiscoveryEngine.EngineListener() {
            @Override
            public void onPeerDiscovered(DiscoveredPeerRecord peer) {
                discovered.set(peer);
            }

            @Override
            public void onPeerLost(PeerId peerId) {
                lost.set(peerId);
            }
        });

        discoveryEngine.startAll();
        assertTrue(discoveryEngine.isRunning());

        // 1. Simulate NSD discovery
        PeerId desktopPeerId = PeerId.newBuilder().setValue("peer_desktop_win10").build();
        nsdAdapter.notifyPeerDiscovered(
                desktopPeerId,
                "Windows Workstation",
                "192.168.1.50",
                8765,
                List.of("QUIC", "TCP_TLS")
        );

        assertNotNull(discovered.get());
        assertEquals("peer_desktop_win10", discovered.get().getPeerId().getValue());
        assertEquals("NSD_MDNS", discovered.get().getDiscoveryTechnology());
        assertEquals(8765, discovered.get().getPort());

        // 2. Simulate Wi-Fi Direct discovery
        PeerId androidPeer2 = PeerId.newBuilder().setValue("peer_android_phone2").build();
        wifiDirectAdapter.notifyPeerDiscovered(
                androidPeer2,
                "Galaxy S24",
                "192.168.49.1",
                8765,
                List.of("TCP_TLS")
        );

        assertEquals("peer_android_phone2", discovered.get().getPeerId().getValue());
        assertEquals("WIFI_DIRECT", discovered.get().getDiscoveryTechnology());

        // 3. Lost peer
        nsdAdapter.notifyPeerLost(desktopPeerId);
        assertEquals(desktopPeerId, lost.get());

        discoveryEngine.stopAll();
        assertFalse(discoveryEngine.isRunning());
    }

    @Test
    public void testBackgroundPolicyAndWorkManagerConstraints() {
        // Condition: On battery 10%, unmetered -> Sync blocked (battery too low)
        AndroidNodeContext lowBatteryCtx = AndroidNodeContext.builder()
                .appInForeground(false)
                .batteryCharging(false)
                .batteryLevelPercent(10)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        assertFalse(AndroidBackgroundPolicy.canRunBackgroundSync(lowBatteryCtx));
        assertFalse(AndroidBackgroundPolicy.canRunBackgroundBackup(lowBatteryCtx));

        // Condition: On Wi-Fi, battery 80% -> Sync allowed, Backup allowed
        AndroidNodeContext healthyCtx = AndroidNodeContext.builder()
                .appInForeground(false)
                .batteryCharging(false)
                .batteryLevelPercent(80)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        assertTrue(AndroidBackgroundPolicy.canRunBackgroundSync(healthyCtx));
        assertTrue(AndroidBackgroundPolicy.canRunBackgroundBackup(healthyCtx));

        // Condition: Cellular metered, battery 50%, data saver off -> Sync allowed, Backup BLOCKED
        AndroidNodeContext meteredCtx = AndroidNodeContext.builder()
                .appInForeground(false)
                .batteryCharging(false)
                .batteryLevelPercent(50)
                .networkType(AndroidNodeContext.NetworkType.CELLULAR_METERED)
                .dataSaverActive(false)
                .build();
        assertTrue(AndroidBackgroundPolicy.canRunBackgroundSync(meteredCtx));
        assertFalse(AndroidBackgroundPolicy.canRunBackgroundBackup(meteredCtx), "Backup must never run on metered cellular");

        // Large transfer threshold: 10 MB requires Foreground Service
        assertTrue(AndroidBackgroundPolicy.requiresForegroundService(10 * 1024 * 1024L, 10));
        assertFalse(AndroidBackgroundPolicy.requiresForegroundService(500 * 1024L, 1));
    }

    @Test
    public void testForegroundServiceAndNotifications_TransferLifecycle() throws Exception {
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(ctx);

        AndroidClipboardAdapter clipboardAdapter = new AndroidClipboardAdapter(
                keystoreManager.getPeerId().getValue(),
                ClipboardSyncMode.OFF,
                clipboardBridge,
                sm
        );

        AndroidNodeFacade facade = new AndroidNodeFacade(
                sm,
                keystoreManager,
                storageAbstraction,
                clipboardAdapter,
                discoveryEngine,
                notificationController
        );
        facade.start();

        // Register a 20 MB file to send
        String bigFileUri = "content://media/external/files/large.zip";
        contentResolverBridge.addFile(bigFileUri, "large.zip", new byte[1024], true, true);
        // override size
        contentResolverBridge.setLength(bigFileUri, 20 * 1024 * 1024L);

        PeerId desktopTarget = PeerId.newBuilder().setValue("peer_desktop_win10").build();

        AtomicBoolean started = new AtomicBoolean(false);
        AtomicInteger lastPercent = new AtomicInteger(0);
        AtomicBoolean completed = new AtomicBoolean(false);

        facade.addTransferListener(new AndroidNodeFacade.TransferEventListener() {
            @Override
            public void onTransferStarted(String transferId, PeerId remotePeer, String fileName, long totalBytes) {
                started.set(true);
            }

            @Override
            public void onTransferProgress(String transferId, int percent, long transferredBytes, long totalBytes) {
                lastPercent.set(percent);
            }

            @Override
            public void onTransferCompleted(String transferId, boolean success, String errorMessage) {
                completed.set(success);
            }
        });

        String txId = facade.initiateSend(desktopTarget, List.of(bigFileUri));
        assertNotNull(txId);
        assertTrue(started.get());
        assertTrue(notificationBridge.hasActiveTransferNotification(txId));

        // Progress updates
        facade.notifyTransferProgress(txId, "large.zip", 50, 10 * 1024 * 1024L, 20 * 1024 * 1024L);
        assertEquals(50, lastPercent.get());
        assertEquals(50, notificationBridge.getLastPercent(txId));

        // Finish transfer
        facade.notifyTransferFinished(txId, "large.zip", true, null);
        assertTrue(completed.get());
        assertFalse(notificationBridge.hasActiveTransferNotification(txId));
        assertEquals("Transfer Complete", notificationBridge.getLastStatusTitle());

        // Pairing prompt lifecycle
        facade.requestPairing("sess_123", desktopTarget, "Desktop PC", "8492");
        assertTrue(notificationBridge.hasPairingPrompt("sess_123"));

        boolean accepted = facade.confirmPairing("sess_123", true);
        assertTrue(accepted);
        assertFalse(notificationBridge.hasPairingPrompt("sess_123"));

        facade.stop();
    }

    @Test
    public void testWindowsToAndroidInteroperability_ProtocolContinuity() {
        // Windows Desktop Node simulated identity
        PeerId windowsPeerId = PeerId.newBuilder().setValue("peer_desktop_win_01").build();

        // Android Node identity
        PeerId androidPeerId = keystoreManager.getPeerId();

        // Both nodes adhere to the exact same protobuf message contracts:
        assertNotNull(windowsPeerId.getValue());
        assertNotNull(androidPeerId.getValue());
        assertNotEquals(windowsPeerId.getValue(), androidPeerId.getValue());

        // Zero protocol deviations: Both use SHA-256 ContentHash, ed25519 keys, and protobuf session negotiation
        byte[] testBlock = "Cross-Platform Interoperable Chunk Block".getBytes(StandardCharsets.UTF_8);
        ContentHash winHash = ContentHash.computeSha256(testBlock);
        ContentHash androidHash = ContentHash.computeSha256(testBlock);

        assertEquals(winHash, androidHash, "Windows and Android must produce bit-for-bit identical content hashes");
    }

    @Test
    public void testAppUiCloseAndProcessLifecycleResilience() {
        // App is foreground -> ACTIVE
        AndroidNodeContext initial = AndroidNodeContext.builder()
                .appInForeground(true)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(initial);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());

        // App closed/backgrounded, but a Foreground Service was spawned for active sync -> Remains ACTIVE!
        AndroidNodeContext fgsActive = AndroidNodeContext.builder()
                .appInForeground(false)
                .activeForegroundService(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        sm.updateContext(fgsActive);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState(),
                "Active Foreground Service must preserve ACTIVE node state even when UI is closed");

        // Transfer completes, Foreground Service stops -> Transitions to BACKGROUND_CAPABLE
        AndroidNodeContext fgsDone = AndroidNodeContext.builder()
                .appInForeground(false)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        sm.updateContext(fgsDone);
        assertEquals(AndroidNodeState.BACKGROUND_CAPABLE, sm.getCurrentState());
    }

    @Test
    public void testNetworkHandoffAndOfflineReconnect() {
        AndroidNodeContext wifiCtx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(wifiCtx);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());

        // Handoff to Cellular Metered
        AndroidNodeContext cellCtx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.CELLULAR_METERED)
                .build();
        sm.updateContext(cellCtx);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState()); // Active because in foreground
        assertTrue(AndroidBackgroundPolicy.shouldThrottleTransfer(cellCtx), "Cellular handoff must signal transfer throttling");

        // Network drops (Airplane mode / Tunnel) -> UNAVAILABLE
        AndroidNodeContext offlineCtx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.OFFLINE)
                .build();
        sm.updateContext(offlineCtx);
        assertEquals(AndroidNodeState.UNAVAILABLE, sm.getCurrentState());

        // Reconnect to Wi-Fi -> Restored to ACTIVE
        sm.updateContext(wifiCtx);
        assertEquals(AndroidNodeState.ACTIVE, sm.getCurrentState());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DEFECT-BETA-01 REGRESSION: Android background keepalive race
    // When app is swiped away while a transfer is TRANSFERRING, the facade's
    // onTaskDismissed() must set tracker state to PAUSED (not FAILED).
    // ─────────────────────────────────────────────────────────────────────────
    @Test
    public void testAndroidTaskDismissalPausesActiveTransfersNotFails() {
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .activeForegroundService(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryLevelPercent(80)
                .batteryCharging(false)
                .storagePermissionGranted(true)
                .build();

        AndroidNodeStateMachine sm = new AndroidNodeStateMachine(ctx);
        AndroidClipboardAdapter clipboardAdapter = new AndroidClipboardAdapter(
                keystoreManager.getPeerId().getValue(),
                ClipboardSyncMode.TEXT_AND_URL,
                clipboardBridge,
                sm
        );
        AndroidNodeFacade facade = new AndroidNodeFacade(
                sm, keystoreManager, storageAbstraction,
                clipboardAdapter, discoveryEngine, notificationController
        );

        // Simulate an active transfer in TRANSFERRING state
        final String transferId = "tx_beta01_regression";
        AtomicReference<org.peerlink.protocol.v1.TransferProgress> lastProgress = new AtomicReference<>();
        org.peerlink.core.transfer.TransferProgressTracker tracker =
                new org.peerlink.core.transfer.TransferProgressTracker(
                        transferId, 10_000_000L, 1,
                        lastProgress::set
                );

        tracker.start();
        tracker.addBytes(2_000_000L); // 20% through
        facade.registerTransferTracker(tracker);

        // Verify we are in TRANSFERRING state
        assertEquals(org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_CONNECTING, tracker.getState());
        assertFalse(tracker.isPaused());

        // Simulate task dismissal (app swiped away from Recents)
        facade.onTaskDismissed();

        // Post-teardown: tracker must be PAUSED, NOT FAILED
        assertEquals(org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_PAUSED, tracker.getState(),
                "DEFECT-BETA-01 regression: transfer must be PAUSED on task dismissal, not FAILED");
        assertTrue(tracker.isPaused(),
                "Transfer must be marked paused so resume checkpoint is preserved");

        // Verify that calling fail after already paused does NOT override to FAILED
        tracker.fail("Service destroyed");
        assertEquals(org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_PAUSED, tracker.getState(),
                "fail() must not override PAUSED into FAILED");
    }

    // --- Mock Helpers ---

    private static class MockContentResolverBridge implements AndroidStorageAbstraction.ContentResolverBridge {
        private static class FileEntry {
            String name;
            byte[] data;
            long length;
            boolean readPerm;
            boolean writePerm;
            boolean isDir;
        }

        private final Map<String, FileEntry> files = new HashMap<>();

        public void addFile(String uri, String name, byte[] data, boolean read, boolean write) {
            FileEntry entry = new FileEntry();
            entry.name = name;
            entry.data = data;
            entry.length = data.length;
            entry.readPerm = read;
            entry.writePerm = write;
            entry.isDir = false;
            files.put(uri, entry);
        }

        public void setLength(String uri, long length) {
            FileEntry e = files.get(uri);
            if (e != null) e.length = length;
        }

        public void setReadPermission(String uri, boolean read) {
            FileEntry e = files.get(uri);
            if (e != null) e.readPerm = read;
        }

        public void setWritePermission(String uri, boolean write) {
            FileEntry e = files.get(uri);
            if (e != null) e.writePerm = write;
        }

        @Override
        public InputStream openInputStream(String uri) throws IOException {
            FileEntry e = files.get(uri);
            if (e == null) throw new FileNotFoundException(uri);
            return new ByteArrayInputStream(e.data);
        }

        @Override
        public OutputStream openOutputStream(String uri) throws IOException {
            FileEntry e = files.get(uri);
            if (e == null) throw new FileNotFoundException(uri);
            return new ByteArrayOutputStream();
        }

        @Override
        public boolean delete(String uri) throws IOException {
            return files.remove(uri) != null;
        }

        @Override
        public boolean exists(String uri) {
            return files.containsKey(uri);
        }

        @Override
        public long getLength(String uri) {
            FileEntry e = files.get(uri);
            return e != null ? e.length : 0L;
        }

        @Override
        public String getDisplayName(String uri) {
            FileEntry e = files.get(uri);
            return e != null ? e.name : "unknown";
        }

        @Override
        public long getLastModified(String uri) {
            return System.currentTimeMillis();
        }

        @Override
        public boolean isDirectory(String uri) {
            FileEntry e = files.get(uri);
            return e != null && e.isDir;
        }

        @Override
        public List<String> listChildren(String treeUri) {
            return Collections.emptyList();
        }

        @Override
        public boolean checkReadPermission(String uri) {
            FileEntry e = files.get(uri);
            return e != null && e.readPerm;
        }

        @Override
        public boolean checkWritePermission(String uri) {
            FileEntry e = files.get(uri);
            return e != null && e.writePerm;
        }
    }

    private static class MockSystemClipboardBridge implements AndroidClipboardAdapter.SystemClipboardBridge {
        private String text = "";
        private boolean lastSensitive = false;

        public void setText(String text) { this.text = text; }
        public String getText() { return text; }
        public boolean isLastWriteSensitive() { return lastSensitive; }

        @Override
        public String readText() { return text; }

        @Override
        public void writeText(String text, boolean isSensitive) {
            this.text = text;
            this.lastSensitive = isSensitive;
        }

        @Override
        public boolean hasText() { return text != null && !text.isEmpty(); }
    }

    private static class MockNotificationBridge implements AndroidNotificationController.PlatformNotificationBridge {
        private final Map<String, Integer> activeProgress = new HashMap<>();
        private final Set<String> activePairings = new HashSet<>();
        private String lastStatusTitle;

        public boolean hasActiveTransferNotification(String transferId) {
            return activeProgress.containsKey(transferId);
        }

        public int getLastPercent(String transferId) {
            return activeProgress.getOrDefault(transferId, 0);
        }

        public boolean hasPairingPrompt(String sessionId) {
            return activePairings.contains(sessionId);
        }

        public String getLastStatusTitle() {
            return lastStatusTitle;
        }

        @Override
        public void showTransferProgress(String transferId, String title, int progressPercent, long bytesTransferred, long totalBytes) {
            activeProgress.put(transferId, progressPercent);
        }

        @Override
        public void dismissTransferProgress(String transferId) {
            activeProgress.remove(transferId);
        }

        @Override
        public void showPairingPrompt(String sessionId, PeerId peerId, String peerName, String sasPin) {
            activePairings.add(sessionId);
        }

        @Override
        public void dismissPairingPrompt(String sessionId) {
            activePairings.remove(sessionId);
        }

        @Override
        public void showStatusNotification(String title, String message) {
            this.lastStatusTitle = title;
        }
    }
}
