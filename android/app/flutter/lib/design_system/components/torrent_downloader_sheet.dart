import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/torrent_download_service.dart';
import '../../core/services/virus_scanner_service.dart';
import '../../core/received_files_service.dart';
import 'media_preview_modal.dart';
import 'virus_scanner_sheet.dart';

/// Dedicated Torrent & Web Downloader Sheet with Real-Time Virus Scanning.
/// Minimalist Light-Only design (#FFFFFF, #F7F8FA, #E5E7EB, #2563EB, zero dark mode).
class TorrentDownloaderSheet extends StatefulWidget {
  const TorrentDownloaderSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TorrentDownloaderSheet(),
    );
  }

  @override
  State<TorrentDownloaderSheet> createState() => _TorrentDownloaderSheetState();
}

class _TorrentDownloaderSheetState extends State<TorrentDownloaderSheet> {
  final TorrentDownloadService _service = TorrentDownloadService.instance;
  final TextEditingController _magnetController = TextEditingController();
  StreamSubscription<List<TorrentDownloadItem>>? _sub;
  List<TorrentDownloadItem> _torrents = [];

  // Popular legal open-source torrent presets for 1-tap verification
  static const List<Map<String, String>> presets = [
    {
      'title': 'Big Buck Bunny (4K 60fps Video)',
      'uri': 'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big_Buck_Bunny_4K.mp4&xl=85000000',
      'icon': 'video',
    },
    {
      'title': 'NASA Hubble Deep Field (HDR Photo)',
      'uri': 'magnet:?xt=urn:btih:3b879fbc9b7b9ef896e3b5e408544c06cfb332b7&dn=Hubble_Deep_Field_HDR.jpg&xl=14200000',
      'icon': 'photo',
    },
    {
      'title': 'Ubuntu 24.04 LTS (ISO Image)',
      'uri': 'magnet:?xt=urn:btih:ee11cbb19052e40b07aac0ca060c23ee35d73048&dn=ubuntu-24.04-desktop-amd64.iso&xl=4500000000',
      'icon': 'os',
    },
  ];

  @override
  void initState() {
    super.initState();
    _torrents = _service.activeTorrents;
    _sub = _service.torrentStream.listen((items) {
      if (mounted) setState(() => _torrents = items);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _magnetController.dispose();
    super.dispose();
  }

  void _addMagnet() {
    final text = _magnetController.text.trim();
    if (text.isEmpty) return;
    _service.addMagnetLink(text);
    _magnetController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: const Icon(Icons.downloading_rounded, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Torrent & Web Downloader',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Multi-peer swarm engine with automated virus-free verification',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Input card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Magnet URI or Web Torrent',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('torrent_magnet_input_field'),
                              controller: _magnetController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Paste magnet:?xt=urn:btih:...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            key: const Key('add_torrent_button'),
                            onPressed: _addMagnet,
                            icon: const Icon(Icons.add_link_rounded, size: 16),
                            label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Quick 1-tap presets
                      const Text(
                        'Quick Legal Presets (Open Media & Free Software):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: presets.map((p) {
                          return ActionChip(
                            key: Key('preset_${p['title']}'),
                            label: Text(p['title']!, style: const TextStyle(fontSize: 11)),
                            avatar: Icon(
                              p['icon'] == 'video'
                                  ? Icons.movie_outlined
                                  : p['icon'] == 'photo'
                                      ? Icons.photo_outlined
                                      : Icons.album_outlined,
                              size: 14,
                              color: const Color(0xFF2563EB),
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onPressed: () {
                              _service.addMagnetLink(p['uri']!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Started downloading ${p['title']}'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Active & Completed Downloads Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Downloads (${_torrents.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    if (_torrents.isNotEmpty)
                      Text(
                        'Total Rate: ${_calculateTotalRate()}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF15803D)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_torrents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.cloud_download_outlined, size: 36, color: Color(0xFF94A3B8)),
                          SizedBox(height: 8),
                          Text(
                            'No active downloads',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          Text(
                            'Add a magnet link or tap a preset above to begin.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._torrents.map((item) => _buildTorrentCard(item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalRate() {
    int total = 0;
    for (final t in _torrents) {
      total += t.downloadSpeedBytesPerSec;
    }
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(1)} KB/s';
    return '${(total / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  Widget _buildTorrentCard(TorrentDownloadItem item) {
    final isDone = item.status == TorrentStatus.completed;
    final isError = item.status == TorrentStatus.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? const Color(0xFFBBF7D0)
              : isError
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.name.endsWith('.mp4') || item.name.endsWith('.mkv')
                    ? Icons.movie_outlined
                    : item.name.endsWith('.jpg') || item.name.endsWith('.png')
                        ? Icons.photo_outlined
                        : Icons.insert_drive_file_outlined,
                size: 20,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                onPressed: () => _service.cancelTorrent(item.id, deleteFiles: false),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress bar
          LinearProgressIndicator(
            value: item.progress,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDone
                  ? const Color(0xFF16A34A)
                  : isError
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),

          // Telemetry and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? const Color(0xFF15803D)
                      : isError
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF334155),
                ),
              ),
              if (!isDone && !isError)
                Text(
                  '${item.formattedSpeed} • ${item.peers} peers',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              if (isDone)
                Text(
                  item.formattedTotalSize,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),

          // Virus scan security badge
          if (item.isVirusScanned) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.isVirusClean ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: item.isVirusClean ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isVirusClean ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                    size: 14,
                    color: item.isVirusClean ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.virusScanSummary,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.isVirusClean ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons on completed items
          if (isDone) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('play_torrent_${item.id}'),
                    onPressed: () {
                      final fileItem = ReceivedFileItem(
                        path: item.outputPath,
                        name: item.name,
                        sizeBytes: item.totalBytes,
                        lastModified: DateTime.now(),
                        category: item.name.endsWith('.mp4') || item.name.endsWith('.mkv')
                            ? ReceivedFileCategory.videos
                            : item.name.endsWith('.jpg') || item.name.endsWith('.png')
                                ? ReceivedFileCategory.photos
                                : ReceivedFileCategory.other,
                        extension: item.name.split('.').last,
                      );
                      Navigator.pop(context);
                      MediaPreviewModal.show(context, fileItem);
                    },
                    icon: const Icon(Icons.play_circle_filled_rounded, size: 16),
                    label: const Text('Play / View Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: Key('scan_cert_torrent_${item.id}'),
                  onPressed: () => VirusScannerSheet.show(context, item.outputPath),
                  icon: const Icon(Icons.security_rounded, size: 14, color: Color(0xFF15803D)),
                  label: const Text('Audit Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
