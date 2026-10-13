package org.peerlink.core.ai.model;

import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.operation.OperationIntent;

import java.util.*;

/**
 * Deterministic proposal produced by the AI Gateway.
 *
 * INVARIANTS:
 * - Proposes structured identifiers (ObjectIdentity), NOT raw or stale filesystem paths.
 * - AI proposal is never authoritative; must pass through DeterministicAiPolicyEngine
 *   and current-state revalidation before reaching OperationManager.
 */
public final class AiProposal {
    public static final long DEFAULT_TTL_MS = 300_000L; // 5 minutes TTL

    private final String proposalId;
    private final AiProposalType type;
    private final String naturalLanguageQuery;
    private final String justification;
    private final OperationIntent mappedIntent;
    private final List<ObjectIdentity> targetObjectIds;
    private final Map<ObjectIdentity, ContentHash> expectedHashes;
    private final String targetPeerId;
    private final Map<String, Object> parameters;
    private final boolean requiresUserConfirmation;
    private final long proposedAtUtcMs;
    private final long ttlMs;

    public AiProposal(
            String proposalId,
            AiProposalType type,
            String naturalLanguageQuery,
            String justification,
            OperationIntent mappedIntent,
            List<ObjectIdentity> targetObjectIds,
            Map<ObjectIdentity, ContentHash> expectedHashes,
            String targetPeerId,
            Map<String, Object> parameters,
            boolean requiresUserConfirmation) {
        this(proposalId, type, naturalLanguageQuery, justification, mappedIntent,
                targetObjectIds, expectedHashes, targetPeerId, parameters, requiresUserConfirmation, DEFAULT_TTL_MS);
    }

    public AiProposal(
            String proposalId,
            AiProposalType type,
            String naturalLanguageQuery,
            String justification,
            OperationIntent mappedIntent,
            List<ObjectIdentity> targetObjectIds,
            Map<ObjectIdentity, ContentHash> expectedHashes,
            String targetPeerId,
            Map<String, Object> parameters,
            boolean requiresUserConfirmation,
            long ttlMs) {
        this.proposalId = Objects.requireNonNull(proposalId, "proposalId is required");
        this.type = Objects.requireNonNull(type, "type is required");
        this.naturalLanguageQuery = naturalLanguageQuery != null ? naturalLanguageQuery : "";
        this.justification = justification != null ? justification : "";
        this.mappedIntent = mappedIntent;
        this.targetObjectIds = targetObjectIds != null ? Collections.unmodifiableList(targetObjectIds) : Collections.emptyList();
        this.expectedHashes = expectedHashes != null ? Collections.unmodifiableMap(expectedHashes) : Collections.emptyMap();
        this.targetPeerId = targetPeerId;
        this.parameters = parameters != null ? Collections.unmodifiableMap(parameters) : Collections.emptyMap();
        this.requiresUserConfirmation = requiresUserConfirmation;
        this.proposedAtUtcMs = System.currentTimeMillis();
        this.ttlMs = ttlMs > 0 ? ttlMs : DEFAULT_TTL_MS;
    }

    public String getProposalId() {
        return proposalId;
    }

    public AiProposalType getType() {
        return type;
    }

    public String getNaturalLanguageQuery() {
        return naturalLanguageQuery;
    }

    public String getJustification() {
        return justification;
    }

    public OperationIntent getMappedIntent() {
        return mappedIntent;
    }

    public List<ObjectIdentity> getTargetObjectIds() {
        return targetObjectIds;
    }

    public Map<ObjectIdentity, ContentHash> getExpectedHashes() {
        return expectedHashes;
    }

    public String getTargetPeerId() {
        return targetPeerId;
    }

    public Map<String, Object> getParameters() {
        return parameters;
    }

    public boolean isRequiresUserConfirmation() {
        return requiresUserConfirmation;
    }

    public long getProposedAtUtcMs() {
        return proposedAtUtcMs;
    }

    public long getTtlMs() {
        return ttlMs;
    }

    public boolean isExpired() {
        return isExpired(System.currentTimeMillis());
    }

    public boolean isExpired(long currentUtcMs) {
        return (currentUtcMs - proposedAtUtcMs) > ttlMs;
    }

    @Override
    public String toString() {
        return "AiProposal{id='" + proposalId + "', type=" + type + ", intent=" + mappedIntent + ", targets=" + targetObjectIds.size() + "}";
    }
}
