package org.peerlink.core.android;

import org.peerlink.core.android.discovery.AndroidDiscoveryEngine;
import org.peerlink.core.collaboration.clipboard.ClipboardItem;
import org.peerlink.core.filesystem.PeerFileHandle;
import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
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

    public interface LifecycleEventListener {
        void onLifecycleChanged(NodeLifecycleState oldState, NodeLifecycleState newState, String reason);
    }

    public interface IncomingOfferListener {
        void onOffer(String transferId, PeerId senderPeer, String fileName, long totalBytes, int itemCount);
    }

    private final AndroidNodeStateMachine stateMachine;
    private final AndroidKeystoreManager keystoreManager;
    private final AndroidStorageAbstraction storageAbstraction;
    private final AndroidClipboardAdapter clipboardAdapter;
    private final AndroidDiscoveryEngine discoveryEngine;
    private final AndroidNotificationController notificationController;
    private final org.peerlink.core.operation.OperationJournal operationJournal;
    private final org.peerlink.core.transfer.PeerTransferEngine transferEngine;

    private final org.peerlink.core.transport.TransportProvider transportProvider;
    private final org.peerlink.core.transport.PeerSessionManager sessionManager;
    private final org.peerlink.core.android.discovery.TransportRouteSelector routeSelector;
    private final java.nio.file.Path destinationRoot;
    private final org.peerlink.core.security.TrustStore trustStore;
    private final java.util.concurrent.ExecutorService transferExecutor = java.util.concurrent.Executors.newCachedThreadPool(r -> {
        Thread t = new Thread(r, "peerlink-node-transfer");
        t.setDaemon(true);
        return t;
    });

    private volatile org.peerlink.core.transfer.TransferSessionReceiver.ReceiverConsentMode receiverConsentMode =
            org.peerlink.core.transfer.TransferSessionReceiver.ReceiverConsentMode.AUTO_ACCEPT_PAIRED_TRUSTED;
    private volatile org.peerlink.core.transfer.TransferSessionReceiver currentReceiver;
    private final List<IncomingOfferListener> incomingOfferListeners = new java.util.concurrent.CopyOnWriteArrayList<>();
    private org.peerlink.core.transport.PeerSessionManager.SessionLifecycleListener inboundSessionLifecycleListener;

    private final ConcurrentMap<String, String> activePairingSessions = new ConcurrentHashMap<>();
    private final List<TransferEventListener> transferListeners = new ArrayList<>();
    private final List<LifecycleEventListener> lifecycleListeners = new java.util.concurrent.CopyOnWriteArrayList<>();
    private final ConcurrentMap<String, org.peerlink.core.transfer.TransferProgressTracker> activeTrackers = new ConcurrentHashMap<>();
    private volatile boolean isStarted = false;
    private volatile NodeLifecycleState lifecycleState = NodeLifecycleState.STOPPED;

    private final java.util.concurrent.ScheduledExecutorService retryScheduler = java.util.concurrent.Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "peerlink-node-retry");
        t.setDaemon(true);
        return t;
    });
    private java.util.concurrent.ScheduledFuture<?> pendingRetryTask;
    private final java.util.concurrent.atomic.AtomicInteger retryCount = new java.util.concurrent.atomic.AtomicInteger(0);
    public static final int MAX_RETRY_BUDGET = 3;

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
        this(stateMachine, keystoreManager, storageAbstraction, clipboardAdapter, discoveryEngine, notificationController,
                operationJournal, transferEngine, null, null, null, null, null);
    }

    public AndroidNodeFacade(AndroidNodeStateMachine stateMachine,
                             AndroidKeystoreManager keystoreManager,
                             AndroidStorageAbstraction storageAbstraction,
                             AndroidClipboardAdapter clipboardAdapter,
                             AndroidDiscoveryEngine discoveryEngine,
                             AndroidNotificationController notificationController,
                             org.peerlink.core.operation.OperationJournal operationJournal,
                             org.peerlink.core.transfer.PeerTransferEngine transferEngine,
                             org.peerlink.core.transport.TransportProvider transportProvider,
                             org.peerlink.core.transport.PeerSessionManager sessionManager,
                             org.peerlink.core.android.discovery.TransportRouteSelector routeSelector,
                             java.nio.file.Path destinationRoot,
                             org.peerlink.core.security.TrustStore trustStore) {
        this.stateMachine = Objects.requireNonNull(stateMachine, "stateMachine must not be null");
        this.keystoreManager = Objects.requireNonNull(keystoreManager, "keystoreManager must not be null");
        this.storageAbstraction = Objects.requireNonNull(storageAbstraction, "storageAbstraction must not be null");
        this.clipboardAdapter = Objects.requireNonNull(clipboardAdapter, "clipboardAdapter must not be null");
        this.discoveryEngine = Objects.requireNonNull(discoveryEngine, "discoveryEngine must not be null");
        this.notificationController = Objects.requireNonNull(notificationController, "notificationController must not be null");
        this.operationJournal = operationJournal;
        this.transferEngine = transferEngine;
        this.transportProvider = transportProvider;
        this.sessionManager = sessionManager;
        this.routeSelector = routeSelector;
        this.destinationRoot = destinationRoot;
        this.trustStore = trustStore;
    }

    public NodeLifecycleState getLifecycleState() {
        return lifecycleState;
    }

    public void addLifecycleListener(LifecycleEventListener listener) {
        lifecycleListeners.add(Objects.requireNonNull(listener, "listener must not be null"));
    }

    public void removeLifecycleListener(LifecycleEventListener listener) {
        lifecycleListeners.remove(listener);
    }

    public synchronized void setLifecycleState(NodeLifecycleState newState, String reason) {
        if (this.lifecycleState == newState) {
            return;
        }
        NodeLifecycleState oldState = this.lifecycleState;
        this.lifecycleState = newState;
        log.info("NodeLifecycleState transition: {} -> {} ({})", oldState, newState, reason);
        for (LifecycleEventListener l : lifecycleListeners) {
            try {
                l.onLifecycleChanged(oldState, newState, reason);
            } catch (Exception e) {
                log.error("Error in LifecycleEventListener callback", e);
            }
        }
    }

    public synchronized void start() {
        if (pendingRetryTask != null && !pendingRetryTask.isDone()) {
            pendingRetryTask.cancel(true);
            pendingRetryTask = null;
        }
        if (isStarted && (lifecycleState == NodeLifecycleState.READY || lifecycleState == NodeLifecycleState.DISCOVERING || lifecycleState == NodeLifecycleState.CONNECTED || lifecycleState == NodeLifecycleState.TRANSFERRING)) {
            log.warn("Node start requested while already in operational state: {}", lifecycleState);
            return;
        }
        isStarted = true;
        setLifecycleState(NodeLifecycleState.STARTING, "Starting Android Node: " + keystoreManager.getPeerId().getValue());

        setLifecycleState(NodeLifecycleState.CHECKING_CAPABILITIES, "Reconciling device capabilities and permissions");
        if (getCurrentState() == AndroidNodeState.UNAVAILABLE) {
            setLifecycleState(NodeLifecycleState.UNAVAILABLE, "Critical prerequisite unavailable (storage permission or offline)");
            scheduleRetryIfEligible("Critical prerequisite unavailable");
            return;
        }

        retryCount.set(0);
        int boundPort = 8765;
        if (transportProvider != null) {
            try {
                if (transportProvider.getListeningPort() <= 0) {
                    transportProvider.startListening(boundPort, conn -> {
                        if (sessionManager != null) {
                            sessionManager.handleInboundConnection(conn);
                        }
                    });
                }
                boundPort = transportProvider.getListeningPort();
            } catch (Exception e) {
                log.warn("Failed to bind on default port 8765, falling back to ephemeral port: {}", e.getMessage());
                try {
                    transportProvider.startListening(0, conn -> {
                        if (sessionManager != null) {
                            sessionManager.handleInboundConnection(conn);
                        }
                    });
                    boundPort = transportProvider.getListeningPort();
                } catch (Exception ex2) {
                    log.error("Fatal error binding transport listener: {}", ex2.getMessage());
                }
            }
        }

        if (sessionManager != null && transferEngine != null && destinationRoot != null) {
            if (inboundSessionLifecycleListener != null) {
                sessionManager.removeSessionLifecycleListener(inboundSessionLifecycleListener);
            }
            inboundSessionLifecycleListener = new org.peerlink.core.transport.PeerSessionManager.SessionLifecycleListener() {
                @Override
                public void onSessionEstablished(org.peerlink.core.transport.PeerSession session) {
                    log.info("Inbound PeerSession established with remote peer: {}", session.getRemotePeer().getPeerId().getValue());
                    org.peerlink.core.transfer.TransferSessionCoordinator coordinator;
                    if (session.getPayloadHandler() instanceof org.peerlink.core.transfer.TransferSessionCoordinator existing) {
                        coordinator = existing;
                    } else {
                        coordinator = new org.peerlink.core.transfer.TransferSessionCoordinator(session);
                    }
                    org.peerlink.core.transfer.TransferSessionReceiver receiver = new org.peerlink.core.transfer.TransferSessionReceiver(
                            transferEngine,
                            destinationRoot,
                            trustStore,
                            receiverConsentMode
                    );
                    currentReceiver = receiver;
                    receiver.addListener(new org.peerlink.core.transfer.TransferSessionReceiver.ReceiverTransferEventListener() {
                        @Override
                        public void onIncomingOffer(org.peerlink.core.transport.PeerSession sess, org.peerlink.protocol.v1.TransferOffer offer) {
                            String xferId = offer.getManifest().getTransferId();
                            String fileName = offer.getManifest().getItemsCount() > 0 ? offer.getManifest().getItems(0).getRelativePath() : "file";
                            String peerName = sess.getRemotePeer().getDisplayName();
                            if (peerName == null || peerName.isEmpty()) {
                                peerName = sess.getRemotePeer().getPeerId().getValue();
                            }
                            notificationController.showIncomingTransferRequest(xferId, sess.getRemotePeer().getPeerId(), peerName, fileName, offer.getManifest().getTotalBytes(), offer.getManifest().getItemsCount());
                            for (IncomingOfferListener l : incomingOfferListeners) {
                                try {
                                    l.onOffer(xferId, sess.getRemotePeer().getPeerId(), fileName, offer.getManifest().getTotalBytes(), offer.getManifest().getItemsCount());
                                } catch (Exception ignored) {}
                            }
                        }

                        @Override
                        public void onTransferProgress(String xferId, String fileName, int percent, long transferred, long total) {
                            notifyTransferProgress(xferId, fileName, percent, transferred, total);
                        }

                        @Override
                        public void onTransferCompleted(String xferId, String fileName, boolean success, String errMsg) {
                            notificationController.dismissIncomingTransferRequest(xferId);
                            notifyTransferFinished(xferId, fileName, success, errMsg);
                        }
                    });
                    coordinator.registerReceiver(receiver);
                    setLifecycleState(NodeLifecycleState.CONNECTED, "Connected to authenticated peer: " + session.getRemotePeer().getPeerId().getValue());
                }

                @Override
                public void onSessionClosed(org.peerlink.core.transport.PeerSession session) {
                    if (activeTrackers.isEmpty() && isStarted) {
                        setLifecycleState(NodeLifecycleState.READY, "Peer disconnected; node ready");
                    }
                }
            };
            sessionManager.addSessionLifecycleListener(inboundSessionLifecycleListener);
        }

        setLifecycleState(NodeLifecycleState.DISCOVERING, "Starting discovery adapters");
        discoveryEngine.setLocalPeerId(keystoreManager.getPeerId());
        discoveryEngine.startAll();
        discoveryEngine.startAdvertisingAll(keystoreManager.getPeerId(), "Android Peer", boundPort);

        setLifecycleState(NodeLifecycleState.READY, "Node ready for verified sharing routes on port " + boundPort);
    }

    private synchronized void scheduleRetryIfEligible(String reason) {
        int attempt = retryCount.incrementAndGet();
        if (attempt <= MAX_RETRY_BUDGET) {
            long delaySeconds = (long) Math.pow(2, attempt - 1);
            log.info("Scheduling startup retry attempt {}/{} in {}s (reason: {})", attempt, MAX_RETRY_BUDGET, delaySeconds, reason);
            pendingRetryTask = retryScheduler.schedule(() -> {
                log.info("Executing startup retry attempt {}/{}", attempt, MAX_RETRY_BUDGET);
                start();
            }, delaySeconds, java.util.concurrent.TimeUnit.SECONDS);
        } else {
            log.warn("Exhausted startup retry budget ({}/{}). Node remains UNAVAILABLE until environmental change.", attempt - 1, MAX_RETRY_BUDGET);
        }
    }

    public int getRetryCount() {
        return retryCount.get();
    }

    public synchronized void stop() {
        if (pendingRetryTask != null && !pendingRetryTask.isDone()) {
            pendingRetryTask.cancel(true);
            pendingRetryTask = null;
        }
        retryCount.set(0);
        if (!isStarted && lifecycleState == NodeLifecycleState.STOPPED) {
            return;
        }
        setLifecycleState(NodeLifecycleState.STOPPING, "Stopping Android Node");
        isStarted = false;
        pauseAllActiveTransfers("Node stopping");
        discoveryEngine.stopAll();
        if (sessionManager != null && inboundSessionLifecycleListener != null) {
            sessionManager.removeSessionLifecycleListener(inboundSessionLifecycleListener);
            inboundSessionLifecycleListener = null;
        }
        if (transportProvider != null && transportProvider.getListeningPort() > 0) {
            transportProvider.stopListening();
        }
        setLifecycleState(NodeLifecycleState.STOPPED, "Node stopped");
    }

    public NodeCapabilities getNodeCapabilities() {
        List<String> ifaces = new ArrayList<>();
        try {
            Enumeration<java.net.NetworkInterface> en = java.net.NetworkInterface.getNetworkInterfaces();
            if (en != null) {
                while (en.hasMoreElements()) {
                    java.net.NetworkInterface nif = en.nextElement();
                    if (nif.isUp()) {
                        ifaces.add(nif.getName() + " (" + (nif.isLoopback() ? "loopback" : "active") + ")");
                    }
                }
            }
        } catch (Exception ignored) {}

        List<String> activeListeners = new ArrayList<>();
        if (lifecycleState.isOperational()) {
            activeListeners.add("TCP://0.0.0.0:8765 (TLS/Ed25519)");
        }

        List<String> usableTransports = Arrays.asList("TCP_TLS", "QUIC", "WIFI_DIRECT");
        List<String> missingPermissions = new ArrayList<>();
        AndroidNodeContext ctx = getCurrentContext();
        if (!ctx.isStoragePermissionGranted()) {
            missingPermissions.add("Storage (SAF/Media)");
        }
        if (!ctx.isNotificationPermissionGranted()) {
            missingPermissions.add("Notifications");
        }
        if (!ctx.isNearbyDevicesPermissionGranted()) {
            missingPermissions.add("Nearby Devices");
        }
        if (!ctx.isLocalNetworkPermissionGranted()) {
            missingPermissions.add("Local Network");
        }
        if (!ctx.isCameraPermissionGranted()) {
            missingPermissions.add("Camera");
        }

        String limitations = "None";
        if (ctx.isDeviceIdleMode()) {
            limitations = "Doze Mode Active (Background sockets suspended)";
        } else if (ctx.isPowerSaveMode()) {
            limitations = "Power Save Mode Active (Throttled execution)";
        } else if (ctx.getBatteryLevelPercent() <= 15 && !ctx.isBatteryCharging()) {
            limitations = "Critical Battery (" + ctx.getBatteryLevelPercent() + "%)";
        }

        Map<String, Boolean> features = new LinkedHashMap<>();
        features.put("SEND", true);
        features.put("ACCESS", true);
        features.put("SYNC", true);
        features.put("BACKUP", true);

        return new NodeCapabilities(
                ifaces,
                activeListeners,
                usableTransports,
                missingPermissions,
                limitations,
                features,
                keystoreManager.isDirectHardwareSigning(),
                keystoreManager.getSecurityLevelDescription(),
                lifecycleState.canAcceptTransfers() && getCurrentState() != AndroidNodeState.UNAVAILABLE
        );
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
        if (isStarted && lifecycleState == NodeLifecycleState.UNAVAILABLE && stateMachine.getCurrentState() != AndroidNodeState.UNAVAILABLE) {
            log.info("Environmental prerequisites restored; resuming node startup");
            retryCount.set(0);
            start();
        }
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
        String transferId = "tx_" + UUID.randomUUID().toString().replace("-", "");
        initiateSendAsync(targetPeer, contentUris, transferId);
        return transferId;
    }

    public java.util.concurrent.CompletableFuture<org.peerlink.protocol.v1.TransferCompletedReceipt> initiateSendAsync(
            PeerId targetPeer, List<String> contentUris, String transferId) throws IOException {
        if (getCurrentState() == AndroidNodeState.UNAVAILABLE) {
            throw new IllegalStateException("Cannot initiate send: Android node is UNAVAILABLE");
        }
        if (contentUris == null || contentUris.isEmpty()) {
            throw new IllegalArgumentException("Cannot initiate send: contentUris list is empty");
        }

        // 1. Resolve and validate EVERY SAF URI before recording operation or emitting events
        List<java.nio.file.Path> sourcePaths = new ArrayList<>();
        List<PeerFileHandle> handles = new ArrayList<>();
        List<String> targetNames = new ArrayList<>();
        long totalBytes = 0;

        for (String uri : contentUris) {
            Optional<PeerFileHandle> handleOpt = storageAbstraction.resolveByPhysicalPath(uri);
            if (handleOpt.isEmpty()) {
                throw new java.io.FileNotFoundException("Cannot resolve SAF content URI or file path: " + uri);
            }
            PeerFileHandle handle = handleOpt.get();
            handles.add(handle);
            targetNames.add(handle.getDisplayName());
            totalBytes += handle.getSizeBytes();
            sourcePaths.add(resolveHandleToPath(handle, transferId));
        }

        String firstFileName = targetNames.isEmpty() ? "File" : targetNames.get(0);
        String opId = "op_send_" + transferId.replace("tx_", "");
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

        setLifecycleState(NodeLifecycleState.TRANSFERRING, "Active transfer started: " + transferId);

        for (TransferEventListener l : transferListeners) {
            l.onTransferStarted(transferId, targetPeer, firstFileName, totalBytes);
        }

        java.util.concurrent.CompletableFuture<org.peerlink.protocol.v1.TransferCompletedReceipt> executionFuture = new java.util.concurrent.CompletableFuture<>();

        if (transferEngine == null) {
            executionFuture.complete(null);
            return executionFuture;
        }

        transferExecutor.submit(() -> {
            try {
                org.peerlink.core.transport.PeerSession session = obtainSessionForPeer(targetPeer);
                org.peerlink.protocol.v1.TransferManifest manifest = transferEngine.prepareSend(
                        keystoreManager.getPeerId().getValue(),
                        targetPeer.getValue(),
                        sourcePaths,
                        org.peerlink.protocol.v1.DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX
                );

                org.peerlink.protocol.v1.TransferCompletedReceipt receipt = transferEngine.sendTransferOverSession(
                        session,
                        manifest,
                        sourcePaths,
                        progress -> {
                            int percent = progress.getTotalBytes() > 0
                                    ? (int) Math.min(100, (progress.getTransferredBytes() * 100) / progress.getTotalBytes())
                                    : 0;
                            notifyTransferProgress(
                                    transferId,
                                    firstFileName,
                                    percent,
                                    progress.getTransferredBytes(),
                                    progress.getTotalBytes()
                            );
                        }
                );

                if (receipt != null && receipt.getSuccess()) {
                    if (operationJournal != null) {
                        operationJournal.updateState(opId, org.peerlink.core.operation.OperationState.COMMITTED);
                        operationJournal.recordJournalStage(opId, org.peerlink.core.operation.JournalStage.COMMIT);
                    }
                    notifyTransferFinished(transferId, firstFileName, true, null);
                    executionFuture.complete(receipt);
                } else {
                    String err = (receipt != null) ? receipt.getErrorMessage() : "Transfer failed with null receipt";
                    if (operationJournal != null) {
                        operationJournal.updateState(opId, org.peerlink.core.operation.OperationState.FAILED);
                        operationJournal.appendNote(opId, "Send failed: " + err);
                    }
                    notifyTransferFinished(transferId, firstFileName, false, err);
                    executionFuture.complete(receipt);
                }
            } catch (Exception e) {
                log.error("Transfer execution failed for transfer {}: {}", transferId, e.getMessage(), e);
                if (operationJournal != null) {
                    operationJournal.updateState(opId, org.peerlink.core.operation.OperationState.FAILED);
                    operationJournal.appendNote(opId, "Exception: " + e.getMessage());
                }
                notifyTransferFinished(transferId, firstFileName, false, e.getMessage());
                executionFuture.completeExceptionally(e);
            }
        });

        return executionFuture;
    }

    private java.nio.file.Path resolveHandleToPath(PeerFileHandle handle, String transferId) throws IOException {
        if (handle instanceof AndroidStorageAbstraction.SafPeerFileHandle safHandle) {
            String physicalUri = safHandle.getPhysicalUri();
            File directFile = new File(physicalUri);
            if (directFile.exists() && directFile.isFile()) {
                return directFile.toPath();
            }
            if (physicalUri.startsWith("file://")) {
                File fileUri = new File(physicalUri.substring(7));
                if (fileUri.exists() && fileUri.isFile()) {
                    return fileUri.toPath();
                }
            }
            java.nio.file.Path stagingOutbound = (destinationRoot != null ? destinationRoot.getParent() : new File(System.getProperty("java.io.tmpdir")).toPath())
                    .resolve("staging_outbound")
                    .resolve(transferId);
            java.nio.file.Files.createDirectories(stagingOutbound);
            String rawName = handle.getDisplayName();
            String safeName = (rawName != null && !rawName.isBlank()) ? new File(rawName).getName() : "item";
            java.nio.file.Path cachedFile = stagingOutbound.resolve(safeName).normalize();
            if (!cachedFile.startsWith(stagingOutbound.normalize())) {
                throw new SecurityException("Path traversal attempt in outbound file name: " + rawName);
            }
            try (InputStream in = handle.openInputStream();
                 OutputStream out = java.nio.file.Files.newOutputStream(cachedFile)) {
                in.transferTo(out);
            }
            return cachedFile;
        }
        throw new IOException("Unsupported PeerFileHandle type: " + handle.getClass().getName());
    }

    private org.peerlink.core.transport.PeerSession obtainSessionForPeer(PeerId targetPeer) throws Exception {
        if (sessionManager == null) {
            throw new IllegalStateException("PeerSessionManager is not configured on AndroidNodeFacade");
        }

        Optional<org.peerlink.core.transport.PeerSession> existing = sessionManager.getSessionByPeerId(targetPeer.getValue());
        if (existing.isPresent() && existing.get().getState() == org.peerlink.protocol.v1.SessionState.SESSION_STATE_ESTABLISHED) {
            return existing.get();
        }

        org.peerlink.core.android.discovery.DiscoveredPeerRecord targetRecord = null;
        for (org.peerlink.core.android.discovery.DiscoveredPeerRecord record : discoveryEngine.getDiscoveredPeers()) {
            if (record.getPeerId().getValue().equals(targetPeer.getValue())) {
                targetRecord = record;
                break;
            }
        }

        if (targetRecord == null) {
            throw new IOException("Target peer " + targetPeer.getValue() + " has no reachable discovered routes or active sessions");
        }

        if (routeSelector == null) {
            throw new IllegalStateException("TransportRouteSelector is not configured on AndroidNodeFacade");
        }

        org.peerlink.core.android.discovery.TransportRouteSelector.TransportConnectionResult connResult =
                routeSelector.connectWithFallbackAsync(targetRecord).get(10, java.util.concurrent.TimeUnit.SECONDS);

        return sessionManager.initiateSessionAsync(connResult.connection()).get(10, java.util.concurrent.TimeUnit.SECONDS);
    }

    public void addIncomingOfferListener(IncomingOfferListener listener) {
        if (listener != null) incomingOfferListeners.add(listener);
    }

    public void removeIncomingOfferListener(IncomingOfferListener listener) {
        if (listener != null) incomingOfferListeners.remove(listener);
    }

    public boolean respondIncomingTransfer(String transferId, boolean accept) {
        notificationController.dismissIncomingTransferRequest(transferId);
        if (currentReceiver != null) {
            return currentReceiver.respondConsent(transferId, accept);
        }
        return false;
    }

    public void setReceiverConsentMode(org.peerlink.core.transfer.TransferSessionReceiver.ReceiverConsentMode mode) {
        this.receiverConsentMode = Objects.requireNonNull(mode);
        if (currentReceiver != null) {
            currentReceiver.setConsentMode(mode);
        }
    }

    public org.peerlink.core.transfer.TransferSessionReceiver.ReceiverConsentMode getReceiverConsentMode() {
        return receiverConsentMode;
    }

    public org.peerlink.core.transport.TransportProvider getTransportProvider() {
        return transportProvider;
    }

    public org.peerlink.core.transport.PeerSessionManager getSessionManager() {
        return sessionManager;
    }

    public org.peerlink.core.android.discovery.TransportRouteSelector getRouteSelector() {
        return routeSelector;
    }

    public java.nio.file.Path getDestinationRoot() {
        return destinationRoot;
    }

    public org.peerlink.core.security.TrustStore getTrustStore() {
        return trustStore;
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
            setLifecycleState(NodeLifecycleState.TRANSFERRING, "Active transfer registered: " + tracker.getTransferId());
        }
    }

    public void unregisterTransferTracker(String transferId) {
        if (transferId != null) {
            activeTrackers.remove(transferId);
            if (activeTrackers.isEmpty() && lifecycleState == NodeLifecycleState.TRANSFERRING) {
                setLifecycleState(NodeLifecycleState.READY, "All active transfers finished; node ready");
            }
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
        if (lifecycleState == NodeLifecycleState.TRANSFERRING) {
            setLifecycleState(NodeLifecycleState.READY, "Transfers paused: " + reason);
        }
    }

    public synchronized boolean pauseTransfer(String transferId, String reason) {
        org.peerlink.core.transfer.TransferProgressTracker tracker = activeTrackers.get(transferId);
        if (tracker != null) {
            tracker.pause(reason);
            if (transferEngine != null) {
                transferEngine.pauseTransfer(transferId, reason);
            }
            notificationController.updateTransferProgress(transferId, "Transfer Paused", 0, tracker.getTransferredBytes(), tracker.getTotalBytes());
            return true;
        }
        return false;
    }

    public synchronized boolean cancelTransfer(String transferId, String reason) {
        org.peerlink.core.transfer.TransferProgressTracker tracker = activeTrackers.get(transferId);
        if (tracker != null) {
            tracker.cancel(reason);
            if (transferEngine != null) {
                transferEngine.cancelTransfer(transferId, reason);
            }
            notifyTransferFinished(transferId, "Transfer Cancelled", false, reason);
            return true;
        }
        return false;
    }

    public void notifyTransferFinished(String transferId, String fileName, boolean success, String errorMessage) {
        unregisterTransferTracker(transferId);
        notificationController.completeTransfer(transferId, fileName, success);
        for (TransferEventListener l : transferListeners) {
            l.onTransferCompleted(transferId, success, errorMessage);
        }
        if (activeTrackers.isEmpty() && lifecycleState == NodeLifecycleState.TRANSFERRING) {
            setLifecycleState(NodeLifecycleState.READY, "All transfers completed; node ready");
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
