package org.peerlink.core.transfer;

import java.nio.file.Path;

/**
 * Thrown when a destination file already exists and the conflict policy rejects overwriting or renaming.
 */
public final class DestinationConflictException extends RuntimeException {
    private final Path conflictPath;

    public DestinationConflictException(Path conflictPath, String message) {
        super(message);
        this.conflictPath = conflictPath;
    }

    public Path getConflictPath() {
        return conflictPath;
    }
}
