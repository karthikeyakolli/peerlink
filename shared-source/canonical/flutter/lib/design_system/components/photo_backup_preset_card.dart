import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/photo_backup_preset_service.dart';
import '../colors/peerlink_colors.dart';

/// Preset UI card providing 1-tap camera & photo backup.
class PhotoBackupPresetCard extends StatefulWidget {
  final Directory? customScanDir;
  final void Function(int count)? onPhotosStaged;

  const PhotoBackupPresetCard({
    super.key,
    this.customScanDir,
    this.onPhotosStaged,
  });

  @override
  State<PhotoBackupPresetCard> createState() => _PhotoBackupPresetCardState();
}

class _PhotoBackupPresetCardState extends State<PhotoBackupPresetCard> {
  bool _isScanning = false;
  int? _foundCount;

  @override
  void initState() {
    super.initState();
    _checkAvailablePhotos();
  }

  Future<void> _checkAvailablePhotos() async {
    final photos = await PhotoBackupPresetService.instance.scanNewPhotos(
      customDir: widget.customScanDir,
    );
    if (mounted) {
      setState(() {
        _foundCount = photos.length;
      });
    }
  }

  Future<void> _handleStageBackup() async {
    setState(() => _isScanning = true);
    final count = await PhotoBackupPresetService.instance.stageNewPhotos(
      customDir: widget.customScanDir,
    );
    if (mounted) {
      setState(() => _isScanning = false);
      widget.onPhotosStaged?.call(count);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? 'Staged $count new photo(s) to beam tray!'
              : 'No new photos found from the last 24 hours.'),
          backgroundColor: count > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final countLabel = _foundCount != null ? '($_foundCount new)' : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEA580C).withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFEA580C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Camera Backup $countLabel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '1-tap delta sync of recent camera photos to your PC.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('stage_photos_preset_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isScanning
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 14),
            label: Text(
              _isScanning ? 'Staging...' : 'Backup',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: _isScanning ? null : _handleStageBackup,
          ),
        ],
      ),
    );
  }
}
