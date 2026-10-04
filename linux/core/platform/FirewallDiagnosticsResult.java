package org.peerlink.core.platform;

import java.util.Collections;
import java.util.List;

/**
 * Result model for platform firewall diagnostics.
 */
public final class FirewallDiagnosticsResult {
    public enum Status {
        CONFIGURED,
        RULE_MISSING,
        PORT_BLOCKED,
        NOT_APPLICABLE,
        ACCESS_DENIED,
        UNKNOWN
    }

    private final Status status;
    private final boolean peerLinkAllowed;
    private final int port;
    private final String transportProtocol;
    private final List<String> diagnosticMessages;
    private final String suggestedCommand;

    public FirewallDiagnosticsResult(
            Status status,
            boolean peerLinkAllowed,
            int port,
            String transportProtocol,
            List<String> diagnosticMessages,
            String suggestedCommand) {
        this.status = status;
        this.peerLinkAllowed = peerLinkAllowed;
        this.port = port;
        this.transportProtocol = transportProtocol;
        this.diagnosticMessages = diagnosticMessages != null ? Collections.unmodifiableList(diagnosticMessages) : Collections.emptyList();
        this.suggestedCommand = suggestedCommand;
    }

    public Status getStatus() {
        return status;
    }

    public boolean isPeerLinkAllowed() {
        return peerLinkAllowed;
    }

    public int getPort() {
        return port;
    }

    public String getTransportProtocol() {
        return transportProtocol;
    }

    public List<String> getDiagnosticMessages() {
        return diagnosticMessages;
    }

    public String getSuggestedCommand() {
        return suggestedCommand;
    }

    @Override
    public String toString() {
        return "FirewallDiagnosticsResult{" +
                "status=" + status +
                ", peerLinkAllowed=" + peerLinkAllowed +
                ", port=" + port +
                ", transportProtocol='" + transportProtocol + '\'' +
                '}';
    }
}
