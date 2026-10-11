package org.peerlink.core.sharing;

public final class ShareRevocationRecord {
    private volatile boolean revoked = false;
    private volatile long revokedAtUtcMs = 0L;
    private volatile String revokeReason = "";
    private volatile long activeGraceEndsAtUtcMs = 0L;

    public synchronized void revoke(long nowUtcMs, String reason, long gracePeriodMs, long operationStartedAtUtcMs) {
        this.revoked = true;
        this.revokedAtUtcMs = nowUtcMs;
        this.revokeReason = reason != null ? reason : "";
        if (gracePeriodMs > 0 && operationStartedAtUtcMs > 0) {
            this.activeGraceEndsAtUtcMs = operationStartedAtUtcMs + gracePeriodMs;
        }
    }

    public boolean isRevoked() { return revoked; }
    public long getRevokedAtUtcMs() { return revokedAtUtcMs; }
    public String getRevokeReason() { return revokeReason; }

    public boolean isActiveOperationPermitted(long nowUtcMs) {
        if (!revoked) return true;
        return activeGraceEndsAtUtcMs > 0 && nowUtcMs <= activeGraceEndsAtUtcMs;
    }
}