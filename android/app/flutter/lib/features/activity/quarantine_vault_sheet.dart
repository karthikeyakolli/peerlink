import 'package:flutter/material.dart';
import '../../core/quarantine_service.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

/// Interactive Quarantine Vault Modal (Rule 9 & 10 Enforcement).
/// Allows reviewing isolated corrupted/uncertain files and crypto-purging them safely.
class QuarantineVaultSheet extends StatefulWidget {
  const QuarantineVaultSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const QuarantineVaultSheet(),
    );
  }

  @override
  State<QuarantineVaultSheet> createState() => _QuarantineVaultSheetState();
}

class _QuarantineVaultSheetState extends State<QuarantineVaultSheet> {
  final QuarantineService _service = QuarantineService.instance;

  void _confirmPurgeItem(QuarantinedItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Crypto-Purge File?'),
          ],
        ),
        content: Text(
          'Are you sure you want to cryptographically shred and delete "${item.fileName}"? This operation cannot be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _service.purgeItem(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${item.fileName}" cryptographically shredded.'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Purge & Shred'),
          ),
        ],
      ),
    );
  }

  void _confirmPurgeAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Purge Entire Vault?'),
          ],
        ),
        content: const Text(
          'Cryptographically overwrite and shred all files currently in quarantine?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _service.purgeAll();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All quarantined files purged successfully.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Purge All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<QuarantinedItem>>(
      stream: _service.quarantinedStream,
      initialData: _service.quarantinedItems,
      builder: (context, snapshot) {
        final items = _service.quarantinedItems;

        return Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.red, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quarantine Vault',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${items.length} isolated item${items.length == 1 ? '' : 's'} (Rule 9 & 10 Enforcement)',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        onPressed: _confirmPurgeAll,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                        label: const Text('Purge All', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Security Policy Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Zero-Trust Isolation: These files failed integrity checks or were aborted unexpectedly. Execute bits are stripped, and files are quarantined in isolation. PeerLink never auto-executes received files or blindly replays uncertain outcomes.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 48, color: Colors.green.shade600),
                        const SizedBox(height: 12),
                        const Text(
                          'Quarantine Vault is Clean',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'All received and synced files have successfully passed SHA-256 verification.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map((item) => _buildQuarantineCard(context, item)),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildQuarantineCard(BuildContext context, QuarantinedItem item) {
    final isMismatch = item.reason == QuarantineReason.checksumMismatch;
    final tagColor = isMismatch ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return InteractiveGlassCard(
      glowColor: tagColor,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: tagColor.withValues(alpha: 0.15),
                child: Icon(Icons.warning_amber_rounded, color: tagColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.formattedSize} · From: ${item.sourcePeerId}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tagColor),
                ),
                child: Text(
                  item.reason.displayTag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: tagColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.reason.humanDescription,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
          const SizedBox(height: 8),

          // Hash Comparison Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHashRow('Expected Hash', item.expectedSha256),
                const SizedBox(height: 4),
                _buildHashRow('Actual Computed', item.actualSha256, isError: true),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _confirmPurgeItem(item),
                icon: const Icon(Icons.delete_forever_rounded, size: 14),
                label: const Text('Crypto-Purge & Shred'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String label, String hash, {bool isError = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(
            hash,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: isError ? Colors.red.shade800 : null,
              fontWeight: isError ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
