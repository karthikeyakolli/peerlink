package org.peerlink.core.ai.model;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Tracks token expenditure and enforces limits to prevent unbounded cloud spend.
 */
public final class TokenBudget {
    private final long maxMonthlyTokens;
    private final AtomicLong usedTokens = new AtomicLong(0);

    public TokenBudget(long maxMonthlyTokens) {
        this.maxMonthlyTokens = maxMonthlyTokens;
    }

    public boolean canConsume(long estimatedTokens) {
        return (usedTokens.get() + estimatedTokens) <= maxMonthlyTokens;
    }

    public void recordUsage(long tokens) {
        usedTokens.addAndGet(tokens);
    }

    public long getUsedTokens() {
        return usedTokens.get();
    }

    public long getRemainingTokens() {
        return Math.max(0, maxMonthlyTokens - usedTokens.get());
    }

    public void reset() {
        usedTokens.set(0);
    }
}
