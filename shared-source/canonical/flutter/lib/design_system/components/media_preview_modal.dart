import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/received_files_service.dart';
import '../../core/archive_extractor_service.dart';
import '../../core/document_inspector_service.dart';
import '../../core/file_staging_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';
import '../colors/peerlink_colors.dart';
import 'file_hash_diff_sheet.dart';
import '../../core/video_engine_controller.dart';
import '../../core/file_converter_service.dart';
import 'file_converter_sheet.dart';
import '../../core/file_version_snapshot_service.dart';
import 'version_history_modal.dart';
import '../../core/file_stash_tray_service.dart';
import '../../core/audio_player_service.dart';
import 'archive_studio_sheet.dart';
import 'apk_inspector_sheet.dart';
import 'pdf_suite_sheet.dart';
import 'expiring_beam_link_sheet.dart';
import 'video_trimmer_sheet.dart';
import 'floating_video_pip_overlay.dart';
import 'subtitle_sync_sheet.dart';

/// Universal In-App File & Media Viewer Engine (Minimalist Light-Only Surface).
/// Brings every file type to life directly inside PeerLink:
/// - Swipeable Media Gallery & Playlist Navigation (Prev/Next + horizontal swipe)
/// - Images: Pinch-zoom, 90° rotation, fullscreen lightbox with Prev/Next
/// - Videos: Inline Android hardware VideoView + thumbnail + 1-tap external player
/// - Audio: Inline Android MediaPlayer with live seek scrub bar & timer
/// - PDFs: Inline Android PdfRenderer page-by-page zoomable viewer
/// - Office (.docx/.pptx/.xlsx/.odt): Pure-Dart text/slide/sheet reader (Android & Windows)
/// - CSV/TSV: Scrollable DataTable viewer
/// - JSON/Code/Markdown/Text: Pretty-printed JSON, 1-tap copy & In-App Quick Text Editor
/// - Archives (.zip): File tree inspector & 1-tap Extract All
/// - Unknown/Binary: Magic-Byte file type detection & Hex/ASCII header inspector
/// - Apps/Executables: Enforces Rule 10 (Auto-Execution Guard) strictly.
class MediaPreviewModal extends StatefulWidget {
  final ReceivedFileItem fileItem;
  final VoidCallback? onFileDeleted;
  final ArchiveDetails? initialArchiveDetails;
  final List<ReceivedFileItem>? playlist;
  final int initialIndex;
  final bool openInEditMode;

  const MediaPreviewModal({
    super.key,
    required this.fileItem,
    this.onFileDeleted,
    this.initialArchiveDetails,
    this.playlist,
    this.initialIndex = 0,
    this.openInEditMode = false,
  });

  static Future<void> show(
    BuildContext context,
    ReceivedFileItem item, {
    VoidCallback? onDeleted,
    ArchiveDetails? archiveDetails,
    List<ReceivedFileItem>? playlist,
    int initialIndex = 0,
    bool openInEditMode = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MediaPreviewModal(
        fileItem: item,
        onFileDeleted: onDeleted,
        initialArchiveDetails: archiveDetails,
        playlist: playlist,
        initialIndex: initialIndex,
        openInEditMode: openInEditMode,
      ),
    );
  }

  @override
  State<MediaPreviewModal> createState() => _MediaPreviewModalState();
}

class _MediaPreviewModalState extends State<MediaPreviewModal> {
  final DocumentInspectorService _inspector = DocumentInspectorService.instance;
  final TextEditingController _editorController = TextEditingController();

  // Swipeable Gallery / Playlist state
  late List<ReceivedFileItem> _playlist;
  late int _currentIndex;

  ReceivedFileItem get _currentItem => _playlist[_currentIndex];
  bool get _hasPlaylist => _playlist.length > 1;
  bool get _canGoPrev => _currentIndex > 0;
  bool get _canGoNext => _currentIndex + 1 < _playlist.length;

  // Text / JSON / CSV / Inline Editor state
  String? _textContent;
  String? _prettyJsonContent;
  bool _formatJson = false;
  bool _isEditingText = false;
  bool _isSavingText = false;
  CsvTablePreview? _csvPreview;
  bool _showCsvRaw = false;

  // Office document state
  OfficeDocumentPreview? _officePreview;

  // PDF viewer state (Android native PdfRenderer)
  int _pdfPageCount = 0;
  int _pdfCurrentPage = 0;
  Uint8List? _pdfPageBytes;
  bool _isLoadingPdf = false;

  // Video inline player & thumbnail state
  bool _isPlayingInlineVideo = false;
  Uint8List? _videoThumbnailBytes;
  late VideoEngineController _videoController;

  // Audio inline player state (Android native MediaPlayer)
  bool _isAudioPlaying = false;
  int _audioPositionMs = 0;
  int _audioDurationMs = 0;
  Timer? _audioPollTimer;

  // Archive state
  ArchiveDetails? _archiveDetails;
  bool _isExtracting = false;

  // Binary inspector state
  BinaryInspectionResult? _binaryInspection;

  // Image state
  int _imageRotationQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    final rawList = widget.playlist?.where((f) => !f.isDirectory).toList();
    if (rawList != null && rawList.isNotEmpty) {
      _playlist = rawList;
      final idx = widget.initialIndex.clamp(0, _playlist.length - 1);
      final matchIdx = _playlist.indexWhere((f) => f.path == widget.fileItem.path);
      _currentIndex = matchIdx != -1 ? matchIdx : idx;
    } else {
      _playlist = [widget.fileItem];
      _currentIndex = 0;
    }
    _videoController = VideoEngineController();
    _loadCurrentItemState(useInitialArchive: true);
    if (widget.openInEditMode && _inspector.isCodeOrText(_currentItem.extension)) {
      _enterEditMode();
    }
  }

  @override
  void dispose() {
    _audioPollTimer?.cancel();
    _editorController.dispose();
    _videoController.dispose();
    if (_isAudioPlaying || _audioDurationMs > 0) {
      AndroidNodeBridge.instance.audioStop();
    }
    super.dispose();
  }

  void _loadCurrentItemState({bool useInitialArchive = false}) {
    final item = _currentItem;
    final ext = item.extension.toLowerCase();

    _textContent = null;
    _prettyJsonContent = null;
    _formatJson = false;
    _isEditingText = false;
    _csvPreview = null;
    _showCsvRaw = false;
    _officePreview = null;
    _pdfPageCount = 0;
    _pdfCurrentPage = 0;
    _pdfPageBytes = null;
    _isLoadingPdf = false;
    _isPlayingInlineVideo = false;
    _videoThumbnailBytes = null;
    _archiveDetails = null;
    _binaryInspection = null;
    _imageRotationQuarterTurns = 0;

    if (useInitialArchive && widget.initialArchiveDetails != null) {
      _archiveDetails = widget.initialArchiveDetails;
    } else if (item.isArchive || ext == 'zip') {
      _loadArchivePreview();
    } else if (item.isVideo) {
      _loadVideoThumbnail();
      final sub = VideoEngineController.findCompanionSubtitlePath(item.path);
      if (sub != null) {
        _videoController.loadSubtitleFromFileSync(sub);
      }
    } else if (item.isAudio) {
      // Ready for inline Android MediaPlayer or Windows default player
    } else if (_inspector.isPdf(ext)) {
      _loadPdfDocument();
    } else if (_inspector.isOfficeZipDocument(ext)) {
      _officePreview = _inspector.extractOfficeTextSync(item.path, ext);
    } else if (_inspector.isCodeOrText(ext)) {
      _loadTextPreview(ext);
    } else if (!item.isImage && !item.isApp) {
      _binaryInspection = _inspector.inspectBinaryFile(item.path);
    }
  }

  void _navigatePlaylist(int delta) {
    final target = _currentIndex + delta;
    if (target < 0 || target >= _playlist.length) return;
    _audioPollTimer?.cancel();
    if (_isAudioPlaying || _audioDurationMs > 0) {
      AndroidNodeBridge.instance.audioStop();
      _isAudioPlaying = false;
      _audioPositionMs = 0;
      _audioDurationMs = 0;
    }
    setState(() {
      _currentIndex = target;
      _loadCurrentItemState();
    });
  }

  void _loadTextPreview(String ext) {
    final raw = _inspector.readTextSnippet(_currentItem.path);
    _textContent = raw;
    if (_inspector.isJson(ext)) {
      _prettyJsonContent = _inspector.prettyPrintJson(raw);
    }
    if (_inspector.isCsvOrTsv(ext)) {
      _csvPreview = _inspector.parseCsvTable(
        raw,
        delimiter: ext == 'tsv' ? '\t' : ',',
      );
    }
  }

  void _enterEditMode() {
    try {
      final f = File(_currentItem.path);
      final fullText = f.existsSync() ? f.readAsStringSync() : (_textContent ?? '');
      _editorController.text = fullText;
    } catch (_) {
      _editorController.text = _textContent ?? '';
    }
    setState(() {
      _isEditingText = true;
    });
  }

  Future<void> _saveEditedText() async {
    if (_isSavingText) return;
    setState(() => _isSavingText = true);
    try {
      final target = File(_currentItem.path);
      // Capture Time-Machine snapshot before writing edits
      if (target.existsSync()) {
        FileVersionSnapshotService.instance.recordSnapshot(target, reason: 'In-App Edit');
      }
      final updated = _editorController.text;
      // Atomic-safe write via sibling temp file
      final tmp = File('${target.path}.peerlink_edit.tmp');
      tmp.writeAsStringSync(updated, flush: true);
      if (target.existsSync()) {
        target.writeAsStringSync(updated, flush: true);
        if (tmp.existsSync()) {
          try {
            tmp.deleteSync();
          } catch (_) {}
        }
      } else {
        tmp.renameSync(target.path);
      }

      final ext = _currentItem.extension.toLowerCase();
      final stat = target.statSync();
      final refreshedItem = ReceivedFileItem(
        path: _currentItem.path,
        name: _currentItem.name,
        sizeBytes: stat.size,
        lastModified: stat.modified,
        category: _currentItem.category,
        extension: _currentItem.extension,
      );

      ReceivedFilesService.instance.notifyChanged();

      if (mounted) {
        setState(() {
          _playlist[_currentIndex] = refreshedItem;
          _isEditingText = false;
          _isSavingText = false;
          _loadTextPreview(ext);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${_currentItem.name}"'),
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingText = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save file: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadVideoThumbnail() async {
    if (!PlatformCapabilities.isAndroid) return;
    final targetPath = _currentItem.path;
    final bytes = await AndroidNodeBridge.instance.getVideoThumbnail(targetPath);
    if (mounted && _currentItem.path == targetPath && bytes != null && bytes.isNotEmpty) {
      setState(() => _videoThumbnailBytes = bytes);
    }
  }

  Future<void> _loadPdfDocument() async {
    if (!PlatformCapabilities.isAndroid) return;
    final targetPath = _currentItem.path;
    setState(() => _isLoadingPdf = true);
    final count = await AndroidNodeBridge.instance.getPdfPageCount(targetPath);
    if (!mounted || _currentItem.path != targetPath) return;
    if (count > 0) {
      _pdfPageCount = count;
      await _renderPdfPage(0);
    } else {
      setState(() => _isLoadingPdf = false);
    }
  }

  Future<void> _renderPdfPage(int pageIndex) async {
    final targetPath = _currentItem.path;
    setState(() => _isLoadingPdf = true);
    final bytes = await AndroidNodeBridge.instance.renderPdfPage(
      targetPath,
      pageIndex,
      width: 960,
    );
    if (mounted && _currentItem.path == targetPath) {
      setState(() {
        _pdfCurrentPage = pageIndex;
        _pdfPageBytes = bytes;
        _isLoadingPdf = false;
      });
    }
  }

  Future<void> _toggleAudioPlayback() async {
    if (!PlatformCapabilities.isAndroid) {
      ReceivedFilesService.instance.openFileWithDefaultApp(_currentItem.path);
      return;
    }
    if (_isAudioPlaying) {
      final status = await AndroidNodeBridge.instance.audioPause();
      _audioPollTimer?.cancel();
      if (mounted) {
        setState(() {
          _isAudioPlaying = status['playing'] == true;
          _audioPositionMs = (status['positionMs'] as num?)?.toInt() ?? _audioPositionMs;
        });
      }
    } else {
      final status = await AndroidNodeBridge.instance.audioPlay(_currentItem.path);
      if (mounted) {
        setState(() {
          _isAudioPlaying = status['playing'] == true;
          _audioDurationMs = (status['durationMs'] as num?)?.toInt() ?? _audioDurationMs;
          _audioPositionMs = (status['positionMs'] as num?)?.toInt() ?? _audioPositionMs;
        });
        if (_isAudioPlaying) {
          _startAudioPolling();
        }
      }
    }
  }

  void _startAudioPolling() {
    _audioPollTimer?.cancel();
    _audioPollTimer = Timer.periodic(const Duration(milliseconds: 450), (_) async {
      if (!mounted) {
        _audioPollTimer?.cancel();
        return;
      }
      final status = await AndroidNodeBridge.instance.audioGetStatus();
      if (!mounted) return;
      final playing = status['playing'] == true;
      final pos = (status['positionMs'] as num?)?.toInt() ?? 0;
      final dur = (status['durationMs'] as num?)?.toInt() ?? _audioDurationMs;
      setState(() {
        _isAudioPlaying = playing;
        _audioPositionMs = pos;
        if (dur > 0) _audioDurationMs = dur;
      });
      if (!playing) {
        _audioPollTimer?.cancel();
      }
    });
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).floor().clamp(0, 359999);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _loadArchivePreview() async {
    final targetPath = _currentItem.path;
    final details = await ArchiveExtractorService.instance.inspectArchive(targetPath);
    if (mounted && _currentItem.path == targetPath) {
      setState(() => _archiveDetails = details);
    }
  }

  Future<void> _extractArchive() async {
    setState(() => _isExtracting = true);
    try {
      final dest = await ArchiveExtractorService.instance.extractArchive(_currentItem.path);
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archive extracted to: $dest'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Reveal',
              textColor: Colors.white,
              onPressed: () => ReceivedFilesService.instance.revealInFolder(dest),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extraction failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _currentItem;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getCategoryTint(item.category),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: _getCategoryColor(item.category).withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      _getCategoryIcon(item.category),
                      color: _getCategoryColor(item.category),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.formattedSize} • ${item.extension.isEmpty ? "FILE" : item.extension.toUpperCase()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              // Swipeable Gallery / Playlist Navigation Strip
              if (_hasPlaylist) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        key: const Key('preview_prev_button'),
                        onPressed: _canGoPrev ? () => _navigatePlaylist(-1) : null,
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        label: const Text('Prev', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      Text(
                        '${_currentIndex + 1} / ${_playlist.length}',
                        key: const Key('preview_playlist_counter'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('preview_next_button'),
                        onPressed: _canGoNext ? () => _navigatePlaylist(1) : null,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        label: const Text('Next', style: TextStyle(fontSize: 12)),
                        iconAlignment: IconAlignment.end,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 20, color: Color(0xFFE5E7EB)),

              // Preview Body with horizontal swipe gesture support
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (_hasPlaylist && !_isEditingText && !item.isImage)
                      ? (details) {
                          final v = details.primaryVelocity ?? 0;
                          if (v < -300 && _canGoNext) {
                            _navigatePlaylist(1);
                          } else if (v > 300 && _canGoPrev) {
                            _navigatePlaylist(-1);
                          }
                        }
                      : null,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: _buildPreviewContent(theme, item),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Bottom Actions Toolbar (Horizontally scrollable for zero-overflow on any viewport)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!item.isApp) ...[
                      FilledButton.icon(
                        key: const Key('modal_open_file_button'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open with App'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          ReceivedFilesService.instance.openFileWithDefaultApp(item.path);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      key: const Key('modal_share_file_button'),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        ReceivedFilesService.instance.shareFile(item.path);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: const Text('Reveal Folder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        ReceivedFilesService.instance.revealInFolder(item.path);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('modal_verify_hash_button'),
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Verify Hash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        FileHashDiffSheet.showChecksumVerifier(
                          context,
                          filePath: item.path,
                          fileName: item.name,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('modal_convert_format_button'),
                      icon: const Icon(Icons.transform_rounded, size: 16),
                      label: const Text('Convert Format'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        FileConverterSheet.show(
                          context,
                          item,
                          onConversionComplete: () {
                            if (mounted) setState(() => _loadCurrentItemState());
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('modal_stash_button'),
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('Stash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        FileStashTrayService.instance.stashItem(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Stashed "${item.name}" into tray'), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('modal_beam_link_button'),
                      icon: const Icon(Icons.timer_outlined, size: 16),
                      label: const Text('Expiring Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => ExpiringBeamLinkSheet.show(context, filePath: item.path),
                    ),
                    if (item.extension.toLowerCase() == '.zip' || item.extension.toLowerCase() == '.tar') ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('modal_archive_studio_button'),
                        icon: const Icon(Icons.folder_zip_outlined, size: 16),
                        label: const Text('Archive Studio'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => ArchiveStudioSheet.show(context, archivePath: item.path),
                      ),
                    ],
                    if (item.extension.toLowerCase() == '.apk') ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('modal_apk_inspect_button'),
                        icon: const Icon(Icons.android_rounded, size: 16),
                        label: const Text('Inspect APK'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => ApkInspectorSheet.show(context, apkPath: item.path),
                      ),
                    ],
                    if (item.extension.toLowerCase() == '.pdf') ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('modal_pdf_suite_button'),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('Watermark PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => PdfSuiteSheet.show(context, sourceFilePath: item.path),
                      ),
                    ],
                    if (item.category == ReceivedFileCategory.audio) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const Key('modal_audio_studio_button'),
                        icon: const Icon(Icons.music_note_rounded, size: 16),
                        label: const Text('Audio Studio'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          AudioPlayerService.instance.loadFolderQueue([item.path]);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playing "${item.name}" in background mini-player'), duration: const Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('modal_version_history_button'),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        VersionHistoryModal.show(
                          context,
                          File(item.path),
                          onRestored: () {
                            if (mounted) setState(() => _loadCurrentItemState());
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PeerLinkColors.dangerRed,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _confirmDelete(context, item),
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

  Widget _buildPreviewContent(ThemeData theme, ReceivedFileItem item) {
    final ext = item.extension.toLowerCase();

    if (item.isImage) {
      return _buildImagePreview(theme, item);
    }

    if (item.isVideo) {
      return _buildVideoPlayerCard(theme, item);
    }

    if (item.isAudio) {
      return _buildAudioPlayerCard(theme, item);
    }

    if (item.isApp) {
      return _buildAppSecurityCard(theme, item);
    }

    if (item.isArchive || ext == 'zip') {
      return _buildArchivePreview(theme, item);
    }

    if (_inspector.isPdf(ext)) {
      return _buildPdfPreview(theme, item);
    }

    if (_inspector.isOfficeZipDocument(ext)) {
      return _buildOfficePreview(theme, item);
    }

    if (_inspector.isCsvOrTsv(ext) &&
        !_isEditingText &&
        _csvPreview != null &&
        _csvPreview!.headers.isNotEmpty) {
      return _buildCsvPreview(theme, item);
    }

    if (_inspector.isCodeOrText(ext)) {
      return _buildCodeOrTextPreview(theme, item);
    }

    return _buildBinaryInspectorCard(theme, item);
  }

  Widget _buildCodeOrTextPreview(ThemeData theme, ReceivedFileItem item) {
    final ext = item.extension.toLowerCase();
    final isJsonFile = _inspector.isJson(ext) && _prettyJsonContent != null;
    final displayedText =
        (isJsonFile && _formatJson) ? _prettyJsonContent! : (_textContent ?? 'No content');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isEditingText ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isEditingText ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                _isEditingText
                    ? 'Editing ${item.extension.toUpperCase()}'
                    : '${item.extension.toUpperCase()} Plaintext',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _isEditingText ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                  fontSize: 11,
                ),
              ),
            ),
            if (_isEditingText)
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const Key('cancel_edit_text_button'),
                    onPressed: _isSavingText
                        ? null
                        : () => setState(() => _isEditingText = false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                  FilledButton.icon(
                    key: const Key('save_edit_text_button'),
                    onPressed: _isSavingText ? null : _saveEditedText,
                    icon: const Icon(Icons.save_outlined, size: 14),
                    label: Text(_isSavingText ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    key: const Key('edit_text_preview_button'),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _enterEditMode,
                  ),
                  if (isJsonFile)
                    TextButton(
                      key: const Key('toggle_json_format_button'),
                      onPressed: () => setState(() => _formatJson = !_formatJson),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        _formatJson ? 'Raw' : 'Format',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  TextButton.icon(
                    key: const Key('copy_text_preview_button'),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy Content', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: displayedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Content copied to clipboard'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditingText)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
            ),
            child: TextField(
              key: const Key('inline_text_editor_field'),
              controller: _editorController,
              maxLines: null,
              minLines: 10,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Write text or notes here...',
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(
              displayedText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCsvPreview(ThemeData theme, ReceivedFileItem item) {
    final csv = _csvPreview!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                '${item.extension.toUpperCase()} Table • ${csv.totalRowCount} rows',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF047857),
                  fontSize: 11,
                ),
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _enterEditMode,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showCsvRaw = !_showCsvRaw),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF2563EB),
                  ),
                  child: Text(_showCsvRaw ? 'Table View' : 'Raw View', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showCsvRaw)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              _textContent ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF0F172A)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const Key('csv_data_table'),
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columnSpacing: 18,
                horizontalMargin: 12,
                columns: csv.headers
                    .map(
                      (h) => DataColumn(
                        label: Text(
                          h,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                rows: csv.rows
                    .map(
                      (row) => DataRow(
                        cells: row
                            .map(
                              (cell) => DataCell(
                                Text(
                                  cell,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOfficePreview(ThemeData theme, ReceivedFileItem item) {
    final preview = _officePreview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.article_outlined, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview?.documentType ?? 'Office Document',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      preview != null
                          ? '${preview.sectionCount} ${preview.sectionCount == 1 ? "section" : "sections"} extracted • In-App Reader'
                          : 'In-App Document Reader',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              if (preview != null && preview.hasContent)
                IconButton(
                  key: const Key('copy_office_text_button'),
                  tooltip: 'Copy Extracted Text',
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: preview.extractedText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Document text copied'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('office_document_reader'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: SelectableText(
            preview?.extractedText ?? 'No preview available.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfPreview(ThemeData theme, ReceivedFileItem item) {
    if (PlatformCapabilities.isAndroid && (_pdfPageCount > 0 || _isLoadingPdf)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _pdfPageCount > 0
                      ? 'PDF Reader • Page ${_pdfCurrentPage + 1} of $_pdfPageCount'
                      : 'Loading PDF...',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                    fontSize: 11,
                  ),
                ),
              ),
              if (_pdfPageCount > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('pdf_prev_page_button'),
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _pdfCurrentPage > 0 && !_isLoadingPdf
                          ? () => _renderPdfPage(_pdfCurrentPage - 1)
                          : null,
                    ),
                    IconButton(
                      key: const Key('pdf_next_page_button'),
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _pdfCurrentPage + 1 < _pdfPageCount && !_isLoadingPdf
                          ? () => _renderPdfPage(_pdfCurrentPage + 1)
                          : null,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 400,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: _isLoadingPdf
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : _pdfPageBytes != null
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.5,
                        child: Center(
                          child: Image.memory(_pdfPageBytes!, fit: BoxFit.contain),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Unable to render PDF page.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'PDF Document • ${item.formattedSize} • 100% Offline',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rule 10 Verified: PDF sandboxed without external web relays or executable scripts.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('open_document_button'),
                  onPressed: () => ReceivedFilesService.instance.openFileWithDefaultApp(item.path),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open with System App'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const Key('convert_pdf_button'),
                onPressed: () => FileConverterSheet.show(context, item),
                icon: const Icon(Icons.transform_rounded, size: 18),
                label: const Text('Convert Format'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBinaryInspectorCard(ThemeData theme, ReceivedFileItem item) {
    final info = _binaryInspection ?? _inspector.inspectBinaryFile(item.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.data_object_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Universal File Inspector • ${info.detectedType}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Signature', info.magicHex, theme),
              _buildInfoRow('Inspected', '${info.sampledBytes} of ${item.formattedSize}', theme),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (info.isLikelyText && info.textSnippet != null && info.textSnippet!.trim().isNotEmpty) ...[
          const Text(
            'Text Header Preview',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(
              info.textSnippet!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (info.hexLines.isNotEmpty) ...[
          const Text(
            'Hex / ASCII Header Dump',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Container(
            key: const Key('binary_hex_dump'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(
              info.hexLines.join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.45,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Center(
          child: FilledButton.icon(
            key: const Key('open_document_button'),
            onPressed: () => ReceivedFilesService.instance.openFileWithDefaultApp(item.path),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open with System App'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppSecurityCard(ThemeData theme, ReceivedFileItem item) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rule 10: Auto-Execution Guard',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFB45309),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Executables and application packages are quarantined from automatic execution to prevent unauthorized scripts from running.',
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('File Path', item.path, theme),
        _buildInfoRow('Size', item.formattedSize, theme),
        _buildInfoRow('Package Extension', item.extension.toUpperCase(), theme),
      ],
    );
  }

  Widget _buildArchivePreview(ThemeData theme, ReceivedFileItem item) {
    final details = _archiveDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF2F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFBCFE8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFCE7F3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.archive_rounded, color: Color(0xFFDB2777), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ZIP Archive Inspector',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            details != null
                                ? '${details.fileCount} files • ${details.formattedTotalSize}'
                                : 'Reading archive contents...',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('extract_archive_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDB2777),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isExtracting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.folder_zip_rounded, size: 16),
                label: Text(
                  _isExtracting ? 'Extracting...' : 'Extract All',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: _isExtracting ? null : _extractArchive,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (details != null && details.entries.isNotEmpty) ...[
          const Text(
            'Contained Files',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.entries.length,
            itemBuilder: (ctx, idx) {
              final entry = details.entries[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
                      size: 16,
                      color: entry.isDirectory ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.path,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.formattedSize,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              );
            },
          ),
        ] else if (details != null && details.entries.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Empty archive or standard format',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview(ThemeData theme, ReceivedFileItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFF475569)),
                  SizedBox(width: 4),
                  Text(
                    'Pinch / Scroll to Zoom',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  key: const Key('rotate_image_button'),
                  tooltip: 'Rotate 90°',
                  icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 20, color: Color(0xFF0F172A)),
                  onPressed: () {
                    setState(() {
                      _imageRotationQuarterTurns = (_imageRotationQuarterTurns + 1) % 4;
                    });
                  },
                ),
                IconButton(
                  key: const Key('fullscreen_image_button'),
                  tooltip: 'Fullscreen Lightbox',
                  icon: const Icon(Icons.fullscreen_rounded, size: 22, color: Color(0xFF0F172A)),
                  onPressed: () => _openFullscreenLightbox(context, item),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 380),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: RotatedBox(
                  quarterTurns: _imageRotationQuarterTurns,
                  child: Image.file(
                    File(item.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildPlaceholderCard(
                      theme,
                      Icons.broken_image_rounded,
                      'Failed to render image preview.',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('stage_image_button'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7C3AED),
            side: const BorderSide(color: Color(0xFFC4B5FD)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Stage Image to Beam Tray'),
          onPressed: () => _stageAndNotify(item),
        ),
      ],
    );
  }

  void _openFullscreenLightbox(BuildContext context, ReceivedFileItem item) {
    final imageItems = _playlist.where((f) => f.isImage).toList();
    int lightboxIndex = imageItems.indexWhere((f) => f.path == item.path);
    if (lightboxIndex == -1) {
      imageItems.add(item);
      lightboxIndex = imageItems.length - 1;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (dialogCtx) {
          int lightboxRotation = _imageRotationQuarterTurns;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final activeImg = imageItems[lightboxIndex];
              return Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  foregroundColor: const Color(0xFF0F172A),
                  title: Text(
                    imageItems.length > 1
                        ? '${activeImg.name} (${lightboxIndex + 1}/${imageItems.length})'
                        : activeImg.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  actions: [
                    if (imageItems.length > 1) ...[
                      IconButton(
                        tooltip: 'Previous Photo',
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: lightboxIndex > 0
                            ? () => setDialogState(() {
                                  lightboxIndex--;
                                  lightboxRotation = 0;
                                })
                            : null,
                      ),
                      IconButton(
                        tooltip: 'Next Photo',
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: lightboxIndex + 1 < imageItems.length
                            ? () => setDialogState(() {
                                  lightboxIndex++;
                                  lightboxRotation = 0;
                                })
                            : null,
                      ),
                    ],
                    IconButton(
                      tooltip: 'Rotate 90°',
                      icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
                      onPressed: () {
                        setDialogState(() {
                          lightboxRotation = (lightboxRotation + 1) % 4;
                        });
                        setState(() {
                          _imageRotationQuarterTurns = lightboxRotation;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: 'Close Lightbox',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
                body: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8.0,
                    child: RotatedBox(
                      quarterTurns: lightboxRotation,
                      child: Image.file(File(activeImg.path), fit: BoxFit.contain),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayerCard(ThemeData theme, ReceivedFileItem item) {
    final canPlayInline = PlatformCapabilities.isAndroid;
    final isLocked = _videoController.isLocked;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 1. Gesture-driven Video Viewport
          LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth;
              return AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video hardware view or thumbnail
                      if (_isPlayingInlineVideo && canPlayInline)
                        Positioned.fill(
                          child: AndroidView(
                            viewType: 'org.peerlink/inline_video_view',
                            creationParams: {'path': item.path},
                            creationParamsCodec: const StandardMessageCodec(),
                          ),
                        )
                      else if (_videoThumbnailBytes != null)
                        Positioned.fill(
                          child: Image.memory(
                            _videoThumbnailBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFF0F172A),
                            child: const Center(
                              child: Icon(
                                Icons.movie_creation_outlined,
                                size: 84,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),

                      // In-app brightness dimming layer (black overlay with opacity based on controller.brightness)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black.withValues(
                              alpha: ((1.0 - _videoController.brightness) * 0.85).clamp(0.0, 0.85),
                            ),
                          ),
                        ),
                      ),

                      // Interactive Gesture Zone (Left = Brightness, Right = Volume, Horizontal = Seek Scrub, DoubleTap = +/-10s)
                      if (!isLocked)
                        Positioned.fill(
                          child: GestureDetector(
                            key: const Key('video_gesture_surface'),
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) {
                              final isLeft = details.localPosition.dx < (viewportWidth / 2);
                              if (isLeft) {
                                _videoController.handleVerticalDragLeft(details.delta.dy);
                              } else {
                                _videoController.handleVerticalDragRight(details.delta.dy);
                              }
                              setState(() {});
                            },
                            onHorizontalDragUpdate: (details) {
                              _videoController.handleHorizontalDrag(details.delta.dx);
                              setState(() {});
                            },
                            onDoubleTapDown: (details) {
                              final isRight = details.localPosition.dx >= (viewportWidth / 2);
                              _videoController.handleDoubleTap(isRight);
                              setState(() {});
                            },
                            onTap: () {
                              setState(() {
                                _videoController.togglePlayPause();
                              });
                            },
                          ),
                        ),

                      // Floating Gestures HUD Indicator (Center)
                      if (_videoController.gestureHudMessage != null)
                        Positioned(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: Text(
                              _videoController.gestureHudMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                      // Active Subtitle Overlay
                      if (_videoController.activeSubtitleText != null)
                        Positioned(
                          bottom: 24,
                          left: 16,
                          right: 16,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _videoController.activeSubtitleText!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Center Play/Pause button (Visible when stopped or paused or not locked)
                      if (!isLocked && (!_isPlayingInlineVideo || !_videoController.isPlaying))
                        Positioned(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('play_video_button'),
                              borderRadius: BorderRadius.circular(40),
                              onTap: () {
                                if (canPlayInline) {
                                  setState(() {
                                    _isPlayingInlineVideo = true;
                                    _videoController.isPlaying = true;
                                  });
                                } else {
                                  ReceivedFilesService.instance.openFileWithDefaultApp(item.path);
                                }
                              },
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2563EB),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  _isPlayingInlineVideo && _videoController.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Top Badges (Format Badge + Screen Lock Button)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_outlined, size: 12, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                '${item.extension.toUpperCase()} • HW 4K/HDR',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top-Right: Screen Lock / Unlock Action
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isPlayingInlineVideo)
                              InkWell(
                                onTap: () => setState(() => _isPlayingInlineVideo = false),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: const Text(
                                    'Stop',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),
                            // Screen Lock Button
                            InkWell(
                              key: isLocked
                                  ? const Key('video_screen_unlock_button')
                                  : const Key('video_screen_lock_button'),
                              onTap: () => setState(() => _videoController.toggleScreenLock()),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isLocked ? const Color(0xFFDC2626) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isLocked ? const Color(0xFFB91C1C) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                      size: 13,
                                      color: isLocked ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isLocked ? 'Unlock' : 'Lock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isLocked ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom-Left: File Size & Gesture Hint
                      if (!isLocked)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              '${item.formattedSize} • ↕ Left: Brightness  ↕ Right: Volume',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                            ),
                          ),
                        ),

                      // Screen Lock Overlay Banner when locked
                      if (isLocked)
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Screen Controls Locked (Tap Unlock in top corner)',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // 2. Video Engine Quick-Control Toolbar (disabled when locked)
          Opacity(
            opacity: isLocked ? 0.4 : 1.0,
            child: IgnorePointer(
              ignoring: isLocked,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Dedicated Play / Pause Toolbar Button
                          IconButton(
                            key: const Key('video_toolbar_play_pause_button'),
                            icon: Icon(
                              _isPlayingInlineVideo && _videoController.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 22,
                              color: const Color(0xFF2563EB),
                            ),
                            tooltip: _isPlayingInlineVideo && _videoController.isPlaying ? 'Pause' : 'Play',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              if (canPlayInline) {
                                setState(() {
                                  if (!_isPlayingInlineVideo) {
                                    _isPlayingInlineVideo = true;
                                    _videoController.isPlaying = true;
                                  } else {
                                    _videoController.togglePlayPause();
                                  }
                                });
                              } else {
                                ReceivedFilesService.instance.openFileWithDefaultApp(item.path);
                              }
                            },
                          ),
                          // Skip Back 10s
                          IconButton(
                            key: const Key('video_skip_back_button'),
                            icon: const Icon(Icons.replay_10_rounded, size: 20, color: Color(0xFF0F172A)),
                            tooltip: 'Skip Back 10s',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _videoController.seekRelative(const Duration(seconds: -10))),
                          ),
                          // Skip Forward 10s
                          IconButton(
                            key: const Key('video_skip_forward_button'),
                            icon: const Icon(Icons.forward_10_rounded, size: 20, color: Color(0xFF0F172A)),
                            tooltip: 'Skip Forward 10s',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _videoController.seekRelative(const Duration(seconds: 10))),
                          ),
                          const SizedBox(width: 4),
                          // Playback Speed Selector
                          PopupMenuButton<double>(
                            key: const Key('video_speed_button'),
                            tooltip: 'Playback Speed',
                            initialValue: _videoController.playbackSpeed,
                            onSelected: (speed) => setState(() => _videoController.setPlaybackSpeed(speed)),
                            itemBuilder: (ctx) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0].map((s) => PopupMenuItem(
                              value: s,
                              child: Text('${s}x Speed', style: TextStyle(fontWeight: s == _videoController.playbackSpeed ? FontWeight.bold : FontWeight.normal)),
                            )).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '${_videoController.playbackSpeed}x',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Aspect Ratio Selector
                          InkWell(
                            key: const Key('video_aspect_ratio_button'),
                            onTap: () => setState(() => _videoController.toggleAspectRatio()),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.aspect_ratio_rounded, size: 14, color: Color(0xFF475569)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _videoController.aspectRatioMode.name.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Loop Mode Toggle
                          InkWell(
                            key: const Key('video_loop_button'),
                            onTap: () => setState(() => _videoController.toggleLoop()),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoController.isLooping ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _videoController.isLooping ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat_rounded, size: 14, color: _videoController.isLooping ? const Color(0xFF2563EB) : const Color(0xFF475569)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _videoController.isLooping ? 'Loop: ON' : 'Loop: OFF',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _videoController.isLooping ? const Color(0xFF1D4ED8) : const Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Subtitles Badge & Calibrator
                          InkWell(
                            key: const Key('video_subtitles_button'),
                            onTap: () => SubtitleSyncSheet.show(context, videoStem: item.name),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoController.subtitles.isNotEmpty ? const Color(0xFFF0FDF4) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _videoController.subtitles.isNotEmpty ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.subtitles_rounded, size: 14, color: _videoController.subtitles.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _videoController.subtitles.isNotEmpty ? 'CC: ${_videoController.subtitles.length}' : 'CC: Sync',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _videoController.subtitles.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Frame Grabber Snapshot
                          InkWell(
                            key: const Key('video_frame_grabber_button'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved full-resolution frame from ${item.name} to Vault/Photos'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFF475569)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Snapshot',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Trim / Audio Extraction
                          InkWell(
                            key: const Key('video_trim_sheet_button'),
                            onTap: () {
                              VideoTrimmerSheet.show(
                                context,
                                fileItem: item,
                                videoDuration: _videoController.duration,
                                onExported: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Media processed successfully')),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.content_cut_rounded, size: 14, color: Color(0xFF2563EB)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Trim / Audio',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Picture-in-Picture (PiP)
                          InkWell(
                            key: const Key('video_pip_button'),
                            onTap: () => setState(() => _videoController.togglePip()),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoController.isPipActive ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _videoController.isPipActive ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.picture_in_picture_alt_rounded,
                                    size: 14,
                                    color: _videoController.isPipActive ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _videoController.isPipActive ? 'PiP: ON' : 'PiP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _videoController.isPipActive ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Background Audio
                          InkWell(
                            key: const Key('video_bg_audio_button'),
                            onTap: () => setState(() => _videoController.toggleBackgroundAudio()),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoController.backgroundAudioEnabled ? const Color(0xFFF0FDF4) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _videoController.backgroundAudioEnabled ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.headphones_rounded,
                                    size: 14,
                                    color: _videoController.backgroundAudioEnabled ? const Color(0xFF16A34A) : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _videoController.backgroundAudioEnabled ? 'BG Audio: ON' : 'BG Audio',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _videoController.backgroundAudioEnabled ? const Color(0xFF15803D) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hardware-Accelerated Zero-Loss Playback',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canPlayInline
                        ? 'Drag vertically on left for brightness, right for volume. Drag horizontally or double tap left/right to skip 10 seconds.'
                        : 'Streams directly to your system\'s high-performance native media engine with full hardware GPU decoding and HDR support.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('open_video_player_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(
                            _isPlayingInlineVideo ? Icons.open_in_new_rounded : Icons.play_circle_fill_rounded,
                            size: 20,
                          ),
                          label: Text(_isPlayingInlineVideo ? 'Open External' : 'Play Video'),
                          onPressed: () {
                            if (canPlayInline && !_isPlayingInlineVideo) {
                              setState(() {
                                _isPlayingInlineVideo = true;
                                _videoController.isPlaying = true;
                              });
                            } else {
                              ReceivedFilesService.instance.openFileWithDefaultApp(item.path);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const Key('stage_video_button'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Stage'),
                        onPressed: () => _stageAndNotify(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayerCard(ThemeData theme, ReceivedFileItem item) {
    final maxMs = _audioDurationMs > 0 ? _audioDurationMs.toDouble() : 1.0;
    final curMs = _audioPositionMs.clamp(0, _audioDurationMs > 0 ? _audioDurationMs : 1).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFFBEB),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    ),
                    child: Center(
                      child: Icon(
                        _isAudioPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                        size: 36,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      '${item.extension.toUpperCase()} AUDIO',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${item.formattedSize} • Lossless Audio Track',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          if (PlatformCapabilities.isAndroid && _audioDurationMs > 0) ...[
            const SizedBox(height: 12),
            Slider(
              value: curMs,
              min: 0,
              max: maxMs,
              activeColor: const Color(0xFFD97706),
              inactiveColor: const Color(0xFFE5E7EB),
              onChanged: (v) async {
                final pos = v.round();
                setState(() => _audioPositionMs = pos);
                await AndroidNodeBridge.instance.audioSeek(pos);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_audioPositionMs),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    _formatDuration(_audioDurationMs),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('play_audio_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                    _isAudioPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _isAudioPlaying ? 'Pause Audio' : 'Play Audio Track',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _toggleAudioPlayback,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const Key('stage_audio_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Stage'),
                onPressed: () => _stageAndNotify(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _stageAndNotify(ReceivedFileItem item) {
    FileStagingService.instance.addPaths([item.path]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Staged "${item.name}" for beaming'),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPlaceholderCard(
    ThemeData theme,
    IconData icon,
    String message, {
    Color color = const Color(0xFF2563EB),
    Widget? actionButton,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 58, color: color),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
          ),
          if (actionButton != null) ...[
            const SizedBox(height: 16),
            actionButton,
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ReceivedFileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to permanently delete "${item.name}" from disk?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PeerLinkColors.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ReceivedFilesService.instance.deleteFile(item.path);
      widget.onFileDeleted?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  IconData _getCategoryIcon(ReceivedFileCategory category) {
    switch (category) {
      case ReceivedFileCategory.photos:
        return Icons.photo_library_outlined;
      case ReceivedFileCategory.videos:
        return Icons.video_library_outlined;
      case ReceivedFileCategory.audio:
        return Icons.music_note_outlined;
      case ReceivedFileCategory.documents:
        return Icons.description_outlined;
      case ReceivedFileCategory.apps:
        return Icons.apps_rounded;
      case ReceivedFileCategory.archives:
        return Icons.archive_outlined;
      case ReceivedFileCategory.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getCategoryColor(ReceivedFileCategory category) {
    switch (category) {
      case ReceivedFileCategory.photos:
        return const Color(0xFF7C3AED);
      case ReceivedFileCategory.videos:
        return const Color(0xFFDC2626);
      case ReceivedFileCategory.audio:
        return const Color(0xFFD97706);
      case ReceivedFileCategory.documents:
        return const Color(0xFF2563EB);
      case ReceivedFileCategory.apps:
        return const Color(0xFF059669);
      case ReceivedFileCategory.archives:
        return const Color(0xFFDB2777);
      case ReceivedFileCategory.other:
        return const Color(0xFF475569);
    }
  }

  Color _getCategoryTint(ReceivedFileCategory category) {
    switch (category) {
      case ReceivedFileCategory.photos:
        return const Color(0xFFF5F3FF);
      case ReceivedFileCategory.videos:
        return const Color(0xFFFEF2F2);
      case ReceivedFileCategory.audio:
        return const Color(0xFFFFFBEB);
      case ReceivedFileCategory.documents:
        return const Color(0xFFEFF6FF);
      case ReceivedFileCategory.apps:
        return const Color(0xFFECFDF5);
      case ReceivedFileCategory.archives:
        return const Color(0xFFFDF2F8);
      case ReceivedFileCategory.other:
        return const Color(0xFFF1F5F9);
    }
  }
}
