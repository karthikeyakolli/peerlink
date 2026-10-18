package org.peerlink.core.android;

import org.peerlink.core.android.discovery.AndroidDiscoveryEngine;
import org.peerlink.core.collaboration.clipboard.ClipboardItem;
import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

/**
 * Authoritative Android Node Facade coordinating all Android platform services,
 * Keystore identity, SAF storage, discovery, notifications, and background state.
 * Bridges to the Flutter UI layer over Pigeon/PlatformChannels.
 */
public class AndroidNodeFacade {
    private static final Logger log = LoggerFactory.getLogger(AndroidNodeFacade.class);

    public interface TransferEventListener {
        void onTransferStarted(String transferId, PeerId remotePeer, String fileName, long totalBytes);
        void onTransferProgress(String transferId, int percent, long transferredBytes, long totalBytes);
        void onTransferCompleted(String transferId, boolean success, String errorMessage);
    }

    private final AndroidNodeStateMachine stateMachine;
    private final AndroidKeystoreManager keystoreManager;
    private final AndroidStorageAbstraction storageAbstraction;
    private final AndroidClipboardAdapter clipboardAdapter;
    private final AndroidDiscoveryEngine discoveryEngine;
    private final AndroidNotificationController notificationController;
    private final org.peerlink.core.operation.OperationJournal operationJournal;
    private final org.peerlink.core.transfer.PeerTransferEngine transferEngine;

    private final ConcurrentMap<String, String> activePairingSessions = new ConcurrentHashMap<>();
    private final List<TransferEventListener> transferListeners = new ArrayList<>();
    private final ConcurrentMap<String, org.peerlink.core.transfer.TransferProgressTracker> activeTrackers = new ConcurrentHashMap<>();
    private volatile boolean isStarted = false;

    public AndroidNodeFacade(AndroidNodeStateMachine stateMachine,
                             AndroidKeystoreManager keystoreManager,
                             AndroidStorageAbstraction storageAbstraction,
                             AndroidClipboardAdapter clipboardAdapter,
                             AndroidDiscoveryEngine discoveryEngine,
                             AndroidNotificationController notificationController) {
        this(stateMachine, keystoreManager, storageAbstraction, clipboardAdapter, discoveryEngine, notificationController, null, null);
    }

    public AndroidNodeFacade(AndroidNodeStateMachine stateMachine,
                             AndroidKeystoreManager keystoreManager,
                             AndroidStorageAbstraction storageAbstraction,
                             AndroidClipboardAdapter clipboardAdapter,
                             AndroidDiscoveryEngine discoveryEngine,
                             AndroidNotificationController notificationController,
                             org.peerlink.core.operation.OperationJournal operationJournal,
                             org.peerlink.core.transfer.PeerTransferEngine transferEngine) {
        this.stateMachine = Objects.requireNonNull(stateMachine, "stateMachine must not be null");
        this.keystoreManager = Objects.requireNonNull(keystoreManager, "keystoreManager must not be null");
        this.storageAbstraction = Objects.requireNonNull(storageAbstraction, "storageAbstraction must not be null");
        this.clipboardAdapter = Objects.requireNonNull(clipboardAdapter, "clipboardAdapter must not be null");
        this.discoveryEngine = Objects.requireNonNull(discoveryEngine, "discoveryEngine must not be null");
        this.notificationController = Objects.requireNonNull(notificationController, "notificationController must not be null");
        this.operationJournal = operationJournal;
        this.transferEngine = transferEngine;
    }

    public synchronized void start() {
        if (isStarted) return;
        isStarted = true;
        log.info("Starting Android PeerLink Node: {}", keystoreManager.getPeerId().getValue());

        // Start discovery adapters
        discoveryEngine.startAll();
        discoveryEngine.startAdvertisingAll(keystoreManager.getPeerId(), "Android Peer", 8765);
    }

    public synchronized void stop() {
        if (!isStarted) return;
        isStarted = false;
        log.info("Stopping Android PeerLink Node");
        pauseAllActiveTransfers("Node stopping");
        discoveryEngine.stopAll();
    }

    public PeerId getLocalPeerId() {
        return keystoreManager.getPeerId();
    }

    public AndroidNodeState getCurrentState() {
        return stateMachine.getCurrentState();
    }

    public AndroidNodeContext getCurrentContext() {
        return stateMachine.getCurrentContext();
    }

    public void updateContext(AndroidNodeContext context) {
        stateMachine.updateContext(context);
    }

    public AndroidNodeStateMachine getStateMachine() {
        return stateMachine;
    }

    public AndroidKeystoreManager getKeystoreManager() {
        return keystoreManager;
    }

    public AndroidStorageAbstraction getStorageAbstraction() {
        return storageAbstraction;
    }

    public AndroidClipboardAdapter getClipboardAdapter() {
        return clipboardAdapter;
    }

    public AndroidDiscoveryEngine getDiscoveryEngine() {
        return discoveryEngine;
    }

    public AndroidNotificationController getNotificationController() {
        return notificationController;
    }

    public org.peerlink.core.operation.OperationJournal getOperationJournal() {
        return operationJournal;
    }

    public org.peerlink.core.transfer.PeerTransferEngine getTransferEngine() {
        return transferEngine;
    }

    public void addTransferListener(TransferEventListener listener) {
        transferListeners.add(Objects.requireNonNull(listener));
    }

    // --- Pairing flow ---

    public void requestPairing(String sessionId, PeerId targetPeer, String peerName, String sasPin) {
        activePairingSessions.put(sessionId, sasPin);
        notificationController.showPairingRequest(sessionId, targetPeer, peerName, sasPin);
    }

    public boolean confirmPairing(String sessionId, boolean accept) {
        String pin = activePairingSessions.remove(sessionId);
        notificationController.dismissPairingRequest(sessionId);
        log.info("Pairing session {} decision: {} (SAS was {})", sessionId, accept ? "ACCEPTED" : "REJECTED", pin);
        return accept;
    }

    // --- Transfer flow ---

    public String initiateSend(PeerId targetPeer, List<String> contentUris) throws IOException {
        if (getCurrentState() == AndroidNodeState.UNAVAILABLE) {
            throw new IllegalStateException("Cannot initiate send: Android node is UNAVAILABLE");
        }
        if (contentUris == null || contentUris.isEmpty()) {
            throw new IllegalArgumentException("Cannot initiate send: contentUris list is empty");
        }

        // 1. Resolve and validate EVERY SAF URI before recording operation or emitting events
        List<PeerFileHandle> handles = new ArrayList<>();
        List<String> targetNames = new ArrayList<>();
        long totalBytes = 0;

        for (String uri : contentUris) {
            Optional<PeerFileHandle> handleOpt = storageAbstraction.resolveByPhysicalPath(uri);
            if (handleOpt.isEmpty()) {
                throw new java.io.FileNotFoundException("Cannot resolve SAF content URI: " + uri);
            }
            PeerFileHandle handle = handleOpt.get();
            handles.add(handle);
            targetNames.add(handle.getDisplayName());
            totalBytes += handle.getSizeBytes();
        }

        String firstFileName = targetNames.isEmpty() ? "File" : targetNames.get(0);
        String transferId = "tx_" + UUID.randomUUID().toString().replace("-", "");
        String opId = "op_send_" + UUID.randomUUID().toString().replace("-", "");
        long now = System.currentTimeMillis();

        // 2. Durably commit operation record to OperationJournal BEFORE emitting any event
        if (operationJournal != null) {
            org.peerlink.core.operation.OperationRecord record = new org.peerlink.core.operation.OperationRecord(
                    opId,
                    org.peerlink.core.operation.OperationIntent.SEND,
                    keystoreManager.getPeerId().getValue(),
                    targetNames,
                    org.peerlink.core.operation.OperationState.CREATED,
                    "idemp_" + transferId,
                    now,
                    now
            );
            operationJournal.recordOperation(record);
            operationJournal.recordJournalStage(opId, org.peerlink.core.operation.JournalStage.INTENT);
        }

        // 3. Only after durable journal commit, trigger background policy check, notifications, and events
        boolean needFgs = AndroidBackgroundPolicy.requiresForegroundService(totalBytes, (int) (totalBytes / (1024 * 1024) + 1));
        log.info("Durably accepted send of {} files ({} bytes) to {} [transferId={}, opId={}] - FGS required: {}",
                contentUris.size(), totalBytes, targetPeer.getValue(), transferId, opId, needFgs);

        notificationController.updateTransferProgress(transferId, firstFileName, 0, 0, totalBytes);

        for (TransferEventListener l : transferListeners) {
            l.onTransferStarted(transferId, targetPeer, firstFileName, totalBytes);
        }

        return transferId;
    }

    public void notifyTransferProgress(String transferId, String fileName, int percent, long transferred, long total) {
        notificationController.updateTransferProgress(transferId, fileName, percent, transferred, total);
        for (TransferEventListener l : transferListeners) {
            l.onTransferProgress(transferId, percent, transferred, total);
        }
    }

    public void registerTransferTracker(org.peerlink.core.transfer.TransferProgressTracker tracker) {
        if (tracker != null) {
            activeTrackers.put(tracker.getTransferId(), tracker);
        }
    }

    public void unregisterTransferTracker(String transferId) {
        if (transferId != null) {
            activeTrackers.remove(transferId);
        }
    }

    public List<org.peerlink.core.transfer.TransferProgressTracker> getActiveTransferTrackers() {
        return new ArrayList<>(activeTrackers.values());
    }

    public synchronized void onTaskDismissed() {
        log.warn("Android task dismissed / service teardown: pausing {} active transfer(s)", activeTrackers.size());
        pauseAllActiveTransfers("App dismissed from recents / task killed");
    }

    public synchronized void pauseAllActiveTransfers(String reason) {
        for (org.peerlink.core.transfer.TransferProgressTracker tracker : activeTrackers.values()) {
            if (!tracker.isCancelled() && tracker.getState() != org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_COMPLETED
                    && tracker.getState() != org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_FAILED
                    && tracker.getState() != org.peerlink.protocol.v1.TransferState.TRANSFER_STATE_PAUSED) {
                log.info("Pausing active transfer {} due to: {}", tracker.getTransferId(), reason);
                tracker.pause(reason);
                notificationController.updateTransferProgress(tracker.getTransferId(), "Transfer Paused", 0, tracker.getTransferredBytes(), tracker.getTotalBytes());
            }
        }
    }

    public void notifyTransferFinished(String transferId, String fileName, boolean success, String errorMessage) {
        unregisterTransferTracker(transferId);
        notificationController.completeTransfer(transferId, fileName, success);
        for (TransferEventListener l : transferListeners) {
            l.onTransferCompleted(transferId, success, errorMessage);
        }
    }

    // --- Clipboard flow ---

    public Optional<ClipboardItem> syncClipboardOutbound() throws IOException {
        return clipboardAdapter.syncLocalClipboardOutbound();
    }

    public boolean applyClipboardInbound(ClipboardItem item, boolean sensitive) {
        return clipboardAdapter.applyRemoteClipboardInbound(item, sensitive);
    }

    // --- Background WorkManager sync & backup participation ---

    public boolean performOpportunisticSync() {
        AndroidNodeContext ctx = getCurrentContext();
        if (!AndroidBackgroundPolicy.canRunBackgroundSync(ctx)) {
            log.info("Opportunistic background sync skipped due to system constraints");
            return false;
        }
        log.info("Executing opportunistic background sync under valid battery/network conditions");
        return true;
    }

    public boolean performOpportunisticBackup() {
        AndroidNodeContext ctx = getCurrentContext();
        if (!AndroidBackgroundPolicy.canRunBackgroundBackup(ctx)) {
            log.info("Opportunistic background backup skipped due to system constraints");
            return false;
        }
        log.info("Executing opportunistic background backup under charging and unmetered Wi-Fi");
        return true;
    }
}
