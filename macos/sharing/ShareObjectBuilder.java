package org.peerlink.core.sharing;

import org.peerlink.protocol.v1.SharePermission;
import org.peerlink.protocol.v1.ShareType;

import java.util.*;

public final class ShareObjectBuilder {
    private String shareId;
    private String ownerPeerId;
    private ShareType shareType = ShareType.SHARE_TYPE_PEER_SPECIFIC;
    private String displayLabel = "";
    private final Set<String> allowedPeerIds = new HashSet<>();
    private final Set<SharePermission> permissions = new HashSet<>();
    private long createdAtUtcMs = System.currentTimeMillis();
    private long expiresAtUtcMs = 0L;
    private long gracePeriodMs = 30_000L;
    private boolean oneTime = false;
    private boolean guestAllowed = false;
    private String authSecret;

    public static ShareObjectBuilder newShare() { return new ShareObjectBuilder(); }

    public ShareObjectBuilder id(String shareId) { this.shareId = shareId; return this; }
    public ShareObjectBuilder owner(String ownerPeerId) { this.ownerPeerId = ownerPeerId; return this; }
    public ShareObjectBuilder type(ShareType type) { this.shareType = type; return this; }
    public ShareObjectBuilder label(String label) { this.displayLabel = label; return this; }
    public ShareObjectBuilder allowPeer(String peerId) { this.allowedPeerIds.add(peerId); return this; }
    public ShareObjectBuilder allowPeers(Collection<String> peers) { this.allowedPeerIds.addAll(peers); return this; }
    public ShareObjectBuilder permit(SharePermission permission) { this.permissions.add(permission); return this; }
    public ShareObjectBuilder permits(Collection<SharePermission> perms) { this.permissions.addAll(perms); return this; }
    public ShareObjectBuilder expiresAt(long utcMs) { this.expiresAtUtcMs = utcMs; return this; }
    public ShareObjectBuilder expiresInMs(long durationMs) { this.expiresAtUtcMs = System.currentTimeMillis() + durationMs; return this; }
    public ShareObjectBuilder gracePeriodMs(long ms) { this.gracePeriodMs = ms; return this; }
    public ShareObjectBuilder oneTime() { this.oneTime = true; return this; }
    public ShareObjectBuilder guestAllowed() { this.guestAllowed = true; return this; }
    public ShareObjectBuilder secret(String secret) { this.authSecret = secret; return this; }

    public ShareObject build() {
        if (shareId == null) shareId = "share_" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        if (authSecret == null) authSecret = UUID.randomUUID().toString();
        return new ShareObject(shareId, ownerPeerId, shareType, displayLabel,
                Collections.unmodifiableSet(new HashSet<>(allowedPeerIds)),
                Collections.unmodifiableSet(new HashSet<>(permissions)),
                createdAtUtcMs, expiresAtUtcMs, gracePeriodMs, oneTime, guestAllowed, authSecret);
    }
}