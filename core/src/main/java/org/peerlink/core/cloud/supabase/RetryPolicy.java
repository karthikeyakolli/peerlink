package org.peerlink.core.cloud.supabase;

import java.io.IOException;
import java.util.Random;
import java.util.concurrent.Callable;

/**
 * Exponential backoff and retry strategy for idempotent Supabase operations.
 */
public final class RetryPolicy {

    private final int maxRetries;
    private final long initialDelayMs;
    private final long maxDelayMs;
    private final double backoffMultiplier;
    private final Random random = new Random();

    public RetryPolicy(int maxRetries, long initialDelayMs, long maxDelayMs, double backoffMultiplier) {
        this.maxRetries = Math.max(0, maxRetries);
        this.initialDelayMs = Math.max(10, initialDelayMs);
        this.maxDelayMs = Math.max(initialDelayMs, maxDelayMs);
        this.backoffMultiplier = Math.max(1.0, backoffMultiplier);
    }

    public static RetryPolicy defaultPolicy() {
        return new RetryPolicy(3, 200, 3000, 2.0);
    }

    public static RetryPolicy noRetry() {
        return new RetryPolicy(0, 0, 0, 1.0);
    }

    public <T> T execute(Callable<T> task, CircuitBreaker circuitBreaker) throws Exception {
        int attempt = 0;
        long currentDelay = initialDelayMs;

        while (true) {
            if (circuitBreaker != null) {
                circuitBreaker.checkPermission();
            }

            try {
                T result = task.call();
                if (circuitBreaker != null) {
                    circuitBreaker.recordSuccess();
                }
                return result;
            } catch (Exception e) {
                attempt++;
                if (circuitBreaker != null) {
                    circuitBreaker.recordFailure();
                }

                if (attempt > maxRetries || !isRetryable(e)) {
                    throw e;
                }

                // Add jitter
                long jitter = (long) (random.nextDouble() * 0.2 * currentDelay);
                long sleepTime = Math.min(maxDelayMs, currentDelay + jitter);

                try {
                    Thread.sleep(sleepTime);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new IOException("Operation interrupted during backoff", ie);
                }

                currentDelay = (long) (currentDelay * backoffMultiplier);
            }
        }
    }

    private boolean isRetryable(Exception e) {
        if (e instanceof SupabaseOutageException) {
            SupabaseOutageException soe = (SupabaseOutageException) e;
            return !soe.isCircuitBreakerOpen() && (soe.getStatusCode() >= 500 || soe.getStatusCode() == 429);
        }
        if (e instanceof IOException) {
            return true;
        }
        return false;
    }
}
