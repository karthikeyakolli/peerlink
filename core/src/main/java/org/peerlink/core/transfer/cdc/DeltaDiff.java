package org.peerlink.core.transfer.cdc;

import java.util.List;

/**
 * Result of computing the difference between a target manifest and a local base manifest.
 * Contains the list of missing chunks that need transmission, as well as bandwidth statistics.
 */
public record DeltaDiff(
        List<ContentDefinedChunk> missingChunks,
        int reusedChunkCount,
        long reusedBytes,
        long transferredBytes,
        long totalBytes
) {
    public int transferredChunkCount() {
        return missingChunks.size();
    }

    public double bandwidthReductionPercentage() {
        if (totalBytes == 0) {
            return 100.0;
        }
        return ((double) reusedBytes / totalBytes) * 100.0;
    }
}
