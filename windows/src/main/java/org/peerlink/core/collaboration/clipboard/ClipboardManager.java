package org.peerlink.core.collaboration.clipboard;

import org.peerlink.core.model.ContentHash;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Manages collaborative clipboard operations.
 *
 * Invariants:
 * - Ephemeral in-memory only.
 * - Does NOT log payload to diagnostics or persistent operation history.
 * - Enforces loop prevention and sensitivity gating.
 */
public final class ClipboardManager {
    public static final long DEFAULT_TTL_MS = 5 * 60 * 1000L; // 5 minutes
    public static final long MAX_CLIPBOARD_SIZE_BYTES = 5 * 1024 * 1024L; // 5 MB

    private final String localPeerId;
    private volatile ClipboardSyncMode mode;
    private final ClipboardLoopGuard loopGuard;
    private final AtomicLong outboundSequence = new AtomicLong(1);
    private volatile ClipboardItem currentItem;

    public ClipboardManager(String localPeerId, ClipboardSyncMode mode) {
        this.localPeerId = Objects.requireNonNull(localPeerId, "localPeerId is required");
        this.mode = mode != null ? mode : ClipboardSyncMode.OFF;
        this.loopGuard = new ClipboardLoopGuard(localPeerId);
    }

    public synchronized Optional<ClipboardItem> publishLocalText(String text) throws IOException {
        if (mode == ClipboardSyncMode.OFF) {
            return Optional.empty();
        }

        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAX_CLIPBOARD_SIZE_BYTES) {
            throw new IOException("Clipboard text exceeds size limit of 5 MB");
        }

        ClipboardItemType type = (text.startsWith("http://") || text.startsWith("https://"))
                ? ClipboardItemType.URL
                : ClipboardItemType.TEXT;

        if (type == ClipboardItemType.URL && mode == ClipboardSyncMode.TEXT) {
            // URL permitted under TEXT or TEXT_AND_URL
        }

        // Sensitivity inspection
        ClipboardSensitivityInspector.SensitivityResult sens = ClipboardSensitivityInspector.inspect(bytes, type);
        if (sens.isSensitive()) {
            throw new SecurityException("Clipboard text contains sensitive " + sens.matchedCategory() + "; broadcast blocked by policy");
        }

        ContentHash hash = ContentHash.computeSha256(bytes);
        loopGuard.markOutbound(hash);

        String id = "clp_" + UUID.randomUUID().toString().replace("-", "");
        ClipboardItem item = new ClipboardItem(
                id, type, bytes, hash, localPeerId, outboundSequence.getAndIncrement(),
                System.currentTimeMillis(), DEFAULT_TTL_MS
        );
        this.currentItem = item;
        return Optional.of(item);
    }

    public synchronized boolean receiveRemoteItem(ClipboardItem item) {
        if (mode == ClipboardSyncMode.OFF) {
            return false;
        }

        // Loop check
        if (loopGuard.shouldDrop(item)) {
            return false;
        }

        // Type mode check
        if (item.getType() == ClipboardItemType.IMAGE && mode != ClipboardSyncMode.TEXT_AND_SUPPORTED_IMAGE) {
            return false;
        }
        if (item.getType() == ClipboardItemType.URL && mode == ClipboardSyncMode.OFF) {
            return false;
        }

        if (item.isExpired(System.currentTimeMillis())) {
            return false;
        }

        this.currentItem = item;
        return true;
    }

    public Optional<ClipboardItem> getCurrentItem() {
        if (currentItem != null && currentItem.isExpired(System.currentTimeMillis())) {
            currentItem = null;
        }
        return Optional.ofNullable(currentItem);
    }

    public void setMode(ClipboardSyncMode mode) {
        this.mode = mode;
        if (mode == ClipboardSyncMode.OFF) {
            this.currentItem = null;
        }
    }

    public ClipboardSyncMode getMode() { return mode; }
}