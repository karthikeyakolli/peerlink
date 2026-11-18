import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/received_files_service.dart';
import '../../design_system/colors/peerlink_colors.dart';

/// Minimalist Light-Only Dual-Pane Explorer for Wide Viewports (>= 960dp).
/// Allows side-by-side file browsing and 1-tap transfers between panes on Windows Desktop and Tablets.
class DualPaneVaultView extends StatefulWidget {
  final String leftTitle;
  final String rightTitle;
  final List<ReceivedFileItem> leftItems;
  final List<ReceivedFileItem> rightItems;
  final Directory leftDirectory;
  final Directory rightDirectory;
  final void Function(ReceivedFileItem item, Directory destDir)? onCopyItem;
  final void Function(ReceivedFileItem item)? onItemTapped;

  const DualPaneVaultView({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftItems,
    required this.rightItems,
    required this.leftDirectory,
    required this.rightDirectory,
    this.onCopyItem,
    this.onItemTapped,
  });

  @override
  State<DualPaneVaultView> createState() => _DualPaneVaultViewState();
}

class _DualPaneVaultViewState extends State<DualPaneVaultView> {
  int _activeMobileTab = 0;

  void _copyFile(ReceivedFileItem item, Directory destDir) {
    if (widget.onCopyItem != null) {
      widget.onCopyItem!(item, destDir);
    } else {
      // Default direct copy
      try {
        final src = File(item.path);
        if (src.existsSync()) {
          final dest = File('${destDir.path}${Platform.pathSeparator}${item.name}');
          src.copySync(dest.path);
        }
      } catch (_) {}
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        if (!isWide) {
          // Mobile Single-Pane Fallback (< 960dp)
          return Column(
            key: const Key('single_pane_view'),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 0, label: Text(widget.leftTitle)),
                          ButtonSegment(value: 1, label: Text(widget.rightTitle)),
                        ],
                        selected: {_activeMobileTab},
                        onSelectionChanged: (set) => setState(() => _activeMobileTab = set.first),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildPane(
                  title: _activeMobileTab == 0 ? widget.leftTitle : widget.rightTitle,
                  items: _activeMobileTab == 0 ? widget.leftItems : widget.rightItems,
                  targetDir: _activeMobileTab == 0 ? widget.rightDirectory : widget.leftDirectory,
                  isLeftPane: _activeMobileTab == 0,
                ),
              ),
            ],
          );
        }

        // Wide Dual-Pane Split View (>= 960dp)
        return Row(
          key: const Key('dual_pane_split_view'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane
            Expanded(
              flex: 1,
              child: _buildPane(
                title: widget.leftTitle,
                items: widget.leftItems,
                targetDir: widget.rightDirectory,
                isLeftPane: true,
              ),
            ),

            // Vertical Divider
            Container(
              width: 1,
              color: const Color(0xFFE5E7EB),
            ),

            // Right Pane
            Expanded(
              flex: 1,
              child: _buildPane(
                title: widget.rightTitle,
                items: widget.rightItems,
                targetDir: widget.leftDirectory,
                isLeftPane: false,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPane({
    required String title,
    required List<ReceivedFileItem> items,
    required Directory targetDir,
    required bool isLeftPane,
  }) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Icon(
                  isLeftPane ? Icons.folder_rounded : Icons.folder_shared_rounded,
                  size: 18,
                  color: isLeftPane ? PeerLinkColors.primaryBlue : const Color(0xFF0F766E),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Text(
                  '${items.length} items',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          // File List
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No files in this pane.',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (ctx, idx) {
                      final it = items[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Icon(
                            _getCategoryIcon(it.category),
                            size: 16,
                            color: const Color(0xFF4B5563),
                          ),
                        ),
                        title: Text(
                          it.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          it.formattedSize,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                        trailing: IconButton(
                          key: const Key('copy_to_other_pane_button'),
                          icon: Icon(
                            isLeftPane ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                            size: 18,
                            color: PeerLinkColors.primaryBlue,
                          ),
                          tooltip: isLeftPane ? 'Copy to Right Pane' : 'Copy to Left Pane',
                          onPressed: () => _copyFile(it, targetDir),
                        ),
                        onTap: () => widget.onItemTapped?.call(it),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ReceivedFileCategory cat) {
    switch (cat) {
      case ReceivedFileCategory.photos:
        return Icons.image_outlined;
      case ReceivedFileCategory.videos:
        return Icons.movie_outlined;
      case ReceivedFileCategory.audio:
        return Icons.music_note_outlined;
      case ReceivedFileCategory.documents:
        return Icons.description_outlined;
      case ReceivedFileCategory.archives:
        return Icons.archive_outlined;
      case ReceivedFileCategory.apps:
        return Icons.android_outlined;
      case ReceivedFileCategory.other:
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
