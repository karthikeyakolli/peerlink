import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/audio_player_service.dart';
import '../../core/received_files_service.dart';
import '../../core/system_media_scanner_service.dart';
import '../../core/models/file_item.dart';
import '../../core/media/media_source_models.dart';
import '../../core/media/media_library_service.dart';
import '../../core/media/playback_backend.dart';
import 'professional_image_viewer.dart';
import 'video_theater_player.dart';
import '../../design_system/components/media_preview_modal.dart';
import '../../design_system/components/floating_audio_mini_player.dart';
import '../../design_system/components/dedicated_tool_page.dart';
import '../../design_system/components/video_trimmer_sheet.dart';
import '../../design_system/components/subtitle_sync_sheet.dart';
import '../../design_system/components/audio_sleep_timer_sheet.dart';
import '../../design_system/components/audio_equalizer_sheet.dart';
import '../../design_system/components/similar_photo_grouper_sheet.dart';
import '../../design_system/components/torrent_downloader_sheet.dart';
import '../../design_system/components/virus_scanner_sheet.dart';
import '../../design_system/components/contextual_share_sheet.dart';
import '../../platform/windows_file_dialog.dart';

enum MediaHubTab { all, photos, videos, audio, documents }
enum MediaStorageScope { device, vault, unified }

/// Reconstructed PeerLink Media Center.
/// Combines the responsive desktop layout of Microsoft Photos and CPlay Windows
/// with the fluid touch gestures and timeline grouping of Aves and Immich.
/// Supports zero-cloud P2P streaming, local device storage scanning, secure vault isolation,
/// professional full-screen photo viewing, and hardware-accelerated video theater playback.
class MediaHubFlowView extends StatefulWidget {
  const MediaHubFlowView({super.key});

  @override
  State<MediaHubFlowView> createState() => _MediaHubFlowViewState();
}

class _MediaHubFlowViewState extends State<MediaHubFlowView> {
  final MediaLibraryService _mediaService = MediaLibraryService.instance;
  final ReceivedFilesService _vaultService = ReceivedFilesService.instance;
  final SystemMediaScannerService _systemScanner = SystemMediaScannerService.instance;
  final AudioPlayerService _audioService = AudioPlayerService.instance;

  MediaHubTab _currentTab = MediaHubTab.all;
  MediaStorageScope _storageScope = MediaStorageScope.device;
  bool _isSelectionMode = false;
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<void>? _vaultSub;

  @override
  void initState() {
    super.initState();
    _mediaService.addListener(_onServiceUpdate);
    _vaultSub = _vaultService.changeStream.listen((_) => _refreshData());
    _refreshData();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mediaService.removeListener(_onServiceUpdate);
    _vaultSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData({bool forceSystemSync = false}) async {
    // Map current scope to service origin
    if (_storageScope == MediaStorageScope.device) {
      _mediaService.setOriginFilter(MediaOrigin.deviceStorage);
    } else if (_storageScope == MediaStorageScope.vault) {
      _mediaService.setOriginFilter(MediaOrigin.vaultStorage);
    } else {
      _mediaService.setOriginFilter(null);
    }
    await _mediaService.refreshMedia(forceSystemSync: forceSystemSync);
  }

  void _handleTabChanged(MediaHubTab tab) {
    HapticFeedback.selectionClick();
    setState(() => _currentTab = tab);
    switch (tab) {
      case MediaHubTab.photos:
        _mediaService.setKindFilter(MediaKind.photo);
        break;
      case MediaHubTab.videos:
        _mediaService.setKindFilter(MediaKind.video);
        break;
      case MediaHubTab.audio:
        _mediaService.setKindFilter(MediaKind.audio);
        break;
      case MediaHubTab.all:
      case MediaHubTab.documents:
      default:
        _mediaService.setKindFilter(null);
        break;
    }
  }

  void _openPhotoViewer(MediaItem photo, {required List<MediaItem> playlist}) {
    final photoList = playlist.where((it) => it.isPhoto).toList();
    final index = photoList.indexWhere((it) => it.id == photo.id);
    ProfessionalImageViewer.open(
      context,
      playlist: photoList.isNotEmpty ? photoList : [photo],
      initialIndex: index != -1 ? index : 0,
      onMediaChanged: () => setState(() {}),
    );
  }

  void _openVideoTheater(MediaItem video) {
    VideoTheaterPlayer.open(
      context,
      source: MediaSourceDescriptor.fromFilePath(video.path, title: video.name),
    );
  }

  void _openItem(MediaItem item, {required List<MediaItem> playlist}) {
    if (item.isPhoto) {
      _openPhotoViewer(item, playlist: playlist);
    } else if (item.isVideo) {
      _openVideoTheater(item);
    } else {
      // Audio or document fallback via MediaPreviewModal
      MediaPreviewModal.show(
        context,
        ReceivedFileItem(
          name: item.name,
          path: item.path,
          sizeBytes: item.sizeBytes,
          lastModified: item.lastModified,
          category: item.isPhoto
              ? ReceivedFileCategory.photos
              : (item.isVideo
                  ? ReceivedFileCategory.videos
                  : (item.isAudio ? ReceivedFileCategory.audio : ReceivedFileCategory.other)),
          extension: item.name.contains('.') ? item.name.split('.').last : '',
        ),
        onDeleted: _refreshData,
      );
    }
  }

  void _revealInExplorer(String filePath) {
    if (!Platform.isWindows) return;
    try {
      Process.run('explorer.exe', ['/select,', filePath]);
    } catch (e) {
      debugPrint('Failed to reveal file: $e');
    }
  }

  void _openSimilarPhotoGrouper() {
    final photos = _mediaService.allItems.where((it) => it.isPhoto).toList();
    DedicatedToolPage.open(
      context,
      title: 'Perceptual dHash Photo Grouper',
      subtitle: 'AI-Free Perceptual Duplicate & Burst Detector',
      icon: Icons.auto_awesome_motion_rounded,
      child: SimilarPhotoGrouperSheet(
        photoItems: photos
            .map((f) => FileItem(
                  name: f.name,
                  path: f.path,
                  size: f.sizeBytes,
                  modified: f.lastModified,
                ))
            .toList(),
      ),
    );
  }

  void _openTorrentDownloader() {
    DedicatedToolPage.open(
      context,
      title: 'Torrent & Web Downloader',
      subtitle: 'Multi-Stream BitTorrent Engine with Real-Time Virus Scanner',
      icon: Icons.downloading_rounded,
      child: const TorrentDownloaderSheet(),
    );
  }

  void _openVirusScanner(String path) {
    DedicatedToolPage.open(
      context,
      title: 'Zero-Trust Antivirus Scanner',
      subtitle: 'Multi-Vector Threat Audit, PE Inspector & Quarantine Enclave',
      icon: Icons.security_rounded,
      child: VirusScannerSheet(filePath: path),
    );
  }

  void _openAudioEqualizer() {
    DedicatedToolPage.open(
      context,
      title: '5-Band Audio Equalizer',
      subtitle: 'Acoustic Tuning & Vocal Clarity Presets',
      icon: Icons.graphic_eq_rounded,
      child: const SingleChildScrollView(child: AudioEqualizerSheet()),
    );
  }

  void _openAudioSleepTimer() {
    DedicatedToolPage.open(
      context,
      title: 'Audio Sleep Timer',
      subtitle: 'Automated Playback Pause & Gradual Volume Fade',
      icon: Icons.bedtime_outlined,
      child: const SingleChildScrollView(child: AudioSleepTimerSheet()),
    );
  }

  Future<void> _pickAndAddCustomFolder() async {
    try {
      final selected = await WindowsFileDialog.pickDirectory(title: 'Select Media Folder to Synchronize');
      if (selected != null && selected.isNotEmpty) {
        _systemScanner.addCustomScanFolder(selected);
        await _refreshData(forceSystemSync: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added media folder: $selected'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking custom folder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Row(
            children: [
              // 1. Desktop Left Navigation Rail / Sidebar (Microsoft Photos paradigm)
              if (isDesktop) _buildDesktopSidebar(),

              // 2. Main Gallery Content Canvas
              Expanded(
                child: Column(
                  children: [
                    // Sticky Control Chrome
                    _buildTopHeader(isDesktop),

                    // Active Gallery Content (Timeline sections)
                    Expanded(
                      child: _mediaService.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                            )
                          : _buildTimelineGallery(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopSidebar() {
    final albums = _mediaService.availableAlbums;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.perm_media_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Media Center',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Navigation Items
          _buildSidebarNavItem(
            label: 'All Media',
            icon: Icons.grid_view_rounded,
            isSelected: _currentTab == MediaHubTab.all && !_mediaService.favoritesOnly && _mediaService.selectedAlbumName == null,
            onTap: () {
              _mediaService.setFavoritesOnly(false);
              _mediaService.setSelectedAlbum(null);
              _handleTabChanged(MediaHubTab.all);
            },
          ),
          _buildSidebarNavItem(
            label: 'Photos',
            icon: Icons.photo_library_outlined,
            isSelected: _currentTab == MediaHubTab.photos && !_mediaService.favoritesOnly,
            onTap: () {
              _mediaService.setFavoritesOnly(false);
              _mediaService.setSelectedAlbum(null);
              _handleTabChanged(MediaHubTab.photos);
            },
          ),
          _buildSidebarNavItem(
            label: 'Videos',
            icon: Icons.video_library_outlined,
            isSelected: _currentTab == MediaHubTab.videos && !_mediaService.favoritesOnly,
            onTap: () {
              _mediaService.setFavoritesOnly(false);
              _mediaService.setSelectedAlbum(null);
              _handleTabChanged(MediaHubTab.videos);
            },
          ),
          _buildSidebarNavItem(
            key: const Key('media_tab_audio'),
            label: 'Audio Jukebox',
            icon: Icons.library_music_outlined,
            isSelected: _currentTab == MediaHubTab.audio && !_mediaService.favoritesOnly,
            onTap: () {
              _mediaService.setFavoritesOnly(false);
              _mediaService.setSelectedAlbum(null);
              _handleTabChanged(MediaHubTab.audio);
            },
          ),
          _buildSidebarNavItem(
            key: const Key('media_tab_documents'),
            label: 'Documents',
            icon: Icons.description_outlined,
            isSelected: _currentTab == MediaHubTab.documents && !_mediaService.favoritesOnly,
            onTap: () {
              _mediaService.setFavoritesOnly(false);
              _mediaService.setSelectedAlbum(null);
              _handleTabChanged(MediaHubTab.documents);
            },
          ),
          _buildSidebarNavItem(
            label: 'Favorites',
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFEF4444),
            isSelected: _mediaService.favoritesOnly,
            onTap: () {
              _mediaService.setSelectedAlbum(null);
              _mediaService.setFavoritesOnly(true);
            },
          ),

          const Divider(color: Color(0xFFE2E8F0), height: 28),

          // Folders & Albums Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'ALBUMS & FOLDERS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: _pickAndAddCustomFolder,
                  child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF0284C7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (albums.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('No folders discovered', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            )
          else
            ...albums.take(8).map((album) => _buildSidebarNavItem(
                  label: album,
                  icon: Icons.folder_outlined,
                  isSelected: _mediaService.selectedAlbumName == album,
                  onTap: () {
                    _mediaService.setFavoritesOnly(false);
                    _mediaService.setSelectedAlbum(album);
                  },
                )),

          const Divider(color: Color(0xFFE2E8F0), height: 28),

          // Tools Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'MEDIA UTILITIES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
            ),
          ),
          _buildSidebarNavItem(
            label: 'Clean Similar / Bursts',
            icon: Icons.auto_awesome_motion_rounded,
            isSelected: false,
            onTap: _openSimilarPhotoGrouper,
          ),
          _buildSidebarNavItem(
            key: const Key('open_torrent_downloader_button'),
            label: 'Web & Torrent Ingest',
            icon: Icons.downloading_rounded,
            isSelected: false,
            onTap: _openTorrentDownloader,
          ),
          _buildSidebarNavItem(
            key: const Key('open_virus_scanner_button'),
            label: 'Zero-Trust Audit',
            icon: Icons.security_rounded,
            isSelected: false,
            onTap: () {
              final files = _mediaService.allItems;
              if (files.isNotEmpty) {
                _openVirusScanner(files.first.path);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    Key? key,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? (isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search input
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (q) => _mediaService.setSearchQuery(q),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                _mediaService.setSearchQuery('');
                              },
                            )
                          : null,
                      hintText: 'Search media by file name...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Storage Scope selector
              _buildScopeChip('Device', MediaStorageScope.device, Icons.smartphone_rounded),
              const SizedBox(width: 4),
              _buildScopeChip('Vault', MediaStorageScope.vault, Icons.shield_rounded),
              const SizedBox(width: 4),
              _buildScopeChip('Unified', MediaStorageScope.unified, Icons.all_inclusive_rounded),

              const SizedBox(width: 6),

              // View density toggle (Comfortable vs Compact)
              IconButton(
                tooltip: _mediaService.viewDensity == MediaViewDensity.comfortable
                    ? 'Switch to Compact Grid'
                    : 'Switch to Comfortable Grid',
                icon: Icon(
                  _mediaService.viewDensity == MediaViewDensity.comfortable
                      ? Icons.view_comfy_rounded
                      : Icons.grid_on_rounded,
                  size: 20,
                  color: const Color(0xFF475569),
                ),
                onPressed: () {
                  _mediaService.setViewDensity(
                    _mediaService.viewDensity == MediaViewDensity.comfortable
                        ? MediaViewDensity.compact
                        : MediaViewDensity.comfortable,
                  );
                },
              ),

              // Sort dropdown
              PopupMenuButton<MediaSortOption>(
                tooltip: 'Sort Media',
                icon: const Icon(Icons.sort_rounded, size: 20, color: Color(0xFF475569)),
                onSelected: (sort) => _mediaService.setSortOption(sort),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: MediaSortOption.dateNewest,
                    child: Text('Date: Newest First', style: TextStyle(fontSize: 12)),
                  ),
                  const PopupMenuItem(
                    value: MediaSortOption.dateOldest,
                    child: Text('Date: Oldest First', style: TextStyle(fontSize: 12)),
                  ),
                  const PopupMenuItem(
                    value: MediaSortOption.sizeLargest,
                    child: Text('Size: Largest First', style: TextStyle(fontSize: 12)),
                  ),
                  const PopupMenuItem(
                    value: MediaSortOption.nameAsc,
                    child: Text('Name: A to Z', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              // Sync / Refresh button
              IconButton(
                key: const Key('sync_system_media_button'),
                tooltip: 'Refresh / Scan Storage',
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                onPressed: () => _refreshData(forceSystemSync: true),
              ),
            ],
          ),

          // Secondary Category Chips on mobile
          if (!isDesktop) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMobileCategoryChip('All Media', MediaHubTab.all),
                  _buildMobileCategoryChip('Photos', MediaHubTab.photos),
                  _buildMobileCategoryChip('Videos', MediaHubTab.videos),
                  _buildMobileCategoryChip('Audio Jukebox', MediaHubTab.audio, key: const Key('media_tab_audio')),
                  _buildMobileCategoryChip('Documents', MediaHubTab.documents, key: const Key('media_tab_documents')),
                  // Similar photos button
                  OutlinedButton.icon(
                    key: const Key('open_similar_photo_grouper_button'),
                    onPressed: _openSimilarPhotoGrouper,
                    icon: const Icon(Icons.auto_awesome_motion_rounded, size: 14, color: Color(0xFF0284C7)),
                    label: const Text('Clean Bursts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Virus scanner button
                  OutlinedButton.icon(
                    key: const Key('open_virus_scanner_button'),
                    onPressed: () {
                      final files = _mediaService.allItems;
                      if (files.isNotEmpty) {
                        _openVirusScanner(files.first.path);
                      }
                    },
                    icon: const Icon(Icons.security_rounded, size: 14, color: Color(0xFF15803D)),
                    label: const Text('Threat Audit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeChip(String label, MediaStorageScope scope, IconData icon) {
    final isSelected = _storageScope == scope;
    return InkWell(
      key: Key('storage_scope_${scope.name}_btn'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _storageScope = scope);
        _refreshData();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCategoryChip(String label, MediaHubTab tab, {Key? key}) {
    final isSelected = _currentTab == tab;
    return Container(
      key: key,
      margin: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        selected: isSelected,
        onSelected: (_) => _handleTabChanged(tab),
        selectedColor: const Color(0xFFE0F2FE),
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildTimelineGallery() {
    final sections = _mediaService.timelineSections;

    return Column(
      children: [
        if (_currentTab == MediaHubTab.audio)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('audio_equalizer_button'),
                  onPressed: _openAudioEqualizer,
                  icon: const Icon(Icons.graphic_eq_rounded, size: 14),
                  label: const Text('Equalizer', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('audio_sleep_timer_button'),
                  onPressed: _openAudioSleepTimer,
                  icon: const Icon(Icons.bedtime_outlined, size: 14),
                  label: const Text('Sleep Timer', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('1.0x', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        Expanded(
          child: sections.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.all(16),
                  itemCount: sections.length,
                  itemBuilder: (context, sectionIdx) {
                    final sec = sections[sectionIdx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sticky Timeline Date Header
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                sec.dateTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${sec.items.length} items',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),

                        // Grid items for this timeline section
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final isCompact = _mediaService.viewDensity == MediaViewDensity.compact;
                            int crossAxisCount = (width / (isCompact ? 110 : 160)).floor();
                            if (crossAxisCount < 2) crossAxisCount = 2;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.88,
                              ),
                              itemCount: sec.items.length,
                              itemBuilder: (context, itemIdx) {
                                final item = sec.items[itemIdx];
                                return _buildMediaGridCard(item, sec.items);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMediaGridCard(MediaItem item, List<MediaItem> contextItems) {
    final file = File(item.path);
    final exists = file.existsSync();

    return InkWell(
      onTap: () => _openItem(item, playlist: contextItems),
      onSecondaryTap: () {
        // Windows right-click context menu
        if (Platform.isWindows) {
          _revealInExplorer(item.path);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visual Preview Area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF1F5F9),
                    child: item.isPhoto && exists
                        ? Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 28, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Center(
                            child: Icon(
                              item.isVideo
                                  ? Icons.movie_creation_outlined
                                  : (item.isAudio ? Icons.audiotrack_rounded : Icons.insert_drive_file_outlined),
                              size: 32,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                  ),

                  // Video Duration & Play Badge
                  if (item.isVideo)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              item.formattedDuration,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Favorite indicator
                  if (item.isFavorite)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFEF4444)),
                    ),
                ],
              ),
            ),

            // Item Name & Metadata
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.formattedSize,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF1F5F9),
            ),
            child: const Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Media Files Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add custom media folders or check your Device / Vault storage.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _refreshData(forceSystemSync: true),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Rescan Storage', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
