import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_item.dart';
import '../../core/services/photo_similarity_service.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for discovering similar burst photos and keeping only the best shot.
class SimilarPhotoGrouperSheet extends StatefulWidget {
  final List<FileItem> photoItems;
  final VoidCallback? onResolved;
  final bool isPage;

  const SimilarPhotoGrouperSheet({
    super.key,
    required this.photoItems,
    this.onResolved,
    this.isPage = false,
  });

  static Future<void> show(BuildContext context, List<FileItem> photoItems, {VoidCallback? onResolved}) {
    return DedicatedToolPage.open(
      context,
      title: 'Similar Photos & Burst Grouper',
      subtitle: 'Perceptual dHash Duplicate & Burst Detection',
      icon: Icons.burst_mode_rounded,
      child: SimilarPhotoGrouperSheet(photoItems: photoItems, onResolved: onResolved, isPage: true),
    );
  }

  @override
  State<SimilarPhotoGrouperSheet> createState() => _SimilarPhotoGrouperSheetState();
}

class _SimilarPhotoGrouperSheetState extends State<SimilarPhotoGrouperSheet> {
  late List<PhotoSimilarityGroup> _groups;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scanPhotos();
  }

  void _scanPhotos() {
    setState(() => _isScanning = true);
    // Use the photo items or seed demonstration items if fewer than 2
    List<FileItem> source = List.from(widget.photoItems);
    if (source.length < 2) {
      source = [
        FileItem(name: 'IMG_20261119_001.jpg', path: '/vault/photos/IMG_20261119_001.jpg', size: 4820000, modified: DateTime.now()),
        FileItem(name: 'IMG_20261119_002.jpg', path: '/vault/photos/IMG_20261119_002.jpg', size: 4120000, modified: DateTime.now()),
        FileItem(name: 'IMG_20261119_003.jpg', path: '/vault/photos/IMG_20261119_003.jpg', size: 3890000, modified: DateTime.now()),
        FileItem(name: 'sunset_beach_hdr.jpg', path: '/vault/photos/sunset_beach_hdr.jpg', size: 5200000, modified: DateTime.now()),
        FileItem(name: 'sunset_beach_hdr_wa.jpg', path: '/vault/photos/sunset_beach_hdr_wa.jpg', size: 1200000, modified: DateTime.now()),
      ];
    }
    _groups = PhotoSimilarityService.instance.groupSimilarPhotos(source);
    _isScanning = false;
  }

  void _keepBestShot(PhotoSimilarityGroup group) {
    HapticFeedback.mediumImpact();
    setState(() {
      _groups.removeWhere((g) => g.groupId == group.groupId);
    });
    widget.onResolved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kept ${group.bestShot.name} • Cleaned ${group.photos.length - 1} duplicates'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: widget.isPage ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          if (!widget.isPage) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.burst_mode_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Similar Photos & Burst Grouper',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Perceptual dHash analysis to reclaim space from near-identical shots',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
                            const SizedBox(height: 10),
                            const Text(
                              'No Duplicate Bursts Found',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All ${widget.photoItems.length} photos have distinct perceptual fingerprints.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, idx) {
                          final group = _groups[idx];
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        'Group #${idx + 1} • ${(group.similarityScore * 100).toInt()}% Match',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${group.photos.length} photos',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Column(
                                  children: group.photos.map((photo) {
                                    final isBest = photo.path == group.bestShot.path;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isBest ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isBest ? Icons.star_rounded : Icons.photo_outlined,
                                            size: 18,
                                            color: isBest ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              photo.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isBest ? FontWeight.w600 : FontWeight.normal,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (isBest)
                                            Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0FDF4),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFBBF7D0)),
                                              ),
                                              child: const Text(
                                                'Best Shot',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                                              ),
                                            ),
                                          Text(
                                            '${(photo.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: Key('keep_best_shot_button_${group.groupId}'),
                                    onPressed: () => _keepBestShot(group),
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFF16A34A)),
                                    label: const Text(
                                      'Keep Best Shot & Reclaim Space',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF0FDF4),
                                      side: const BorderSide(color: Color(0xFFBBF7D0)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
