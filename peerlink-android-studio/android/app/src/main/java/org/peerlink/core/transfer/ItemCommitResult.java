package org.peerlink.core.transfer;

import java.nio.file.Path;

/**
 * Detailed commit status of a single item in a multi-file transfer batch.
 */
public final class ItemCommitResult {
    private final int itemIndex;
    private final String relativePath;
    private final Path resolvedDestination;
    private final boolean committed;
    private final String errorMessage;

    public ItemCommitResult(
            int itemIndex,
            String relativePath,
            Path resolvedDestination,
            boolean committed,
            String errorMessage) {
        this.itemIndex = itemIndex;
        this.relativePath = relativePath;
        this.resolvedDestination = resolvedDestination;
        this.committed = committed;
        this.errorMessage = errorMessage;
    }

    public int getItemIndex() { return itemIndex; }
    public String getRelativePath() { return relativePath; }
    public Path getResolvedDestination() { return resolvedDestination; }
    public boolean isCommitted() { return committed; }
    public String getErrorMessage() { return errorMessage; }

    @Override
    public String toString() {
        return "ItemCommitResult{" +
                "index=" + itemIndex +
                ", path='" + relativePath + '\'' +
                ", dest=" + resolvedDestination +
                ", committed=" + committed +
                (errorMessage != null ? ", error='" + errorMessage + '\'' : "") +
                '}';
    }
}
