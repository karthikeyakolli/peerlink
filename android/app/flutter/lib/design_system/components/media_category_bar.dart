import 'package:flutter/material.dart';

enum MediaCategoryType {
  photos,
  videos,
  apps,
  music,
  documents,
  allFiles,
}

class MediaCategoryItem {
  final MediaCategoryType type;
  final String label;
  final IconData icon;
  final Color accentColor;

  const MediaCategoryItem({
    required this.type,
    required this.label,
    required this.icon,
    required this.accentColor,
  });
}

/// Horizontal quick-access category shelf inspired by SHAREit's multi-category tabs.
class MediaCategoryBar extends StatelessWidget {
  final void Function(MediaCategoryType category) onCategorySelected;
  final MediaCategoryType? activeCategory;

  const MediaCategoryBar({
    super.key,
    required this.onCategorySelected,
    this.activeCategory,
  });

  static const List<MediaCategoryItem> categories = [
    MediaCategoryItem(
      type: MediaCategoryType.photos,
      label: 'Photos',
      icon: Icons.photo_library_outlined,
      accentColor: Color(0xFF8B5CF6), // Purple
    ),
    MediaCategoryItem(
      type: MediaCategoryType.videos,
      label: 'Videos',
      icon: Icons.video_collection_outlined,
      accentColor: Color(0xFFEF4444), // Red
    ),
    MediaCategoryItem(
      type: MediaCategoryType.apps,
      label: 'Apps',
      icon: Icons.apps_rounded,
      accentColor: Color(0xFF10B981), // Emerald
    ),
    MediaCategoryItem(
      type: MediaCategoryType.music,
      label: 'Music',
      icon: Icons.music_note_outlined,
      accentColor: Color(0xFFF59E0B), // Amber
    ),
    MediaCategoryItem(
      type: MediaCategoryType.documents,
      label: 'Docs',
      icon: Icons.description_outlined,
      accentColor: Color(0xFF3B82F6), // Blue
    ),
    MediaCategoryItem(
      type: MediaCategoryType.allFiles,
      label: 'Browse',
      icon: Icons.folder_open_rounded,
      accentColor: Color(0xFF64748B), // Slate
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = categories[index];
          final isSelected = activeCategory == item.type;

          return SizedBox(
            width: 76,
            child: Material(
              color: isSelected
                  ? item.accentColor.withValues(alpha: isDark ? 0.28 : 0.16)
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? item.accentColor
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onCategorySelected(item.type),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          color: item.accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? item.accentColor
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
