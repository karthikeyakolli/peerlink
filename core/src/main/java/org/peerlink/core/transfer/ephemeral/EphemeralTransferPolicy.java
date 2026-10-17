package org.peerlink.core.transfer.ephemeral;

import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

/**
 * Immutable security policy specifying ephemeral retention, auto-shredding constraints,
 * view quotas, and time-to-live (TTL).
 */
public final class EphemeralTransferPolicy {
    private final boolean burnAfterRead;
    private final long ttlSeconds;
    private final int allowedViews;
    private final String clientWatermark;
    private final Instant createdAt;

    public EphemeralTransferPolicy(boolean burnAfterRead, long ttlSeconds, int allowedViews, String clientWatermark) {
        this.burnAfterRead = burnAfterRead;
        this.ttlSeconds = Math.max(0, ttlSeconds);
        this.allowedViews = Math.max(1, allowedViews);
        this.clientWatermark = clientWatermark != null ? clientWatermark : "";
        this.createdAt = Instant.now();
    }

    public static EphemeralTransferPolicy standard() {
        return new EphemeralTransferPolicy(false, 0, Integer.MAX_VALUE, "");
    }

    public static EphemeralTransferPolicy burnAfterOneView() {
        return new EphemeralTransferPolicy(true, 0, 1, "CONFIDENTIAL - 1-VIEW BURN");
    }

    public static EphemeralTransferPolicy timeLimited(long ttlSeconds) {
        return new EphemeralTransferPolicy(true, ttlSeconds, 1, "CONFIDENTIAL - EXPIRES SOON");
    }

    public boolean isBurnAfterRead() {
        return burnAfterRead;
    }

    public long getTtlSeconds() {
        return ttlSeconds;
    }

    public int getAllowedViews() {
        return allowedViews;
    }

    public String getClientWatermark() {
        return clientWatermark;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public boolean isExpired() {
        if (ttlSeconds <= 0) {
            return false;
        }
        return Instant.now().isAfter(createdAt.plus(Duration.ofSeconds(ttlSeconds)));
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        EphemeralTransferPolicy that = (EphemeralTransferPolicy) o;
        return burnAfterRead == that.burnAfterRead &&
               ttlSeconds == that.ttlSeconds &&
               allowedViews == that.allowedViews &&
               Objects.equals(clientWatermark, that.clientWatermark);
    }

    @Override
    public int hashCode() {
        return Objects.hash(burnAfterRead, ttlSeconds, allowedViews, clientWatermark);
    }

    @Override
    public String toString() {
        return "EphemeralTransferPolicy{" +
                "burnAfterRead=" + burnAfterRead +
                ", ttlSeconds=" + ttlSeconds +
                ", allowedViews=" + allowedViews +
                ", watermark='" + clientWatermark + '\'' +
                '}';
    }
}
