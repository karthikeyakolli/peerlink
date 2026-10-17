package org.peerlink.core.transfer.cdc;

import java.util.Objects;

/**
 * Immutable representation of a content-defined chunk produced by FastCDC.
 * Contains byte position, length, and content digest.
 */
public record ContentDefinedChunk(
        int chunkIndex,
        long offsetBytes,
        int lengthBytes,
        String sha256Hex
) {
    public ContentDefinedChunk {
        if (chunkIndex < 0) {
            throw new IllegalArgumentException("chunkIndex must be non-negative: " + chunkIndex);
        }
        if (offsetBytes < 0) {
            throw new IllegalArgumentException("offsetBytes must be non-negative: " + offsetBytes);
        }
        if (lengthBytes <= 0) {
            throw new IllegalArgumentException("lengthBytes must be strictly positive: " + lengthBytes);
        }
        Objects.requireNonNull(sha256Hex, "sha256Hex must not be null");
    }
}
