package org.peerlink.core.safety;

import org.peerlink.core.security.SecurityVerdict;

import java.io.Serializable;
import java.util.Map;
import java.util.Objects;

public record ScanResult(
        SecurityVerdict verdict,
        String scannerName,
        String threatName,
        long scanDurationMs,
        Map<String, String> details
) implements Serializable {
    public ScanResult {
        Objects.requireNonNull(verdict, "verdict cannot be null");
        Objects.requireNonNull(scannerName, "scannerName cannot be null");
        details = details == null ? Map.of() : Map.copyOf(details);
    }

    public static ScanResult clean(String scannerName, long durationMs) {
        return new ScanResult(SecurityVerdict.CLEAN, scannerName, null, durationMs, Map.of());
    }

    public static ScanResult malicious(String scannerName, String threatName, long durationMs) {
        return new ScanResult(SecurityVerdict.MALICIOUS, scannerName, threatName, durationMs, Map.of("threat", threatName));
    }

    public static ScanResult suspicious(String scannerName, String reason, long durationMs) {
        return new ScanResult(SecurityVerdict.SUSPICIOUS, scannerName, reason, durationMs, Map.of("reason", reason));
    }

    public static ScanResult unavailable(String scannerName, String reason) {
        return new ScanResult(SecurityVerdict.UNAVAILABLE, scannerName, null, 0, Map.of("reason", reason));
    }

    public static ScanResult failed(String scannerName, String error) {
        return new ScanResult(SecurityVerdict.SCAN_FAILED, scannerName, null, 0, Map.of("error", error));
    }

    public static ScanResult unsupported(String scannerName, String reason) {
        return new ScanResult(SecurityVerdict.UNSUPPORTED, scannerName, null, 0, Map.of("reason", reason));
    }
}