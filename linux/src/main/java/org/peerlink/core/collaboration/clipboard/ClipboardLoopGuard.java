package org.peerlink.core.collaboration.clipboard;

import org.peerlink.core.model.ContentHash;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Prevents echo loops across connected peers.
 */
public final class ClipboardLoopGuard {
    private final String localPeerId;
    private final Map<String, Long> processedHashes = new ConcurrentHashMap<>();

    public ClipboardLoopGuard(String localPeerId) {
        this.localPeerId = localPeerId;
    }

    public boolean shouldDrop(ClipboardItem item) {
        // 1. Origin is self -> Loop detected
        if (item.getOriginPeerId().equals(localPeerId)) {
            return true;
        }

        // 2. Already processed recently
        String hashKey = item.getContentHash().getHexString();
        if (processedHashes.containsKey(hashKey)) {
            return true;
        }

        // Record as processed
        processedHashes.put(hashKey, System.currentTimeMillis());
        return false;
    }

    public void markOutbound(ContentHash hash) {
        processedHashes.put(hash.getHexString(), System.currentTimeMillis());
    }

    public void pruneExpired(long ttlMs) {
        long now = System.currentTimeMillis();
        processedHashes.entrySet().removeIf(e -> (now - e.getValue()) > ttlMs);
    }
}