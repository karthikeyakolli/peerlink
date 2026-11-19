import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/file_item.dart';
import '../../core/received_files_service.dart';
import '../../core/system_media_scanner_service.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet rendering a WinDirStat-style disk space treemap heatmap.
/// Dynamically aggregates storage consumption from Vault and Device Storage.
class StorageTreemapSheet extends StatefulWidget {
  final bool isPage;

  const StorageTreemapSheet({super.key, this.isPage = false});

  static Future<void> show(BuildContext context) {
    return DedicatedToolPage.open(
      context,
      title: 'Disk Space Treemap & Heatmap',
      subtitle: 'WinDirStat-Style Proportional Storage Allocation',
      icon: Icons.donut_large_rounded,
      child: const StorageTreemapSheet(isPage: true),
    );
  }

  @override
  State<StorageTreemapSheet> createState() => _StorageTreemapSheetState();
}

class _StorageTreemapSheetState extends State<StorageTreemapSheet> {
  bool _isLoading = true;
  List<ReceivedFileItem> _allFiles = [];
  int _totalBytes = 0;

  int _videoBytes = 0;
  int _videoCount = 0;
  int _photoBytes = 0;
  int _photoCount = 0;
  int _archiveBytes = 0;
  int _archiveCount = 0;
  int _audioBytes = 0;
  int _audioCount = 0;
  int _docBytes = 0;
  int _docCount = 0;

  List<ReceivedFileItem> _topFiles = [];

  @override
  void initState() {
    super.initState();
    _loadDynamicStorageData();
  }

  Future<void> _loadDynamicStorageData() async {
    try {
      final vaultFiles = await ReceivedFilesService.instance.getReceivedFiles();
      final nonDirVault = vaultFiles.where((f) => !f.isDirectory).toList();
      final deviceFiles = SystemMediaScannerService.instance.cachedFiles;

      final Set<String> seenPaths = {};
      final List<ReceivedFileItem> combined = [];

      for (final f in nonDirVault) {
        if (seenPaths.add(f.path.toLowerCase())) {
          combined.add(f);
        }
      }
      for (final f in deviceFiles) {
        if (!f.isDirectory && seenPaths.add(f.path.toLowerCase())) {
          combined.add(f);
        }
      }

      int vBytes = 0, vCount = 0;
      int pBytes = 0, pCount = 0;
      int aBytes = 0, aCount = 0;
      int audBytes = 0, audCount = 0;
      int dBytes = 0, dCount = 0;
      int sumBytes = 0;

      for (final item in combined) {
        final b = item.sizeBytes;
        sumBytes += b;
        if (item.isVideo) {
          vBytes += b;
          vCount++;
        } else if (item.isImage) {
          pBytes += b;
          pCount++;
        } else if (item.isArchive) {
          aBytes += b;
          aCount++;
        } else if (item.isAudio) {
          audBytes += b;
          audCount++;
        } else {
          dBytes += b;
          dCount++;
        }
      }

      // Sort by size descending for top consumers
      combined.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

      if (mounted) {
        setState(() {
          _allFiles = combined;
          _totalBytes = sumBytes;
          _videoBytes = vBytes;
          _videoCount = vCount;
          _photoBytes = pBytes;
          _photoCount = pCount;
          _archiveBytes = aBytes;
          _archiveCount = aCount;
          _audioBytes = audBytes;
          _audioCount = audCount;
          _docBytes = dBytes;
          _docCount = dCount;
          _topFiles = combined.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final double safeTotal = _totalBytes > 0 ? _totalBytes.toDouble() : 1.0;

    final categories = [
      {
        'name': 'Videos & Recordings',
        'size': _formatBytes(_videoBytes),
        'ratio': _totalBytes > 0 ? (_videoBytes / safeTotal).clamp(0.02, 1.0) : 0.20,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFEFF6FF),
        'border': const Color(0xFFBFDBFE),
        'count': '$_videoCount files',
      },
      {
        'name': 'Photos & Camera Bursts',
        'size': _formatBytes(_photoBytes),
        'ratio': _totalBytes > 0 ? (_photoBytes / safeTotal).clamp(0.02, 1.0) : 0.20,
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFF0FDF4),
        'border': const Color(0xFFBBF7D0),
        'count': '$_photoCount files',
      },
      {
        'name': 'ZIP & Installer Archives',
        'size': _formatBytes(_archiveBytes),
        'ratio': _totalBytes > 0 ? (_archiveBytes / safeTotal).clamp(0.02, 1.0) : 0.20,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFFFBEB),
        'border': const Color(0xFFFDE68A),
        'count': '$_archiveCount files',
      },
      {
        'name': 'Podcasts & Music',
        'size': _formatBytes(_audioBytes),
        'ratio': _totalBytes > 0 ? (_audioBytes / safeTotal).clamp(0.02, 1.0) : 0.20,
        'color': const Color(0xFF9333EA),
        'bg': const Color(0xFFFAF5FF),
        'border': const Color(0xFFE9D5FF),
        'count': '$_audioCount files',
      },
      {
        'name': 'Documents & Code',
        'size': _formatBytes(_docBytes),
        'ratio': _totalBytes > 0 ? (_docBytes / safeTotal).clamp(0.02, 1.0) : 0.20,
        'color': const Color(0xFF475569),
        'bg': const Color(0xFFF8FAFC),
        'border': const Color(0xFFCBD5E1),
        'count': '$_docCount files',
      },
    ];

    return Container(
      constraints: widget.isPage ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isPage) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
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
                  child: const Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disk Space Heatmap & Treemap',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Visual WinDirStat-style storage consumption breakdown',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Visual Treemap Multi-Bar
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: categories.map((c) {
                            return Expanded(
                              flex: ((c['ratio'] as double) * 100).round().clamp(1, 100),
                              child: Container(
                                color: c['color'] as Color,
                                alignment: Alignment.center,
                                child: Text(
                                  (c['ratio'] as double) > 0.08
                                      ? '${((c['ratio'] as double) * 100).toStringAsFixed(0)}%'
                                      : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Category Allocation Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Category Allocation',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Total Indexed: ${_formatBytes(_totalBytes)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Categories List
                      ...categories.map((c) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: c['bg'] as Color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c['border'] as Color),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: c['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['name'] as String,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      c['count'] as String,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                c['size'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c['color'] as Color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      // Top Space-Hogging Files
                      const Text(
                        'Top Space Consumers',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      if (_topFiles.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text(
                              'No indexed files found in storage.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ] else ...[
                        ..._topFiles.map((f) {
                          String typeLabel = 'Document';
                          Color badgeColor = const Color(0xFF475569);
                          if (f.isVideo) {
                            typeLabel = 'Video';
                            badgeColor = const Color(0xFF2563EB);
                          } else if (f.isImage) {
                            typeLabel = 'Photo';
                            badgeColor = const Color(0xFF16A34A);
                          } else if (f.isAudio) {
                            typeLabel = 'Audio';
                            badgeColor = const Color(0xFF9333EA);
                          } else if (f.isArchive) {
                            typeLabel = 'Archive';
                            badgeColor = const Color(0xFFD97706);
                          }
                          return _buildTopFileTile(f.name, f.formattedSize, typeLabel, badgeColor);
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFileTile(String name, String size, String type, Color badgeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              type,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            size,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
