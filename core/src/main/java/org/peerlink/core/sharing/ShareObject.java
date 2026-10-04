package org.peerlink.core.sharing;

import org.peerlink.protocol.v1.SharePermission;
import org.peerlink.protocol.v1.ShareType;

import java.util.*;

/**
 * Immutable definition of a share created by the local owner.
 *
 * <p>Invariants:
 * <ul>
 *   <li>authSecret is never exposed externally; it signs capability tokens.</li>
 *   <li>A share is unavailable when the owner is offline (no cloud relay for data).</li>
 *   <li>expiresAtUtcMs == 0 means no expiry.</li>
 *   <li>oneTime == true: capability is consumed after first successful complete operation.</li>
 *   <li>guestAllowed == true: isolated, untrusted guest path — no trusted-identity privileges.</li>
 * </ul>
 */
public record ShareObject(
        String shareId,
        String ownerPeerId,
        ShareType shareType,
        String displayLabel,
        Set<String> allowedPeerIds,
        Set<SharePermission> permissions,
        long createdAtUtcMs,
        long expiresAtUtcMs,
        long gracePeriodMs,
        boolean oneTime,
        boolean guestAllowed,
        String authSecret
) {
    public ShareObject {
        if (shareId == null || shareId.isBlank()) throw new IllegalArgumentException("shareId cannot be blank");
        if (ownerPeerId == null || ownerPeerId.isBlank()) throw new IllegalArgumentException("ownerPeerId cannot be blank");
        if (authSecret == null || authSecret.isBlank()) throw new IllegalArgumentException("authSecret cannot be blank");
        if (shareType == null) shareType = ShareType.SHARE_TYPE_PEER_SPECIFIC;
        allowedPeerIds = allowedPeerIds == null ? Set.of() : Collections.unmodifiableSet(new HashSet<>(allowedPeerIds));
        permissions = permissions == null ? Set.of() : Collections.unmodifiableSet(new HashSet<>(permissions));
    }

    public boolean isExpired(long nowUtcMs) {
        return expiresAtUtcMs > 0 && nowUtcMs > expiresAtUtcMs;
    }

    public boolean isNewOperationAllowed(long nowUtcMs) {
        return !isExpired(nowUtcMs);
    }

    public boolean isActiveOperationAllowed(long nowUtcMs, long operationStartedAtUtcMs) {
        if (!isExpired(nowUtcMs)) return true;
        if (gracePeriodMs <= 0) return false;
        return nowUtcMs <= (operationStartedAtUtcMs + gracePeriodMs);
    }

    public boolean isPeerAllowed(String peerId) {
        if (allowedPeerIds.isEmpty()) return false;
        return allowedPeerIds.contains(peerId);
    }

    public boolean hasPermission(SharePermission permission) {
        return permissions.contains(SharePermission.SHARE_PERMISSION_DOWNLOAD)
                || permissions.contains(permission);
    }
}