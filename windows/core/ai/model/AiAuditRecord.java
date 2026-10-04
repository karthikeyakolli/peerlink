package org.peerlink.core.ai.model;

import java.util.Objects;

/**
 * Immutable audit trail record for AI actions.
 * Never stores raw credentials, private keys, or clipboard contents.
 */
public final class AiAuditRecord {
    public enum Outcome {
        PROPOSED,
        CONFIRMED_AND_QUEUED,
        USER_REJECTED,
        POLICY_BLOCKED,
        VALIDATION_FAILED,
        PROVIDER_ERROR,
        RATE_LIMITED
    }

    private final String auditId;
    private final String requestId;
    private final String proposalId;
    private final String providerName;
    private final String modelName;
    private final String userPromptSanitized;
    private final AiProposalType proposalType;
    private final Outcome outcome;
    private final String reason;
    private final int tokenUsage;
    private final long latencyMs;
    private final long timestampUtcMs;

    public AiAuditRecord(
            String auditId,
            String requestId,
            String proposalId,
            String providerName,
            String modelName,
            String userPromptSanitized,
            AiProposalType proposalType,
            Outcome outcome,
            String reason,
            int tokenUsage,
            long latencyMs) {
        this.auditId = Objects.requireNonNull(auditId, "auditId is required");
        this.requestId = requestId;
        this.proposalId = proposalId;
        this.providerName = providerName != null ? providerName : "UNKNOWN";
        this.modelName = modelName != null ? modelName : "UNKNOWN";
        this.userPromptSanitized = userPromptSanitized != null ? userPromptSanitized : "";
        this.proposalType = proposalType;
        this.outcome = Objects.requireNonNull(outcome, "outcome is required");
        this.reason = reason != null ? reason : "";
        this.tokenUsage = tokenUsage;
        this.latencyMs = latencyMs;
        this.timestampUtcMs = System.currentTimeMillis();
    }

    public String getAuditId() { return auditId; }
    public String getRequestId() { return requestId; }
    public String getProposalId() { return proposalId; }
    public String getProviderName() { return providerName; }
    public String getModelName() { return modelName; }
    public String getUserPromptSanitized() { return userPromptSanitized; }
    public AiProposalType getProposalType() { return proposalType; }
    public Outcome getOutcome() { return outcome; }
    public String getReason() { return reason; }
    public int getTokenUsage() { return tokenUsage; }
    public long getLatencyMs() { return latencyMs; }
    public long getTimestampUtcMs() { return timestampUtcMs; }

    @Override
    public String toString() {
        return "AiAuditRecord{" +
                "auditId='" + auditId + '\'' +
                ", outcome=" + outcome +
                ", type=" + proposalType +
                ", tokens=" + tokenUsage +
                '}';
    }
}
