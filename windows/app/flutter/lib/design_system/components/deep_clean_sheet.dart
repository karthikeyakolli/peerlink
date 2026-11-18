import 'package:flutter/material.dart';
import '../../core/storage_analyzer_service.dart';
import '../../core/received_files_service.dart';

/// Interactive modal sheet providing the Xiaomi MIUI / HyperOS "Deep Clean" experience.
class DeepCleanSheet extends StatefulWidget {
  const DeepCleanSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DeepCleanSheet(),
    );
  }

  @override
  State<DeepCleanSheet> createState() => _DeepCleanSheetState();
}

class _DeepCleanSheetState extends State<DeepCleanSheet> {
  bool _loading = true;
  StorageAnalysisReport? _report;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() => _loading = true);
    final rep = await StorageAnalyzerService.instance.analyzeStorage();
    if (mounted) {
      setState(() {
        _report = rep;
        _loading = false;
      });
    }
  }

  Future<void> _cleanCache() async {
    if (_report == null || _report!.cacheFragments.isEmpty) return;
    final purged = await StorageAnalyzerService.instance
        .purgeAllCacheFragments(_report!.cacheFragments);
    await ReceivedFilesService.instance.getStorageBreakdown();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleaned $purged cache fragments successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _runAnalysis();
    }
  }

  void _openReviewModal({
    required String title,
    required List<StorageAnomalyItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ReviewItemsSheet(
        title: title,
        items: items,
        onItemsDeleted: () {
          _runAnalysis();
        },
      ),
    );
  }

  void _openDuplicatesReview() {
    if (_report == null || _report!.duplicateGroups.isEmpty) return;
    // Flatten duplicate copies (keep the first, select the copies for removal)
    final List<StorageAnomalyItem> duplicateCopies = [];
    for (final grp in _report!.duplicateGroups) {
      if (grp.files.length > 1) {
        duplicateCopies.addAll(grp.files.skip(1));
      }
    }

    _openReviewModal(
      title: 'Duplicate File Copies',
      items: duplicateCopies,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cleaning_services_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deep Clean',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Xiaomi HyperOS Storage Hygiene',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Rescan storage',
                  onPressed: _runAnalysis,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 16),
                        Text(
                          'Scanning storage hygiene...',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _report == null
                    ? const Center(child: Text('Unable to analyze storage.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Storage Reclaim Hero (Flat Minimalist Light Card)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.auto_delete_rounded,
                                    color: Color(0xFF8B5CF6),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _report!.totalReclaimableBytes > 0
                                            ? 'Up to ${_report!.formattedReclaimableBytes}'
                                            : 'Storage is Optimized',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _report!.totalReclaimableBytes > 0
                                            ? 'Reclaimable junk, duplicates, & APK packages'
                                            : 'No redundant files or temporary junk detected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Visual Storage Breakdown by Category & Largest Folders
                          if (_report!.totalScannedBytes > 0) ...[
                            _buildVisualStorageBreakdownCard(_report!),
                            const SizedBox(height: 16),
                          ],

                          // Card 1: Cache & Staging Junk
                          _buildCleanCard(
                            title: 'Cache & Temporary Junk',
                            subtitle: '${_report!.cacheFragments.length} temporary chunk fragments',
                            sizeText: _formatBytes(_report!.cacheFragments.fold(0, (sum, i) => sum + i.sizeBytes)),
                            icon: Icons.delete_sweep_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            actionLabel: 'Clean Now',
                            isActionEnabled: _report!.cacheFragments.isNotEmpty,
                            onAction: _cleanCache,
                          ),

                          const SizedBox(height: 12),

                          // Card 2: Duplicate Files
                          _buildCleanCard(
                            title: 'Duplicate Files',
                            subtitle: '${_report!.duplicateGroups.length} duplicate file groups detected',
                            sizeText: _formatBytes(_report!.duplicateGroups.fold(0, (sum, g) => sum + g.reclaimableBytes)),
                            icon: Icons.copy_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            actionLabel: 'Review',
                            isActionEnabled: _report!.duplicateGroups.isNotEmpty,
                            onAction: _openDuplicatesReview,
                          ),

                          const SizedBox(height: 12),

                          // Card 3: Redundant APKs & Installers
                          _buildCleanCard(
                            title: 'Downloaded APKs & Installers',
                            subtitle: '${_report!.redundantApks.length} package files in vault',
                            sizeText: _formatBytes(_report!.redundantApks.fold(0, (sum, i) => sum + i.sizeBytes)),
                            icon: Icons.android_rounded,
                            iconColor: const Color(0xFF10B981),
                            actionLabel: 'Review',
                            isActionEnabled: _report!.redundantApks.isNotEmpty,
                            onAction: () => _openReviewModal(
                              title: 'Downloaded APK Installers',
                              items: _report!.redundantApks,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Card 4: Large Files (> 50 MB)
                          _buildCleanCard(
                            title: 'Large Files (> 50 MB)',
                            subtitle: '${_report!.largeFiles.length} heavy files taking up space',
                            sizeText: _formatBytes(_report!.largeFiles.fold(0, (sum, i) => sum + i.sizeBytes)),
                            icon: Icons.disc_full_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            actionLabel: 'Review',
                            isActionEnabled: _report!.largeFiles.isNotEmpty,
                            onAction: () => _openReviewModal(
                              title: 'Large Files (> 50 MB)',
                              items: _report!.largeFiles,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualStorageBreakdownCard(StorageAnalysisReport report) {
    final entries = report.categoryBytes.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = report.totalScannedBytes > 0 ? report.totalScannedBytes : 1;

    Color catColor(ReceivedFileCategory c) => switch (c) {
          ReceivedFileCategory.photos => const Color(0xFF7C3AED),
          ReceivedFileCategory.videos => const Color(0xFFDC2626),
          ReceivedFileCategory.audio => const Color(0xFFD97706),
          ReceivedFileCategory.documents => const Color(0xFF2563EB),
          ReceivedFileCategory.archives => const Color(0xFFDB2777),
          ReceivedFileCategory.apps => const Color(0xFF059669),
          ReceivedFileCategory.other => const Color(0xFF64748B),
        };

    String catName(ReceivedFileCategory c) => switch (c) {
          ReceivedFileCategory.photos => 'Photos',
          ReceivedFileCategory.videos => 'Videos',
          ReceivedFileCategory.audio => 'Audio',
          ReceivedFileCategory.documents => 'Docs',
          ReceivedFileCategory.archives => 'Archives',
          ReceivedFileCategory.apps => 'Apps',
          ReceivedFileCategory.other => 'Other',
        };

    return Container(
      key: const Key('visual_storage_breakdown_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Storage Breakdown',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              Text(
                report.formattedTotalScannedBytes,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Proportional flat stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: entries.map((e) {
                  final flex = ((e.value / total) * 1000).round().clamp(15, 1000);
                  return Expanded(
                    flex: flex,
                    child: Container(color: catColor(e.key)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: entries.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: catColor(e.key), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${catName(e.key)}: ${_formatBytes(e.value)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ],
              );
            }).toList(),
          ),
          if (report.largestFolders.isNotEmpty) ...[
            const Divider(height: 18, color: Color(0xFFE5E7EB)),
            const Text(
              'Largest Folders',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            ...report.largestFolders.take(4).map((folder) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${folder.name} (${folder.fileCount} files)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        folder.formattedSize,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanCard({
    required String title,
    required String subtitle,
    required String sizeText,
    required IconData icon,
    required Color iconColor,
    required String actionLabel,
    required bool isActionEnabled,
    required VoidCallback onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                sizeText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              FilledButton.tonal(
                onPressed: isActionEnabled ? onAction : null,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: Text(actionLabel, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Interactive sheet to review and selectively delete items.
class _ReviewItemsSheet extends StatefulWidget {
  final String title;
  final List<StorageAnomalyItem> items;
  final VoidCallback onItemsDeleted;

  const _ReviewItemsSheet({
    required this.title,
    required this.items,
    required this.onItemsDeleted,
  });

  @override
  State<_ReviewItemsSheet> createState() => _ReviewItemsSheetState();
}

class _ReviewItemsSheetState extends State<_ReviewItemsSheet> {
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    // Pre-select all items by default for review
    _selectedPaths.addAll(widget.items.map((i) => i.path));
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete ${_selectedPaths.length} selected file(s)? This operation is permanent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = await StorageAnalyzerService.instance.deleteSelectedFiles(_selectedPaths);
      widget.onItemsDeleted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted $count file(s).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedBytes = widget.items
        .where((i) => _selectedPaths.contains(i.path))
        .fold<int>(0, (sum, i) => sum + i.sizeBytes);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.items.length} items found',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedPaths.length == widget.items.length) {
                        _selectedPaths.clear();
                      } else {
                        _selectedPaths.addAll(widget.items.map((i) => i.path));
                      }
                    });
                  },
                  child: Text(_selectedPaths.length == widget.items.length ? 'Deselect All' : 'Select All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = _selectedPaths.contains(item.path);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedPaths.add(item.path);
                      } else {
                        _selectedPaths.remove(item.path);
                      }
                    });
                  },
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${item.formattedSize} · ${item.reason}',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insert_drive_file_rounded, size: 20, color: Colors.blue),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selectedPaths.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        _formatBytes(selectedBytes),
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selectedPaths.isNotEmpty ? _deleteSelected : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete Selected'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
