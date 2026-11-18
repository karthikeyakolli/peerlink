import 'package:flutter/material.dart';
import '../../core/storage_cleaner_service.dart';

class StorageCleanerSheet extends StatefulWidget {
  final VoidCallback onCleaned;

  const StorageCleanerSheet({
    super.key,
    required this.onCleaned,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onCleaned}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StorageCleanerSheet(onCleaned: onCleaned),
    );
  }

  @override
  State<StorageCleanerSheet> createState() => _StorageCleanerSheetState();
}

class _StorageCleanerSheetState extends State<StorageCleanerSheet> {
  final StorageCleanerService _service = StorageCleanerService.instance;
  StorageScrubSummary? _summary;
  bool _isLoading = true;
  bool _isPurging = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _isLoading = true);
    final res = await _service.scanJunk();
    if (mounted) {
      setState(() {
        _summary = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _purge() async {
    if (_summary == null || _summary!.items.isEmpty || _isPurging) return;
    setState(() => _isPurging = true);
    final count = await _service.purgeItems(_summary!.items, moveToTrash: true);
    if (!mounted) return;
    widget.onCleaned();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Safely moved $count junk item(s) to Recycle Bin'),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.cleaning_services_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deep Storage Cleaner',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Detects fragments, zero-byte stubs & duplicate copies',
                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              )
            else if (summary == null || summary.items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 40, color: Color(0xFF16A34A)),
                    const SizedBox(height: 8),
                    const Text(
                      'Storage is 100% Clean',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No orphaned fragments, stubs, or duplicates found.',
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${summary.count} Junk Items Found',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                          ),
                          Text(
                            'Reclaim up to ${summary.formattedTotalSize} of storage safely',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Category pills
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (summary.fragments.isNotEmpty)
                    _buildPill('Fragments', summary.fragments.length, const Color(0xFFEF4444)),
                  if (summary.zeroByteFiles.isNotEmpty)
                    _buildPill('0-Byte Stubs', summary.zeroByteFiles.length, const Color(0xFFF59E0B)),
                  if (summary.duplicateCopies.isNotEmpty)
                    _buildPill('Duplicates', summary.duplicateCopies.length, const Color(0xFF8B5CF6)),
                  if (summary.emptyDirectories.isNotEmpty)
                    _buildPill('Empty Folders', summary.emptyDirectories.length, const Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('purge_junk_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isPurging ? Icons.hourglass_top_rounded : Icons.delete_outline_rounded, size: 18),
                label: Text(
                  _isPurging ? 'Purging to Recycle Bin...' : 'Clean All (${summary.count} items)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isPurging ? null : _purge,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
