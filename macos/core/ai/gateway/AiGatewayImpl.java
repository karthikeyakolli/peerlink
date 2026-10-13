package org.peerlink.core.ai.gateway;

import org.peerlink.core.ai.model.*;
import org.peerlink.core.ai.policy.*;
import org.peerlink.core.ai.provider.AiProvider;
import org.peerlink.core.ai.provider.AiProviderRegistry;
import org.peerlink.core.model.ContentHash;
import org.peerlink.core.model.ObjectIdentity;
import org.peerlink.core.operation.OperationIntent;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Authoritative implementation of the PeerLink AI Gateway.
 */
public class AiGatewayImpl implements AiGateway {

    private final AiProviderRegistry providerRegistry;
    private final DeterministicAiPolicyEngine policyEngine;
    private final RateLimiter rateLimiter;
    private final TokenBudget tokenBudget;
    private final List<AiAuditRecord> auditTrail = new CopyOnWriteArrayList<>();
    private volatile boolean sensitiveDisclosureAuthorized = false;

    public AiGatewayImpl(AiProviderRegistry providerRegistry) {
        this(providerRegistry, new DeterministicAiPolicyEngine(), new RateLimiter(60), new TokenBudget(1_000_000));
    }

    public AiGatewayImpl(
            AiProviderRegistry providerRegistry,
            DeterministicAiPolicyEngine policyEngine,
            RateLimiter rateLimiter,
            TokenBudget tokenBudget) {
        this.providerRegistry = Objects.requireNonNull(providerRegistry, "providerRegistry is required");
        this.policyEngine = Objects.requireNonNull(policyEngine, "policyEngine is required");
        this.rateLimiter = Objects.requireNonNull(rateLimiter, "rateLimiter is required");
        this.tokenBudget = Objects.requireNonNull(tokenBudget, "tokenBudget is required");
    }

    @Override
    public boolean isSensitiveDisclosureAuthorized() {
        return sensitiveDisclosureAuthorized;
    }

    @Override
    public void setSensitiveDisclosureAuthorized(boolean authorized) {
        this.sensitiveDisclosureAuthorized = authorized;
    }

    @Override
    public AiResponse executeRequest(AiRequest request) throws IOException {
        Objects.requireNonNull(request, "request is required");

        // 1. Rate limiter check
        if (!rateLimiter.tryAcquire()) {
            recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                    AiAuditRecord.Outcome.RATE_LIMITED, "Rate limit exceeded (requests per minute)", 0, 0);
            throw new IOException("AI Gateway rate limit exceeded. Please throttle requests.");
        }

        // 2. Token budget check
        if (!tokenBudget.canConsume(request.getMaxTokens())) {
            recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                    AiAuditRecord.Outcome.POLICY_BLOCKED, "Monthly token budget exhausted", 0, 0);
            throw new IOException("AI Gateway monthly token budget exhausted.");
        }

        // 3. Context Sanitization & Secret Redaction (respecting sensitive disclosure authorization)
        List<AiMessage> sanitizedMessages = SanitizedContextFilter.sanitize(request.getMessages(), sensitiveDisclosureAuthorized);
        AiRequest sanitizedRequest = new AiRequest(
                request.getRequestId(),
                sanitizedMessages,
                request.getTools(),
                request.getTemperature(),
                request.getMaxTokens()
        );

        // 4. Resolve Active Provider with Fallback
        Optional<AiProvider> providerOpt = providerRegistry.getActiveProvider();
        if (providerOpt.isEmpty()) {
            recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                    AiAuditRecord.Outcome.PROVIDER_ERROR, "No AI provider available or configured", 0, 0);
            throw new IOException("No AI provider available. Check network or API configuration.");
        }

        AiProvider provider = providerOpt.get();
        long start = System.currentTimeMillis();
        AiResponse response;
        try {
            response = provider.generateResponse(sanitizedRequest);
        } catch (java.io.InterruptedIOException e) {
            long latency = System.currentTimeMillis() - start;
            recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                    AiAuditRecord.Outcome.PROVIDER_ERROR, "Model provider timeout: " + e.getMessage(), 0, latency);
            throw e;
        } catch (IOException e) {
            long latency = System.currentTimeMillis() - start;
            recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                    AiAuditRecord.Outcome.PROVIDER_ERROR, e.getMessage(), 0, latency);
            throw e;
        }

        long latency = System.currentTimeMillis() - start;
        // Enforce response safety limits & schema bounds
        if (response == null || response.getContent() == null ||
                (response.getContent().isBlank() && response.getToolCalls().isEmpty()) ||
                response.getContent().length() > 65536 || response.getToolCalls().size() > 20) {
            recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                    AiAuditRecord.Outcome.VALIDATION_FAILED, "Model output exceeds safety bounds or is malformed", 0, latency);
            throw new IOException("Model output exceeds defined safety limits or is malformed");
        }

        tokenBudget.recordUsage(response.getTotalTokens());
        recordAudit(request.getRequestId(), null, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                AiAuditRecord.Outcome.PROPOSED, "Generated successfully by " + provider.getProviderType(),
                response.getTotalTokens(), latency);

        return response;
    }

    @Override
    public PolicyValidationResult validateProposal(AiProposal proposal) {
        PolicyValidationResult result = policyEngine.evaluate(proposal);
        AiAuditRecord.Outcome outcome;
        switch (result.getStatus()) {
            case ALLOWED:
                outcome = AiAuditRecord.Outcome.PROPOSED;
                break;
            case REQUIRES_USER_CONFIRMATION:
                outcome = AiAuditRecord.Outcome.PROPOSED;
                break;
            case SECURITY_VIOLATION:
                outcome = AiAuditRecord.Outcome.POLICY_BLOCKED;
                break;
            default:
                outcome = AiAuditRecord.Outcome.POLICY_BLOCKED;
                break;
        }

        recordAudit("val_" + UUID.randomUUID(), proposal.getProposalId(), proposal.getType(),
                outcome, result.getReason(), 0, 0);
        return result;
    }

    @Override
    public AiProposal proposeSearch(String naturalLanguageQuery) {
        String propId = "prop_search_" + UUID.randomUUID();
        recordAudit("req_" + UUID.randomUUID(), propId, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                AiAuditRecord.Outcome.PROPOSED, "Search proposal generated", 0, 0);
        return new AiProposal(
                propId,
                AiProposalType.NATURAL_LANGUAGE_SEARCH,
                naturalLanguageQuery,
                "User requested natural language file search",
                null,
                Collections.emptyList(),
                Collections.emptyMap(),
                null,
                Map.of("query", naturalLanguageQuery),
                false
        );
    }

    @Override
    public AiProposal proposeSmartShare(String userPrompt, String targetPeerId, List<ObjectIdentity> objects, long durationSeconds) {
        String propId = "prop_share_" + UUID.randomUUID();
        recordAudit("req_" + UUID.randomUUID(), propId, AiProposalType.SMART_SHARE,
                AiAuditRecord.Outcome.PROPOSED, "Smart share proposal generated", 0, 0);
        return new AiProposal(
                propId,
                AiProposalType.SMART_SHARE,
                userPrompt,
                "Smart Share proposed for " + durationSeconds + "s",
                OperationIntent.ACCESS,
                objects,
                Collections.emptyMap(),
                targetPeerId,
                Map.of("durationSeconds", durationSeconds),
                true // Requires explicit user confirmation
        );
    }

    @Override
    public AiProposal proposeSmartBundle(String userPrompt, String bundleName, List<ObjectIdentity> objects) {
        String propId = "prop_bundle_" + UUID.randomUUID();
        recordAudit("req_" + UUID.randomUUID(), propId, AiProposalType.SMART_BUNDLE,
                AiAuditRecord.Outcome.PROPOSED, "Smart bundle proposal generated", 0, 0);
        return new AiProposal(
                propId,
                AiProposalType.SMART_BUNDLE,
                userPrompt,
                "Smart Bundle for: " + bundleName,
                OperationIntent.SEND,
                objects,
                Collections.emptyMap(),
                null,
                Map.of("bundleName", bundleName),
                true // Requires confirmation
        );
    }

    @Override
    public AiProposal proposeTransferRecipe(String userPrompt, String recurrenceSchedule, String targetPeerId, List<ObjectIdentity> objects) {
        String propId = "prop_recipe_" + UUID.randomUUID();
        recordAudit("req_" + UUID.randomUUID(), propId, AiProposalType.TRANSFER_RECIPE,
                AiAuditRecord.Outcome.PROPOSED, "Transfer recipe proposal generated", 0, 0);
        return new AiProposal(
                propId,
                AiProposalType.TRANSFER_RECIPE,
                userPrompt,
                "Transfer Recipe: " + recurrenceSchedule,
                OperationIntent.SEND,
                objects,
                Collections.emptyMap(),
                targetPeerId,
                Map.of("recurrence", recurrenceSchedule),
                true // Requires confirmation
        );
    }

    @Override
    public String explainCompatibility(String fileName, String targetPlatform, String deterministicDetails) {
        return String.format(
                "File '%s' compatibility analysis for %s:\n%s\nPeerLink never silently converts or executes unsupported files.",
                fileName, targetPlatform, deterministicDetails);
    }

    @Override
    public String explainDiagnostics(String connectionType, String natType, String diagnosticDetails) {
        return String.format(
                "Diagnostic explanation:\n- Active Transport: %s\n- Local NAT Profile: %s\n- Reason: %s\nPeerLink selects relay only when direct UDP/TCP paths are unavailable.",
                connectionType, natType, diagnosticDetails);
    }

    @Override
    public String explainSyncStatus(String folderName, String syncStatus, String conflictDetails) {
        return String.format(
                "Sync assistant for folder '%s':\n- Status: %s\n- Details: %s\nDeterministic causal resolution preserves non-conflicting versions.",
                folderName, syncStatus, conflictDetails);
    }

    @Override
    public List<AiAuditRecord> getAuditTrail() {
        return Collections.unmodifiableList(auditTrail);
    }

    @Override
    public AiProposal fallbackSearch(String query, List<ObjectIdentity> availableObjects, Map<ObjectIdentity, String> objectNames) {
        Objects.requireNonNull(query, "query is required");
        String lowerQuery = query.toLowerCase().trim();
        List<ObjectIdentity> matchedObjects = new ArrayList<>();

        if (availableObjects != null && objectNames != null) {
            for (ObjectIdentity objId : availableObjects) {
                String name = objectNames.get(objId);
                if (name != null) {
                    String lowerName = name.toLowerCase();
                    if (lowerName.contains(lowerQuery) ||
                        (lowerQuery.startsWith("*.") && lowerName.endsWith(lowerQuery.substring(1))) ||
                        (lowerQuery.equals("pdf") && lowerName.endsWith(".pdf"))) {
                        matchedObjects.add(objId);
                    }
                }
            }
        }

        String propId = "prop_fallback_search_" + UUID.randomUUID();
        recordAudit("req_" + UUID.randomUUID(), propId, AiProposalType.NATURAL_LANGUAGE_SEARCH,
                AiAuditRecord.Outcome.PROPOSED, "Deterministic non-AI fallback search executed", 0, 0);

        Map<String, Object> params = new HashMap<>();
        params.put("query", query);
        params.put("isDeterministicFallback", true);
        params.put("matchCount", matchedObjects.size());

        return new AiProposal(
                propId,
                AiProposalType.NATURAL_LANGUAGE_SEARCH,
                query,
                "Deterministic local keyword search without AI model",
                null,
                matchedObjects,
                Collections.emptyMap(),
                null,
                params,
                false
        );
    }

    private void recordAudit(String reqId, String propId, AiProposalType type, AiAuditRecord.Outcome outcome, String reason, int tokens, long latencyMs) {
        auditTrail.add(new AiAuditRecord(
                "aud_" + UUID.randomUUID(),
                reqId,
                propId,
                providerRegistry.getActiveProvider().map(p -> p.getProviderType().name()).orElse("NONE"),
                providerRegistry.getActiveProvider().map(AiProvider::getModelName).orElse("NONE"),
                "User AI request",
                type,
                outcome,
                reason,
                tokens,
                latencyMs
        ));
    }
}
