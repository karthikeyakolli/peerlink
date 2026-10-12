package org.peerlink.core.cloud.supabase;

import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Thread-safe Token-Bucket Rate Limiter for signaling messages.
 * Protects against signaling floods, quota exhaustion, and DoS attacks.
 * Enforces both a global rate limit and per-recipient rate limits.
 */
public class SignalingRateLimiter {

    private static final class TokenBucket {
        private final double capacity;
        private final double refillRatePerSecond;
        private double tokens;
        private long lastRefillTimestamp;

        TokenBucket(double capacity, double refillRatePerSecond) {
            this.capacity = capacity;
            this.refillRatePerSecond = refillRatePerSecond;
            this.tokens = capacity;
            this.lastRefillTimestamp = System.currentTimeMillis();
        }

        synchronized boolean tryAcquire(double requestedTokens) {
            refill();
            if (tokens >= requestedTokens) {
                tokens -= requestedTokens;
                return true;
            }
            return false;
        }

        private void refill() {
            long now = System.currentTimeMillis();
            long elapsedMs = now - lastRefillTimestamp;
            if (elapsedMs > 0) {
                double tokensToAdd = (elapsedMs / 1000.0) * refillRatePerSecond;
                this.tokens = Math.min(capacity, tokens + tokensToAdd);
                this.lastRefillTimestamp = now;
            }
        }
    }

    private final TokenBucket globalBucket;
    private final double perPeerCapacity;
    private final double perPeerRefillRate;
    private final Map<String, TokenBucket> peerBuckets = new ConcurrentHashMap<>();

    public SignalingRateLimiter() {
        // Defaults: Global max 20 burst, 10/sec; Per-peer max 10 burst, 3/sec
        this(20, 10, 10, 3);
    }

    public SignalingRateLimiter(double globalCapacity, double globalRefillRatePerSec,
                                double perPeerCapacity, double perPeerRefillRatePerSec) {
        this.globalBucket = new TokenBucket(globalCapacity, globalRefillRatePerSec);
        this.perPeerCapacity = perPeerCapacity;
        this.perPeerRefillRate = perPeerRefillRatePerSec;
    }

    public boolean tryAcquire(String recipientPeerId) {
        Objects.requireNonNull(recipientPeerId, "recipientPeerId must not be null");

        // 1. Check global rate limit
        if (!globalBucket.tryAcquire(1.0)) {
            return false;
        }

        // 2. Check per-peer rate limit
        TokenBucket peerBucket = peerBuckets.computeIfAbsent(
                recipientPeerId,
                k -> new TokenBucket(perPeerCapacity, perPeerRefillRate)
        );

        return peerBucket.tryAcquire(1.0);
    }

    public void acquireOrThrow(String recipientPeerId) throws SignalingRateLimitException {
        if (!tryAcquire(recipientPeerId)) {
            throw new SignalingRateLimitException("Signaling rate limit exceeded for recipient peer: " + recipientPeerId);
        }
    }

    public void reset() {
        peerBuckets.clear();
    }
}
