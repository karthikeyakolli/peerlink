package org.peerlink.core.transfer.compression;

/**
 * Representation of a processed block ready for wire transmission.
 */
public record CompressedBlock(
        byte[] payload,
        boolean isCompressed,
        int originalLength,
        int payloadLength
) {
    public double compressionRatio() {
        if (originalLength == 0) return 1.0;
        return (double) payloadLength / originalLength;
    }
}
