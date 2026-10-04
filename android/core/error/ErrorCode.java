package org.peerlink.core.error;

/**
 * Standard machine-readable error codes in PeerLink.
 */
public enum ErrorCode {
    // Protocol / Transport
    PROTOCOL_VERSION_MISMATCH("ERR_PROTO_VERSION", false, "Upgrade node software"),
    TRANSPORT_UNAVAILABLE("ERR_TRANSPORT_UNAVAILABLE", true, "Check network connectivity or retry"),
    UNTRUSTED_PEER("ERR_PEER_UNTRUSTED", false, "Initiate authenticated pairing flow"),
    CONNECTION_LOST("ERR_CONN_LOST", true, "Reconnect or retry over fallback transport"),

    // Operations / Safety
    OPERATION_NOT_AUTHORIZED("ERR_OP_UNAUTHORIZED", false, "Verify access permissions and trust level"),
    INVALID_LIFECYCLE_STATE("ERR_INVALID_STATE", false, "Review operation journal and status"),
    DESTINATION_CONFLICT("ERR_DEST_CONFLICT", false, "Resolve destination name/path conflict"),
    HASH_MISMATCH("ERR_INTEGRITY_FAILED", false, "Re-transfer file payload or check storage"),
    SCANNER_DETECTED_THREAT("ERR_THREAT_DETECTED", false, "File quarantined by security policy"),

    // IPC
    UNAUTHORIZED_IPC_CLIENT("ERR_IPC_UNAUTHORIZED", false, "Provide valid local secret token"),
    IPC_COMMUNICATION_ERROR("ERR_IPC_FAILED", true, "Check daemon status and restart IPC");

    private final String code;
    private final boolean retryable;
    private final String recoveryAction;

    ErrorCode(String code, boolean retryable, String recoveryAction) {
        this.code = code;
        this.retryable = retryable;
        this.recoveryAction = recoveryAction;
    }

    public String getCode() { return code; }
    public boolean isRetryable() { return retryable; }
    public String getRecoveryAction() { return recoveryAction; }
}
