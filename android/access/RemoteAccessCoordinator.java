package org.peerlink.core.access;

import com.google.protobuf.ByteString;
import org.peerlink.protocol.v1.*;

import java.io.IOException;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Main coordinator handling incoming Remote Access protocol requests.
 *
 * <p>Enforces:
 * <ul>
 *   <li>Authorization and capability token verification.</li>
 *   <li>Path traversal and symlink escape rejection.</li>
 *   <li>Safe preview rules (rejection of executables).</li>
 *   <li>Cooperative cancellation and peer disconnect cleanup.</li>
 *   <li>Comprehensive audit logging for all interactions.</li>
 * </ul>
 */
public final class RemoteAccessCoordinator {

    private final ShareManager shareManager;
    private final RemoteFolderBrowser browser;
    private final RemoteSearchEngine searchEngine;
    private final SafePreviewEngine previewEngine;
    private final ArchiveInspector archiveInspector;
    private final AccessAuditJournal auditJournal;
    private final PathSandboxValidator pathValidator;

    private final Map<String, CancellationToken> activeOperations = new ConcurrentHashMap<>();
    private final Map<String, Set<String>> peerOperations = new ConcurrentHashMap<>();

    public RemoteAccessCoordinator(
            ShareManager shareManager,
            AccessAuditJournal auditJournal
    ) {
        this.shareManager = shareManager;
        this.auditJournal = auditJournal;
        this.pathValidator = new PathSandboxValidator();
        this.browser = new RemoteFolderBrowser(pathValidator);
        this.searchEngine = new RemoteSearchEngine(pathValidator);
        this.previewEngine = new SafePreviewEngine();
        this.archiveInspector = new ArchiveInspector();
    }

    public RemoteAccessCoordinator(
            ShareManager shareManager,
            RemoteFolderBrowser browser,
            RemoteSearchEngine searchEngine,
            SafePreviewEngine previewEngine,
            ArchiveInspector archiveInspector,
            AccessAuditJournal auditJournal,
            PathSandboxValidator pathValidator
    ) {
        this.shareManager = shareManager;
        this.browser = browser;
        this.searchEngine = searchEngine;
        this.previewEngine = previewEngine;
        this.archiveInspector = archiveInspector;
        this.auditJournal = auditJournal;
        this.pathValidator = pathValidator;
    }

    /**
     * Handles an incoming AccessRequest and produces a corresponding AccessResponse.
     */
    public AccessResponse handleAccessRequest(AccessRequest request) {
        long startTime = System.currentTimeMillis();
        String reqId = request.getRequestId();
        String peerId = request.getRequesterPeerId().getValue();
        AccessRequestType reqType = request.getRequestType();
        String shareId = request.getShareId();
        String relPath = request.getRelativePath();

        AccessScope requiredScope = mapRequestTypeToScope(reqType);

        // 1. Authorization validation
        ShareManager.ValidationResult valResult = shareManager.validateAccess(
                shareId,
                peerId,
                requiredScope,
                request.getAuthorizationToken(),
                reqId,
                request.getClientTimestampUtcMs()
        );

        if (!valResult.isAuthorized()) {
            AccessAuditRecord.AuditOutcome outcome = switch (valResult.rejectReason()) {
                case SHARE_EXPIRED, TOKEN_EXPIRED -> AccessAuditRecord.AuditOutcome.REJECTED_EXPIRED;
                case SHARE_REVOKED, TOKEN_REVOKED -> AccessAuditRecord.AuditOutcome.REJECTED_REVOKED;
                case ONE_TIME_CONSUMED -> AccessAuditRecord.AuditOutcome.REJECTED_ONE_TIME_CONSUMED;
                default -> AccessAuditRecord.AuditOutcome.REJECTED_UNAUTHORIZED;
            };
            auditJournal.log(new AccessAuditRecord(
                    startTime, reqId, peerId, reqType, shareId, relPath,
                    request.getSearchQuery(), outcome, 0, 0, valResult.errorMessage()
            ));

            return AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(false)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_UNAUTHORIZED)
                            .setHumanSummary(valResult.errorMessage())
                            .build())
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();
        }

        ShareDefinition share = valResult.share();
        CancellationToken cancellationToken = new CancellationToken();
        activeOperations.put(reqId, cancellationToken);
        peerOperations.computeIfAbsent(peerId, k -> ConcurrentHashMap.newKeySet()).add(reqId);

        try {
            AccessResponse.Builder responseBuilder = AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(true);

            switch (reqType) {
                case ACCESS_REQUEST_TYPE_BROWSE -> {
                    RemoteFolderBrowser.BrowseResult browseResult = browser.browse(
                            share.rootDirectory(),
                            relPath,
                            request.getMaxResults(),
                            request.getPaginationCursor(),
                            cancellationToken
                    );
                    responseBuilder.addAllItems(browseResult.items())
                            .setNextPaginationCursor(browseResult.nextCursor())
                            .setHasMore(browseResult.hasMore())
                            .setTotalMatching(browseResult.totalInDirectory());

                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            null, AccessAuditRecord.AuditOutcome.AUTHORIZED,
                            browseResult.items().size(), 0, "Folder browse successful"
                    ));
                }

                case ACCESS_REQUEST_TYPE_METADATA -> {
                    RemoteObjectReference ref = browser.getMetadata(share.rootDirectory(), relPath);
                    responseBuilder.addItems(ref)
                            .setTotalMatching(1);

                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            null, AccessAuditRecord.AuditOutcome.AUTHORIZED,
                            1, 0, "Metadata retrieved"
                    ));
                }

                case ACCESS_REQUEST_TYPE_SEARCH -> {
                    RemoteSearchEngine.SearchResult searchResult = searchEngine.search(
                            share.rootDirectory(),
                            relPath,
                            request.getSearchQuery(),
                            request.getMaxResults(),
                            request.getMaxDepth(),
                            request.getTimeoutMs(),
                            request.getPaginationCursor(),
                            cancellationToken
                    );
                    responseBuilder.addAllItems(searchResult.matches())
                            .setNextPaginationCursor(searchResult.nextCursor())
                            .setHasMore(searchResult.hasMore())
                            .setTotalMatching(searchResult.totalFound());

                    AccessAuditRecord.AuditOutcome outcome = searchResult.timedOut() ?
                            AccessAuditRecord.AuditOutcome.TIMED_OUT : AccessAuditRecord.AuditOutcome.AUTHORIZED;

                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            request.getSearchQuery(), outcome,
                            searchResult.matches().size(), 0,
                            searchResult.timedOut() ? "Search timed out partially" : "Search completed"
                    ));
                }

                case ACCESS_REQUEST_TYPE_PREVIEW -> {
                    Path targetFile = pathValidator.resolveAndValidate(share.rootDirectory(), relPath);
                    SafePreviewEngine.PreviewResult preview = previewEngine.generatePreview(
                            targetFile,
                            request.getPreviewMaxBytes()
                    );
                    responseBuilder.setPreviewData(ByteString.copyFrom(preview.data()))
                            .setPreviewMimeType(preview.mimeType())
                            .setTotalMatching(1);

                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            null, AccessAuditRecord.AuditOutcome.AUTHORIZED,
                            1, preview.data().length, "Preview generated safely"
                    ));
                }

                case ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT -> {
                    Path archiveFile = pathValidator.resolveAndValidate(share.rootDirectory(), relPath);
                    List<ArchiveEntryDescriptor> entries = archiveInspector.inspectZip(archiveFile);
                    responseBuilder.addAllArchiveEntries(entries)
                            .setTotalMatching(entries.size());

                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            null, AccessAuditRecord.AuditOutcome.AUTHORIZED,
                            entries.size(), 0, "Archive inspected safely"
                    ));
                }

                case ACCESS_REQUEST_TYPE_DOWNLOAD -> {
                    Path targetFile = pathValidator.resolveAndValidate(share.rootDirectory(), relPath);
                    RemoteObjectReference targetRef = browser.getMetadata(share.rootDirectory(), relPath);
                    responseBuilder.addItems(targetRef)
                            .setTotalMatching(1);

                    long transferredBytes = 0;
                    if (java.nio.file.Files.isRegularFile(targetFile)) {
                        int maxBytes = request.getPreviewMaxBytes() > 0 ?
                                request.getPreviewMaxBytes() :
                                BoundedFileReader.DEFAULT_MAX_RETRIEVAL_BYTES;

                        long fileSize = targetRef.getByteSize();
                        if (fileSize <= BoundedFileReader.ABSOLUTE_MAX_RETRIEVAL_BYTES) {
                            BoundedFileReader.ReadResult readResult = BoundedFileReader.readBounded(targetFile, maxBytes);
                            responseBuilder.setPreviewData(ByteString.copyFrom(readResult.data()));
                            transferredBytes = readResult.data().length;

                            if (share.isOneTime() && readResult.isComplete()) {
                                shareManager.markOneTimeConsumed(shareId, reqId);
                            }
                        }
                    }

                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            null, AccessAuditRecord.AuditOutcome.AUTHORIZED,
                            1, transferredBytes > 0 ? transferredBytes : targetRef.getByteSize(),
                            transferredBytes > 0 ? "On-demand bounded retrieval authorized" : "Download reference authorized"
                    ));
                }

                default -> {
                    auditJournal.log(new AccessAuditRecord(
                            startTime, reqId, peerId, reqType, shareId, relPath,
                            null, AccessAuditRecord.AuditOutcome.FAILED,
                            0, 0, "Unrecognized request type: " + reqType
                    ));
                    return AccessResponse.newBuilder()
                            .setRequestId(reqId)
                            .setSuccess(false)
                            .setError(ErrorDetail.newBuilder()
                                    .setCode(ErrorCode.ERROR_CODE_UNSUPPORTED_CAPABILITY)
                                    .setHumanSummary("Unrecognized request type: " + reqType)
                                    .build())
                            .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                            .build();
                }
            }

            return responseBuilder
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();

        } catch (PathSandboxValidator.PathTraversalException e) {
            auditJournal.log(new AccessAuditRecord(
                    startTime, reqId, peerId, reqType, shareId, relPath,
                    request.getSearchQuery(), AccessAuditRecord.AuditOutcome.REJECTED_PATH_TRAVERSAL,
                    0, 0, e.getMessage()
            ));
            return AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(false)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_UNAUTHORIZED)
                            .setHumanSummary("Access denied: " + e.getMessage())
                            .build())
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();

        } catch (SafePreviewEngine.UnsafePreviewException e) {
            auditJournal.log(new AccessAuditRecord(
                    startTime, reqId, peerId, reqType, shareId, relPath,
                    request.getSearchQuery(), AccessAuditRecord.AuditOutcome.REJECTED_UNSAFE_PREVIEW,
                    0, 0, e.getMessage()
            ));
            return AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(false)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_UNAUTHORIZED)
                            .setHumanSummary("Unsafe preview rejected: " + e.getMessage())
                            .build())
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();

        } catch (CancellationToken.OperationCancelledException e) {
            auditJournal.log(new AccessAuditRecord(
                    startTime, reqId, peerId, reqType, shareId, relPath,
                    request.getSearchQuery(), AccessAuditRecord.AuditOutcome.CANCELLED,
                    0, 0, e.getMessage()
            ));
            return AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(false)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_OPERATION_CANCELLED)
                            .setHumanSummary("Operation was cancelled: " + e.getMessage())
                            .build())
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();

        } catch (NoSuchFileException e) {
            auditJournal.log(new AccessAuditRecord(
                    startTime, reqId, peerId, reqType, shareId, relPath,
                    request.getSearchQuery(), AccessAuditRecord.AuditOutcome.FAILED,
                    0, 0, "Target not found: " + e.getMessage()
            ));
            return AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(false)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_OBJECT_NOT_FOUND)
                            .setHumanSummary("Resource not found: " + e.getMessage())
                            .build())
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();

        } catch (Exception e) {
            auditJournal.log(new AccessAuditRecord(
                    startTime, reqId, peerId, reqType, shareId, relPath,
                    request.getSearchQuery(), AccessAuditRecord.AuditOutcome.FAILED,
                    0, 0, "Internal error: " + e.getMessage()
            ));
            return AccessResponse.newBuilder()
                    .setRequestId(reqId)
                    .setSuccess(false)
                    .setError(ErrorDetail.newBuilder()
                            .setCode(ErrorCode.ERROR_CODE_INTERNAL_ERROR)
                            .setHumanSummary("Internal error processing access request: " + e.getMessage())
                            .build())
                    .setExecutionTimeMs(System.currentTimeMillis() - startTime)
                    .build();

        } finally {
            activeOperations.remove(reqId);
            Set<String> set = peerOperations.get(peerId);
            if (set != null) {
                set.remove(reqId);
            }
        }
    }

    /**
     * Handles an incoming cancellation request.
     */
    public AccessCancelResponse handleCancelRequest(AccessCancelRequest cancelRequest) {
        String reqId = cancelRequest.getRequestId();
        CancellationToken token = activeOperations.get(reqId);
        if (token != null) {
            token.cancel(cancelRequest.getReason());
            return AccessCancelResponse.newBuilder()
                    .setRequestId(reqId)
                    .setCancelled(true)
                    .setMessage("Cancellation requested successfully")
                    .build();
        }
        return AccessCancelResponse.newBuilder()
                .setRequestId(reqId)
                .setCancelled(false)
                .setMessage("Operation not found or already completed")
                .build();
    }

    /**
     * Cleans up and aborts in-flight operations when a remote peer disconnects.
     */
    public void onPeerDisconnected(String peerId) {
        if (peerId == null) return;
        Set<String> ops = peerOperations.remove(peerId);
        if (ops != null) {
            for (String reqId : ops) {
                CancellationToken token = activeOperations.get(reqId);
                if (token != null) {
                    token.cancel("Remote peer disconnected: " + peerId);
                }
            }
        }
    }

    public ShareManager getShareManager() {
        return shareManager;
    }

    public AccessAuditJournal getAuditJournal() {
        return auditJournal;
    }

    private static AccessScope mapRequestTypeToScope(AccessRequestType type) {
        return switch (type) {
            case ACCESS_REQUEST_TYPE_BROWSE -> AccessScope.ACCESS_SCOPE_BROWSE;
            case ACCESS_REQUEST_TYPE_METADATA -> AccessScope.ACCESS_SCOPE_READ_METADATA;
            case ACCESS_REQUEST_TYPE_SEARCH -> AccessScope.ACCESS_SCOPE_SEARCH;
            case ACCESS_REQUEST_TYPE_PREVIEW, ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT -> AccessScope.ACCESS_SCOPE_PREVIEW;
            case ACCESS_REQUEST_TYPE_DOWNLOAD -> AccessScope.ACCESS_SCOPE_DOWNLOAD;
            default -> AccessScope.ACCESS_SCOPE_UNSPECIFIED;
        };
    }
}
