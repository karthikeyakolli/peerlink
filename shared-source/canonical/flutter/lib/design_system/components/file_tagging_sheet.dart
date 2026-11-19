import 'package:flutter/material.dart';
import '../../core/models/file_item.dart';
import '../../core/services/file_tagging_service.dart';

/// Modal sheet for adding and toggling virtual tags and color badges on files.
class FileTaggingSheet extends StatefulWidget {
  final FileItem fileItem;
  final VoidCallback? onTagsChanged;

  const FileTaggingSheet({
    super.key,
    required this.fileItem,
    this.onTagsChanged,
  });

  static Future<void> show(BuildContext context, FileItem fileItem, {VoidCallback? onTagsChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FileTaggingSheet(fileItem: fileItem, onTagsChanged: onTagsChanged),
    );
  }

  @override
  State<FileTaggingSheet> createState() => _FileTaggingSheetState();
}

class _FileTaggingSheetState extends State<FileTaggingSheet> {
  final TextEditingController _customTagController = TextEditingController();

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(FileTag tag) {
    setState(() {
      FileTaggingService.instance.toggleTag(widget.fileItem.path, tag);
    });
    widget.onTagsChanged?.call();
  }

  void _addCustomTag() {
    final text = _customTagController.text.trim();
    if (text.isNotEmpty) {
      final tag = FileTag(label: text, color: const Color(0xFF0284C7));
      setState(() {
        FileTaggingService.instance.addTag(widget.fileItem.path, tag);
        _customTagController.clear();
      });
      widget.onTagsChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTags = FileTaggingService.instance.getTagsForFile(widget.fileItem.path);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.label_outline_rounded, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Virtual Tags & Color Badges',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      widget.fileItem.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Presets (Tap to toggle)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FileTaggingService.defaultTags.map((tag) {
              final isApplied = activeTags.contains(tag);
              return FilterChip(
                key: Key('tag_chip_${tag.label.toLowerCase()}'),
                label: Text(
                  tag.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isApplied ? Colors.white : tag.color,
                  ),
                ),
                selected: isApplied,
                selectedColor: tag.color,
                backgroundColor: tag.color.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: tag.color.withValues(alpha: 0.3)),
                ),
                showCheckmark: isApplied,
                checkmarkColor: Colors.white,
                onSelected: (_) => _toggleTag(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Custom tag entry
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _customTagController,
                    decoration: InputDecoration(
                      hintText: 'New custom tag...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('add_custom_tag_button'),
                onPressed: _addCustomTag,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Add Tag', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
