package org.peerlink.core.access;

import org.peerlink.protocol.v1.AccessRequestType;

/**
 * Audit log entry for an access request from a remote peer.
 */
public record AccessAuditRecord(
        long timestampUtcMs,
        String requestId,
        String requesterPeerId,
        AccessRequestType requestType,
        String shareId,
        String targetPath,
        String searchQuery,
        AuditOutcome outcome,
        int itemsReturned,
        long bytesTransferred,
        String detailMessage
) {
    public enum AuditOutcome {
        AUTHORIZED,
        REJECTED_UNAUTHORIZED,
        REJECTED_EXPIRED,
        REJECTED_REVOKED,
        REJECTED_ONE_TIME_CONSUMED,
        REJECTED_PATH_TRAVERSAL,
        REJECTED_UNSAFE_PREVIEW,
        CANCELLED,
        TIMED_OUT,
        FAILED
    }
}
