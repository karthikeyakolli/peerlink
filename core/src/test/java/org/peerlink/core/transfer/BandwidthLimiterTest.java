package org.peerlink.core.transfer;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;

public class BandwidthLimiterTest {

    @Test
    @Timeout(value = 5, unit = TimeUnit.SECONDS)
    public void testUnlimitedConsumption() throws InterruptedException {
        BandwidthLimiter limiter = new BandwidthLimiter(0);
        assertFalse(limiter.isLimited());
        limiter.consume(1_000_000); // should not block
    }

    @Test
    @Timeout(value = 5, unit = TimeUnit.SECONDS)
    public void testConsumeWithinRateLimit() throws InterruptedException {
        BandwidthLimiter limiter = new BandwidthLimiter(10_000);
        assertTrue(limiter.isLimited());
        assertEquals(10_000, limiter.getRateLimit());

        // Initial capacity allows immediate consumption
        limiter.consume(5_000);
    }

    @Test
    @Timeout(value = 5, unit = TimeUnit.SECONDS)
    public void testConsumeExceedingTokenBucketCapacityDoesNotHang() throws InterruptedException {
        // Bucket capacity is 2 * maxBytesPerSecond = 2,000 bytes.
        // Requesting 5,000 bytes previously caused an infinite loop!
        BandwidthLimiter limiter = new BandwidthLimiter(5_000);

        long start = System.currentTimeMillis();
        limiter.consume(6_000); // Exceeds bucket capacity of 5,000
        long elapsed = System.currentTimeMillis() - start;

        // Since initial capacity was 5,000, it consumes 5,000, then waits for ~1,000 bytes (approx 200ms)
        assertTrue(elapsed >= 150, "Should have throttled consumption");
    }

    @Test
    @Timeout(value = 5, unit = TimeUnit.SECONDS)
    public void testDynamicRateLimitUnthrottlesWaitingThread() throws Exception {
        BandwidthLimiter limiter = new BandwidthLimiter(100); // very slow limit

        // Drain available tokens
        limiter.consume(100);

        AtomicBoolean consumed = new AtomicBoolean(false);
        Thread t = new Thread(() -> {
            try {
                limiter.consume(1_000);
                consumed.set(true);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        t.start();

        Thread.sleep(100);
        assertFalse(consumed.get(), "Thread should be waiting for tokens");

        // Remove limit dynamically
        limiter.setRateLimit(0);
        t.join(1000);

        assertTrue(consumed.get(), "Thread should wake up immediately when limit is removed");
    }

    @Test
    @Timeout(value = 5, unit = TimeUnit.SECONDS)
    public void testInterruptionHandling() throws Exception {
        BandwidthLimiter limiter = new BandwidthLimiter(100);
        limiter.consume(100);

        AtomicBoolean interrupted = new AtomicBoolean(false);
        Thread t = new Thread(() -> {
            try {
                limiter.consume(10_000);
            } catch (InterruptedException e) {
                interrupted.set(true);
            }
        });
        t.start();
        Thread.sleep(100);
        t.interrupt();
        t.join(1000);

        assertTrue(interrupted.get(), "Consume should propagate InterruptedException cleanly");
    }
}
