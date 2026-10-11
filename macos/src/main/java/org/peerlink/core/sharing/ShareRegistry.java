package org.peerlink.core.sharing;

import org.peerlink.protocol.v1.ShareAuditEvent;
import org.peerlink.protocol.v1.SharePermission;
import org.peerlink.protocol.v1.ShareStatus;
import org.peerlink.protocol.v1.ShareType;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Central registry managing the full lifecycle of shares on the owner device.
 * The owner's device is the sole authority. If the owner is offline, shares are unavailable.
 */
public final class ShareRegistry {

    private final Map<String, ShareObject> shares = new ConcurrentHashMap<>();
    private final Map<String, ShareRevocationRecord> revocations = new ConcurrentHashMap<>();
    private final Map<String, OneTimeConsumptionTracker> oneTimeTrackers = new ConcurrentHashMap<>();
    private final Map<String, ShareApprovalState> approvalStates = new ConcurrentHashMap<>();
    private final ShareAuditJournal auditJournal;

    public ShareRegistry(ShareAuditJournal auditJournal) {
        this.auditJournal = Objects.requireNonNull(auditJournal, "auditJournal");
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    public ShareObject createShare(ShareObject share) {
        Objects.requireNonNull(share, "share");
        shares.put(share.shareId(), share);
        revocations.put(share.shareId(), new ShareRevocationRecord());
        if (share.oneTime()) {
            oneTimeTrackers.put(share.shareId(), new OneTimeConsumptionTracker());
        }
        approvalStates.put(share.shareId(), new ShareApprovalState(share.shareId()));
        auditJournal.log(share.shareId(), share.ownerPeerId(), ShareAuditEvent.SHARE_AUDIT_CREATED, "", "Share created: " + share.displayLabel());
        return share;
    }

    public Optional<ShareObject> getShare(String shareId) {
        if (shareId == null) return Optional.empty();
        return Optional.ofNullable(shares.get(shareId));
    }

    public List<ShareObject> getAllShares() { return new ArrayList<>(shares.values()); }

    public void removeShare(String shareId) {
        shares.remove(shareId);
        revocations.remove(shareId);
        oneTimeTrackers.remove(shareId);
        approvalStates.remove(shareId);
    }

    // ── Capability issuance ──────────────────────────────────────────────────

    public ShareCapability issueCapability(String shareId, String requesterPeerId,
            Set<SharePermission> permissions, long validityMs) {
        ShareObject share = requireShare(shareId);
        long now = System.currentTimeMillis();
        long expiresAt = validityMs > 0 ? now + validityMs : 0;
        ShareCapability cap = ShareCapability.issue(shareId, share.shareType(), permissions, now, expiresAt, requesterPeerId, share.authSecret());
        auditJournal.log(shareId, requesterPeerId, ShareAuditEvent.SHARE_AUDIT_CAPABILITY_ISSUED, "", "Capability issued to peer: " + requesterPeerId);
        return cap;
    }

    public ShareCapability issueOneTimeCapability(String shareId, String requesterPeerId,
            Set<SharePermission> permissions, long validityMs, String operationId) {
        ShareObject share = requireShare(shareId);
        if (!share.oneTime()) throw new IllegalStateException("Share is not one-time: " + shareId);
        long now = System.currentTimeMillis();
        long expiresAt = validityMs > 0 ? now + validityMs : 0;
        ShareCapability cap = ShareCapability.issueOneTime(shareId, share.shareType(), permissions, now, expiresAt, requesterPeerId, operationId, share.authSecret());
        auditJournal.log(shareId, requesterPeerId, ShareAuditEvent.SHARE_AUDIT_CAPABILITY_ISSUED, operationId, "One-time capability issued");
        return cap;
    }

    public ShareCapability issueGuestCapability(String shareId, Set<SharePermission> permissions, long validityMs) {
        ShareObject share = requireShare(shareId);
        if (!share.guestAllowed()) throw new IllegalStateException("Guest access not permitted on share: " + shareId);
        long now = System.currentTimeMillis();
        long expiresAt = validityMs > 0 ? now + validityMs : 0;
        ShareCapability cap = ShareCapability.issueGuest(shareId, permissions, now, expiresAt, share.authSecret());
        auditJournal.log(shareId, "GUEST", ShareAuditEvent.SHARE_AUDIT_GUEST_ACCESS, "", "Guest capability issued");
        return cap;
    }

    // ── Authorization ────────────────────────────────────────────────────────

    public AuthorizationDecision authorizeUse(String token, String requesterPeerId,
            SharePermission permission, String operationId, long operationStartedAtUtcMs) {
        long now = System.currentTimeMillis();

        Optional<ShareCapability> capOpt = ShareCapability.fromToken(token);
        if (capOpt.isEmpty()) {
            return AuthorizationDecision.reject(RejectReason.INVALID_TOKEN, "Capability token is malformed or unreadable");
        }
        ShareCapability cap = capOpt.get();

        ShareObject share = shares.get(cap.shareId());
        if (share == null) {
            return AuthorizationDecision.reject(RejectReason.SHARE_NOT_FOUND, "Share does not exist: " + cap.shareId());
        }

        if (!cap.verifySignature(share.authSecret())) {
            auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "Signature verification failed");
            return AuthorizationDecision.reject(RejectReason.INVALID_SIGNATURE, "Capability token signature verification failed");
        }

        ShareRevocationRecord rev = revocations.get(cap.shareId());
        if (rev != null && rev.isRevoked()) {
            boolean graceAllowed = (operationStartedAtUtcMs > 0) && rev.isActiveOperationPermitted(now);
            if (!graceAllowed) {
                auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "Share is revoked: " + rev.getRevokeReason());
                return AuthorizationDecision.reject(RejectReason.SHARE_REVOKED, "Share has been revoked: " + rev.getRevokeReason());
            }
        }

        if (share.isExpired(now)) {
            boolean graceAllowed = (operationStartedAtUtcMs > 0) && share.isActiveOperationAllowed(now, operationStartedAtUtcMs);
            if (!graceAllowed) {
                auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_EXPIRED, operationId, "Share expired");
                return AuthorizationDecision.reject(RejectReason.SHARE_EXPIRED, "Share has expired");
            }
        }

        if (cap.isExpired(now)) {
            auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "Token expired");
            return AuthorizationDecision.reject(RejectReason.TOKEN_EXPIRED, "Capability token has expired");
        }

        if (cap.isGuestToken()) {
            if (requesterPeerId != null && !requesterPeerId.isBlank() && !requesterPeerId.equalsIgnoreCase("GUEST")) {
                return AuthorizationDecision.reject(RejectReason.GUEST_IDENTITY_VIOLATION, "Guest token cannot bind a trusted peer identity");
            }
        } else {
            if (!cap.boundPeerId().isBlank() && !cap.boundPeerId().equals(requesterPeerId)) {
                auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "Token bound to different peer: " + cap.boundPeerId());
                return AuthorizationDecision.reject(RejectReason.PEER_MISMATCH, "Capability token was issued to a different peer");
            }
            if (!share.guestAllowed() && !cap.isGuestToken()) {
                if (!share.isPeerAllowed(requesterPeerId)) {
                    auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "Peer not in allowed list: " + requesterPeerId);
                    return AuthorizationDecision.reject(RejectReason.PEER_NOT_ALLOWED, "Peer is not in the share allowed list: " + requesterPeerId);
                }
            }
        }

        if (!cap.hasPermission(permission)) {
            auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "Insufficient permission: " + permission);
            return AuthorizationDecision.reject(RejectReason.INSUFFICIENT_PERMISSION, "Token does not carry required permission: " + permission);
        }

        if (share.oneTime()) {
            OneTimeConsumptionTracker tracker = oneTimeTrackers.get(cap.shareId());
            if (tracker != null) {
                if (!tracker.isOperationPermitted(operationId)) {
                    auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_REJECTED, operationId, "One-time share already consumed by: " + tracker.getConsumedByOperationId());
                    return AuthorizationDecision.reject(RejectReason.ONE_TIME_CONSUMED, "One-time share already consumed; retries of original operation " + tracker.getConsumedByOperationId() + " only");
                }
                if (tracker.isConsumed() && operationId.equals(tracker.getConsumedByOperationId())) {
                    auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_OPERATION_RETRY, operationId, "Retry of same operation permitted");
                }
            }
        }

        auditJournal.log(cap.shareId(), requesterPeerId, ShareAuditEvent.SHARE_AUDIT_ACCESS_AUTHORIZED, operationId, "Access authorized: " + permission);
        return AuthorizationDecision.authorized(cap, share);
    }

    public boolean markOneTimeConsumed(String shareId, String operationId) {
        OneTimeConsumptionTracker tracker = oneTimeTrackers.get(shareId);
        if (tracker == null) return false;
        boolean accepted = tracker.markConsumed(operationId, System.currentTimeMillis());
        if (accepted) auditJournal.log(shareId, "", ShareAuditEvent.SHARE_AUDIT_CONSUMED, operationId, "One-time share consumed");
        return accepted;
    }

    // ── Revocation ───────────────────────────────────────────────────────────

    public void revokeShare(String shareId, String reason, long operationStartedAtUtcMs) {
        ShareObject share = shares.get(shareId);
        if (share == null) throw new IllegalArgumentException("Share not found: " + shareId);
        long now = System.currentTimeMillis();
        ShareRevocationRecord rev = revocations.computeIfAbsent(shareId, id -> new ShareRevocationRecord());
        rev.revoke(now, reason, share.gracePeriodMs(), operationStartedAtUtcMs);
        auditJournal.log(shareId, share.ownerPeerId(), ShareAuditEvent.SHARE_AUDIT_REVOKED, "", "Revoked: " + reason);
    }

    public boolean isRevoked(String shareId) {
        ShareRevocationRecord rev = revocations.get(shareId);
        return rev != null && rev.isRevoked();
    }

    // ── Status ───────────────────────────────────────────────────────────────

    public ShareStatus getStatus(String shareId) {
        ShareObject share = shares.get(shareId);
        if (share == null) return ShareStatus.SHARE_STATUS_UNSPECIFIED;
        long now = System.currentTimeMillis();
        ShareRevocationRecord rev = revocations.get(shareId);
        if (rev != null && rev.isRevoked()) return ShareStatus.SHARE_STATUS_REVOKED;
        OneTimeConsumptionTracker tracker = oneTimeTrackers.get(shareId);
        if (tracker != null && tracker.isConsumed()) return ShareStatus.SHARE_STATUS_CONSUMED;
        if (share.isExpired(now)) return ShareStatus.SHARE_STATUS_EXPIRED;
        return ShareStatus.SHARE_STATUS_ACTIVE;
    }

    // ── UI Approval State ────────────────────────────────────────────────────

    public ShareApprovalState getApprovalState(String shareId) {
        return approvalStates.getOrDefault(shareId, new ShareApprovalState(shareId));
    }

    public void approveShare(String shareId) {
        approvalStates.computeIfAbsent(shareId, ShareApprovalState::new).approve();
    }

    public void denyShare(String shareId, String reason) {
        approvalStates.computeIfAbsent(shareId, ShareApprovalState::new).deny(reason);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private ShareObject requireShare(String shareId) {
        ShareObject s = shares.get(shareId);
        if (s == null) throw new IllegalArgumentException("Share does not exist: " + shareId);
        return s;
    }
}