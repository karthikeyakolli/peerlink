package org.peerlink.linux.os.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Linux Desktop Notification Manager.
 *
 * Dispatches notifications conforming to the Freedesktop Desktop Notifications specification
 * via notify-send or D-Bus org.freedesktop.Notifications.
 */
public final class LinuxNotificationManager {
    private static final Logger log = LoggerFactory.getLogger(LinuxNotificationManager.class);

    private LinuxNotificationManager() {}

    public static void showNotification(String title, String message, String urgency) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("linux")) {
            log.debug("Non-Linux OS: mock notification {} - {}", title, message);
            return;
        }

        try {
            String safeUrgency = (urgency != null && (urgency.equals("low") || urgency.equals("critical")))
                    ? urgency : "normal";

            ProcessBuilder pb = new ProcessBuilder(
                    "notify-send",
                    "--app-name=PeerLink",
                    "--urgency=" + safeUrgency,
                    "--icon=peerlink",
                    title != null ? title : "PeerLink",
                    message != null ? message : ""
            );
            pb.start();
            log.info("Dispatched Linux notification: {} - {}", title, message);
        } catch (Exception e) {
            log.debug("notify-send failed: {}", e.getMessage());
        }
    }
}
