package org.peerlink.core.transfer;

/**
 * Thrown when SHA-256 cryptographic verification fails for a received item.
 */
public final class HashMismatchException extends RuntimeException {
    private final String expectedHash;
    private final String computedHash;

    public HashMismatchException(String itemPath, String expectedHash, String computedHash) {
        super(String.format("Cryptographic hash mismatch for item '%s': expected %s, computed %s",
                itemPath, expectedHash, computedHash));
        this.expectedHash = expectedHash;
        this.computedHash = computedHash;
    }

    public String getExpectedHash() { return expectedHash; }
    public String getComputedHash() { return computedHash; }
}
