package org.peerlink.windows.os.notifications;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Windows Action Center & Toast Notification Manager.
 */
public final class WindowsNotificationManager {
    private static final Logger log = LoggerFactory.getLogger(WindowsNotificationManager.class);

    private WindowsNotificationManager() {}

    /**
     * Displays a native Windows toast notification via Windows Runtime APIs.
     */
    public static void showToast(String title, String message) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("win")) {
            return;
        }

        try {
            String safeTitle = title != null ? title.replace("'", "''").replace("\"", "`\"") : "PeerLink";
            String safeMsg = message != null ? message.replace("'", "''").replace("\"", "`\"") : "";

            String script = String.format(
                    "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; " +
                    "$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); " +
                    "$texts = $template.GetElementsByTagName('text'); " +
                    "$texts.Item(0).AppendChild($template.CreateTextNode('%s')) | Out-Null; " +
                    "$texts.Item(1).AppendChild($template.CreateTextNode('%s')) | Out-Null; " +
                    "$toast = [Windows.UI.Notifications.ToastNotification]::new($template); " +
                    "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('PeerLink').Show($toast);",
                    safeTitle, safeMsg);

            new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script).start();
            log.info("Dispatched Windows toast notification: {} - {}", safeTitle, safeMsg);
        } catch (Exception e) {
            log.debug("Failed to dispatch Windows toast notification: {}", e.getMessage());
        }
    }
}
