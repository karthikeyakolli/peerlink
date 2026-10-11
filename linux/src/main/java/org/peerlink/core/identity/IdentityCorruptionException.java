package org.peerlink.core.identity;

/**
 * Thrown when an existing identity record in storage is incomplete, malformed, or tampered.
 * Mandatory invariant: Never silently regenerate an identity because a file or table
 * is temporarily unavailable or invalid!
 */
public class IdentityCorruptionException extends RuntimeException {

    public IdentityCorruptionException(String message) {
        super(message);
    }

    public IdentityCorruptionException(String message, Throwable cause) {
        super(message, cause);
    }
}
