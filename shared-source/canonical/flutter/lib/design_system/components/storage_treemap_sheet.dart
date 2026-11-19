import 'package:flutter/material.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet rendering a WinDirStat-style disk space treemap heatmap.
class StorageTreemapSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Proportional breakdown data
    final categories = [
      {'name': 'Videos & Recordings', 'size': '18.4 GB', 'ratio': 0.46, 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFEFF6FF), 'border': const Color(0xFFBFDBFE), 'count': '42 files'},
      {'name': 'Photos & Camera Bursts', 'size': '9.2 GB', 'ratio': 0.23, 'color': const Color(0xFF16A34A), 'bg': const Color(0xFFF0FDF4), 'border': const Color(0xFFBBF7D0), 'count': '1,280 files'},
      {'name': 'ZIP & Installer Archives', 'size': '5.6 GB', 'ratio': 0.14, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFFFBEB), 'border': const Color(0xFFFDE68A), 'count': '18 files'},
      {'name': 'Podcasts & Music', 'size': '4.1 GB', 'ratio': 0.10, 'color': const Color(0xFF9333EA), 'bg': const Color(0xFFFAF5FF), 'border': const Color(0xFFE9D5FF), 'count': '85 files'},
      {'name': 'Documents & Code', 'size': '2.7 GB', 'ratio': 0.07, 'color': const Color(0xFF475569), 'bg': const Color(0xFFF8FAFC), 'border': const Color(0xFFCBD5E1), 'count': '420 files'},
    ];

    return Container(
      constraints: isPage ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isPage) ...[
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
            child: ListView(
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
                        flex: ((c['ratio'] as double) * 100).toInt(),
                        child: Container(
                          color: c['color'] as Color,
                          alignment: Alignment.center,
                          child: Text(
                            '${((c['ratio'] as double) * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Category Allocation',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Column(
                  children: categories.map((cat) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cat['bg'] as Color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cat['border'] as Color),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: cat['color'] as Color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['name'] as String,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  cat['count'] as String,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            cat['size'] as String,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cat['color'] as Color),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Top Space-Hogging Files
                const Text(
                  'Top Space Consumers',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                _buildTopFileTile('ubuntu-24.04-desktop-amd64.iso', '5.79 GB', 'OS Image', const Color(0xFF2563EB)),
                _buildTopFileTile('family_reunion_4k_hdr.mov', '4.21 GB', 'Video', const Color(0xFF2563EB)),
                _buildTopFileTile('drone_flight_raw_footage.mp4', '2.84 GB', 'Video', const Color(0xFF2563EB)),
                _buildTopFileTile('project_backup_202611.tar.gz', '1.95 GB', 'Archive', const Color(0xFFD97706)),
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
