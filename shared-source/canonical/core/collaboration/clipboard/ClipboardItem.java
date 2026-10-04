package org.peerlink.core.collaboration.clipboard;

import org.peerlink.core.model.ContentHash;

import java.io.Serializable;
import java.util.Objects;

/**
 * Ephemeral clipboard content representation.
 * Invariant: Transient in-memory only. Must NOT be persisted in normal history or diagnostics.
 */
public final class ClipboardItem implements Serializable {
    private static final long serialVersionUID = 1L;

    private final String itemId;
    private final ClipboardItemType type;
    private final byte[] payload;
    private final ContentHash contentHash;
    private final String originPeerId;
    private final long sequence;
    private final long createdAtUtcMs;
    private final long ttlMs;

    public ClipboardItem(
            String itemId,
            ClipboardItemType type,
            byte[] payload,
            ContentHash contentHash,
            String originPeerId,
            long sequence,
            long createdAtUtcMs,
            long ttlMs
    ) {
        this.itemId = Objects.requireNonNull(itemId, "itemId cannot be null");
        this.type = Objects.requireNonNull(type, "type cannot be null");
        this.payload = Objects.requireNonNull(payload, "payload cannot be null").clone();
        this.contentHash = Objects.requireNonNull(contentHash, "contentHash cannot be null");
        this.originPeerId = Objects.requireNonNull(originPeerId, "originPeerId cannot be null");
        this.sequence = sequence;
        this.createdAtUtcMs = createdAtUtcMs;
        this.ttlMs = ttlMs;
    }

    public boolean isExpired(long nowUtcMs) {
        return nowUtcMs > (createdAtUtcMs + ttlMs);
    }

    public String getItemId() { return itemId; }
    public ClipboardItemType getType() { return type; }
    public byte[] getPayload() { return payload.clone(); }
    public ContentHash getContentHash() { return contentHash; }
    public String getOriginPeerId() { return originPeerId; }
    public long getSequence() { return sequence; }
    public long getCreatedAtUtcMs() { return createdAtUtcMs; }
    public long getTtlMs() { return ttlMs; }
}