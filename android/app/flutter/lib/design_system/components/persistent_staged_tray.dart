import 'package:flutter/material.dart';
import '../../core/file_staging_service.dart';
import 'glass_container.dart';

/// Floating review bar that displays currently staged draft files.
/// Appears globally when files are queued, allowing instant navigation back to the Send tray.
class PersistentStagedTray extends StatelessWidget {
  final VoidCallback onReviewPressed;

  const PersistentStagedTray({super.key, required this.onReviewPressed});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StagedFileItem>>(
      stream: FileStagingService.instance.stagedFilesStream,
      initialData: FileStagingService.instance.stagedFiles,
      builder: (context, snapshot) {
        final service = FileStagingService.instance;
        if (service.isEmpty) {
          return const SizedBox.shrink();
        }

        final count = service.selectedCount;
        final totalSize = service.formattedTotalBytes;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onReviewPressed,
              borderRadius: BorderRadius.circular(16),
              child: GlassContainer(
                glowColor: null, // Minimal, clean, non-glowing
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.file_copy_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count item${count == 1 ? '' : 's'} staged ($totalSize)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Draft files preserved · Tap to review',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => service.clear(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: onReviewPressed,
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Review & Send'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
