package org.peerlink.core.android;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine;
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode;
import org.peerlink.protocol.v1.PeerId;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

class AndroidForegroundTransferTest {

    private AndroidNodeFacade facade;
    private AndroidNodeStateMachine stateMachine;
    private AndroidSafStorageTest.MockContentResolverBridge storageBridge;

    @BeforeEach
    void setUp() {
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .activeForegroundService(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI_UNMETERED)
                .batteryLevelPercent(85)
                .batteryCharging(false)
                .storagePermissionGranted(true)
                .build();
        stateMachine = new AndroidNodeStateMachine(ctx);

        AndroidKeystoreManager keystore = new AndroidKeystoreManager(
                new AndroidKeystoreManager.SoftwareKeystoreProvider(false), "test_alias");

        storageBridge = new AndroidSafStorageTest.MockContentResolverBridge();
        AndroidStorageAbstraction storage = new AndroidStorageAbstraction(storageBridge);

        AndroidClipboardAdapter.SystemClipboardBridge clipBridge = new AndroidClipboardAdapter.SystemClipboardBridge() {
            private String clip = "";
            @Override public String readText() { return clip; }
            @Override public void writeText(String text, boolean sensitive) { clip = text; }
            @Override public boolean hasText() { return !clip.isEmpty(); }
        };
        AndroidClipboardAdapter clipboard = new AndroidClipboardAdapter(
                keystore.getPeerId().getValue(), ClipboardSyncMode.TEXT_AND_URL, clipBridge, stateMachine);

        AndroidDiscoveryEngine discovery = new AndroidDiscoveryEngine(Collections.emptyList());

        AndroidNotificationController notification = new AndroidNotificationController(
                new AndroidNotificationController.NotificationBridge() {
                    @Override public void createChannels() {}
                    @Override public void notify(int id, String channelId, String title, String text, int progress, int maxProgress, boolean ongoing) {}
                    @Override public void cancel(int id) {}
                    @Override public void showPairingPrompt(String sessionId, String peerName, String sasPin) {}
                });

        facade = new AndroidNodeFacade(stateMachine, keystore, storage, clipboard, discovery, notification);
    }

    @Test
    void testInitiateSendAndTransferLifecycleEvents() throws IOException {
        String docUri = "content://media/external/files/101";
        storageBridge.putDocument(docUri, "photos.zip", new byte[1024 * 512]);

        AtomicBoolean started = new AtomicBoolean(false);
        AtomicInteger progressUpdates = new AtomicInteger(0);
        AtomicBoolean completed = new AtomicBoolean(false);

        facade.addTransferListener(new AndroidNodeFacade.TransferEventListener() {
            @Override
            public void onTransferStarted(String transferId, PeerId remotePeer, String fileName, long totalBytes) {
                started.set(true);
                assertEquals("photos.zip", fileName);
                assertEquals(1024 * 512, totalBytes);
            }

            @Override
            public void onTransferProgress(String transferId, int percent, long transferredBytes, long totalBytes) {
                progressUpdates.incrementAndGet();
            }

            @Override
            public void onTransferCompleted(String transferId, boolean success, String errorMessage) {
                completed.set(true);
                assertTrue(success);
            }
        });

        PeerId remotePeer = PeerId.newBuilder().setValue("peer-desktop-windows-01").build();
        String txId = facade.initiateSend(remotePeer, List.of(docUri));
        assertNotNull(txId);
        assertTrue(started.get());

        // Emit progress
        facade.notifyTransferProgress(txId, "photos.zip", 50, 1024 * 256, 1024 * 512);
        assertEquals(1, progressUpdates.get());

        // Emit completion
        facade.notifyTransferFinished(txId, "photos.zip", true, null);
        assertTrue(completed.get());
    }

    @Test
    void testOpportunisticSyncAllowedOnlyOnValidSystemConditions() {
        // Condition: app backgrounded, Wi-Fi unmetered, good battery -> allowed
        stateMachine.updateContext(stateMachine.getCurrentContext().toBuilder()
                .appInForeground(false)
                .networkType(AndroidNodeContext.NetworkType.WIFI_UNMETERED)
                .batteryLevelPercent(70)
                .build());
        assertTrue(facade.performOpportunisticSync());

        // Condition: battery critical 10% not charging -> skipped
        stateMachine.updateContext(stateMachine.getCurrentContext().toBuilder()
                .batteryLevelPercent(10)
                .batteryCharging(false)
                .build());
        assertFalse(facade.performOpportunisticSync());

        // Condition: metered cellular with data saver -> skipped
        stateMachine.updateContext(stateMachine.getCurrentContext().toBuilder()
                .batteryLevelPercent(90)
                .networkType(AndroidNodeContext.NetworkType.CELLULAR_METERED)
                .dataSaverActive(true)
                .build());
        assertFalse(facade.performOpportunisticSync());
    }
}
