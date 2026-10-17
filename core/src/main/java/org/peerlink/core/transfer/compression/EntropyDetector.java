package org.peerlink.core.transfer.compression;

/**
 * Calculates Shannon entropy of byte sequences to determine compressibility.
 * High entropy (> 7.5 bits/byte out of 8.0) indicates encrypted or pre-compressed data
 * (JPEG, PNG, MP4, ZIP, etc.), allowing PeerLink to bypass compression and save CPU cycles.
 */
public final class EntropyDetector {

    public static final double COMPRESSIBILITY_THRESHOLD = 7.50;
    private static final int MAX_SAMPLE_BYTES = 4096;

    private EntropyDetector() {}

    /**
     * Compute Shannon entropy in bits per byte (0.0 to 8.0).
     */
    public static double calculateShannonEntropy(byte[] data) {
        if (data == null || data.length == 0) {
            return 0.0;
        }

        int sampleLen = Math.min(data.length, MAX_SAMPLE_BYTES);
        int[] frequencies = new int[256];

        for (int i = 0; i < sampleLen; i++) {
            frequencies[data[i] & 0xFF]++;
        }

        double entropy = 0.0;
        double log2 = Math.log(2.0);

        for (int count : frequencies) {
            if (count > 0) {
                double prob = (double) count / sampleLen;
                entropy -= prob * (Math.log(prob) / log2);
            }
        }

        return entropy;
    }

    /**
     * Returns true if the content has low-enough entropy to benefit from compression.
     */
    public static boolean isCompressible(byte[] data) {
        return calculateShannonEntropy(data) < COMPRESSIBILITY_THRESHOLD;
    }
}
