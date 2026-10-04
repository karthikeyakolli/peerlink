package org.peerlink.core.cloud.supabase;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

/**
 * Thread-safe Circuit Breaker for Supabase HTTP and WebSocket connections.
 * Prevents cascading delays during cloud outages and trips to local P2P mode.
 */
public final class CircuitBreaker {

    public enum State {
        CLOSED,
        OPEN,
        HALF_OPEN
    }

    private final int failureThreshold;
    private final long resetTimeoutMs;
    private final AtomicReference<State> state = new AtomicReference<>(State.CLOSED);
    private final AtomicInteger consecutiveFailures = new AtomicInteger(0);
    private final AtomicLong lastFailureTime = new AtomicLong(0);
    private Consumer<State> stateChangeListener;

    public CircuitBreaker(int failureThreshold, long resetTimeoutMs) {
        this.failureThreshold = Math.max(1, failureThreshold);
        this.resetTimeoutMs = Math.max(100, resetTimeoutMs);
    }

    public void setStateChangeListener(Consumer<State> listener) {
        this.stateChangeListener = listener;
    }

    public State getState() {
        if (state.get() == State.OPEN) {
            long elapsed = System.currentTimeMillis() - lastFailureTime.get();
            if (elapsed >= resetTimeoutMs) {
                transitionTo(State.HALF_OPEN);
            }
        }
        return state.get();
    }

    public synchronized void recordSuccess() {
        consecutiveFailures.set(0);
        if (state.get() != State.CLOSED) {
            transitionTo(State.CLOSED);
        }
    }

    public synchronized void recordFailure() {
        lastFailureTime.set(System.currentTimeMillis());
        int fails = consecutiveFailures.incrementAndGet();
        if (state.get() == State.HALF_OPEN || fails >= failureThreshold) {
            transitionTo(State.OPEN);
        }
    }

    public void checkPermission() throws SupabaseOutageException {
        State current = getState();
        if (current == State.OPEN) {
            throw new SupabaseOutageException(
                    "Circuit breaker is OPEN: Supabase control plane is temporarily unreachable",
                    503,
                    true,
                    null
            );
        }
    }

    public void reset() {
        consecutiveFailures.set(0);
        transitionTo(State.CLOSED);
    }

    private void transitionTo(State newState) {
        State oldState = state.getAndSet(newState);
        if (oldState != newState && stateChangeListener != null) {
            stateChangeListener.accept(newState);
        }
    }
}
