package org.peerlink.core.cloud.supabase;

import java.io.IOException;

/**
 * Thrown when the Supabase control plane experiences an outage, network partition,
 * or when the client-side circuit breaker trips.
 * Signals to PeerLink engine to degrade gracefully into local offline/P2P mode.
 */
public class SupabaseOutageException extends IOException {

    private final int statusCode;
    private final boolean circuitBreakerOpen;

    public SupabaseOutageException(String message) {
        this(message, 0, false, null);
    }

    public SupabaseOutageException(String message, Throwable cause) {
        this(message, 0, false, cause);
    }

    public SupabaseOutageException(String message, int statusCode) {
        this(message, statusCode, false, null);
    }

    public SupabaseOutageException(String message, int statusCode, boolean circuitBreakerOpen, Throwable cause) {
        super(message, cause);
        this.statusCode = statusCode;
        this.circuitBreakerOpen = circuitBreakerOpen;
    }

    public int getStatusCode() {
        return statusCode;
    }

    public boolean isCircuitBreakerOpen() {
        return circuitBreakerOpen;
    }
}
