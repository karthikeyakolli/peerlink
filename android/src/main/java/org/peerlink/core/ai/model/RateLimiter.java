package org.peerlink.core.ai.model;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Token bucket rate limiter for AI Gateway requests.
 */
public final class RateLimiter {
    private final int maxRequestsPerMinute;
    private final AtomicInteger currentTokens;
    private final AtomicLong lastRefillTimestampMs;

    public RateLimiter(int maxRequestsPerMinute) {
        this.maxRequestsPerMinute = maxRequestsPerMinute;
        this.currentTokens = new AtomicInteger(maxRequestsPerMinute);
        this.lastRefillTimestampMs = new AtomicLong(System.currentTimeMillis());
    }

    public synchronized boolean tryAcquire() {
        refill();
        if (currentTokens.get() > 0) {
            currentTokens.decrementAndGet();
            return true;
        }
        return false;
    }

    private void refill() {
        long now = System.currentTimeMillis();
        long elapsed = now - lastRefillTimestampMs.get();
        if (elapsed > 60000) {
            currentTokens.set(maxRequestsPerMinute);
            lastRefillTimestampMs.set(now);
        } else if (elapsed > 0) {
            int refillAmount = (int) (elapsed * maxRequestsPerMinute / 60000);
            if (refillAmount > 0) {
                currentTokens.updateAndGet(curr -> Math.min(maxRequestsPerMinute, curr + refillAmount));
                lastRefillTimestampMs.set(now);
            }
        }
    }

    public int getAvailableTokens() {
        refill();
        return currentTokens.get();
    }
}
