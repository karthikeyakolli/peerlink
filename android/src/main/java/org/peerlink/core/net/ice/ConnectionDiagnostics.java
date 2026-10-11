package org.peerlink.core.net.ice;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Diagnostics engine explaining ICE connection results:
 * - direct succeeded
 * - direct failed
 * - relay used
 * - why relay was selected
 */
public final class ConnectionDiagnostics {

    public enum Outcome {
        DIRECT_SUCCEEDED,
        DIRECT_FAILED,
        RELAY_USED,
        ALL_FAILED
    }

    private final Outcome outcome;
    private final CandidatePair selectedPair;
    private final String directFailureReason;
    private final String relaySelectionReason;
    private final ConnectionQuality connectionQuality;
    private final List<String> probeHistory;
    private final String timestamp;

    public ConnectionDiagnostics(Outcome outcome,
                                 CandidatePair selectedPair,
                                 String directFailureReason,
                                 String relaySelectionReason,
                                 ConnectionQuality connectionQuality,
                                 List<String> probeHistory) {
        this.outcome = outcome;
        this.selectedPair = selectedPair;
        this.directFailureReason = directFailureReason;
        this.relaySelectionReason = relaySelectionReason;
        this.connectionQuality = connectionQuality != null ? connectionQuality : ConnectionQuality.unknown();
        this.probeHistory = probeHistory != null ? Collections.unmodifiableList(new ArrayList<>(probeHistory)) : Collections.emptyList();
        this.timestamp = Instant.now().toString();
    }

    public Outcome getOutcome() { return outcome; }
    public CandidatePair getSelectedPair() { return selectedPair; }
    public String getDirectFailureReason() { return directFailureReason; }
    public String getRelaySelectionReason() { return relaySelectionReason; }
    public ConnectionQuality getConnectionQuality() { return connectionQuality; }
    public List<String> getProbeHistory() { return probeHistory; }
    public String getTimestamp() { return timestamp; }

    public boolean isDirect() {
        return outcome == Outcome.DIRECT_SUCCEEDED;
    }

    public boolean isRelayed() {
        return outcome == Outcome.RELAY_USED;
    }

    public String toDiagnosticReport() {
        StringBuilder sb = new StringBuilder();
        sb.append("=== PeerLink Connection Diagnostics ===\n");
        sb.append("Timestamp: ").append(timestamp).append("\n");
        sb.append("Outcome: ").append(outcome).append("\n");

        if (selectedPair != null) {
            sb.append("Selected Path: ").append(selectedPair).append("\n");
            sb.append("Local Type: ").append(selectedPair.getLocalCandidate().getType())
              .append(" (").append(selectedPair.getLocalCandidate().getIp()).append(":")
              .append(selectedPair.getLocalCandidate().getPort()).append(")\n");
            sb.append("Remote Type: ").append(selectedPair.getRemoteCandidate().getType())
              .append(" (").append(selectedPair.getRemoteCandidate().getIp()).append(":")
              .append(selectedPair.getRemoteCandidate().getPort()).append(")\n");
            sb.append("Transport: ").append(selectedPair.getLocalCandidate().getProtocol()).append("\n");
        }

        if (outcome == Outcome.DIRECT_SUCCEEDED) {
            sb.append("Status: Direct peer-to-peer path established successfully.\n");
        } else if (outcome == Outcome.RELAY_USED) {
            sb.append("Status: Relayed path via TURN coturn server.\n");
            sb.append("Direct Failure Rationale: ").append(directFailureReason != null ? directFailureReason : "None provided").append("\n");
            sb.append("Why Relay Selected: ").append(relaySelectionReason != null ? relaySelectionReason : "Direct path unavailable").append("\n");
        } else {
            sb.append("Status: All direct and relay paths failed to establish.\n");
            sb.append("Failure Rationale: ").append(directFailureReason != null ? directFailureReason : "Unknown").append("\n");
        }

        sb.append("Connection Quality: ").append(connectionQuality).append("\n");
        if (!probeHistory.isEmpty()) {
            sb.append("Probe Event History:\n");
            for (String event : probeHistory) {
                sb.append("  - ").append(event).append("\n");
            }
        }
        sb.append("========================================\n");
        return sb.toString();
    }

    @Override
    public String toString() {
        return toDiagnosticReport();
    }
}
