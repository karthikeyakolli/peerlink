package org.peerlink.core.transfer;

import java.util.Collections;
import java.util.List;

/**
 * Result model representing the outcome of committing a multi-file batch to the filesystem.
 * Explicitly distinguishes verified committed items from failed or pending ones without
 * falsely claiming that multiple independent filesystem moves are a single atomic transaction.
 */
public final class BatchCommitResult {
    private final String transferId;
    private final String operationId;
    private final boolean fullyCommitted;
    private final List<ItemCommitResult> itemResults;
    private final long committedBytes;
    private final int totalItems;

    public BatchCommitResult(
            String transferId,
            String operationId,
            boolean fullyCommitted,
            List<ItemCommitResult> itemResults,
            long committedBytes,
            int totalItems) {
        this.transferId = transferId;
        this.operationId = operationId;
        this.fullyCommitted = fullyCommitted;
        this.itemResults = Collections.unmodifiableList(itemResults);
        this.committedBytes = committedBytes;
        this.totalItems = totalItems;
    }

    public String getTransferId() { return transferId; }
    public String getOperationId() { return operationId; }
    public boolean isFullyCommitted() { return fullyCommitted; }
    public List<ItemCommitResult> getItemResults() { return itemResults; }
    public long getCommittedBytes() { return committedBytes; }
    public int getTotalItems() { return totalItems; }

    public int getCommittedCount() {
        return (int) itemResults.stream().filter(ItemCommitResult::isCommitted).count();
    }

    public int getFailedCount() {
        return (int) itemResults.stream().filter(r -> !r.isCommitted()).count();
    }

    public boolean isPartiallyCommitted() {
        int committed = getCommittedCount();
        return committed > 0 && committed < totalItems;
    }

    @Override
    public String toString() {
        return String.format("BatchCommitResult{transferId='%s', committed=%d/%d, bytes=%d, full=%s}",
                transferId, getCommittedCount(), totalItems, committedBytes, fullyCommitted);
    }
}
