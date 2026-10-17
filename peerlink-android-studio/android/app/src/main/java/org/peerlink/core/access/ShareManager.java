package org.peerlink.core.access;

import org.peerlink.core.sharing.OneTimeConsumptionTracker;
import org.peerlink.core.sharing.ShareCapability;
import org.peerlink.core.sharing.ShareRevocationRecord;
import org.peerlink.protocol.v1.AccessScope;
import org.peerlink.protocol.v1.SharePermission;

import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages registered local shares and enforces authoritative access validation on the Local Node.
 *
 * <p>Authoritative Invariants:
 * <ul>
 *   <li>The Local Node enforces authorization on every single operation.</li>
 *   <li>Being a previously trusted paired peer NEVER grants automatic access to local files.</li>
 *   <li>Supports time-bounded expiration and explicit owner revocation with grace periods.</li>
 *   <li>Supports one-time shares with idempotent operation retries and rejection of new operations.</li>
 *   <li>Accepts both AccessGrant tokens and ShareCapability tokens.</li>
 * </ul>
 */
public final class ShareManager {

    private final Map<String, ShareDefinition> activeShares = new ConcurrentHashMap<>();
    private final Map<String, ShareRevocationRecord> revocations = new ConcurrentHashMap<>();
    private final Map<String, OneTimeConsumptionTracker> oneTimeTrackers = new ConcurrentHashMap<>();

    public void registerShare(ShareDefinition share) {
        if (share == null) throw new IllegalArgumentException("share cannot be null");
        activeShares.put(share.shareId(), share);
        revocations.put(share.shareId(), new ShareRevocationRecord());
        if (share.isOneTime()) {
            oneTimeTrackers.put(share.shareId(), new OneTimeConsumptionTracker());
        }
    }

    public void unregisterShare(String shareId) {
        if (shareId != null) {
            activeShares.remove(shareId);
            revocations.remove(shareId);
            oneTimeTrackers.remove(shareId);
        }
    }

    public Optional<ShareDefinition> getShare(String shareId) {
        if (shareId == null) return Optional.empty();
        return Optional.ofNullable(activeShares.get(shareId));
    }

    public List<ShareDefinition> getAllShares() {
        return new ArrayList<>(activeShares.values());
    }

    // ── Revocation ───────────────────────────────────────────────────────────

    public void revokeShare(String shareId, String reason, long operationStartedAtUtcMs) {
        ShareDefinition share = activeShares.get(shareId);
        if (share == null) throw new IllegalArgumentException("Share does not exist: " + shareId);
        long now = System.currentTimeMillis();
        ShareRevocationRecord rev = revocations.computeIfAbsent(shareId, id -> new ShareRevocationRecord());
        rev.revoke(now, reason, share.gracePeriodMs(), operationStartedAtUtcMs);
    }

    public void revokeShare(String shareId, String reason) {
        revokeShare(shareId, reason, 0L);
    }

    public boolean isRevoked(String shareId) {
        ShareRevocationRecord rev = revocations.get(shareId);
        return rev != null && rev.isRevoked();
    }

    public Optional<String> getRevocationReason(String shareId) {
        ShareRevocationRecord rev = revocations.get(shareId);
        if (rev != null && rev.isRevoked()) {
            return Optional.ofNullable(rev.getRevokeReason());
        }
        return Optional.empty();
    }

    // ── One-Time Consumption ─────────────────────────────────────────────────

    public boolean markOneTimeConsumed(String shareId, String operationId) {
        OneTimeConsumptionTracker tracker = oneTimeTrackers.computeIfAbsent(shareId, id -> new OneTimeConsumptionTracker());
        return tracker.markConsumed(operationId, System.currentTimeMillis());
    }

    public boolean isOneTimeConsumed(String shareId) {
        OneTimeConsumptionTracker tracker = oneTimeTrackers.get(shareId);
        return tracker != null && tracker.isConsumed();
    }

    public Optional<String> getConsumedByOperationId(String shareId) {
        OneTimeConsumptionTracker tracker = oneTimeTrackers.get(shareId);
        if (tracker != null && tracker.isConsumed()) {
            return Optional.ofNullable(tracker.getConsumedByOperationId());
        }
        return Optional.empty();
    }

    // ── Grant Issuance ───────────────────────────────────────────────────────

    /**
     * Issues an authorized AccessGrant for a remote peer on a specific share.
     */
    public AccessGrant issueGrant(
            String shareId,
            String requesterPeerId,
            Set<AccessScope> scopes,
            long validityDurationMs
    ) {
        ShareDefinition share = activeShares.get(shareId);
        if (share == null) {
            throw new IllegalArgumentException("Share does not exist: " + shareId);
        }
        if (!share.isPeerPermitted(requesterPeerId)) {
            throw new IllegalStateException("Peer is not permitted on share " + shareId + ": " + requesterPeerId);
        }

        long now = System.currentTimeMillis();
        long expiresAt = validityDurationMs > 0 ? now + validityDurationMs : 0;
        String grantId = "grant_" + UUID.randomUUID().toString().substring(0, 8);

        return AccessGrant.issue(
                grantId,
                shareId,
                requesterPeerId,
                scopes,
                now,
                expiresAt,
                share.authSecret()
        );
    }

    // ── Authorization Validation ─────────────────────────────────────────────

    public ValidationResult validateAccess(
            String shareId,
            String requesterPeerId,
            AccessScope requestedScope,
            String authorizationToken
    ) {
        return validateAccess(shareId, requesterPeerId, requestedScope, authorizationToken, null, 0L);
    }

    public ValidationResult validateAccess(
            String shareId,
            String requesterPeerId,
            AccessScope requestedScope,
            String authorizationToken,
            String operationId,
            long operationStartedAtUtcMs
    ) {
        ShareDefinition share = activeShares.get(shareId);
        if (share == null) {
            return ValidationResult.rejected(ValidationResult.RejectReason.SHARE_NOT_FOUND, "Share does not exist: " + shareId);
        }

        long now = System.currentTimeMillis();

        // 1. Check Revocation
        ShareRevocationRecord rev = revocations.get(shareId);
        if (rev != null && rev.isRevoked()) {
            boolean graceAllowed = (operationStartedAtUtcMs > 0) && rev.isActiveOperationPermitted(now);
            if (!graceAllowed) {
                return ValidationResult.rejected(ValidationResult.RejectReason.SHARE_REVOKED,
                        "Share has been revoked: " + rev.getRevokeReason());
            }
        }

        // 2. Check Expiration
        if (share.isExpired(now)) {
            boolean graceAllowed = (operationStartedAtUtcMs > 0) && share.isActiveOperationAllowed(now, operationStartedAtUtcMs);
            if (!graceAllowed) {
                return ValidationResult.rejected(ValidationResult.RejectReason.SHARE_EXPIRED,
                        "Share has expired: " + shareId);
            }
        }

        // 3. Check One-time consumption at share level
        if (share.isOneTime()) {
            OneTimeConsumptionTracker tracker = oneTimeTrackers.get(shareId);
            if (tracker != null) {
                if (!tracker.isOperationPermitted(operationId)) {
                    return ValidationResult.rejected(ValidationResult.RejectReason.ONE_TIME_CONSUMED,
                            "One-time share already consumed by operation: " + tracker.getConsumedByOperationId());
                }
            }
        }

        // 4. Token requirement check
        boolean hasToken = authorizationToken != null && !authorizationToken.isBlank();
        if (share.requireToken() && !hasToken) {
            return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_REQUIRED,
                    "Cryptographic capability token is required to access share: " + shareId);
        }

        // 5. If no token provided (and not required), check static permission list
        if (!hasToken) {
            if (!share.isPeerPermitted(requesterPeerId)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.PEER_NOT_ALLOWED,
                        "Peer is not authorized for this share: " + requesterPeerId);
            }
            if (!share.allowsScope(requestedScope)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.SCOPE_NOT_ALLOWED,
                        "Scope is not permitted on this share: " + requestedScope);
            }
            return ValidationResult.authorized(share);
        }

        // 6. Token provided: validate token cryptographically
        // Try AccessGrant format first
        Optional<AccessGrant> accessGrantOpt = AccessGrant.parseToken(authorizationToken);
        if (accessGrantOpt.isPresent()) {
            AccessGrant grant = accessGrantOpt.get();
            if (!shareId.equals(grant.shareId())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_SHARE_MISMATCH,
                        "Token was issued for another share: " + grant.shareId());
            }
            if (!requesterPeerId.equals(grant.requesterPeerId())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_PEER_MISMATCH,
                        "Token was issued to another peer: " + grant.requesterPeerId());
            }
            if (grant.isExpired(now)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_EXPIRED,
                        "Authorization token has expired");
            }
            if (!grant.verifySignature(share.authSecret())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INVALID_SIGNATURE,
                        "Cryptographic token signature verification failed");
            }
            if (!grant.hasScope(requestedScope)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INSUFFICIENT_SCOPE,
                        "Token does not grant required scope: " + requestedScope);
            }
            return ValidationResult.authorized(share);
        }

        // Try ShareCapability format
        Optional<ShareCapability> shareCapOpt = ShareCapability.fromToken(authorizationToken);
        if (shareCapOpt.isPresent()) {
            ShareCapability cap = shareCapOpt.get();
            if (!shareId.equals(cap.shareId())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_SHARE_MISMATCH,
                        "Capability token was issued for another share: " + cap.shareId());
            }
            if (!cap.verifySignature(share.authSecret())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INVALID_SIGNATURE,
                        "Capability token signature verification failed");
            }
            if (cap.isExpired(now)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_EXPIRED,
                        "Capability token has expired");
            }

            // Identity check
            if (cap.isGuestToken()) {
                if (!share.guestAllowed()) {
                    return ValidationResult.rejected(ValidationResult.RejectReason.GUEST_NOT_ALLOWED,
                            "Guest access is not permitted on this share");
                }
                if (requesterPeerId != null && !requesterPeerId.isBlank() && !requesterPeerId.equalsIgnoreCase("GUEST")) {
                    return ValidationResult.rejected(ValidationResult.RejectReason.GUEST_IDENTITY_VIOLATION,
                            "Guest token cannot bind a trusted peer identity");
                }
            } else {
                if (!cap.boundPeerId().isBlank() && !cap.boundPeerId().equals(requesterPeerId)) {
                    return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_PEER_MISMATCH,
                            "Capability token was issued to a different peer: " + cap.boundPeerId());
                }
                if (!share.isPeerPermitted(requesterPeerId)) {
                    return ValidationResult.rejected(ValidationResult.RejectReason.PEER_NOT_ALLOWED,
                            "Peer is not in allowed list for share: " + requesterPeerId);
                }
            }

            // Scope check
            SharePermission requiredPerm = mapScopeToPermission(requestedScope);
            if (!cap.hasPermission(requiredPerm)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INSUFFICIENT_SCOPE,
                        "Capability token does not grant permission: " + requiredPerm);
            }

            // One-time capability check
            if (cap.isOneTime()) {
                OneTimeConsumptionTracker tracker = oneTimeTrackers.computeIfAbsent(shareId, id -> new OneTimeConsumptionTracker());
                String effectiveOpId = (operationId != null && !operationId.isBlank()) ? operationId : cap.operationId();
                if (!tracker.isOperationPermitted(effectiveOpId)) {
                    return ValidationResult.rejected(ValidationResult.RejectReason.ONE_TIME_CONSUMED,
                            "One-time capability already consumed by operation: " + tracker.getConsumedByOperationId());
                }
            }

            return ValidationResult.authorized(share);
        }

        return ValidationResult.rejected(ValidationResult.RejectReason.INVALID_TOKEN, "Authorization token is malformed");
    }

    private static SharePermission mapScopeToPermission(AccessScope scope) {
        return switch (scope) {
            case ACCESS_SCOPE_BROWSE, ACCESS_SCOPE_READ_METADATA -> SharePermission.SHARE_PERMISSION_BROWSE;
            case ACCESS_SCOPE_SEARCH -> SharePermission.SHARE_PERMISSION_SEARCH;
            case ACCESS_SCOPE_PREVIEW -> SharePermission.SHARE_PERMISSION_PREVIEW;
            case ACCESS_SCOPE_DOWNLOAD -> SharePermission.SHARE_PERMISSION_DOWNLOAD;
            default -> SharePermission.SHARE_PERMISSION_UNSPECIFIED;
        };
    }

    public record ValidationResult(
            boolean isAuthorized,
            ShareDefinition share,
            RejectReason rejectReason,
            String errorMessage
    ) {
        public enum RejectReason {
            NONE,
            SHARE_NOT_FOUND,
            SHARE_EXPIRED,
            SHARE_REVOKED,
            PEER_NOT_ALLOWED,
            SCOPE_NOT_ALLOWED,
            TOKEN_REQUIRED,
            INVALID_TOKEN,
            TOKEN_SHARE_MISMATCH,
            TOKEN_PEER_MISMATCH,
            TOKEN_EXPIRED,
            TOKEN_REVOKED,
            INVALID_SIGNATURE,
            INSUFFICIENT_SCOPE,
            ONE_TIME_CONSUMED,
            GUEST_NOT_ALLOWED,
            GUEST_IDENTITY_VIOLATION
        }

        public static ValidationResult authorized(ShareDefinition share) {
            return new ValidationResult(true, share, RejectReason.NONE, null);
        }

        public static ValidationResult rejected(RejectReason reason, String message) {
            return new ValidationResult(false, null, reason, message);
        }
    }
}
