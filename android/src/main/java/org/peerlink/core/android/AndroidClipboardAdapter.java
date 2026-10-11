package org.peerlink.core.android;

import org.peerlink.core.collaboration.clipboard.ClipboardItem;
import org.peerlink.core.collaboration.clipboard.ClipboardManager;
import org.peerlink.core.collaboration.clipboard.ClipboardSyncMode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.Objects;
import java.util.Optional;

/**
 * Android system clipboard adapter that obeys Android OS clipboard constraints:
 * - Android 10+ (API 29+): Background clipboard read access is blocked by the OS unless app is default IME or in focus.
 * - Android 13+ (API 33+): Sensitivity flag (EXTRA_IS_SENSITIVE) handling.
 * - Invariant: Ephemeral in-memory only. Payloads are NEVER logged to diagnostics or history.
 */
public class AndroidClipboardAdapter {
    private static final Logger log = LoggerFactory.getLogger(AndroidClipboardAdapter.class);

    public interface SystemClipboardBridge {
        String readText();
        void writeText(String text, boolean isSensitive);
        boolean hasText();
    }

    private final ClipboardManager coreClipboardManager;
    private final SystemClipboardBridge systemBridge;
    private final AndroidNodeStateMachine stateMachine;

    public AndroidClipboardAdapter(String localPeerId,
                                   ClipboardSyncMode mode,
                                   SystemClipboardBridge systemBridge,
                                   AndroidNodeStateMachine stateMachine) {
        this.coreClipboardManager = new ClipboardManager(
                Objects.requireNonNull(localPeerId, "localPeerId must not be null"),
                mode
        );
        this.systemBridge = Objects.requireNonNull(systemBridge, "systemBridge must not be null");
        this.stateMachine = Objects.requireNonNull(stateMachine, "stateMachine must not be null");
    }

    public ClipboardManager getCoreClipboardManager() {
        return coreClipboardManager;
    }

    /**
     * Attempts to read local system clipboard and publish outbound to connected peers.
     * Enforces Android 10+ background restriction: returns empty if app is not in foreground.
     */
    public Optional<ClipboardItem> syncLocalClipboardOutbound() throws IOException {
        AndroidNodeContext ctx = stateMachine.getCurrentContext();
        if (!ctx.isAppInForeground()) {
            log.debug("Android 10+ clipboard policy: Background clipboard read suppressed.");
            return Optional.empty();
        }

        if (!systemBridge.hasText()) {
            return Optional.empty();
        }

        String text = systemBridge.readText();
        if (text == null || text.isEmpty()) {
            return Optional.empty();
        }

        // Delegate to core manager for sensitivity inspection, loop guard, hashing
        return coreClipboardManager.publishLocalText(text);
    }

    /**
     * Receives clipboard payload from a remote peer and writes it to the local Android system clipboard.
     * Marks as sensitive if indicated.
     */
    public boolean applyRemoteClipboardInbound(ClipboardItem item, boolean markSensitive) {
        boolean accepted = coreClipboardManager.receiveRemoteItem(item);
        if (!accepted) {
            return false;
        }

        byte[] payload = item.getPayload();
        String text = new String(payload, java.nio.charset.StandardCharsets.UTF_8);
        systemBridge.writeText(text, markSensitive);
        log.info("Applied remote clipboard item {} to Android system clipboard (sensitive={})",
                item.getItemId(), markSensitive);
        return true;
    }

    public void setMode(ClipboardSyncMode mode) {
        coreClipboardManager.setMode(mode);
    }

    public ClipboardSyncMode getMode() {
        return coreClipboardManager.getMode();
    }
}
