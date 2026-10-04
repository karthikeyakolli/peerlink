package org.peerlink.core.operation;

/**
 * Thrown when a second operation submission arrives with the same idempotency key
 * but a different operation ID — this indicates a duplicate request that cannot be
 * safely merged.
 */
public final class DuplicateOperationException extends RuntimeException {
    private final String idempotencyKey;
    private final String existingOperationId;

    public DuplicateOperationException(String idempotencyKey, String existingOperationId) {
        super("Duplicate idempotency key [" + idempotencyKey + "] already maps to operation [" + existingOperationId + "]");
        this.idempotencyKey = idempotencyKey;
        this.existingOperationId = existingOperationId;
    }

    public String getIdempotencyKey() { return idempotencyKey; }
    public String getExistingOperationId() { return existingOperationId; }
}
