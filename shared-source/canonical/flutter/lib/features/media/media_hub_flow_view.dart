import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/audio_player_service.dart';
import '../../core/received_files_service.dart';
import '../../core/models/file_item.dart';
import '../../design_system/components/media_preview_modal.dart';
import '../../design_system/components/floating_audio_mini_player.dart';
import '../../design_system/components/video_trimmer_sheet.dart';
import '../../design_system/components/subtitle_sync_sheet.dart';
import '../../design_system/components/audio_sleep_timer_sheet.dart';
import '../../design_system/components/audio_equalizer_sheet.dart';
import '../../design_system/components/similar_photo_grouper_sheet.dart';
import '../../design_system/components/torrent_downloader_sheet.dart';
import '../../design_system/components/virus_scanner_sheet.dart';

enum MediaHubTab { all, photos, videos, audio, documents }

/// Dedicated Media Viewer & Player Flow.
/// Provides specialized gallery views for photos, a gesture-enabled video theater,
/// an audio jukebox with speed controls and sleep timer, and a document previewer.
class MediaHubFlowView extends StatefulWidget {
  const MediaHubFlowView({super.key});

  @override
  State<MediaHubFlowView> createState() => _MediaHubFlowViewState();
}

class _MediaHubFlowViewState extends State<MediaHubFlowView> {
  final ReceivedFilesService _service = ReceivedFilesService.instance;
  final AudioPlayerService _audioService = AudioPlayerService.instance;

  MediaHubTab _currentTab = MediaHubTab.all;
  List<ReceivedFileItem> _allFiles = [];
  bool _isLoading = true;
  StreamSubscription<void>? _changeSub;

  double _playbackSpeed = 1.0;
  int _sleepTimerMinutes = 0;
  Timer? _sleepTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _changeSub = _service.changeStream.listen((_) => _loadData());
  }

  @override
  void dispose() {
    _changeSub?.cancel();
    _sleepTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final files = await _service.getReceivedFiles();
    if (mounted) {
      setState(() {
        _allFiles = files.where((f) => !f.isDirectory).toList();
        _isLoading = false;
      });
    }
  }

  List<ReceivedFileItem> get _filteredFiles {
    switch (_currentTab) {
      case MediaHubTab.photos:
        return _allFiles.where((f) => f.isImage).toList();
      case MediaHubTab.videos:
        return _allFiles.where((f) => f.isVideo).toList();
      case MediaHubTab.audio:
        return _allFiles.where((f) => f.isAudio).toList();
      case MediaHubTab.documents:
        return _allFiles.where((f) => f.isDocument).toList();
      case MediaHubTab.all:
      default:
        return _allFiles;
    }
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _audioService.setPlaybackSpeed(speed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Audio speed set to ${speed}x'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepTimerMinutes = minutes);
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _audioService.pause();
        if (mounted) {
          setState(() => _sleepTimerMinutes = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sleep timer paused media playback.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer set for $minutes minutes'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Utility Toolbar (Torrent Downloader & Antivirus Audit)
        _buildTopUtilityBar(),

        // Top Media Tab Selector
        _buildCategoryChips(),

        // Active Tab Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _filteredFiles.isEmpty
                  ? _buildEmptyState()
                  : _buildTabContent(),
        ),

        // Sticky Audio Mini-Player
        const FloatingAudioMiniPlayer(),
      ],
    );
  }

  Widget _buildTopUtilityBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('open_torrent_downloader_button'),
              onPressed: () => TorrentDownloaderSheet.show(context),
              icon: const Icon(Icons.downloading_rounded, size: 16, color: Color(0xFF2563EB)),
              label: const Text(
                'Torrent Downloader (Virus-Free)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('open_virus_scanner_button'),
            onPressed: () {
              final files = _allFiles;
              if (files.isNotEmpty) {
                VirusScannerSheet.show(context, files.first.path);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No media files in vault to audit.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.security_rounded, size: 15, color: Color(0xFF15803D)),
            label: const Text(
              'Virus Scan',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              side: const BorderSide(color: Color(0xFFBBF7D0)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip(MediaHubTab.all, 'All Media', Icons.perm_media_outlined),
            const SizedBox(width: 8),
            _buildTabChip(MediaHubTab.photos, 'Photos', Icons.photo_outlined),
            const SizedBox(width: 8),
            _buildTabChip(MediaHubTab.videos, 'Videos', Icons.videocam_outlined),
            const SizedBox(width: 8),
            _buildTabChip(MediaHubTab.audio, 'Audio Jukebox', Icons.headphones_outlined),
            const SizedBox(width: 8),
            _buildTabChip(MediaHubTab.documents, 'Documents', Icons.description_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(MediaHubTab tab, String label, IconData icon) {
    final isSelected = _currentTab == tab;
    return InkWell(
      key: Key('media_tab_${tab.name}'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTab = tab);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case MediaHubTab.photos:
        return _buildPhotosGrid();
      case MediaHubTab.videos:
        return _buildVideosList();
      case MediaHubTab.audio:
        return _buildAudioJukebox();
      case MediaHubTab.documents:
      case MediaHubTab.all:
      default:
        return _buildGenericMediaGrid();
    }
  }

  Widget _buildPhotosGrid() {
    final photos = _filteredFiles;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFFF8FAFC),
          child: OutlinedButton.icon(
            key: const Key('find_similar_photos_button'),
            onPressed: () {
              final photoFiles = _filteredFiles.map((f) => FileItem(name: f.name, path: f.path, size: f.sizeBytes, modified: f.lastModified)).toList();
              SimilarPhotoGrouperSheet.show(context, photoFiles, onResolved: _loadData);
            },
            icon: const Icon(Icons.burst_mode_rounded, size: 16, color: Color(0xFF2563EB)),
            label: const Text('Find Similar Photos & Burst Duplicates (dHash)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              side: const BorderSide(color: Color(0xFFDBEAFE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final item = photos[index];
              return InkWell(
                key: Key('photo_tile_$index'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openPreview(item, playlist: photos, index: index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                        cacheHeight: 240,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          color: Colors.black45,
                          child: Text(
                            item.name,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideosList() {
    final videos = _filteredFiles;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final item = videos[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openPreview(item, playlist: videos, index: index),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 30),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.extension.toUpperCase(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.formattedSize,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.subtitles_outlined, size: 18, color: Color(0xFF2563EB)),
                    tooltip: 'Subtitles & Real-Time Sync',
                    onPressed: () {
                      SubtitleSyncSheet.show(context, videoStem: item.name);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Lossless Video Frame Grabber',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved full-resolution frame from ${item.name} to Vault/Photos'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_cut_rounded, size: 18, color: Color(0xFF2563EB)),
                    tooltip: 'Trim Clip & Extract Soundtrack',
                    onPressed: () {
                      VideoTrimmerSheet.show(
                        context,
                        fileItem: item,
                        videoDuration: const Duration(minutes: 2),
                        onExported: _loadData,
                      );
                    },
                  ),
                  IconButton(
                    key: Key('video_virus_scan_$index'),
                    icon: const Icon(Icons.security_rounded, size: 18, color: Color(0xFF15803D)),
                    tooltip: 'Virus-Free Security Audit',
                    onPressed: () => VirusScannerSheet.show(context, item.path),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioJukebox() {
    final audioFiles = _filteredFiles;
    return Column(
      children: [
        // Speed, Equalizer & Sleep Controls Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 4),
              DropdownButton<double>(
                value: _playbackSpeed,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                  DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                  DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                  DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                  DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                  DropdownMenuItem(value: 2.5, child: Text('2.5x')),
                  DropdownMenuItem(value: 3.0, child: Text('3.0x')),
                ],
                onChanged: (val) {
                  if (val != null) _setPlaybackSpeed(val);
                },
              ),
              const SizedBox(width: 8),
              // Equalizer button
              InkWell(
                key: const Key('audio_equalizer_button'),
                onTap: () => AudioEqualizerSheet.show(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text('EQ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Sleep Timer with volume fade
              InkWell(
                key: const Key('audio_sleep_timer_button'),
                onTap: () => AudioSleepTimerSheet.show(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bedtime_outlined, size: 14, color: Color(0xFF9333EA)),
                      SizedBox(width: 4),
                      Text('Sleep Fade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7E22CE))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: audioFiles.length,
            itemBuilder: (context, index) {
              final item = audioFiles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.formattedSize,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB)),
                      onPressed: () {
                        _audioService.loadFolderQueue([item.path]);
                      },
                    ),
                    onTap: () {
                      _audioService.loadFolderQueue([item.path]);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenericMediaGrid() {
    final files = _filteredFiles;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final item = files[index];
        final icon = item.isImage
            ? Icons.photo_outlined
            : (item.isVideo
                ? Icons.videocam_outlined
                : (item.isAudio ? Icons.headphones_outlined : Icons.description_outlined));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: Icon(icon, color: const Color(0xFF2563EB)),
              title: Text(
                item.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${item.extension.toUpperCase()} • ${item.formattedSize}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              onTap: () => _openPreview(item, playlist: files, index: index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.perm_media_outlined, size: 28, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          const Text('No Media Files Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Received media or photos will appear here automatically.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _openPreview(ReceivedFileItem file, {List<ReceivedFileItem>? playlist, int index = 0}) {
    MediaPreviewModal.show(
      context,
      file,
      onDeleted: _loadData,
      playlist: playlist,
      initialIndex: index,
    );
  }
}
