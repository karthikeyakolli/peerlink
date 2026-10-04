package org.peerlink.core.ai.policy;

import java.util.Objects;

/**
 * Result of deterministic policy evaluation on an AI proposal.
 */
public final class PolicyValidationResult {
    public enum Status {
        ALLOWED,
        REQUIRES_USER_CONFIRMATION,
        BLOCKED_BY_POLICY,
        SECURITY_VIOLATION
    }

    private final Status status;
    private final String reason;

    public PolicyValidationResult(Status status, String reason) {
        this.status = Objects.requireNonNull(status, "status is required");
        this.reason = reason != null ? reason : "";
    }

    public static PolicyValidationResult allowed(String reason) {
        return new PolicyValidationResult(Status.ALLOWED, reason);
    }

    public static PolicyValidationResult requiresConfirmation(String reason) {
        return new PolicyValidationResult(Status.REQUIRES_USER_CONFIRMATION, reason);
    }

    public static PolicyValidationResult blocked(String reason) {
        return new PolicyValidationResult(Status.BLOCKED_BY_POLICY, reason);
    }

    public static PolicyValidationResult violation(String reason) {
        return new PolicyValidationResult(Status.SECURITY_VIOLATION, reason);
    }

    public Status getStatus() { return status; }
    public String getReason() { return reason; }
    public boolean isAllowed() { return status == Status.ALLOWED; }
    public boolean isPermissibleWithUserConsent() {
        return status == Status.ALLOWED || status == Status.REQUIRES_USER_CONFIRMATION;
    }

    @Override
    public String toString() {
        return "PolicyValidationResult{status=" + status + ", reason='" + reason + "'}";
    }
}
