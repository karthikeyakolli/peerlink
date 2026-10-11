package org.peerlink.windows.os.firewall;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.InputStreamReader;

/**
 * Windows Defender Firewall Coordinator.
 *
 * Inspects and configures firewall inbound rules for local P2P listening ports.
 */
public final class WindowsFirewallCoordinator {
    private static final Logger log = LoggerFactory.getLogger(WindowsFirewallCoordinator.class);

    private static final String RULE_NAME = "PeerLink P2P Transport";

    private WindowsFirewallCoordinator() {}

    /**
     * Verifies whether an inbound firewall rule exists allowing traffic on the specified port.
     */
    public static boolean verifyFirewallRule(int port) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("win")) {
            return true;
        }

        try {
            ProcessBuilder pb = new ProcessBuilder(
                    "netsh.exe", "advfirewall", "firewall", "show", "rule", "name=" + RULE_NAME);
            Process p = pb.start();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("Enabled:") && line.contains("Yes")) {
                        return true;
                    }
                }
            }
            int exitCode = p.waitFor();
            return exitCode == 0;
        } catch (Exception e) {
            log.debug("Failed to query Windows Firewall rule: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Attempts to create an inbound allow rule for the P2P TCP port.
     */
    public static boolean requestAddFirewallRule(int port, String executablePath) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("win")) {
            return true;
        }

        try {
            String command = String.format(
                    "netsh advfirewall firewall add rule name=\"%s\" dir=in action=allow protocol=TCP localport=%d",
                    RULE_NAME, port);
            Process p = new ProcessBuilder("powershell.exe", "-NoProfile", "-Command", command).start();
            return p.waitFor() == 0;
        } catch (Exception e) {
            log.warn("Cannot configure Windows Firewall rule (administrator privileges may be required): {}", e.getMessage());
            return false;
        }
    }
}
