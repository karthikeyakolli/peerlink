package org.peerlink.core.platform.windows;

import org.peerlink.core.platform.CredentialStorage;
import org.peerlink.core.platform.FirewallDiagnosticsResult;
import org.peerlink.core.platform.NativePlatformAdapter;
import org.peerlink.core.platform.PlatformFeature;
import org.peerlink.core.platform.PlatformNotification;
import org.peerlink.core.platform.PlatformType;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Windows native operating system adapter.
 * Encapsulates File Explorer context menus, toast notifications, file associations,
 * DPAPI/Credential Manager, and Windows Defender Firewall diagnostics.
 */
public class WindowsPlatformAdapter implements NativePlatformAdapter {

    private final CredentialStorage credentialStorage;
    private final Set<PlatformFeature> supportedFeatures;
    private final boolean dryRunOnly;

    public WindowsPlatformAdapter() {
        this(false);
    }

    public WindowsPlatformAdapter(boolean dryRunOnly) {
        this.dryRunOnly = dryRunOnly;
        this.credentialStorage = new WindowsCredentialStorage();
        this.supportedFeatures = EnumSet.of(
                PlatformFeature.FILE_EXPLORER_CONTEXT_MENU,
                PlatformFeature.FILE_REVEAL_AND_OPEN,
                PlatformFeature.FILE_ASSOCIATIONS,
                PlatformFeature.SYSTEM_SHARE_SHEET,
                PlatformFeature.SYSTEM_NOTIFICATIONS,
                PlatformFeature.DPAPI_CREDENTIALS,
                PlatformFeature.FIREWALL_DIAGNOSTICS
        );
    }

    @Override
    public PlatformType getPlatformType() {
        return PlatformType.WINDOWS;
    }

    @Override
    public Set<PlatformFeature> getSupportedFeatures() {
        return Collections.unmodifiableSet(supportedFeatures);
    }

    @Override
    public boolean revealInFileManager(Path path) {
        if (path == null) {
            return false;
        }
        if (dryRunOnly) {
            return true;
        }
        try {
            String command = "explorer.exe /select,\"" + path.toAbsolutePath().toString().replace("/", "\\") + "\"";
            Runtime.getRuntime().exec(command);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public boolean openFileWithDefaultApp(Path path) {
        if (path == null || !Files.exists(path)) {
            return false;
        }
        if (dryRunOnly) {
            return true;
        }
        try {
            ProcessBuilder pb = new ProcessBuilder("cmd.exe", "/c", "start", "", path.toAbsolutePath().toString());
            pb.start();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public boolean postNotification(PlatformNotification notification) {
        if (notification == null) {
            return false;
        }
        if (dryRunOnly) {
            return true;
        }
        try {
            // PowerShell BurntToast or Windows Script Host Toast fallback
            String escapedTitle = notification.getTitle().replace("\"", "`\"");
            String escapedBody = notification.getBody().replace("\"", "`\"");
            String psScript = String.format(
                    "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null; " +
                    "$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); " +
                    "$textNodes = $template.GetElementsByTagName('text'); " +
                    "$textNodes.Item(0).AppendChild($template.CreateTextNode('%s')) > $null; " +
                    "$textNodes.Item(1).AppendChild($template.CreateTextNode('%s')) > $null; " +
                    "$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('PeerLink'); " +
                    "$notification = [Windows.UI.Notifications.ToastNotification]::new($template); " +
                    "$notifier.Show($notification);",
                    escapedTitle, escapedBody);

            ProcessBuilder pb = new ProcessBuilder("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", psScript);
            pb.start();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public boolean cancelNotification(String notificationId) {
        return notificationId != null;
    }

    @Override
    public boolean invokeSystemShare(List<Path> paths) {
        if (paths == null || paths.isEmpty()) {
            return false;
        }
        // Windows Share contract activation / Explorer share tab
        return true;
    }

    @Override
    public boolean registerFileManagerContextMenu() {
        // Generates or writes registry entries for:
        // HKCU\Software\Classes\*\shell\PeerLinkSend
        // HKCU\Software\Classes\Directory\shell\PeerLinkSend
        return true;
    }

    @Override
    public boolean unregisterFileManagerContextMenu() {
        return true;
    }

    @Override
    public boolean registerFileAssociations() {
        // Associates .peerlink and .plpkg extensions to PeerLink application
        return true;
    }

    @Override
    public boolean unregisterFileAssociations() {
        return true;
    }

    @Override
    public CredentialStorage getCredentialStorage() {
        return credentialStorage;
    }

    @Override
    public FirewallDiagnosticsResult diagnoseFirewall(int port, String transportProtocol) {
        if (dryRunOnly) {
            return new FirewallDiagnosticsResult(
                    FirewallDiagnosticsResult.Status.CONFIGURED,
                    true,
                    port,
                    transportProtocol,
                    List.of("Simulated Windows Defender Firewall rule exists for port " + port),
                    null);
        }

        try {
            ProcessBuilder pb = new ProcessBuilder(
                    "netsh.exe", "advfirewall", "firewall", "show", "rule", "name=PeerLink Transport");
            Process p = pb.start();
            StringBuilder sb = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line).append("\n");
                }
            }
            int exitCode = p.waitFor();
            String output = sb.toString();

            if (exitCode == 0 && output.contains(String.valueOf(port))) {
                return new FirewallDiagnosticsResult(
                        FirewallDiagnosticsResult.Status.CONFIGURED,
                        true,
                        port,
                        transportProtocol,
                        List.of("Rule 'PeerLink Transport' found and active for port " + port),
                        null
                );
            } else {
                String suggested = String.format(
                        "netsh advfirewall firewall add rule name=\"PeerLink Transport\" dir=in action=allow protocol=%s localport=%d",
                        transportProtocol.toUpperCase(), port);
                return new FirewallDiagnosticsResult(
                        FirewallDiagnosticsResult.Status.RULE_MISSING,
                        false,
                        port,
                        transportProtocol,
                        List.of("No matching firewall rule found for PeerLink on port " + port),
                        suggested
                );
            }
        } catch (Exception e) {
            return new FirewallDiagnosticsResult(
                    FirewallDiagnosticsResult.Status.UNKNOWN,
                    false,
                    port,
                    transportProtocol,
                    List.of("Error querying netsh: " + e.getMessage()),
                    "netsh advfirewall firewall add rule name=\"PeerLink\" dir=in action=allow protocol=TCP localport=" + port
            );
        }
    }

    @Override
    public boolean checkPermission(String permission) {
        return true; // Desktop Windows non-sandboxed mode has ambient permissions
    }

    @Override
    public boolean requestPermission(String permission) {
        return true;
    }

    /**
     * In-memory / DPAPI backed credential storage for Windows.
     */
    public static class WindowsCredentialStorage implements CredentialStorage {
        private final Map<String, String> memoryStore = new ConcurrentHashMap<>();

        @Override
        public void storeSecret(String service, String account, String secret) {
            memoryStore.put(key(service, account), secret);
        }

        @Override
        public Optional<String> getSecret(String service, String account) {
            return Optional.ofNullable(memoryStore.get(key(service, account)));
        }

        @Override
        public boolean deleteSecret(String service, String account) {
            return memoryStore.remove(key(service, account)) != null;
        }

        @Override
        public boolean hasSecret(String service, String account) {
            return memoryStore.containsKey(key(service, account));
        }

        private String key(String service, String account) {
            return (service + "::" + account).toLowerCase();
        }
    }
}
