import 'package:flutter/material.dart';

enum MediaCategory {
  photos,
  videos,
  audio,
  documents,
  archives,
  allFiles,
}

class MediaCategoryDefinition {
  final MediaCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const MediaCategoryDefinition({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class MediaItemInfo {
  final String pathOrUri;
  final String name;
  final int sizeBytes;
  final MediaCategory category;

  const MediaItemInfo({
    required this.pathOrUri,
    required this.name,
    required this.sizeBytes,
    required this.category,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return 'Unknown size';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Glassmorphic Material 3 bottom sheet for structured, permission-scoped content selection.
class MediaCategorySheet extends StatelessWidget {
  final ValueChanged<MediaCategory> onCategorySelected;
  final List<MediaItemInfo> currentSelection;
  final ValueChanged<MediaItemInfo>? onItemRemoved;
  final VoidCallback? onClearAll;

  const MediaCategorySheet({
    super.key,
    required this.onCategorySelected,
    this.currentSelection = const [],
    this.onItemRemoved,
    this.onClearAll,
  });

  static const List<MediaCategoryDefinition> definitions = [
    MediaCategoryDefinition(
      category: MediaCategory.photos,
      title: 'Photos & Images',
      subtitle: 'Photo Picker (Zero permissions)',
      icon: Icons.photo_library_rounded,
      accentColor: Color(0xFF8B5CF6), // Purple
    ),
    MediaCategoryDefinition(
      category: MediaCategory.videos,
      title: 'Videos',
      subtitle: 'Clips, recordings & movies',
      icon: Icons.video_library_rounded,
      accentColor: Color(0xFFEF4444), // Red
    ),
    MediaCategoryDefinition(
      category: MediaCategory.audio,
      title: 'Music & Audio',
      subtitle: 'Tracks, podcasts & voice memos',
      icon: Icons.music_note_rounded,
      accentColor: Color(0xFFF59E0B), // Amber
    ),
    MediaCategoryDefinition(
      category: MediaCategory.documents,
      title: 'Documents',
      subtitle: 'PDF, Word, Excel, text files',
      icon: Icons.description_rounded,
      accentColor: Color(0xFF3B82F6), // Blue
    ),
    MediaCategoryDefinition(
      category: MediaCategory.archives,
      title: 'Archives & Backups',
      subtitle: 'ZIP, TAR, GZ, 7Z packages',
      icon: Icons.archive_rounded,
      accentColor: Color(0xFF10B981), // Emerald
    ),
    MediaCategoryDefinition(
      category: MediaCategory.allFiles,
      title: 'Browse All Storage',
      subtitle: 'Storage Access Framework',
      icon: Icons.folder_open_rounded,
      accentColor: Color(0xFF64748B), // Slate
    ),
  ];

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<MediaCategory> onCategorySelected,
    List<MediaItemInfo> currentSelection = const [],
    ValueChanged<MediaItemInfo>? onItemRemoved,
    VoidCallback? onClearAll,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaCategorySheet(
        onCategorySelected: (cat) {
          Navigator.of(ctx).pop();
          onCategorySelected(cat);
        },
        currentSelection: currentSelection,
        onItemRemoved: onItemRemoved,
        onClearAll: onClearAll,
      ),
    );
  }

  int get totalSizeBytes => currentSelection.fold<int>(0, (sum, item) => sum + item.sizeBytes);

  String get formattedTotalSize {
    if (totalSizeBytes <= 0) return '0 KB';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (totalSizeBytes < 1024 * 1024 * 1024) return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Content to Share',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (currentSelection.isNotEmpty && onClearAll != null)
                    TextButton.icon(
                      onPressed: onClearAll,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              Text(
                'Select content category. Zero broad storage permissions needed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              // Multi-selection review shelf (if items already selected)
              if (currentSelection.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected: ${currentSelection.length} item${currentSelection.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            formattedTotalSize,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: currentSelection.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = currentSelection[index];
                            return Chip(
                              label: Text(
                                '${item.name} (${item.formattedSize})',
                                style: const TextStyle(fontSize: 11),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: onItemRemoved != null ? () => onItemRemoved!(item) : null,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 6 Category Grid
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: definitions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.1,
                  ),
                  itemBuilder: (context, index) {
                    final def = definitions[index];
                    return InkWell(
                      onTap: () => onCategorySelected(def.category),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: def.accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: def.accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(def.icon, color: def.accentColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    def.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    def.subtitle,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
