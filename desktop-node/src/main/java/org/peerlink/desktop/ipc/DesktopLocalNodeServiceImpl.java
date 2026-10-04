package org.peerlink.desktop.ipc;

import io.grpc.stub.StreamObserver;
import org.peerlink.protocol.v1.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Closeable;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Service implementation for the authenticated Desktop Local Node gRPC IPC.
 * Supports:
 * - Handshake with token validation and strict API/client version compatibility check
 * - Node status queries
 * - Server-streaming real-time events (heartbeats, lifecycle events)
 * - Remote lifecycle controls (restart, stop)
 */
public final class DesktopLocalNodeServiceImpl extends DesktopLocalNodeServiceGrpc.DesktopLocalNodeServiceImplBase implements Closeable {
    private static final Logger log = LoggerFactory.getLogger(DesktopLocalNodeServiceImpl.class);

    public static final String NODE_VERSION = "0.1.0";
    public static final String MIN_COMPATIBLE_CLIENT_VERSION = "0.1.0";

    private final String expectedAuthToken;
    private final String localPeerId;
    private final int listenPort;
    private final long startTimeMs = System.currentTimeMillis();
    private final Runnable restartHandler;
    private final Runnable stopHandler;
    private final org.peerlink.core.transfer.PeerTransferEngine transferEngine;
    private final List<TransferProgress> transferHistory = new CopyOnWriteArrayList<>();

    private final List<StreamObserver<NodeEvent>> eventSubscribers = new CopyOnWriteArrayList<>();
    private final ScheduledExecutorService eventScheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "peerlink-ipc-heartbeat");
        t.setDaemon(true);
        return t;
    });
    private final AtomicLong heartbeatSequence = new AtomicLong(0);

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort) {
        this(expectedAuthToken, localPeerId, listenPort, null, null, null);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler) {
        this(expectedAuthToken, localPeerId, listenPort, restartHandler, stopHandler, null);
    }

    public DesktopLocalNodeServiceImpl(String expectedAuthToken, String localPeerId, int listenPort,
                                       Runnable restartHandler, Runnable stopHandler,
                                       org.peerlink.core.transfer.PeerTransferEngine transferEngine) {
        this.expectedAuthToken = expectedAuthToken;
        this.localPeerId = localPeerId;
        this.listenPort = listenPort;
        this.restartHandler = restartHandler;
        this.stopHandler = stopHandler;
        this.transferEngine = transferEngine;

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
            log.info("Client authenticated successfully (pid: {}, version: {})", request.getClientPid(), request.getClientVersion());
            AuthenticateIpcResponse response = AuthenticateIpcResponse.newBuilder()
                    .setAuthenticated(true)
                    .setIsCompatible(true)
                    .setSessionToken(expectedAuthToken)
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

        java.nio.file.Path destRoot;
        if (request.getDestinationFolder() != null && !request.getDestinationFolder().isBlank()) {
            destRoot = java.nio.file.Paths.get(request.getDestinationFolder());
        } else {
            // Default received folder: Downloads/PeerLinkReceived
            destRoot = java.nio.file.Paths.get(System.getProperty("user.home"), "Downloads", "PeerLinkReceived");
        }

        try {
            org.peerlink.protocol.v1.TransferManifest manifest = transferEngine.prepareSend(
                    localPeerId,
                    request.getTargetPeerId().getValue(),
                    sourcePaths,
                    request.getDuplicatePolicy());

            String transferId = manifest.getTransferId();
            String opId = manifest.getOperationId().getValue();

            // Run asynchronous transfer in background thread
            new Thread(() -> {
                try {
                    transferEngine.executeTransfer(
                            sourcePaths,
                            destRoot,
                            request.getDuplicatePolicy(),
                            localPeerId,
                            request.getTargetPeerId().getValue(),
                            this::broadcastTransferProgress);
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
