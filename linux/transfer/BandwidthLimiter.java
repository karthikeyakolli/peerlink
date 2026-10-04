package org.peerlink.core.transfer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Token-bucket rate limiter for controlling transfer bandwidth.
 * Allows dynamic throttling of bytes sent or received per second.
 */
public final class BandwidthLimiter {
    private static final Logger log = LoggerFactory.getLogger(BandwidthLimiter.class);

    private volatile long maxBytesPerSecond;
    private long availableTokens;
    private long lastReplenishTimeMs;

    public BandwidthLimiter() {
        this(0); // 0 means unlimited
    }

    public BandwidthLimiter(long maxBytesPerSecond) {
        this.maxBytesPerSecond = maxBytesPerSecond;
        this.availableTokens = maxBytesPerSecond;
        this.lastReplenishTimeMs = System.currentTimeMillis();
    }

    /**
     * Update the bandwidth limit dynamically.
     *
     * @param bytesPerSecond Max bytes per second, or <= 0 for unlimited.
     */
    public synchronized void setRateLimit(long bytesPerSecond) {
        this.maxBytesPerSecond = Math.max(0, bytesPerSecond);
        this.availableTokens = this.maxBytesPerSecond;
        this.lastReplenishTimeMs = System.currentTimeMillis();
        log.info("Bandwidth limit set to {} bytes/second", this.maxBytesPerSecond);
    }

    public long getRateLimit() {
        return maxBytesPerSecond;
    }

    public boolean isLimited() {
        return maxBytesPerSecond > 0;
    }

    /**
     * Consume a number of bytes, blocking until enough bandwidth capacity is available.
     *
     * @param bytes Number of bytes to consume
     * @throws InterruptedException if interrupted while waiting for tokens
     */
    public synchronized void consume(int bytes) throws InterruptedException {
        if (maxBytesPerSecond <= 0 || bytes <= 0) {
            return;
        }

        while (true) {
            replenishTokens();
            if (availableTokens >= bytes) {
                availableTokens -= bytes;
                return;
            }

            // Calculate wait time needed for required tokens
            long missingTokens = bytes - availableTokens;
            long waitMillis = (long) Math.ceil((missingTokens * 1000.0) / maxBytesPerSecond);
            if (waitMillis > 0) {
                wait(Math.min(waitMillis, 1000));
            }
        }
    }

    private void replenishTokens() {
        long now = System.currentTimeMillis();
        long elapsedMs = now - lastReplenishTimeMs;
        if (elapsedMs > 0) {
            long newTokens = (elapsedMs * maxBytesPerSecond) / 1000;
            if (newTokens > 0) {
                availableTokens = Math.min(maxBytesPerSecond * 2, availableTokens + newTokens);
                lastReplenishTimeMs = now;
            }
        }
    }
}
