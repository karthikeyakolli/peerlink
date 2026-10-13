package org.peerlink.core.ai.gateway;

import org.peerlink.core.ai.model.AiAuditRecord;
import org.peerlink.core.ai.model.AiProposal;
import org.peerlink.core.ai.policy.PolicyValidationResult;
import org.peerlink.core.model.ObjectIdentity;

import java.io.IOException;
import java.util.List;

/**
 * PeerLink AI Gateway contract.
 * Mediates all interactions between users/UI and LLM providers.
 */
public interface AiGateway {

    /**
     * Dispatches a structured request through sanitization, rate limiting, and provider routing.
     */
    AiResponse executeRequest(AiRequest request) throws IOException;

    /**
     * Evaluates an AI proposal against the deterministic policy engine.
     */
    PolicyValidationResult validateProposal(AiProposal proposal);

    /**
     * Proposes a natural language search over authorized index.
     */
    AiProposal proposeSearch(String naturalLanguageQuery);

    /**
     * Proposes a Smart Share action for specific objects and target peer.
     */
    AiProposal proposeSmartShare(String userPrompt, String targetPeerId, List<ObjectIdentity> objects, long durationSeconds);

    /**
     * Proposes a Smart Bundle for project files.
     */
    AiProposal proposeSmartBundle(String userPrompt, String bundleName, List<ObjectIdentity> objects);

    /**
     * Proposes a recurring Transfer Recipe.
     */
    AiProposal proposeTransferRecipe(String userPrompt, String recurrenceSchedule, String targetPeerId, List<ObjectIdentity> objects);

    /**
     * Explains deterministic file compatibility results.
     */
    String explainCompatibility(String fileName, String targetPlatform, String deterministicDetails);

    /**
     * Explains diagnostic network routing or relay fallback.
     */
    String explainDiagnostics(String connectionType, String natType, String diagnosticDetails);

    /**
     * Explains sync state, conflicts, or restrictions.
     */
    String explainSyncStatus(String folderName, String syncStatus, String conflictDetails);

    /**
     * Returns whether user has authorized sensitive metadata disclosure to external models.
     */
    boolean isSensitiveDisclosureAuthorized();

    /**
     * Updates user authorization for sensitive metadata disclosure.
     */
    void setSensitiveDisclosureAuthorized(boolean authorized);

    /**
     * Deterministic non-AI fallback search over local objects without invoking any model.
     */
    AiProposal fallbackSearch(String query, List<ObjectIdentity> availableObjects, java.util.Map<ObjectIdentity, String> objectNames);

    /**
     * Returns immutable audit trail of all AI gateway operations.
     */
    List<AiAuditRecord> getAuditTrail();
}
