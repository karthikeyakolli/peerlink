package org.peerlink.core.android;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.peerlink.core.android.discovery.AndroidDiscoveryEngine;
import org.peerlink.core.collaboration.clipboard.ClipboardItem;
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode;
import org.peerlink.core.operation.*;
import org.peerlink.protocol.v1.PeerId;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.AccessDeniedException;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;

public class AndroidRealSendWorkflowTest {

    private AndroidNodeStateMachine stateMachine;
    private AndroidKeystoreManager keystoreManager;
    private AndroidStorageAbstraction storageAbstraction;
    private AndroidClipboardAdapter clipboardAdapter;
    private AndroidDiscoveryEngine discoveryEngine;
    private AndroidNotificationController notificationController;
    private InMemoryOperationJournal operationJournal;

    private MockContentResolverBridge contentResolver;
    private AndroidNodeFacade facade;

    private static class MockContentResolverBridge implements AndroidStorageAbstraction.ContentResolverBridge {
        final Map<String, byte[]> fileContents = new HashMap<>();
        final Map<String, String> displayNames = new HashMap<>();
        final Set<String> unreadableUris = new HashSet<>();

        void putFile(String uri, String displayName, byte[] data) {
            fileContents.put(uri, data);
            displayNames.put(uri, displayName);
        }

        @Override
        public InputStream openInputStream(String uri) throws IOException {
            if (unreadableUris.contains(uri) || !fileContents.containsKey(uri)) {
                throw new IOException("Cannot open input stream for: " + uri);
            }
            return new ByteArrayInputStream(fileContents.get(uri));
        }

        @Override
        public OutputStream openOutputStream(String uri) throws IOException {
            throw new UnsupportedOperationException();
        }

        @Override
        public boolean delete(String uri) {
            return fileContents.remove(uri) != null;
        }

        @Override
        public boolean exists(String uri) {
            return fileContents.containsKey(uri);
        }

        @Override
        public long getLength(String uri) {
            byte[] data = fileContents.get(uri);
            return data != null ? data.length : 0;
        }

        @Override
        public String getDisplayName(String uri) {
            return displayNames.getOrDefault(uri, "Unknown");
        }

        @Override
        public long getLastModified(String uri) {
            return 1700000000000L;
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
            return !unreadableUris.contains(uri);
        }

        @Override
        public boolean checkWritePermission(String uri) {
            return true;
        }
    }

    private static class MockClipboardBridge implements AndroidClipboardAdapter.SystemClipboardBridge {
        private String text = "";
        private boolean lastSensitive = false;

        @Override
        public String readText() {
            return text;
        }

        @Override
        public void writeText(String text, boolean isSensitive) {
            this.text = text;
            this.lastSensitive = isSensitive;
        }

        @Override
        public boolean hasText() {
            return text != null && !text.isEmpty();
        }
    }

    private static class MockNotificationBridge implements AndroidNotificationController.PlatformNotificationBridge {
        @Override
        public void showTransferProgress(String transferId, String title, int progressPercent, long bytesTransferred, long totalBytes) {}

        @Override
        public void dismissTransferProgress(String transferId) {}

        @Override
        public void showPairingPrompt(String sessionId, PeerId peerId, String peerName, String sasPin) {}

        @Override
        public void dismissPairingPrompt(String sessionId) {}

        @Override
        public void showStatusNotification(String title, String message) {}
    }

    @BeforeEach
    void setUp() {
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .batteryLevelPercent(90)
                .batteryCharging(false)
                .build();
        stateMachine = new AndroidNodeStateMachine(ctx);

        AndroidKeystoreManager.SoftwareKeystoreProvider swProvider =
                new AndroidKeystoreManager.SoftwareKeystoreProvider(true);
        keystoreManager = new AndroidKeystoreManager(swProvider, "test_android_alias");

        contentResolver = new MockContentResolverBridge();
        storageAbstraction = new AndroidStorageAbstraction(contentResolver);

        MockClipboardBridge clipboardBridge = new MockClipboardBridge();
        clipboardAdapter = new AndroidClipboardAdapter(
                keystoreManager.getPeerId().getValue(),
                ClipboardSyncMode.OFF,
                clipboardBridge,
                stateMachine
        );

        discoveryEngine = new AndroidDiscoveryEngine(Collections.emptyList());
        notificationController = new AndroidNotificationController(new MockNotificationBridge());
        operationJournal = new InMemoryOperationJournal();

        facade = new AndroidNodeFacade(
                stateMachine,
                keystoreManager,
                storageAbstraction,
                clipboardAdapter,
                discoveryEngine,
                notificationController,
                operationJournal,
                null
        );
    }

    @Test
    void testGenuineSafSendWorkflowWritesDurableJournalBeforeEmittingEvents() throws Exception {
        String safUri = "content://com.android.providers.media.documents/document/image%3A12345";
        byte[] payloadData = new byte[128 * 1024]; // 128 KB
        contentResolver.putFile(safUri, "photo_vacation.jpg", payloadData);

        AtomicBoolean eventEmitted = new AtomicBoolean(false);
        AtomicBoolean journalExistedBeforeEvent = new AtomicBoolean(false);

        facade.addTransferListener(new AndroidNodeFacade.TransferEventListener() {
            @Override
            public void onTransferStarted(String transferId, PeerId remotePeer, String fileName, long totalBytes) {
                eventEmitted.set(true);
                // Verify authoritative operation journal ALREADY has the record durably accepted
                List<OperationRecord> incomplete = operationJournal.listIncompleteOperations();
                if (!incomplete.isEmpty() && incomplete.get(0).getState() == OperationState.CREATED) {
                    journalExistedBeforeEvent.set(true);
                }
            }

            @Override
            public void onTransferProgress(String transferId, int percent, long transferredBytes, long totalBytes) {}

            @Override
            public void onTransferCompleted(String transferId, boolean success, String errorMessage) {}
        });

        PeerId targetPeer = PeerId.newBuilder().setValue("peer_windows_desktop").build();
        String transferId = facade.initiateSend(targetPeer, List.of(safUri));

        assertNotNull(transferId);
        assertTrue(eventEmitted.get(), "Transfer start event must be emitted");
        assertTrue(journalExistedBeforeEvent.get(),
                "Authoritative OperationJournal record must be durably committed BEFORE transfer-start events or notifications are emitted");

        // Verify journal entry details
        List<OperationRecord> records = operationJournal.listIncompleteOperations();
        assertEquals(1, records.size());
        OperationRecord record = records.get(0);
        assertEquals(OperationIntent.SEND, record.getIntent());
        assertEquals(keystoreManager.getPeerId().getValue(), record.getActorPeerId());
        assertTrue(record.getTargetObjectIds().contains("photo_vacation.jpg"));
    }

    @Test
    void testUnreadableOrInvalidSafUriFailsGracefullyWithoutOrphanJournal() {
        String invalidUri = "content://com.android.providers.media.documents/document/nonexistent";

        PeerId targetPeer = PeerId.newBuilder().setValue("peer_windows_desktop").build();

        AtomicBoolean eventEmitted = new AtomicBoolean(false);
        facade.addTransferListener(new AndroidNodeFacade.TransferEventListener() {
            @Override public void onTransferStarted(String transferId, PeerId remotePeer, String fileName, long totalBytes) { eventEmitted.set(true); }
            @Override public void onTransferProgress(String transferId, int percent, long transferredBytes, long totalBytes) {}
            @Override public void onTransferCompleted(String transferId, boolean success, String errorMessage) {}
        });

        assertThrows(Exception.class, () -> {
            facade.initiateSend(targetPeer, List.of(invalidUri));
        }, "Initiating send with unresolvable SAF URI must throw exception");

        // Verify NO events emitted and NO orphan journal entry created
        assertFalse(eventEmitted.get(), "No transfer started event should be emitted on failure");
        assertTrue(operationJournal.listIncompleteOperations().isEmpty(),
                "No orphan operation journal entries should be left on invalid SAF URI");
    }

    @Test
    void testPermissionDeniedSafUriThrowsAccessDeniedAndNoJournalEntry() {
        String forbiddenUri = "content://com.android.providers.media.documents/document/forbidden";
        contentResolver.putFile(forbiddenUri, "secret.dat", new byte[100]);
        contentResolver.unreadableUris.add(forbiddenUri);

        PeerId targetPeer = PeerId.newBuilder().setValue("peer_windows_desktop").build();

        assertThrows(AccessDeniedException.class, () -> {
            facade.initiateSend(targetPeer, List.of(forbiddenUri));
        });

        assertTrue(operationJournal.listIncompleteOperations().isEmpty(),
                "Access denied SAF URI must not produce orphan journal entries");
    }

    @Test
    void testOperationStateRecoveryAcrossSimulatedProcessRecreation() throws Exception {
        String safUri = "content://com.android.providers.media.documents/document/doc%3A999";
        contentResolver.putFile(safUri, "report.pdf", new byte[50000]);

        PeerId targetPeer = PeerId.newBuilder().setValue("peer_windows_desktop").build();
        facade.initiateSend(targetPeer, List.of(safUri));

        List<OperationRecord> incomplete = operationJournal.listIncompleteOperations();
        assertEquals(1, incomplete.size());
        String opId = incomplete.get(0).getOperationId();

        // Simulate process termination / recreation:
        // New AndroidNodeFacade initialized with the persistent journal
        AndroidNodeContext ctx = AndroidNodeContext.builder()
                .appInForeground(true)
                .networkType(AndroidNodeContext.NetworkType.WIFI)
                .build();
        AndroidNodeFacade restoredFacade = new AndroidNodeFacade(
                new AndroidNodeStateMachine(ctx),
                keystoreManager,
                storageAbstraction,
                clipboardAdapter,
                discoveryEngine,
                notificationController,
                operationJournal,
                null
        );

        // Verify incomplete operations can be retrieved and reconciled
        Optional<OperationRecord> restoredOp = restoredFacade.getOperationJournal().getOperation(opId);
        assertTrue(restoredOp.isPresent(), "Operation must be recoverable from journal after process recreation");
        assertEquals(OperationState.CREATED, restoredOp.get().getState());
    }
}
