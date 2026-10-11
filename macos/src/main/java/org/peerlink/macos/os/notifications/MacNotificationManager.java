package org.peerlink.macos.os.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * macOS Desktop Notification Manager.
 * Dispatches notifications using AppleScript via /usr/bin/osascript.
 */
public class MacNotificationManager {

    private static final Logger log = LoggerFactory.getLogger(MacNotificationManager.class);

    private final boolean dryRunOnly;

    public MacNotificationManager() {
        this(false);
    }

    public MacNotificationManager(boolean dryRunOnly) {
        this.dryRunOnly = dryRunOnly;
    }

    /**
     * Posts a notification to the macOS Notification Center.
     */
    public boolean postNotification(String title, String message, String subtitle) {
        if (title == null || message == null) {
            return false;
        }

        if (dryRunOnly) {
            return true;
        }

        try {
            String safeTitle = title.replace("\"", "\\\"");
            String safeMessage = message.replace("\"", "\\\"");
            String safeSubtitle = (subtitle != null) ? subtitle.replace("\"", "\\\"") : "PeerLink";

            String script = String.format(
                    "display notification \"%s\" with title \"%s\" subtitle \"%s\"",
                    safeMessage, safeTitle, safeSubtitle
            );

            ProcessBuilder pb = new ProcessBuilder("/usr/bin/osascript", "-e", script);
            Process p = pb.start();
            return p.waitFor() == 0;
        } catch (Exception e) {
            log.warn("Failed to dispatch macOS desktop notification: {}", e.getMessage());
            return false;
        }
    }
}
