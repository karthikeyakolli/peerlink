package org.peerlink.core.transfer;

import org.peerlink.protocol.v1.TransferManifest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.FileStore;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Executes preflight resource checks before initiating or accepting a transfer.
 *
 * <p>Invariants:
 * <ul>
 *   <li>The destination drive must have sufficient free space for the total transfer size plus safety reserve.</li>
 *   <li>The destination path must be writable and accessible.</li>
 *   <li>Failing preflight halts the operation before any network streaming or partial disk writes occur.</li>
 * </ul>
 */
public final class TransferPreflight {
    private static final Logger log = LoggerFactory.getLogger(TransferPreflight.class);

    /** Default safety margin reserved on disk (10 MB). */
    public static final long DEFAULT_SAFETY_RESERVE_BYTES = 10L * 1024 * 1024;

    private final long safetyReserveBytes;

    public TransferPreflight() {
        this(DEFAULT_SAFETY_RESERVE_BYTES);
    }

    public TransferPreflight(long safetyReserveBytes) {
        this.safetyReserveBytes = safetyReserveBytes;
    }

    /**
     * Check if destination path has sufficient usable disk space and write permission for the manifest.
     *
     * @param destinationDir Destination root folder where received files will be placed
     * @param manifest The transfer manifest describing payload size
     * @throws PreflightException if disk is full or destination is unavailable
     */
    public void checkDestination(Path destinationDir, TransferManifest manifest) throws PreflightException {
        checkDestination(destinationDir, manifest.getTotalBytes());
    }

    /**
     * Check if destination path has sufficient usable disk space and write permission for the given byte count.
     */
    public void checkDestination(Path destinationDir, long requiredBytes) throws PreflightException {
        try {
            if (!Files.exists(destinationDir)) {
                try {
                    Files.createDirectories(destinationDir);
                } catch (Exception e) {
                    throw new PreflightException(
                            PreflightException.PreflightErrorCode.DESTINATION_UNAVAILABLE,
                            "Cannot create destination directory: " + destinationDir + " (" + e.getMessage() + ")");
                }
            }

            if (!Files.isWritable(destinationDir)) {
                throw new PreflightException(
                        PreflightException.PreflightErrorCode.PERMISSION_DENIED,
                        "Destination directory is not writable: " + destinationDir);
            }

            long usableSpace;
            try {
                usableSpace = Files.getFileStore(destinationDir).getUsableSpace();
            } catch (Exception | LinkageError e) {
                // Fallback to java.io.File statvfs which succeeds on Android sandbox
                try {
                    usableSpace = destinationDir.toFile().getUsableSpace();
                } catch (Exception ignored) {
                    usableSpace = Long.MAX_VALUE;
                }
            }

            long neededSpace = requiredBytes + safetyReserveBytes;

            if (usableSpace > 0 && usableSpace < neededSpace) {
                log.error("Insufficient disk space on destination store: usable={} bytes, needed={} bytes",
                        usableSpace, neededSpace);
                throw new PreflightException(
                        PreflightException.PreflightErrorCode.INSUFFICIENT_DISK_SPACE,
                        String.format("Insufficient disk space: %d bytes usable, %d bytes needed (including %d reserve)",
                                usableSpace, neededSpace, safetyReserveBytes));
            }
        } catch (PreflightException e) {
            throw e;
        } catch (Exception e) {
            throw new PreflightException(
                    PreflightException.PreflightErrorCode.DESTINATION_UNAVAILABLE,
                    "Failed to query destination file store: " + e.getMessage());
        }
    }
}
