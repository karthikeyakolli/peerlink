package org.peerlink.core.security;

/**
 * Deterministic verdicts for security and malware scanning.
 * Invariant: UNAVAILABLE or UNKNOWN must never be treated or presented as CLEAN.
 */
public enum SecurityVerdict {
    CLEAN,
    SUSPICIOUS,
    MALICIOUS,
    UNKNOWN,
    SCAN_FAILED,
    UNSUPPORTED,
    UNAVAILABLE;

    public boolean isSafeToCommit() {
        return this == CLEAN;
    }

    public boolean isKnownThreat() {
        return this == MALICIOUS || this == SUSPICIOUS;
    }
}