package org.peerlink.core.safety;

import org.peerlink.core.security.SecurityVerdict;

import java.util.Objects;

/**
 * Scan policy controlling admission of scanned files.
 * Invariant: Never claims "safe" when scanner is unavailable.
 */
public final class ScanPolicy {
    private final boolean allowCleanOnly;
    private final boolean requireScanner;
    private final boolean holdSuspiciousForDecision;

    public ScanPolicy(boolean allowCleanOnly, boolean requireScanner, boolean holdSuspiciousForDecision) {
        this.allowCleanOnly = allowCleanOnly;
        this.requireScanner = requireScanner;
        this.holdSuspiciousForDecision = holdSuspiciousForDecision;
    }

    public static ScanPolicy strict() {
        return new ScanPolicy(true, true, true);
    }

    public static ScanPolicy standard() {
        return new ScanPolicy(false, false, true);
    }

    public PolicyDecision evaluate(ScanResult scanResult) {
        Objects.requireNonNull(scanResult, "scanResult cannot be null");
        SecurityVerdict v = scanResult.verdict();

        if (v == SecurityVerdict.MALICIOUS) {
            return PolicyDecision.REJECT_AND_DELETE;
        }

        if (v == SecurityVerdict.SUSPICIOUS) {
            return holdSuspiciousForDecision
                    ? PolicyDecision.HOLD_IN_QUARANTINE_FOR_DECISION
                    : PolicyDecision.REJECT_AND_DELETE;
        }

        if (v == SecurityVerdict.CLEAN) {
            return PolicyDecision.PERMIT_COMMIT;
        }

        return PolicyDecision.HOLD_IN_QUARANTINE_FOR_DECISION;
    }

    public boolean isAllowCleanOnly() { return allowCleanOnly; }
    public boolean isRequireScanner() { return requireScanner; }
    public boolean isHoldSuspiciousForDecision() { return holdSuspiciousForDecision; }
}