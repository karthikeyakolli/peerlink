import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/photo_burst_blur_cleaner_service.dart';
import '../../core/received_files_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only Smart Photo Burst & Blur Cleaner Sheet.
/// Groups photos taken in quick bursts (< 2s) and identifies the highest detail shot to keep.
class SmartPhotoCleanerSheet extends StatefulWidget {
  final VoidCallback? onCleanComplete;

  const SmartPhotoCleanerSheet({super.key, this.onCleanComplete});

  static Future<void> show(BuildContext context, {VoidCallback? onCleanComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartPhotoCleanerSheet(onCleanComplete: onCleanComplete),
    );
  }

  @override
  State<SmartPhotoCleanerSheet> createState() => _SmartPhotoCleanerSheetState();
}

class _SmartPhotoCleanerSheetState extends State<SmartPhotoCleanerSheet> {
  final PhotoBurstBlurCleanerService _cleaner = PhotoBurstBlurCleanerService.instance;
  List<PhotoBurstCluster> _clusters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scanPhotos();
  }

  Future<void> _scanPhotos() async {
    final files = await ReceivedFilesService.instance.getReceivedFiles(includeDirectories: false);
    final photos = files.where((f) => f.isImage).map((f) {
      return PhotoMetadata(
        path: f.path,
        timestamp: f.lastModified,
        sizeBytes: f.sizeBytes,
      );
    }).toList();

    final found = _cleaner.clusterBurstPhotos(photos);
    if (mounted) {
      setState(() {
        _clusters = found;
        _isLoading = false;
      });
    }
  }

  void _cleanCluster(PhotoBurstCluster cluster) {
    for (final p in cluster.redundantPhotos) {
      ReceivedFilesService.instance.moveToTrash(p.path);
    }
    setState(() {
      _clusters.remove(cluster);
    });
    widget.onCleanComplete?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kept best shot and moved ${cluster.redundantPhotos.length} burst shots to Recycle Bin!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.burst_mode_rounded, size: 22, color: PeerLinkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart Photo Burst Cleaner',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        _isLoading
                            ? 'Analyzing camera photos...'
                            : '${_clusters.length} burst ${_clusters.length == 1 ? "group" : "groups"} found',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _clusters.isEmpty
                      ? const Center(
                          child: Text(
                            'No photo bursts or near-duplicates found in Vault.',
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _clusters.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final cluster = _clusters[idx];
                            final bestName = File(cluster.bestPhoto.path).uri.pathSegments.last;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF374151)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Burst Group • ${cluster.photos.length} photos',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Recommended: Keep $bestName (${(cluster.bestPhoto.sizeBytes / 1024).toStringAsFixed(0)} KB)',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    key: Key('clean_cluster_$idx'),
                                    onPressed: () => _cleanCluster(cluster),
                                    icon: const Icon(Icons.auto_delete_outlined, size: 16),
                                    label: Text('Keep Best & Clean ${cluster.redundantPhotos.length} Redundant'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PeerLinkColors.primaryBlue,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
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
      ),
    );
  }
}
