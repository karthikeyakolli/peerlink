package org.peerlink.core.transfer;

/**
 * Thrown when resource preflight checks fail before starting or accepting a transfer.
 */
public final class PreflightException extends RuntimeException {

    public enum PreflightErrorCode {
        INSUFFICIENT_DISK_SPACE,
        DESTINATION_UNAVAILABLE,
        SOURCE_UNAVAILABLE,
        PERMISSION_DENIED
    }

    private final PreflightErrorCode errorCode;

    public PreflightException(PreflightErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public PreflightErrorCode getErrorCode() {
        return errorCode;
    }
}
