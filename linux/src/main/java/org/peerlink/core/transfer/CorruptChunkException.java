package org.peerlink.core.transfer;

/**
 * Thrown when a transferred chunk fails cryptographic integrity verification.
 */
public class CorruptChunkException extends Exception {
    private final String transferId;
    private final int itemIndex;
    private final long chunkIndex;
    private final String expectedSha256;
    private final String computedSha256;

    public CorruptChunkException(
            String transferId,
            int itemIndex,
            long chunkIndex,
            String expectedSha256,
            String computedSha256) {
        super(String.format("Corrupt chunk detected in transfer [%s] item [%d] chunk [%d]: expected=%s, computed=%s",
                transferId, itemIndex, chunkIndex, expectedSha256, computedSha256));
        this.transferId = transferId;
        this.itemIndex = itemIndex;
        this.chunkIndex = chunkIndex;
        this.expectedSha256 = expectedSha256;
        this.computedSha256 = computedSha256;
    }

    public String getTransferId() {
        return transferId;
    }

    public int getItemIndex() {
        return itemIndex;
    }

    public long getChunkIndex() {
        return chunkIndex;
    }

    public String getExpectedSha256() {
        return expectedSha256;
    }

    public String getComputedSha256() {
        return computedSha256;
    }
}
