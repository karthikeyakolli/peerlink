package org.peerlink.core.safety;

import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;

/**
 * Structured, privacy-safe failure diagnostics for PeerLink operations.
 *
 * <p>Enforces Section 16 requirements:
 * <ul>
 *   <li>Failure reason</li>
 *   <li>Authoritative Operation ID</li>
 *   <li>Relevant transport/connection info</li>
 *   <li>Recovery state (RESUMABLE, RECONCILIATION_REQUIRED, etc.)</li>
 *   <li>User-facing plain-English explanation</li>
 *   <li>Privacy-safe diagnostic report (STRICTLY REDACTING secrets, tokens, private keys)</li>
 * </ul>
 */
public final class OperationDiagnostics {

    public enum RecoveryState {
        RESUMABLE,
        RECONCILIATION_REQUIRED,
        RETRY_RECOMMENDED,
        ABORTED_SAFELY,
        TERMINAL_FAILURE
    }

    private static final Pattern SECRET_PATTERN = Pattern.compile(
            "(?i)(password|secret|token|bearer|key|credential|auth)[\\s:=]+([a-zA-Z0-9_\\-\\.~+/]{8,})"
    );
    private static final Pattern PRIVATE_KEY_HEADER = Pattern.compile(
            "-----BEGIN[ A-Z_-]+PRIVATE KEY-----[\\s\\S]*?-----END[ A-Z_-]+PRIVATE KEY-----"
    );

    private final String operationId;
    private final String failureReason;
    private final String connectionInfo;
    private final RecoveryState recoveryState;
    private final String userFacingExplanation;
    private final Map<String, String> privacySafeDetails;
    private final Instant generatedAt;

    private static final Pattern SENSITIVE_KEY_PATTERN = Pattern.compile(
            "(?i).*(password|secret|token|bearer|credential|private_?key|auth).*"
    );

    public OperationDiagnostics(
            String operationId,
            String failureReason,
            String connectionInfo,
            RecoveryState recoveryState,
            String userFacingExplanation,
            Map<String, String> rawDetails) {
        this.operationId = Objects.requireNonNull(operationId, "operationId");
        this.failureReason = Objects.requireNonNull(failureReason, "failureReason");
        this.connectionInfo = sanitize(connectionInfo != null ? connectionInfo : "N/A");
        this.recoveryState = Objects.requireNonNull(recoveryState, "recoveryState");
        this.userFacingExplanation = sanitize(Objects.requireNonNull(userFacingExplanation, "userFacingExplanation"));
        this.generatedAt = Instant.now();

        Map<String, String> cleanMap = new LinkedHashMap<>();
        if (rawDetails != null) {
            for (Map.Entry<String, String> e : rawDetails.entrySet()) {
                String k = e.getKey() != null ? e.getKey() : "";
                String v = e.getValue() != null ? e.getValue() : "";
                if (SENSITIVE_KEY_PATTERN.matcher(k).matches()) {
                    cleanMap.put(sanitize(k), "[REDACTED]");
                } else {
                    cleanMap.put(sanitize(k), sanitize(v));
                }
            }
        }
        this.privacySafeDetails = Collections.unmodifiableMap(cleanMap);
    }

    public static String sanitize(String input) {
        if (input == null) return "";
        String s = PRIVATE_KEY_HEADER.matcher(input).replaceAll("[REDACTED_PRIVATE_KEY]");
        return SECRET_PATTERN.matcher(s).replaceAll("$1=[REDACTED]");
    }

    public String getOperationId() { return operationId; }
    public String getFailureReason() { return failureReason; }
    public String getConnectionInfo() { return connectionInfo; }
    public RecoveryState getRecoveryState() { return recoveryState; }
    public String getUserFacingExplanation() { return userFacingExplanation; }
    public Map<String, String> getPrivacySafeDetails() { return privacySafeDetails; }
    public Instant getGeneratedAt() { return generatedAt; }

    public String toDiagnosticReport() {
        StringBuilder sb = new StringBuilder();
        sb.append("=== PEERLINK DIAGNOSTIC REPORT ===\n");
        sb.append("Timestamp:       ").append(generatedAt).append("\n");
        sb.append("Operation ID:    ").append(operationId).append("\n");
        sb.append("Failure Reason:  ").append(failureReason).append("\n");
        sb.append("Connection:      ").append(connectionInfo).append("\n");
        sb.append("Recovery State:  ").append(recoveryState).append("\n");
        sb.append("User Notice:     ").append(userFacingExplanation).append("\n");
        if (!privacySafeDetails.isEmpty()) {
            sb.append("Details:\n");
            for (Map.Entry<String, String> entry : privacySafeDetails.entrySet()) {
                sb.append("  * ").append(entry.getKey()).append(": ").append(entry.getValue()).append("\n");
            }
        }
        sb.append("==================================");
        return sb.toString();
    }
}
