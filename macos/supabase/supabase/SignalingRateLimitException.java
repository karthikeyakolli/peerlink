package org.peerlink.core.cloud.supabase;

import java.io.IOException;

/**
 * Thrown when outbound or inbound signaling rate limits are exceeded.
 */
public class SignalingRateLimitException extends IOException {
    public SignalingRateLimitException(String message) {
        super(message);
    }
}
