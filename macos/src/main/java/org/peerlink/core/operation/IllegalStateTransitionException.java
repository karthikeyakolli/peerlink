package org.peerlink.core.operation;

/**
 * Thrown when an attempted operation state transition violates the allowed
 * state machine rules — e.g., trying to move a COMMITTED operation back to
 * EXECUTING, or advancing directly from CREATED to COMMITTED.
 */
public final class IllegalStateTransitionException extends RuntimeException {
    private final String operationId;
    private final OperationState from;
    private final OperationState to;

    public IllegalStateTransitionException(String operationId, OperationState from, OperationState to) {
        super("Illegal state transition for operation [" + operationId + "]: " + from + " → " + to);
        this.operationId = operationId;
        this.from = from;
        this.to = to;
    }

    public String getOperationId() { return operationId; }
    public OperationState getFrom() { return from; }
    public OperationState getTo() { return to; }
}
