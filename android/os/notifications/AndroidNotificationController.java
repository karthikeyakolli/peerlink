package org.peerlink.core.android;

import org.peerlink.protocol.v1.PeerId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Objects;

/**
 * Controller managing user-visible notifications for Android platform:
 * - Ongoing transfer progress with pause/cancel actions
 * - Pairing confirmation requests with SAS PIN and Accept/Reject actions
 * - Background sync/backup completion alerts
 */
public class AndroidNotificationController {
    private static final Logger log = LoggerFactory.getLogger(AndroidNotificationController.class);

    public static final String CHANNEL_TRANSFERS = "peerlink_transfers";
    public static final String CHANNEL_PAIRING = "peerlink_pairing";
    public static final String CHANNEL_SYNC = "peerlink_sync";

    public interface PlatformNotificationBridge {
        void showTransferProgress(String transferId, String title, int progressPercent, long bytesTransferred, long totalBytes);
        void dismissTransferProgress(String transferId);
        void showPairingPrompt(String sessionId, PeerId peerId, String peerName, String sasPin);
        void dismissPairingPrompt(String sessionId);
        void showStatusNotification(String title, String message);
    }

    private final PlatformNotificationBridge bridge;

    public AndroidNotificationController(PlatformNotificationBridge bridge) {
        this.bridge = Objects.requireNonNull(bridge, "bridge must not be null");
    }

    public void updateTransferProgress(String transferId, String fileName, int percent, long transferred, long total) {
        bridge.showTransferProgress(transferId, "Transferring " + fileName, percent, transferred, total);
    }

    public void completeTransfer(String transferId, String fileName, boolean success) {
        bridge.dismissTransferProgress(transferId);
        if (success) {
            bridge.showStatusNotification("Transfer Complete", fileName + " received successfully.");
        } else {
            bridge.showStatusNotification("Transfer Failed", "Failed to transfer " + fileName);
        }
    }

    public void showPairingRequest(String sessionId, PeerId remotePeerId, String peerName, String sasPin) {
        log.info("Displaying pairing notification for peer {} with SAS PIN {}", remotePeerId.getValue(), sasPin);
        bridge.showPairingPrompt(sessionId, remotePeerId, peerName, sasPin);
    }

    public void dismissPairingRequest(String sessionId) {
        bridge.dismissPairingPrompt(sessionId);
    }
}
