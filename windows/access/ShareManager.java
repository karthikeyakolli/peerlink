package org.peerlink.core.access;

import org.peerlink.protocol.v1.AccessScope;

import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages registered local shares and issues/validates access grants for remote peers.
 */
public final class ShareManager {

    private final Map<String, ShareDefinition> activeShares = new ConcurrentHashMap<>();

    public void registerShare(ShareDefinition share) {
        if (share == null) throw new IllegalArgumentException("share cannot be null");
        activeShares.put(share.shareId(), share);
    }

    public void unregisterShare(String shareId) {
        if (shareId != null) {
            activeShares.remove(shareId);
        }
    }

    public Optional<ShareDefinition> getShare(String shareId) {
        if (shareId == null) return Optional.empty();
        return Optional.ofNullable(activeShares.get(shareId));
    }

    public List<ShareDefinition> getAllShares() {
        return new ArrayList<>(activeShares.values());
    }

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

    /**
     * Validates an incoming request or token against the target share.
     */
    public ValidationResult validateAccess(
            String shareId,
            String requesterPeerId,
            AccessScope requestedScope,
            String authorizationToken
    ) {
        ShareDefinition share = activeShares.get(shareId);
        if (share == null) {
            return ValidationResult.rejected(ValidationResult.RejectReason.SHARE_NOT_FOUND, "Share does not exist: " + shareId);
        }

        long now = System.currentTimeMillis();
        if (share.isExpired(now)) {
            return ValidationResult.rejected(ValidationResult.RejectReason.SHARE_EXPIRED, "Share has expired: " + shareId);
        }

        // Check if peer is in allowed list
        if (!share.isPeerPermitted(requesterPeerId)) {
            return ValidationResult.rejected(ValidationResult.RejectReason.PEER_NOT_ALLOWED, "Peer is not authorized for this share: " + requesterPeerId);
        }

        // Check if share globally permits this scope
        if (!share.allowsScope(requestedScope)) {
            return ValidationResult.rejected(ValidationResult.RejectReason.SCOPE_NOT_ALLOWED, "Scope is not permitted on this share: " + requestedScope);
        }

        // If an explicit authorization token is supplied, validate its signature and bounds
        if (authorizationToken != null && !authorizationToken.isBlank()) {
            Optional<AccessGrant> parsedOpt = AccessGrant.parseToken(authorizationToken);
            if (parsedOpt.isEmpty()) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INVALID_TOKEN, "Authorization token is malformed");
            }
            AccessGrant grant = parsedOpt.get();
            if (!shareId.equals(grant.shareId())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_SHARE_MISMATCH, "Token was issued for another share: " + grant.shareId());
            }
            if (!requesterPeerId.equals(grant.requesterPeerId())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_PEER_MISMATCH, "Token was issued to another peer: " + grant.requesterPeerId());
            }
            if (grant.isExpired(now)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.TOKEN_EXPIRED, "Authorization token has expired");
            }
            if (!grant.verifySignature(share.authSecret())) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INVALID_SIGNATURE, "Cryptographic token signature verification failed");
            }
            if (!grant.hasScope(requestedScope)) {
                return ValidationResult.rejected(ValidationResult.RejectReason.INSUFFICIENT_SCOPE, "Token does not grant required scope: " + requestedScope);
            }
        }

        return ValidationResult.authorized(share);
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
            PEER_NOT_ALLOWED,
            SCOPE_NOT_ALLOWED,
            INVALID_TOKEN,
            TOKEN_SHARE_MISMATCH,
            TOKEN_PEER_MISMATCH,
            TOKEN_EXPIRED,
            INVALID_SIGNATURE,
            INSUFFICIENT_SCOPE
        }

        public static ValidationResult authorized(ShareDefinition share) {
            return new ValidationResult(true, share, RejectReason.NONE, null);
        }

        public static ValidationResult rejected(RejectReason reason, String message) {
            return new ValidationResult(false, null, reason, message);
        }
    }
}
