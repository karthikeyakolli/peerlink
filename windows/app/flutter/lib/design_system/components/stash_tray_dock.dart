import 'package:flutter/material.dart';
import '../../core/file_stash_tray_service.dart';
import '../../core/received_files_service.dart';

/// Minimalist Light floating shelf / stash dock for collecting files across folders.
class StashTrayDock extends StatelessWidget {
  final VoidCallback? onZipRequested;
  final VoidCallback? onActionCompleted;

  const StashTrayDock({
    super.key,
    this.onZipRequested,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ReceivedFileItem>>(
      valueListenable: FileStashTrayService.instance.stashedItemsNotifier,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          '${items.length} stashed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: items.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.only(left: 8, right: 4, top: 2, bottom: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 90),
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () => FileStashTrayService.instance.removeItem(item.path),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Zip button
                  TextButton.icon(
                    key: const Key('stash_zip_button'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFEFF6FF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.folder_zip_outlined, size: 14),
                    label: const Text('Zip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      onZipRequested?.call();
                    },
                  ),
                  const SizedBox(width: 4),
                  // Clear button
                  IconButton(
                    key: const Key('stash_clear_button'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Clear Stash',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => FileStashTrayService.instance.clearStash(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
