package org.peerlink.core.net.ice;

/**
 * Metric representation of path connection quality.
 */
public final class ConnectionQuality {

    private final long roundTripTimeMs;
    private final double packetLossRate; // 0.0 - 1.0
    private final long jitterMs;
    private final long estimatedBandwidthBytesPerSec;

    public ConnectionQuality(long roundTripTimeMs, double packetLossRate, long jitterMs, long estimatedBandwidthBytesPerSec) {
        this.roundTripTimeMs = Math.max(0, roundTripTimeMs);
        this.packetLossRate = Math.min(1.0, Math.max(0.0, packetLossRate));
        this.jitterMs = Math.max(0, jitterMs);
        this.estimatedBandwidthBytesPerSec = Math.max(0, estimatedBandwidthBytesPerSec);
    }

    public static ConnectionQuality unknown() {
        return new ConnectionQuality(-1, 0.0, 0, 0);
    }

    public long getRoundTripTimeMs() { return roundTripTimeMs; }
    public double getPacketLossRate() { return packetLossRate; }
    public long getJitterMs() { return jitterMs; }
    public long getEstimatedBandwidthBytesPerSec() { return estimatedBandwidthBytesPerSec; }

    /**
     * Composite score from 0 (unusable) to 100 (excellent).
     */
    public int computeScore() {
        if (roundTripTimeMs < 0) return 0;
        double rttScore = Math.max(0, 100 - (roundTripTimeMs / 5.0)); // <10ms -> ~98, 200ms -> ~60, 500ms -> 0
        double lossScore = Math.max(0, 100 * (1.0 - (packetLossRate * 5.0))); // 10% loss -> 50 score
        double jitterScore = Math.max(0, 100 - (jitterMs * 2.0));

        return (int) Math.round((rttScore * 0.5) + (lossScore * 0.3) + (jitterScore * 0.2));
    }

    @Override
    public String toString() {
        return "Quality[rtt=" + roundTripTimeMs + "ms, loss=" + String.format("%.1f%%", packetLossRate * 100) +
                ", jitter=" + jitterMs + "ms, score=" + computeScore() + "/100]";
    }
}
