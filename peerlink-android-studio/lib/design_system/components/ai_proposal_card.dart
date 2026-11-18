import 'package:flutter/material.dart';
import '../../core/ai_gateway_service.dart';
import 'glass_container.dart';

/// Non-Authoritative AI Proposal Card (Phase 15, Rule 11).
/// Presents AI-generated action suggestions without executing them automatically.
/// Execution REQUIRES explicit user tap.
class AiProposalCard extends StatelessWidget {
  final AiProposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final bool isExecuting;

  const AiProposalCard({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onDismiss,
    this.isExecuting = false,
  });

  String _typeLabel(AiProposalType type) {
    switch (type) {
      case AiProposalType.naturalLanguageSearch:
        return 'Search Suggestion';
      case AiProposalType.smartShare:
        return 'Smart Share Proposal';
      case AiProposalType.smartBundle:
        return 'Smart Bundle Proposal';
      case AiProposalType.transferRecipe:
        return 'Transfer Recipe';
      case AiProposalType.diagnosticsExplanation:
        return 'System Diagnostic';
      case AiProposalType.syncExplanation:
        return 'Sync State Explanation';
      case AiProposalType.compatibilityExplanation:
        return 'Compatibility Advisor';
      case AiProposalType.organizationSuggestion:
        return 'Organization Proposal';
      case AiProposalType.unauthorizedAction:
        return 'Security Block';
    }
  }

  IconData _typeIcon(AiProposalType type) {
    switch (type) {
      case AiProposalType.naturalLanguageSearch:
        return Icons.saved_search_rounded;
      case AiProposalType.smartShare:
        return Icons.share_rounded;
      case AiProposalType.smartBundle:
        return Icons.inventory_2_rounded;
      case AiProposalType.transferRecipe:
        return Icons.auto_mode_rounded;
      case AiProposalType.diagnosticsExplanation:
      case AiProposalType.syncExplanation:
      case AiProposalType.compatibilityExplanation:
        return Icons.info_outline_rounded;
      case AiProposalType.organizationSuggestion:
        return Icons.folder_special_rounded;
      case AiProposalType.unauthorizedAction:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isViolation = proposal.type == AiProposalType.unauthorizedAction;

    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isViolation
                      ? Colors.red.withValues(alpha: 0.16)
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _typeIcon(proposal.type),
                      size: 16,
                      color: isViolation ? Colors.red : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _typeLabel(proposal.type),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isViolation ? Colors.red : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Rule 11 Guarded',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // User Query Quote
          Text(
            '"${proposal.naturalLanguageQuery}"',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Justification
          Text(
            proposal.justification,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isViolation ? Colors.red.shade700 : theme.colorScheme.onSurface,
            ),
          ),

          if (proposal.targetPeerId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.devices_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Target Peer: ${proposal.targetPeerId}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isExecuting ? null : onDismiss,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Dismiss'),
              ),
              if (!isViolation) ...[
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: isExecuting ? null : onAccept,
                  icon: isExecuting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(proposal.requiresUserConfirmation ? 'Confirm & Execute' : 'Apply Search'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
