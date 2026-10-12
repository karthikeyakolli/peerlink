package org.peerlink.core.access;

import org.peerlink.core.transport.PeerSession;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.*;

/**
 * Client for performing authorized remote access operations (browse, search, preview, metadata)
 * over an active PeerSession.
 */
public final class RemoteAccessClient {

    private final String localPeerId;
    private final String targetPeerId;
    private final PeerSession session;
    private final Map<String, CompletableFuture<AccessResponse>> pendingRequests = new ConcurrentHashMap<>();
    private final Map<String, CompletableFuture<AccessCancelResponse>> pendingCancels = new ConcurrentHashMap<>();

    public RemoteAccessClient(String localPeerId, String targetPeerId, PeerSession session) {
        this.localPeerId = localPeerId;
        this.targetPeerId = targetPeerId;
        this.session = session;

        if (session != null) {
            session.setPayloadHandler((sess, payload) -> {
                try {
                    AccessWireMessage wire = AccessWireMessage.parseFrom(payload);
                    if (wire.hasResponse()) {
                        AccessResponse response = wire.getResponse();
                        CompletableFuture<AccessResponse> future = pendingRequests.remove(response.getRequestId());
                        if (future != null) {
                            future.complete(response);
                        }
                    } else if (wire.hasCancelResponse()) {
                        AccessCancelResponse cancelResp = wire.getCancelResponse();
                        CompletableFuture<AccessCancelResponse> future = pendingCancels.remove(cancelResp.getRequestId());
                        if (future != null) {
                            future.complete(cancelResp);
                        }
                    }
                } catch (Exception ignored) {
                    // Not an AccessWireMessage or parsing error; ignore gracefully
                }
            });
        }
    }

    /**
     * Browses a remote directory.
     */
    public CompletableFuture<AccessResponse> browseAsync(
            String shareId,
            String relativePath,
            int maxResults,
            String cursor,
            String authorizationToken,
            long timeoutMs
    ) {
        AccessRequest request = AccessRequest.newBuilder()
                .setRequestId(generateRequestId())
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(targetPeerId).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_BROWSE)
                .setShareId(shareId)
                .setRelativePath(relativePath == null ? "" : relativePath)
                .setMaxResults(maxResults)
                .setPaginationCursor(cursor == null ? "" : cursor)
                .setAuthorizationToken(authorizationToken == null ? "" : authorizationToken)
                .setTimeoutMs(timeoutMs)
                .setClientTimestampUtcMs(System.currentTimeMillis())
                .build();

        return sendRequestAsync(request, timeoutMs);
    }

    /**
     * Queries metadata for a specific remote path.
     */
    public CompletableFuture<AccessResponse> getMetadataAsync(
            String shareId,
            String relativePath,
            String authorizationToken,
            long timeoutMs
    ) {
        AccessRequest request = AccessRequest.newBuilder()
                .setRequestId(generateRequestId())
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(targetPeerId).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_METADATA)
                .setShareId(shareId)
                .setRelativePath(relativePath == null ? "" : relativePath)
                .setAuthorizationToken(authorizationToken == null ? "" : authorizationToken)
                .setTimeoutMs(timeoutMs)
                .setClientTimestampUtcMs(System.currentTimeMillis())
                .build();

        return sendRequestAsync(request, timeoutMs);
    }

    /**
     * Executes a remote search within an authorized share.
     */
    public CompletableFuture<AccessResponse> searchAsync(
            String shareId,
            String relativeScope,
            String query,
            int maxResults,
            int maxDepth,
            long timeoutMs,
            String cursor,
            String authorizationToken
    ) {
        AccessRequest request = AccessRequest.newBuilder()
                .setRequestId(generateRequestId())
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(targetPeerId).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_SEARCH)
                .setShareId(shareId)
                .setRelativePath(relativeScope == null ? "" : relativeScope)
                .setSearchQuery(query == null ? "" : query)
                .setMaxResults(maxResults)
                .setMaxDepth(maxDepth)
                .setTimeoutMs(timeoutMs)
                .setPaginationCursor(cursor == null ? "" : cursor)
                .setAuthorizationToken(authorizationToken == null ? "" : authorizationToken)
                .setClientTimestampUtcMs(System.currentTimeMillis())
                .build();

        return sendRequestAsync(request, timeoutMs);
    }

    /**
     * Requests safe preview data for a remote file.
     */
    public CompletableFuture<AccessResponse> previewAsync(
            String shareId,
            String relativePath,
            int maxBytes,
            String authorizationToken,
            long timeoutMs
    ) {
        AccessRequest request = AccessRequest.newBuilder()
                .setRequestId(generateRequestId())
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(targetPeerId).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_PREVIEW)
                .setShareId(shareId)
                .setRelativePath(relativePath == null ? "" : relativePath)
                .setPreviewMaxBytes(maxBytes)
                .setAuthorizationToken(authorizationToken == null ? "" : authorizationToken)
                .setTimeoutMs(timeoutMs)
                .setClientTimestampUtcMs(System.currentTimeMillis())
                .build();

        return sendRequestAsync(request, timeoutMs);
    }

    /**
     * Requests inspection of an archive file.
     */
    public CompletableFuture<AccessResponse> inspectArchiveAsync(
            String shareId,
            String relativePath,
            String authorizationToken,
            long timeoutMs
    ) {
        AccessRequest request = AccessRequest.newBuilder()
                .setRequestId(generateRequestId())
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(targetPeerId).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT)
                .setShareId(shareId)
                .setRelativePath(relativePath == null ? "" : relativePath)
                .setAuthorizationToken(authorizationToken == null ? "" : authorizationToken)
                .setTimeoutMs(timeoutMs)
                .setClientTimestampUtcMs(System.currentTimeMillis())
                .build();

        return sendRequestAsync(request, timeoutMs);
    }

    /**
     * Requests on-demand retrieval of a remote file within an authorized share.
     */
    public CompletableFuture<AccessResponse> retrieveFileAsync(
            String shareId,
            String relativePath,
            int maxBytes,
            String authorizationToken,
            long timeoutMs
    ) {
        AccessRequest request = AccessRequest.newBuilder()
                .setRequestId(generateRequestId())
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .setTargetPeerId(PeerId.newBuilder().setValue(targetPeerId).build())
                .setRequestType(AccessRequestType.ACCESS_REQUEST_TYPE_DOWNLOAD)
                .setShareId(shareId)
                .setRelativePath(relativePath == null ? "" : relativePath)
                .setPreviewMaxBytes(maxBytes)
                .setAuthorizationToken(authorizationToken == null ? "" : authorizationToken)
                .setTimeoutMs(timeoutMs)
                .setClientTimestampUtcMs(System.currentTimeMillis())
                .build();

        return sendRequestAsync(request, timeoutMs);
    }

    /**
     * Cancels an ongoing access request.
     */
    public CompletableFuture<AccessCancelResponse> cancelAsync(String targetRequestId, String reason) {
        AccessCancelRequest cancelReq = AccessCancelRequest.newBuilder()
                .setRequestId(targetRequestId)
                .setReason(reason == null ? "User cancelled" : reason)
                .setRequesterPeerId(PeerId.newBuilder().setValue(localPeerId).build())
                .build();

        CompletableFuture<AccessCancelResponse> future = new CompletableFuture<>();
        pendingCancels.put(targetRequestId, future);

        AccessWireMessage wire = AccessWireMessage.newBuilder()
                .setCancelRequest(cancelReq)
                .build();

        if (session != null) {
            session.sendPayloadAsync(wire.toByteArray()).exceptionally(ex -> {
                pendingCancels.remove(targetRequestId);
                future.completeExceptionally(ex);
                return null;
            });
        }

        return future;
    }

    /**
     * Sends an AccessRequest over the session wire and awaits response.
     */
    public CompletableFuture<AccessResponse> sendRequestAsync(AccessRequest request, long timeoutMs) {
        CompletableFuture<AccessResponse> future = new CompletableFuture<>();
        pendingRequests.put(request.getRequestId(), future);

        AccessWireMessage wire = AccessWireMessage.newBuilder()
                .setRequest(request)
                .build();

        if (session != null) {
            session.sendPayloadAsync(wire.toByteArray()).exceptionally(ex -> {
                pendingRequests.remove(request.getRequestId());
                future.completeExceptionally(ex);
                return null;
            });
        }

        // Apply timeout if requested
        if (timeoutMs > 0) {
            CompletableFuture.delayedExecutor(timeoutMs, TimeUnit.MILLISECONDS).execute(() -> {
                CompletableFuture<AccessResponse> timedOut = pendingRequests.remove(request.getRequestId());
                if (timedOut != null && !timedOut.isDone()) {
                    timedOut.completeExceptionally(new TimeoutException("Access request timed out after " + timeoutMs + "ms"));
                }
            });
        }

        return future;
    }

    /**
     * Dispatches an incoming response manually (useful for direct in-memory wiring/testing).
     */
    public void dispatchIncomingResponse(AccessResponse response) {
        CompletableFuture<AccessResponse> future = pendingRequests.remove(response.getRequestId());
        if (future != null) {
            future.complete(response);
        }
    }

    /**
     * Fails all pending requests on disconnect.
     */
    public void onSessionClosed(String reason) {
        for (CompletableFuture<AccessResponse> future : pendingRequests.values()) {
            future.completeExceptionally(new IOException("Session closed: " + reason));
        }
        pendingRequests.clear();
        for (CompletableFuture<AccessCancelResponse> future : pendingCancels.values()) {
            future.completeExceptionally(new IOException("Session closed: " + reason));
        }
        pendingCancels.clear();
    }

    private String generateRequestId() {
        return "acc_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }
}
