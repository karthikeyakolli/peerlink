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

    public static final int MAX_QUERY_LENGTH = 4096;
    public static final int MAX_JUSTIFICATION_LENGTH = 4096;
    public static final int MAX_TARGET_OBJECTS = 100;
    public static final long MAX_SHARE_DURATION_SECONDS = 86400L; // 24 hours

    private static final Set<String> FORBIDDEN_DIRECTIVES = Set.of(
            "delete_files", "delete_file", "delete_all", "rm", "unlink", "drop_table",
            "revoke_device", "modify_trust", "grant_trust", "authorize_peer",
            "disable_scanner", "execute_command", "system_call", "execute_binary",
            "export_private_key", "exec", "shell", "bash", "powershell", "cmd", "format",
            "mass_deletion", "bypass_safeguards", "bypass_safety"
    );

    private static final java.util.regex.Pattern PATH_TRAVERSAL_PATTERN = java.util.regex.Pattern.compile(
            "(?i)(\\.\\./|\\.\\.\\\\|/etc/|/root/|[a-zA-Z]:\\\\windows|[a-zA-Z]:\\\\program\\s+files)"
    );

    public PolicyValidationResult evaluate(AiProposal proposal) {
        Objects.requireNonNull(proposal, "proposal is required");

        // 1. Direct forbidden tool or proposal type check & narrow allowlist
        if (proposal.getType() == null || proposal.getType() == AiProposalType.UNAUTHORIZED_ACTION) {
            return PolicyValidationResult.violation("AI attempted an unauthorized action category");
        }

        // 2. Schema length and resource limits
        if (proposal.getNaturalLanguageQuery().length() > MAX_QUERY_LENGTH) {
            return PolicyValidationResult.violation("Query exceeds maximum allowed length of " + MAX_QUERY_LENGTH + " chars");
        }
        if (proposal.getJustification().length() > MAX_JUSTIFICATION_LENGTH) {
            return PolicyValidationResult.violation("Justification exceeds maximum allowed length of " + MAX_JUSTIFICATION_LENGTH + " chars");
        }
        if (proposal.getTargetObjectIds().size() > MAX_TARGET_OBJECTS) {
            return PolicyValidationResult.violation("Target objects count exceeds safety limit of " + MAX_TARGET_OBJECTS);
        }

        // 3. Prompt injection check on query or justification
        if (PromptInjectionGuard.containsInjectionPattern(proposal.getNaturalLanguageQuery()) ||
            PromptInjectionGuard.containsInjectionPattern(proposal.getJustification())) {
            return PolicyValidationResult.violation("Adversarial prompt injection pattern detected in proposal parameters");
        }

        // 4. Secrets / key material leak check
        if (SanitizedContextFilter.containsForbiddenSecrets(proposal.getNaturalLanguageQuery()) ||
            SanitizedContextFilter.containsForbiddenSecrets(proposal.getJustification())) {
            return PolicyValidationResult.violation("Proposal parameters contain private cryptographic secrets or tokens");
        }

        // 5. Intent and capability checks
        OperationIntent intent = proposal.getMappedIntent();
        if (intent != null) {
            if (intent == OperationIntent.BACKUP) {
                return PolicyValidationResult.requiresConfirmation("Backup operations proposed by AI require explicit user confirmation");
            }
        }

        // 6. Tool call parameters check (both keys and string values)
        for (java.util.Map.Entry<String, Object> entry : proposal.getParameters().entrySet()) {
            String paramKey = entry.getKey().toLowerCase();
            if (FORBIDDEN_DIRECTIVES.contains(paramKey)) {
                return PolicyValidationResult.violation("Proposal includes prohibited control directive: " + entry.getKey());
            }

            if (entry.getValue() instanceof String strVal) {
                String lowerVal = strVal.toLowerCase();
                for (String forbidden : FORBIDDEN_DIRECTIVES) {
                    if (lowerVal.equals(forbidden) || lowerVal.contains(forbidden)) {
                        return PolicyValidationResult.violation("Proposal parameter value contains prohibited control directive: " + forbidden);
                    }
                }
                if (PATH_TRAVERSAL_PATTERN.matcher(strVal).find()) {
                    return PolicyValidationResult.violation("Proposal parameter contains unauthorized file reference or path traversal: " + strVal);
                }
            }
        }

        // 7. Action specific rules and mandatory confirmation verification
        switch (proposal.getType()) {
            case NATURAL_LANGUAGE_SEARCH:
            case COMPATIBILITY_EXPLANATION:
            case DIAGNOSTICS_EXPLANATION:
            case SYNC_EXPLANATION:
                // Read-only explanations and searches are safe
                return PolicyValidationResult.allowed("Read-only explanation/search permitted");

            case SMART_SHARE:
                // Sharing external access always requires user consent
                if (!proposal.isRequiresUserConfirmation()) {
                    return PolicyValidationResult.violation("Smart Share proposal cannot bypass mandatory user confirmation");
                }
                if (proposal.getTargetPeerId() == null || proposal.getTargetPeerId().isBlank()) {
                    return PolicyValidationResult.violation("Smart Share proposal missing targetPeerId");
                }
                Object durObj = proposal.getParameters().get("durationSeconds");
                if (durObj instanceof Number durNum) {
                    long dur = durNum.longValue();
                    if (dur <= 0 || dur > MAX_SHARE_DURATION_SECONDS) {
                        return PolicyValidationResult.violation("Smart Share duration out of valid bounds (1 - " + MAX_SHARE_DURATION_SECONDS + " seconds)");
                    }
                } else if (durObj != null) {
                    return PolicyValidationResult.violation("Malformed durationSeconds parameter in Smart Share proposal");
                }
                return PolicyValidationResult.requiresConfirmation("Smart Share grants external access and requires user confirmation");

            case SMART_BUNDLE:
                if (!proposal.isRequiresUserConfirmation()) {
                    return PolicyValidationResult.violation("Smart Bundle proposal cannot bypass mandatory user confirmation");
                }
                Object bundleName = proposal.getParameters().get("bundleName");
                if (bundleName != null && PATH_TRAVERSAL_PATTERN.matcher(bundleName.toString()).find()) {
                    return PolicyValidationResult.violation("Smart Bundle name contains unauthorized path traversal");
                }
                return PolicyValidationResult.requiresConfirmation("Batch/recurring operation requires user confirmation");

            case TRANSFER_RECIPE:
                if (!proposal.isRequiresUserConfirmation()) {
                    return PolicyValidationResult.violation("Transfer Recipe proposal cannot bypass mandatory user confirmation");
                }
                if (proposal.getTargetPeerId() == null || proposal.getTargetPeerId().isBlank()) {
                    return PolicyValidationResult.violation("Transfer Recipe proposal missing targetPeerId");
                }
                return PolicyValidationResult.requiresConfirmation("Batch/recurring operation requires user confirmation");

            case ORGANIZATION_SUGGESTION:
                if (!proposal.isRequiresUserConfirmation()) {
                    return PolicyValidationResult.violation("Organization reorganization cannot bypass mandatory user confirmation");
                }
                return PolicyValidationResult.requiresConfirmation("Organization reorganization requires user confirmation");

            default:
                return PolicyValidationResult.violation("Unsupported AI proposal category");
        }
    }
}
