package org.peerlink.desktop.ipc;

import io.grpc.stub.StreamObserver;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Service implementation for the authenticated Desktop Local Node gRPC IPC.
 * Supports:
 * - Handshake with token validation, ephemeral session issuance, and version compatibility
 * - Session token management (expiration, revocation, rotation)
 * - Node status queries
 * - Server-streaming real-time events (heartbeats, lifecycle events)
 * - Remote lifecycle controls (restart, stop)
 * - Authoritative trust-enforced transfer initiation
 */
public final class DesktopLocalNodeServiceImpl extends DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceImplBase implements Closeable {
    private static final Logger log = LoggerFactory.getLogger(DesktopLocalNodeServiceImpl.class);

    public static final String NODE_VERSION = "0.1.0";
    public static final String MIN_COMPATIBLE_CLIENT_VERSION = "0.1.0";
    public static final long DEFAULT_SESSION_TTL_MS = 3600_000L; // 1 hour session lifetime

    /**
     * Active IPC session authenticated via boot secret exchange.
     */
    public static final class IpcSessionRecord {
        private final String sessionToken;
        private final int clientPid;
        private final long createdAtMs;
        private final long expiresAtMs;

        public IpcSessionRecord(String sessionToken, int clientPid, long createdAtMs, long expiresAtMs) {
            this.sessionToken = sessionToken;
            this.clientPid = clientPid;
            this.createdAtMs = createdAtMs;
            this.expiresAtMs = expiresAtMs;
        }

        public String getSessionToken() { return sessionToken; }
        public int getClientPid() { return clientPid; }
        public long getCreatedAtMs() { return createdAtMs; }
        public long getExpiresAtMs() { return expiresAtMs; }

        public boolean isExpired(long nowMs) {
            return nowMs > expiresAtMs;
        }
    }

    private final String expectedAuthToken;
    private final String localPeerId;
    private final int listenPort;
    private final long startTimeMs = System.currentTimeMillis();
    private final Runnable restartHandler;
    private final Runnable stopHandler;
    private final org.peerlink.core.transfer.PeerTransferEngine transferEngine;
    private final org.peerlink.core.security.TrustStore trustStore;
    private final org.peerlink.core.identity.PairingCoordinator pairingCoordinator;
    private final org.peerlink.core.transport.PeerSessionManager sessionManager;
    private final long sessionTtlMs;
    private final SecureRandom secureRandom = new SecureRandom();
    private final Map<String, IpcSessionRecord> activeSessions = new ConcurrentHashMap<>();
    private final List<TransferProgress> transferHistory = new CopyOnWriteArrayList<>();

    private final List<StreamObserver<NodeEvent>> eventSubscribers = new CopyOnWriteArrayList<>();
    private final ScheduledExecutorService eventScheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "peerlink-ipc-heartbeat");
        t.setDaemon(true);
        return t;
    });
    private final AtomicLong heartbeatSequence = new AtomicLong(0);

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort) {
        this(expectedAuthToken, localPeerId, listenPort, null, null, null, null, null, null, DEFAULT_SESSION_TTL_MS);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler) {
        this(expectedAuthToken, localPeerId, listenPort, restartHandler, stopHandler, null, null, null, null, DEFAULT_SESSION_TTL_MS);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler,
                                       org.peerlink.core.transfer.PeerTransferEngine transferEngine) {
        this(expectedAuthToken, localPeerId, listenPort, restartHandler, stopHandler, transferEngine, null, null, null, DEFAULT_SESSION_TTL_MS);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler,
                                       org.peerlink.core.transfer.PeerTransferEngine transferEngine,
                                       org.peerlink.core.security.TrustStore trustStore,
                                       org.peerlink.core.identity.PairingCoordinator pairingCoordinator) {
        this(expectedAuthToken, localPeerId, listenPort, restartHandler, stopHandler, transferEngine, trustStore, pairingCoordinator, null, DEFAULT_SESSION_TTL_MS);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler,
                                       org.peerlink.core.transfer.PeerTransferEngine transferEngine,
                                       org.peerlink.core.security.TrustStore trustStore,
                                       org.peerlink.core.identity.PairingCoordinator pairingCoordinator,
                                       org.peerlink.core.transport.PeerSessionManager sessionManager) {
        this(expectedAuthToken, localPeerId, listenPort, restartHandler, stopHandler, transferEngine, trustStore, pairingCoordinator, sessionManager, DEFAULT_SESSION_TTL_MS);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler,
                                       org.peerlink.core.transfer.PeerTransferEngine transferEngine,
                                       org.peerlink.core.security.TrustStore trustStore,
                                       org.peerlink.core.identity.PairingCoordinator pairingCoordinator,
                                       long sessionTtlMs) {
        this(expectedAuthToken, localPeerId, listenPort, restartHandler, stopHandler, transferEngine, trustStore, pairingCoordinator, null, sessionTtlMs);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler,
                                       org.peerlink.core.transfer.PeerTransferEngine transferEngine,
                                       org.peerlink.core.security.TrustStore trustStore,
                                       org.peerlink.core.identity.PairingCoordinator pairingCoordinator,
                                       org.peerlink.core.transport.PeerSessionManager sessionManager,
                                       long sessionTtlMs) {
        this.expectedAuthToken = expectedAuthToken;
        this.localPeerId = localPeerId;
        this.listenPort = listenPort;
        this.restartHandler = restartHandler;
        this.stopHandler = stopHandler;
        this.transferEngine = transferEngine;
        this.trustStore = trustStore;
        this.pairingCoordinator = pairingCoordinator;
        this.sessionManager = sessionManager;
        this.sessionTtlMs = sessionTtlMs > 0 ? sessionTtlMs : DEFAULT_SESSION_TTL_MS;

        // Schedule periodic heartbeat streaming (every 1 second)
        eventScheduler.scheduleAtFixedRate(this::broadcastHeartbeat, 1, 1, TimeUnit.SECONDS);
    }

    @Override
    public void authenticate(AuthenticateIpcRequest request, StreamObserver<AuthenticateIpcResponse> responseObserver) {
        String clientVersion = request.getClientVersion();
        boolean isCompatible = checkVersionCompatibility(clientVersion);

        if (!isCompatible) {
            log.warn("Rejected incompatible client version: '{}' (node requires {}.x)", clientVersion, MIN_COMPATIBLE_CLIENT_VERSION);
            AuthenticateIpcResponse response = AuthenticateIpcResponse.newBuilder()
                    .setAuthenticated(false)
                    .setIsCompatible(false)
                    .setNodeVersion(NODE_VERSION)
                    .setMinCompatibleVersion(MIN_COMPATIBLE_CLIENT_VERSION)
                    .setErrorMessage("Incompatible client version: " + clientVersion + ". Requires " + MIN_COMPATIBLE_CLIENT_VERSION)
                    .build();
            responseObserver.onNext(response);
            responseObserver.onCompleted();
            return;
        }

        boolean validToken = expectedAuthToken != null && !expectedAuthToken.isBlank()
                && request.getAuthToken() != null
                && java.security.MessageDigest.isEqual(
                        expectedAuthToken.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                        request.getAuthToken().getBytes(java.nio.charset.StandardCharsets.UTF_8)
                );
        if (validToken) {
            // Issue a fresh, time-bound session token to avoid bearer secret re-use
            byte[] rand = new byte[32];
            secureRandom.nextBytes(rand);
            String sessionToken = "sess_" + Base64.getUrlEncoder().withoutPadding().encodeToString(rand);
            long now = System.currentTimeMillis();
            long expiresAt = now + sessionTtlMs;
            IpcSessionRecord session = new IpcSessionRecord(sessionToken, request.getClientPid(), now, expiresAt);
            activeSessions.put(sessionToken, session);

            log.info("Client authenticated successfully (pid: {}, version: {}). Active sessions: {}",
                    request.getClientPid(), request.getClientVersion(), activeSessions.size());
            AuthenticateIpcResponse response = AuthenticateIpcResponse.newBuilder()
                    .setAuthenticated(true)
                    .setIsCompatible(true)
                    .setSessionToken(sessionToken)
                    .setNodeVersion(NODE_VERSION)
                    .setMinCompatibleVersion(MIN_COMPATIBLE_CLIENT_VERSION)
                    .setLocalPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                    .build();
            responseObserver.onNext(response);
            responseObserver.onCompleted();
        } else {
            log.warn("Rejected invalid IPC authentication attempt from client pid: {}", request.getClientPid());
            AuthenticateIpcResponse response = AuthenticateIpcResponse.newBuilder()
                    .setAuthenticated(false)
                    .setIsCompatible(true)
                    .setNodeVersion(NODE_VERSION)
                    .setMinCompatibleVersion(MIN_COMPATIBLE_CLIENT_VERSION)
                    .setErrorMessage("Invalid local IPC auth token")
                    .build();
            responseObserver.onNext(response);
            responseObserver.onCompleted();
        }
    }

    public boolean isSessionValid(String token) {
        if (token == null || token.isBlank()) {
            return false;
        }
        IpcSessionRecord session = activeSessions.get(token);
        if (session == null) {
            return false;
        }
        if (session.isExpired(System.currentTimeMillis())) {
            activeSessions.remove(token);
            log.warn("Rejected expired local IPC session token");
            return false;
        }
        return true;
    }

    public boolean revokeSession(String token) {
        if (token == null) return false;
        return activeSessions.remove(token) != null;
    }

    public void revokeAllSessions() {
        activeSessions.clear();
        log.info("All local IPC sessions have been revoked");
    }

    public int getActiveSessionCount() {
        long now = System.currentTimeMillis();
        activeSessions.entrySet().removeIf(e -> e.getValue().isExpired(now));
        return activeSessions.size();
    }

    public String createCustomSession(int clientPid, long ttlMs) {
        byte[] rand = new byte[32];
        secureRandom.nextBytes(rand);
        String sessionToken = "sess_" + Base64.getUrlEncoder().withoutPadding().encodeToString(rand);
        long now = System.currentTimeMillis();
        long expiresAt = now + ttlMs;
        activeSessions.put(sessionToken, new IpcSessionRecord(sessionToken, clientPid, now, expiresAt));
        return sessionToken;
    }

    public String rotateSession(String oldToken) {
        if (!isSessionValid(oldToken)) {
            return null;
        }
        IpcSessionRecord oldSession = activeSessions.remove(oldToken);
        if (oldSession == null) {
            return null;
        }
        return createCustomSession(oldSession.getClientPid(), sessionTtlMs);
    }

    public org.peerlink.core.security.TrustStore getTrustStore() {
        return trustStore;
    }

    public org.peerlink.core.identity.PairingCoordinator getPairingCoordinator() {
        return pairingCoordinator;
    }

    private boolean checkVersionCompatibility(String clientVersion) {
        if (clientVersion == null || clientVersion.isBlank()) {
            return false;
        }
        // Baseline version rule: Client and Node must belong to same minor release (0.1.x)
        return clientVersion.startsWith("0.1.") || clientVersion.equals("0.1.0");
    }

    @Override
    public void getStatus(GetNodeStatusRequest request, StreamObserver<GetNodeStatusResponse> responseObserver) {
        long uptime = (System.currentTimeMillis() - startTimeMs) / 1000;
        long memoryUsed = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();

        GetNodeStatusResponse response = GetNodeStatusResponse.newBuilder()
                .setStatus(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING)
                .setPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setListenPort(listenPort)
                .addSupportedCapabilities(FeatureCapability.FEATURE_TRANSFER_RESUME)
                .addSupportedCapabilities(FeatureCapability.FEATURE_TCP_TLS)
                .setUptimeSeconds(uptime)
                .setMemoryUsedBytes(memoryUsed)
                .setNodeVersion(NODE_VERSION)
                .setActiveSubscribers(eventSubscribers.size())
                .build();

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }

    @Override
    public void subscribeEvents(NodeEventSubscriptionRequest request, StreamObserver<NodeEvent> responseObserver) {
        log.info("Client subscribed to IPC event stream.");

        // Register active subscriber
        eventSubscribers.add(responseObserver);

        // Send immediate initial heartbeat (sequence 0)
        long uptime = (System.currentTimeMillis() - startTimeMs) / 1000;
        long memoryUsed = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        NodeEvent initialEvent = NodeEvent.newBuilder()
                .setTimestampUtcMs(System.currentTimeMillis())
                .setHeartbeat(NodeHeartbeat.newBuilder()
                        .setTimestampUtcMs(System.currentTimeMillis())
                        .setStatus(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING)
                        .setUptimeSeconds(uptime)
                        .setMemoryUsedBytes(memoryUsed)
                        .setSequenceNumber(0)
                        .build())
                .build();

        try {
            responseObserver.onNext(initialEvent);
        } catch (Exception e) {
            log.debug("Failed to deliver initial heartbeat, removing subscriber: {}", e.getMessage());
            eventSubscribers.remove(responseObserver);
        }
    }

    private void broadcastHeartbeat() {
        if (eventSubscribers.isEmpty()) {
            return;
        }

        long seq = heartbeatSequence.incrementAndGet();
        long uptime = (System.currentTimeMillis() - startTimeMs) / 1000;
        long memoryUsed = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();

        NodeEvent event = NodeEvent.newBuilder()
                .setTimestampUtcMs(System.currentTimeMillis())
                .setHeartbeat(NodeHeartbeat.newBuilder()
                        .setTimestampUtcMs(System.currentTimeMillis())
                        .setStatus(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING)
                        .setUptimeSeconds(uptime)
                        .setMemoryUsedBytes(memoryUsed)
                        .setSequenceNumber(seq)
                        .build())
                .build();

        for (StreamObserver<NodeEvent> subscriber : eventSubscribers) {
            try {
                subscriber.onNext(event);
            } catch (Exception e) {
                log.debug("Removing disconnected subscriber: {}", e.getMessage());
                eventSubscribers.remove(subscriber);
            }
        }
    }

    public void broadcastLifecycleEvent(String message) {
        NodeEvent event = NodeEvent.newBuilder()
                .setTimestampUtcMs(System.currentTimeMillis())
                .setLifecycleEvent(message)
                .build();

        for (StreamObserver<NodeEvent> subscriber : eventSubscribers) {
            try {
                subscriber.onNext(event);
            } catch (Exception e) {
                eventSubscribers.remove(subscriber);
            }
        }
    }

    @Override
    public void restart(RestartNodeRequest request, StreamObserver<RestartNodeResponse> responseObserver) {
        log.info("Received restart request via local IPC");
        broadcastLifecycleEvent("Node restart initiated via local IPC");

        RestartNodeResponse response = RestartNodeResponse.newBuilder()
                .setAccepted(true)
                .setMessage("Node restart initiated")
                .build();
        responseObserver.onNext(response);
        responseObserver.onCompleted();

        if (restartHandler != null) {
            Executors.newSingleThreadScheduledExecutor().schedule(restartHandler, request.getDelayMs(), TimeUnit.MILLISECONDS);
        }
    }

    @Override
    public void stop(StopNodeRequest request, StreamObserver<StopNodeResponse> responseObserver) {
        log.info("Received stop request via local IPC");
        broadcastLifecycleEvent("Node shutdown initiated via local IPC");

        StopNodeResponse response = StopNodeResponse.newBuilder()
                .setAccepted(true)
                .setMessage("Node stopping")
                .build();
        responseObserver.onNext(response);
        responseObserver.onCompleted();

        if (stopHandler != null) {
            Executors.newSingleThreadScheduledExecutor().schedule(stopHandler, 200, TimeUnit.MILLISECONDS);
        }
    }

    public int getActiveSubscriberCount() {
        return eventSubscribers.size();
    }

    public void broadcastTransferProgress(TransferProgress progress) {
        // Update history
        transferHistory.removeIf(p -> p.getTransferId().equals(progress.getTransferId()));
        transferHistory.add(progress);

        NodeEvent event = NodeEvent.newBuilder()
                .setTimestampUtcMs(System.currentTimeMillis())
                .setTransferProgress(progress)
                .build();

        for (StreamObserver<NodeEvent> subscriber : eventSubscribers) {
            try {
                subscriber.onNext(event);
            } catch (Exception e) {
                eventSubscribers.remove(subscriber);
            }
        }
    }

    @Override
    public void initiateSend(InitiateSendRequest request, StreamObserver<InitiateSendResponse> responseObserver) {
        log.info("Received InitiateSend request for {} source path(s) to peer {}",
                request.getSourcePathsCount(), request.getTargetPeerId().getValue());

        String targetPeerId = request.getTargetPeerId().getValue();
        if (trustStore != null) {
            if (trustStore.isRevoked(targetPeerId)) {
                log.warn("Blocked InitiateSend: target peer {} is revoked", targetPeerId);
                responseObserver.onNext(InitiateSendResponse.newBuilder()
                        .setAccepted(false)
                        .setErrorMessage("Target peer " + targetPeerId + " is revoked")
                        .build());
                responseObserver.onCompleted();
                return;
            }
            if (!trustStore.isTrusted(targetPeerId)) {
                log.warn("Blocked InitiateSend: target peer {} is not trusted", targetPeerId);
                responseObserver.onNext(InitiateSendResponse.newBuilder()
                        .setAccepted(false)
                        .setErrorMessage("Target peer " + targetPeerId + " is not trusted. Explicit cryptographic pairing required.")
                        .build());
                responseObserver.onCompleted();
                return;
            }
        }

        if (transferEngine == null) {
            responseObserver.onNext(InitiateSendResponse.newBuilder()
                    .setAccepted(false)
                    .setErrorMessage("Transfer engine not initialized on this node")
                    .build());
            responseObserver.onCompleted();
            return;
        }

        List<java.nio.file.Path> sourcePaths = new ArrayList<>();
        for (String p : request.getSourcePathsList()) {
            sourcePaths.add(java.nio.file.Paths.get(p));
        }

        try {
            org.peerlink.protocol.v1.TransferManifest manifest = transferEngine.prepareSend(
                    localPeerId,
                    targetPeerId,
                    sourcePaths,
                    request.getDuplicatePolicy());

            String transferId = manifest.getTransferId();
            String opId = manifest.getOperationId().getValue();

            // Run asynchronous transfer over active PeerSession in background thread
            new Thread(() -> {
                try {
                    Optional<org.peerlink.core.transport.PeerSession> sessionOpt =
                            sessionManager != null ? sessionManager.getSessionByPeerId(targetPeerId) : Optional.empty();

                    if (sessionOpt.isPresent()) {
                        transferEngine.sendTransferOverSession(
                                sessionOpt.get(),
                                manifest,
                                sourcePaths,
                                this::broadcastTransferProgress);
                    } else {
                        log.warn("Transfer {} deferred: No active PeerSession with target peer {}", transferId, targetPeerId);
                        broadcastTransferProgress(TransferProgress.newBuilder()
                                .setTransferId(transferId)
                                .setState(TransferState.TRANSFER_STATE_FAILED)
                                .setBytesTransferred(0)
                                .setTotalBytes(manifest.getTotalBytes())
                                .setCurrentItemIndex(0)
                                .setTotalItems(manifest.getItemsCount())
                                .setPercentComplete(0.0f)
                                .build());
                    }
                } catch (Exception e) {
                    log.error("Transfer {} failed during execution: {}", transferId, e.getMessage(), e);
                }
            }, "peerlink-send-" + transferId).start();

            InitiateSendResponse response = InitiateSendResponse.newBuilder()
                    .setAccepted(true)
                    .setTransferId(transferId)
                    .setOperationId(manifest.getOperationId())
                    .setTotalBytes(manifest.getTotalBytes())
                    .setFileCount(manifest.getItemsCount())
                    .build();

            responseObserver.onNext(response);
            responseObserver.onCompleted();

        } catch (Exception e) {
            log.error("Failed to initiate send: {}", e.getMessage(), e);
            responseObserver.onNext(InitiateSendResponse.newBuilder()
                    .setAccepted(false)
                    .setErrorMessage(e.getMessage())
                    .build());
            responseObserver.onCompleted();
        }
    }

    @Override
    public void cancelTransfer(CancelTransferRequest request, StreamObserver<CancelTransferResponse> responseObserver) {
        log.info("Received CancelTransfer for transferId: {}", request.getTransferId());
        if (transferEngine != null) {
            transferEngine.cancelTransfer(request.getTransferId(), request.getReason());
        }
        responseObserver.onNext(CancelTransferResponse.newBuilder()
                .setAccepted(true)
                .setMessage("Cancellation signaled")
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void pauseTransfer(PauseTransferRequest request, StreamObserver<PauseTransferResponse> responseObserver) {
        log.info("Received PauseTransfer for transferId: {}", request.getTransferId());
        if (transferEngine != null) {
            transferEngine.pauseTransfer(request.getTransferId(), request.getReason());
        }
        responseObserver.onNext(PauseTransferResponse.newBuilder()
                .setAccepted(true)
                .setMessage("Pause signaled")
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void resumeTransfer(ResumeTransferRequest request, StreamObserver<ResumeTransferResponse> responseObserver) {
        log.info("Received ResumeTransfer for transferId: {}", request.getTransferId());
        responseObserver.onNext(ResumeTransferResponse.newBuilder()
                .setAccepted(true)
                .setMessage("Resume initiated")
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void setBandwidthLimit(SetBandwidthLimitRequest request, StreamObserver<SetBandwidthLimitResponse> responseObserver) {
        log.info("Received SetBandwidthLimit: {} bps", request.getMaxBytesPerSec());
        if (transferEngine != null) {
            transferEngine.setBandwidthLimit(request.getMaxBytesPerSec());
        }
        responseObserver.onNext(SetBandwidthLimitResponse.newBuilder()
                .setAccepted(true)
                .setCurrentLimitBps(request.getMaxBytesPerSec())
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void getTransfer(GetTransferRequest request, StreamObserver<GetTransferResponse> responseObserver) {
        Optional<TransferProgress> progress = transferHistory.stream()
                .filter(p -> p.getTransferId().equals(request.getTransferId()))
                .findFirst();

        if (progress.isPresent()) {
            responseObserver.onNext(GetTransferResponse.newBuilder()
                    .setFound(true)
                    .setProgress(progress.get())
                    .build());
        } else {
            responseObserver.onNext(GetTransferResponse.newBuilder()
                    .setFound(false)
                    .build());
        }
        responseObserver.onCompleted();
    }

    @Override
    public void listTransfers(ListTransfersRequest request, StreamObserver<ListTransfersResponse> responseObserver) {
        List<TransferProgress> list = request.getActiveOnly()
                ? transferHistory.stream()
                    .filter(p -> p.getState() != TransferState.TRANSFER_STATE_COMPLETED
                              && p.getState() != TransferState.TRANSFER_STATE_FAILED
                              && p.getState() != TransferState.TRANSFER_STATE_CANCELLED)
                    .toList()
                : new ArrayList<>(transferHistory);

        responseObserver.onNext(ListTransfersResponse.newBuilder()
                .addAllTransfers(list)
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void revealInFolder(RevealInFolderRequest request, StreamObserver<RevealInFolderResponse> responseObserver) {
        log.info("Received RevealInFolder for: {}", request.getFileOrFolderPath());
        boolean success = org.peerlink.desktop.runtime.RevealInFolderUtil.revealInFolder(
                java.nio.file.Paths.get(request.getFileOrFolderPath()));

        responseObserver.onNext(RevealInFolderResponse.newBuilder()
                .setOpened(success)
                .setErrorMessage(success ? "" : "Failed to launch native file explorer")
                .build());
        responseObserver.onCompleted();
    }

    @Override
    public void close() {
        eventScheduler.shutdownNow();
        for (StreamObserver<NodeEvent> subscriber : eventSubscribers) {
            try {
                subscriber.onCompleted();
            } catch (Exception ignored) {}
        }
        eventSubscribers.clear();
    }
}
