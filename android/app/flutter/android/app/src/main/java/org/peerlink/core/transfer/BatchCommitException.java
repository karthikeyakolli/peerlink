package org.peerlink.core.transfer;

import java.io.IOException;

/**
 * Thrown when one or more items fail during a multi-file batch commit.
 * Carries the granular BatchCommitResult recording which items were committed
 * and which failed, preventing false claims of atomicity and enabling recovery.
 */
public class BatchCommitException extends IOException {
    private final BatchCommitResult commitResult;

    public BatchCommitException(String message, BatchCommitResult commitResult, Throwable cause) {
        super(message, cause);
        this.commitResult = commitResult;
    }

    public BatchCommitException(String message, BatchCommitResult commitResult) {
        super(message);
        this.commitResult = commitResult;
    }

    public BatchCommitResult getCommitResult() {
        return commitResult;
    }
}
