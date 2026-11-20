import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/media/media_source_models.dart';
import '../../core/media/media_library_service.dart';
import '../../core/models/file_item.dart';
import '../../design_system/components/contextual_share_sheet.dart';

/// Professional Full-Screen Image Viewer inspired by Aves and Immich.
/// Features matrix-based pinch-to-zoom (up to 8x), gesture disambiguation,
/// double-tap zoom, 90° rotation, timed slideshow, slide-over EXIF/technical metadata inspector,
/// and Windows desktop keyboard/mouse integration.
class ProfessionalImageViewer extends StatefulWidget {
  final List<MediaItem> playlist;
  final int initialIndex;
  final VoidCallback? onMediaChanged;

  const ProfessionalImageViewer({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
    this.onMediaChanged,
  });

  static Future<void> open(
    BuildContext context, {
    required List<MediaItem> playlist,
    int initialIndex = 0,
    VoidCallback? onMediaChanged,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) => ProfessionalImageViewer(
          playlist: playlist,
          initialIndex: initialIndex,
          onMediaChanged: onMediaChanged,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ProfessionalImageViewer> createState() => _ProfessionalImageViewerState();
}

class _ProfessionalImageViewerState extends State<ProfessionalImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformController = TransformationController();
  final FocusNode _focusNode = FocusNode();

  bool _isChromeVisible = true;
  bool _isZoomed = false;
  int _rotationQuarterTurns = 0;
  bool _isSlideshowRunning = false;
  Timer? _slideshowTimer;
  bool _showMetadataSheet = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.playlist.isEmpty ? 0 : widget.playlist.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _transformController.addListener(_handleTransformChanged);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _transformController.removeListener(_handleTransformChanged);
    _transformController.dispose();
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final isZoomedNow = scale > 1.05;
    if (isZoomedNow != _isZoomed) {
      setState(() => _isZoomed = isZoomedNow);
    }
  }

  void _toggleChrome() {
    setState(() => _isChromeVisible = !_isChromeVisible);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale > 1.1) {
      // Reset to 1.0x fit
      _transformController.value = Matrix4.identity();
    } else {
      // Zoom into tap point at 2.5x
      final position = details.localPosition;
      final x = -position.dx * (2.5 - 1.0);
      final y = -position.dy * (2.5 - 1.0);
      final zoomed = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.5);
      _transformController.value = zoomed;
    }
  }

  void _rotate90() {
    HapticFeedback.lightImpact();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _toggleSlideshow() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSlideshowRunning = !_isSlideshowRunning;
    });

    if (_isSlideshowRunning) {
      _startSlideshow();
    } else {
      _slideshowTimer?.cancel();
    }
  }

  void _startSlideshow() {
    _slideshowTimer?.cancel();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_isSlideshowRunning) {
        timer.cancel();
        return;
      }
      if (_currentIndex < widget.playlist.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      } else {
        // Loop back to start
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _nextImage() {
    if (_currentIndex < widget.playlist.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuad,
      );
    }
  }

  void _prevImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuad,
      );
    }
  }

  void _revealInExplorer(String filePath) {
    if (!Platform.isWindows) return;
    try {
      Process.run('explorer.exe', ['/select,', filePath]);
    } catch (e) {
      debugPrint('Failed to reveal in explorer: $e');
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        _nextImage();
        break;
      case LogicalKeyboardKey.arrowLeft:
        _prevImage();
        break;
      case LogicalKeyboardKey.space:
        _toggleSlideshow();
        break;
      case LogicalKeyboardKey.keyR:
        _rotate90();
        break;
      case LogicalKeyboardKey.keyI:
        setState(() => _showMetadataSheet = !_showMetadataSheet);
        break;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlist.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('No media items to display', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final currentItem = widget.playlist[_currentIndex];

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        body: Stack(
          children: [
            // 1. Gesture-disambiguated Interactive PageView
            PageView.builder(
              controller: _pageController,
              physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              itemCount: widget.playlist.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _transformController.value = Matrix4.identity();
                  _rotationQuarterTurns = 0;
                  _isZoomed = false;
                });
              },
              itemBuilder: (context, index) {
                final item = widget.playlist[index];
                final file = File(item.path);

                return GestureDetector(
                  onTap: _toggleChrome,
                  onDoubleTapDown: _handleDoubleTap,
                  child: Center(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1.0,
                      maxScale: 8.0,
                      child: RotatedBox(
                        quarterTurns: _rotationQuarterTurns,
                        child: file.existsSync()
                            ? Image.file(
                                file,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildErrorWidget(),
                              )
                            : _buildMissingWidget(item.path),
                      ),
                    ),
                  ),
                );
              },
            ),

            // 2. Animated Top Chrome Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isChromeVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isChromeVisible,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 12,
                      left: 16,
                      right: 16,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Close Lightbox',
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentItem.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_currentIndex + 1} of ${widget.playlist.length} • ${currentItem.formattedSize}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _isSlideshowRunning ? 'Pause Slideshow' : 'Start Slideshow',
                          icon: Icon(
                            _isSlideshowRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
                            color: _isSlideshowRunning ? const Color(0xFF38BDF8) : Colors.white,
                          ),
                          onPressed: _toggleSlideshow,
                        ),
                        IconButton(
                          tooltip: 'Photo Information (EXIF)',
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: _showMetadataSheet ? const Color(0xFF38BDF8) : Colors.white,
                          ),
                          onPressed: () {
                            setState(() => _showMetadataSheet = !_showMetadataSheet);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Animated Bottom Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isChromeVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isChromeVisible,
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                      top: 12,
                      left: 20,
                      right: 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.rotate_right_rounded,
                          label: 'Rotate 90°',
                          onTap: _rotate90,
                        ),
                        _buildActionButton(
                          icon: currentItem.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          label: 'Favorite',
                          iconColor: currentItem.isFavorite ? const Color(0xFFEF4444) : Colors.white,
                          onTap: () {
                            MediaLibraryService.instance.toggleFavorite(currentItem.id);
                            setState(() {});
                            widget.onMediaChanged?.call();
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.share_rounded,
                          label: 'Beam / Share',
                          onTap: () {
                            ContextualShareSheet.show(
                              context,
                              initialPaths: [currentItem.path],
                            );
                          },
                        ),
                        if (Platform.isWindows)
                          _buildActionButton(
                            icon: Icons.folder_open_rounded,
                            label: 'Reveal',
                            onTap: () => _revealInExplorer(currentItem.path),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Slide-Over Metadata Inspector Panel
            if (_showMetadataSheet)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 320,
                child: _buildMetadataInspector(currentItem),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataInspector(MediaItem item) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131924),
        border: Border(left: BorderSide(color: Color(0xFF1E293B))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Photo Details',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _showMetadataSheet = false),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildMetaRow('File Name', item.name),
                _buildMetaRow('File Size', item.formattedSize),
                _buildMetaRow('Resolution', item.resolutionString),
                _buildMetaRow('Origin', item.origin.name),
                _buildMetaRow('Date Taken', item.dateTaken.toLocal().toString().split('.').first),
                _buildMetaRow('Album / Folder', item.parentDirectoryName),
                _buildMetaRow('File Path', item.path, isPath: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFFE2E8F0),
              fontSize: 12,
              fontFamily: isPath ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFF64748B)),
        SizedBox(height: 12),
        Text('Unable to render image', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildMissingWidget(String path) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.file_present_rounded, size: 48, color: Color(0xFF64748B)),
        const SizedBox(height: 12),
        const Text('File not found at path', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            path,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
