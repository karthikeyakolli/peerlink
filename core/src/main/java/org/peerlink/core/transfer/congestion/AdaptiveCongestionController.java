package org.peerlink.core.transfer.congestion;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Adaptive Congestion Controller based on LEDBAT and BBR concepts.
 *
 * <p>Monitors chunk round-trip time (RTT) and calculates queuing delay
 * against a minimum base RTT. When queueing delay rises above the target threshold,
 * it yields bandwidth proportionally to prevent bufferbloat and packet drops.
 * When the link is clean, it probes available capacity upwards with additive increase.
 */
public final class AdaptiveCongestionController {

    private static final Logger log = LoggerFactory.getLogger(AdaptiveCongestionController.class);

    public static final long DEFAULT_INITIAL_RATE = 5_000_000L;  // 5 MB/s
    public static final long DEFAULT_MIN_RATE = 200_000L;        // 200 KB/s
    public static final long DEFAULT_MAX_RATE = 100_000_000L;    // 100 MB/s
    public static final long DEFAULT_TARGET_DELAY_MS = 50L;      // 50ms queueing delay

    private volatile long currentRateBytesPerSec;
    private final long minRateBytesPerSec;
    private final long maxRateBytesPerSec;
    private final long targetQueueDelayMs;

    private volatile long baseRttMs = Long.MAX_VALUE;

    public AdaptiveCongestionController() {
        this(DEFAULT_INITIAL_RATE, DEFAULT_MIN_RATE, DEFAULT_MAX_RATE, DEFAULT_TARGET_DELAY_MS);
    }

    public AdaptiveCongestionController(long initialRate, long minRate, long maxRate, long targetQueueDelayMs) {
        if (minRate <= 0 || initialRate < minRate || maxRate < initialRate) {
            throw new IllegalArgumentException(String.format(
                    "Invalid rate bounds: min (%d) <= initial (%d) <= max (%d)",
                    minRate, initialRate, maxRate));
        }
        this.currentRateBytesPerSec = initialRate;
        this.minRateBytesPerSec = minRate;
        this.maxRateBytesPerSec = maxRate;
        this.targetQueueDelayMs = Math.max(5, targetQueueDelayMs);
    }

    /**
     * Record a completed chunk transmission sample.
     *
     * @param sampleRttMs round-trip time elapsed from chunk dispatch to acknowledgement
     * @param chunkBytes number of payload bytes transmitted
     * @return updated transmission rate limit
     */
    public synchronized long recordSample(long sampleRttMs, int chunkBytes) {
        if (sampleRttMs <= 0) {
            return currentRateBytesPerSec;
        }

        if (sampleRttMs < baseRttMs) {
            baseRttMs = sampleRttMs;
        }

        long queueDelayMs = Math.max(0, sampleRttMs - baseRttMs);

        if (queueDelayMs > targetQueueDelayMs) {
            // Congestion detected: multiplicative backoff (-20%)
            long newRate = Math.max(minRateBytesPerSec, (long) (currentRateBytesPerSec * 0.80));
            log.debug("Congestion delay {}ms > {}ms. Throttling rate: {} -> {} B/s",
                    queueDelayMs, targetQueueDelayMs, currentRateBytesPerSec, newRate);
            currentRateBytesPerSec = newRate;
        } else {
            // Clean link: additive increase (+2x chunk size)
            long increase = Math.max(16 * 1024L, chunkBytes * 2L);
            long newRate = Math.min(maxRateBytesPerSec, currentRateBytesPerSec + increase);
            currentRateBytesPerSec = newRate;
        }

        return currentRateBytesPerSec;
    }

    /**
     * Handle unacknowledged chunk timeout or transport link error.
     * Halves the transmission rate immediately.
     */
    public synchronized void onTimeoutOrLoss() {
        long newRate = Math.max(minRateBytesPerSec, currentRateBytesPerSec / 2);
        log.warn("Emergency congestion backoff on timeout/loss: {} -> {} B/s",
                currentRateBytesPerSec, newRate);
        currentRateBytesPerSec = newRate;
    }

    public long getCurrentRateBytesPerSec() {
        return currentRateBytesPerSec;
    }

    public long getBaseRttMs() {
        return baseRttMs;
    }

    public long getTargetQueueDelayMs() {
        return targetQueueDelayMs;
    }
}
