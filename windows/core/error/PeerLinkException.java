package org.peerlink.core.error;

/**
 * Standard typed application exception for PeerLink.
 */
public class PeerLinkException extends RuntimeException {
    private final ErrorCode errorCode;

    public PeerLinkException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public PeerLinkException(ErrorCode errorCode, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }

    @Override
    public String toString() {
        return "PeerLinkException[" + errorCode.getCode() + ": " + getMessage() + "]";
    }
}
