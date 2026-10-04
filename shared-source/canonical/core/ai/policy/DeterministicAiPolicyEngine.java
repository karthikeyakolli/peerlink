package org.peerlink.core.ai.policy;

import org.peerlink.core.ai.model.AiProposal;
import org.peerlink.core.ai.model.AiProposalType;
import org.peerlink.core.operation.OperationIntent;

import java.util.Objects;
import java.util.Set;

/**
 * Authoritative, deterministic policy engine guarding PeerLink from unauthorized AI proposals.
 *
 * INVARIANTS:
 * - AI is NEVER the source of truth.
 * - AI cannot delete files, revoke devices, alter trust, change security policies,
 *   execute system commands, or bypass normal operation pipelines.
 */
public final class DeterministicAiPolicyEngine {

    private static final Set<String> FORBIDDEN_TOOL_NAMES = Set.of(
            "delete_files", "delete_file", "rm", "unlink", "drop_table",
            "revoke_device", "modify_trust", "disable_scanner", "execute_command",
            "system_call", "execute_binary", "export_private_key"
    );

    public PolicyValidationResult evaluate(AiProposal proposal) {
        Objects.requireNonNull(proposal, "proposal is required");

        // 1. Direct forbidden tool or proposal type check
        if (proposal.getType() == AiProposalType.UNAUTHORIZED_ACTION) {
            return PolicyValidationResult.violation("AI attempted an unauthorized action category");
        }

        // 2. Prompt injection check on query or justification
        if (PromptInjectionGuard.containsInjectionPattern(proposal.getNaturalLanguageQuery()) ||
            PromptInjectionGuard.containsInjectionPattern(proposal.getJustification())) {
            return PolicyValidationResult.violation("Adversarial prompt injection pattern detected in proposal parameters");
        }

        // 3. Secrets / key material leak check
        if (SanitizedContextFilter.containsForbiddenSecrets(proposal.getNaturalLanguageQuery()) ||
            SanitizedContextFilter.containsForbiddenSecrets(proposal.getJustification())) {
            return PolicyValidationResult.violation("Proposal parameters contain private cryptographic secrets or tokens");
        }

        // 4. Intent and capability checks
        OperationIntent intent = proposal.getMappedIntent();
        if (intent != null) {
            if (intent == OperationIntent.BACKUP) {
                return PolicyValidationResult.requiresConfirmation("Backup operations proposed by AI require explicit user confirmation");
            }
        }

        // 5. Tool call parameters check
        for (String paramKey : proposal.getParameters().keySet()) {
            if (FORBIDDEN_TOOL_NAMES.contains(paramKey.toLowerCase())) {
                return PolicyValidationResult.violation("Proposal includes prohibited control directive: " + paramKey);
            }
        }

        // 6. Action specific rules
        switch (proposal.getType()) {
            case NATURAL_LANGUAGE_SEARCH:
            case COMPATIBILITY_EXPLANATION:
            case DIAGNOSTICS_EXPLANATION:
            case SYNC_EXPLANATION:
                // Read-only explanations and searches are safe
                return PolicyValidationResult.allowed("Read-only explanation/search permitted");

            case SMART_SHARE:
                // Sharing external access always requires user consent
                return PolicyValidationResult.requiresConfirmation("Smart Share grants external access and requires user confirmation");

            case SMART_BUNDLE:
            case TRANSFER_RECIPE:
                // Batch/recurring operations require user confirmation
                return PolicyValidationResult.requiresConfirmation("Batch/recurring operation requires user confirmation");

            case ORGANIZATION_SUGGESTION:
                return PolicyValidationResult.requiresConfirmation("Organization reorganization requires user confirmation");

            default:
                return PolicyValidationResult.blocked("Unsupported AI proposal category");
        }
    }
}
