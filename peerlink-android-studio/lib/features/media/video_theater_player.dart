import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import '../../core/media/playback_backend.dart';
import '../../core/media/media_source_models.dart';
import '../../core/video_engine_controller.dart';
import '../../core/models/file_item.dart';
import '../../design_system/components/contextual_share_sheet.dart';

/// Advanced Video Theater Player inspired by CPlay, VLC, and UC Browser.
/// Powered by media_kit (libmpv hardware decoder on Windows and Android)
/// with touch gestures (brightness, volume, scrub, double-tap skip),
/// desktop keyboard shortcuts, subtitle parsing, A-B repeat looping,
/// and auto-hiding HUD chrome.
class VideoTheaterPlayer extends StatefulWidget {
  final MediaSourceDescriptor source;
  final VideoEngineController? controller;
  final VoidCallback? onBack;

  const VideoTheaterPlayer({
    super.key,
    required this.source,
    this.controller,
    this.onBack,
  });

  static Future<void> open(
    BuildContext context, {
    required MediaSourceDescriptor source,
    VideoEngineController? controller,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoTheaterPlayer(
          source: source,
          controller: controller,
        ),
      ),
    );
  }

  @override
  State<VideoTheaterPlayer> createState() => _VideoTheaterPlayerState();
}

class _VideoTheaterPlayerState extends State<VideoTheaterPlayer> {
  late VideoEngineController _controller;
  late bool _ownsController;
  final FocusNode _focusNode = FocusNode();

  bool _isChromeVisible = true;
  Timer? _chromeTimer;
  Duration? _loopPointA;
  Duration? _loopPointB;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = VideoEngineController();
      _ownsController = true;
    }

    _controller.addListener(_onControllerUpdate);
    _focusNode.requestFocus();
    _startPlayback();
    _resetChromeTimer();
  }

  Future<void> _startPlayback() async {
    // Attempt companion subtitle auto-detection if source is a local file
    if (widget.source.type == MediaSourceType.file) {
      final subPath = VideoEngineController.findCompanionSubtitlePath(widget.source.uriOrPath);
      if (subPath != null) {
        _controller.loadSubtitleFromFileSync(subPath);
      }
    }
    await _controller.openSource(widget.source, autoPlay: true);
  }

  void _onControllerUpdate() {
    // Check A-B repeat loop
    if (_loopPointA != null && _loopPointB != null) {
      if (_controller.currentPosition >= _loopPointB!) {
        _controller.seekTo(_loopPointA!);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    if (_ownsController) {
      _controller.dispose();
    } else {
      _controller.pause();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _resetChromeTimer() {
    _chromeTimer?.cancel();
    if (!_controller.isPlaying) {
      setState(() => _isChromeVisible = true);
      return;
    }
    _chromeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.isPlaying) {
        setState(() => _isChromeVisible = false);
      }
    });
  }

  void _toggleChrome() {
    setState(() {
      _isChromeVisible = !_isChromeVisible;
      if (_isChromeVisible) _resetChromeTimer();
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    _resetChromeTimer();
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _controller.togglePlayPause();
        _resetChromeTimer();
        break;
      case LogicalKeyboardKey.arrowRight:
        final offset = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
        _controller.seekRelative(offset);
        break;
      case LogicalKeyboardKey.arrowLeft:
        final offset = isCtrl ? const Duration(seconds: -30) : const Duration(seconds: -5);
        _controller.seekRelative(offset);
        break;
      case LogicalKeyboardKey.arrowUp:
        _controller.setVolume((_controller.volume + 0.05).clamp(0.0, 1.0));
        _controller.setGestureHud('🔊 Volume: ${(_controller.volume * 100).round()}%');
        break;
      case LogicalKeyboardKey.arrowDown:
        _controller.setVolume((_controller.volume - 0.05).clamp(0.0, 1.0));
        _controller.setGestureHud('🔊 Volume: ${(_controller.volume * 100).round()}%');
        break;
      case LogicalKeyboardKey.keyM:
        _controller.toggleMute();
        _controller.setGestureHud(_controller.isMuted ? '🔇 Muted' : '🔊 Unmuted');
        break;
      case LogicalKeyboardKey.bracketRight:
        final nextSpeed = (_controller.playbackSpeed + 0.25).clamp(0.25, 3.0);
        _controller.setPlaybackSpeed(nextSpeed);
        _controller.setGestureHud('⚡ Speed: ${nextSpeed}x');
        break;
      case LogicalKeyboardKey.bracketLeft:
        final prevSpeed = (_controller.playbackSpeed - 0.25).clamp(0.25, 3.0);
        _controller.setPlaybackSpeed(prevSpeed);
        _controller.setGestureHud('⚡ Speed: ${prevSpeed}x');
        break;
      case LogicalKeyboardKey.keyF:
      case LogicalKeyboardKey.f11:
        setState(() => _isFullscreen = !_isFullscreen);
        break;
      case LogicalKeyboardKey.escape:
        if (_isFullscreen) {
          setState(() => _isFullscreen = false);
        } else {
          Navigator.of(context).maybePop();
        }
        break;
    }
  }

  void _toggleABRepeat() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_loopPointA == null) {
        _loopPointA = _controller.currentPosition;
        _controller.setGestureHud('A-B Loop: Point A set (${VideoEngineController.formatDuration(_loopPointA!)})');
      } else if (_loopPointB == null) {
        if (_controller.currentPosition > _loopPointA!) {
          _loopPointB = _controller.currentPosition;
          _controller.setGestureHud('A-B Loop: Active [A-B]');
        } else {
          _controller.setGestureHud('Point B must be after Point A');
        }
      } else {
        _loopPointA = null;
        _loopPointB = null;
        _controller.setGestureHud('A-B Loop Cleared');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nativeCtrl = _controller.backend.nativeVideoController;
    final isLocked = _controller.isLocked;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0C),
        body: MouseRegion(
          onHover: (_) => _resetChromeTimer(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Hardware Video Canvas or Simulated Fallback
              Center(
                child: _buildVideoViewport(nativeCtrl),
              ),

              // 2. Subtitle Overlay
              if (_controller.activeSubtitleText != null)
                Positioned(
                  bottom: _isChromeVisible ? 90 : 36,
                  left: 24,
                  right: 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _controller.activeSubtitleText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Touch Gesture Interceptor (Android / Touch screens)
              if (!isLocked)
                Positioned.fill(
                  child: Row(
                    children: [
                      // Left 50%: Brightness drag + Double tap rewind
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _toggleChrome,
                          onDoubleTap: () {
                            _controller.handleDoubleTap(false);
                            _resetChromeTimer();
                          },
                          onVerticalDragUpdate: (details) {
                            _controller.handleVerticalDragLeft(details.delta.dy);
                            _resetChromeTimer();
                          },
                        ),
                      ),
                      // Right 50%: Volume drag + Double tap fast-forward
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _toggleChrome,
                          onDoubleTap: () {
                            _controller.handleDoubleTap(true);
                            _resetChromeTimer();
                          },
                          onVerticalDragUpdate: (details) {
                            _controller.handleVerticalDragRight(details.delta.dy);
                            _resetChromeTimer();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Gesture HUD Pill Indicator
              if (_controller.gestureHudMessage != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 12),
                      ],
                    ),
                    child: Text(
                      _controller.gestureHudMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // 5. Screen Unlock Button when locked
              if (isLocked)
                Positioned(
                  bottom: 30,
                  left: 24,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white24,
                    onPressed: () {
                      _controller.toggleScreenLock();
                      _resetChromeTimer();
                    },
                    child: const Icon(Icons.lock_open_rounded, color: Colors.white),
                  ),
                ),

              // 6. Top Chrome Bar
              if (!isLocked)
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
                            colors: [Color(0xDD000000), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () {
                                if (widget.onBack != null) {
                                  widget.onBack!();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.source.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _getSubtitleBadge(),
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Aspect Ratio
                            IconButton(
                              tooltip: 'Aspect Ratio: ${_controller.aspectRatioMode.name}',
                              icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70),
                              onPressed: () {
                                _controller.toggleAspectRatio();
                                _controller.setGestureHud('Aspect: ${_controller.aspectRatioMode.name.toUpperCase()}');
                                _resetChromeTimer();
                              },
                            ),
                            // Screen Lock
                            IconButton(
                              tooltip: 'Lock Screen Controls',
                              icon: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                              onPressed: () {
                                _controller.toggleScreenLock();
                                _resetChromeTimer();
                              },
                            ),
                            // Audio / Subtitles modal
                            IconButton(
                              tooltip: 'Audio & Subtitle Tracks',
                              icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                              onPressed: _openTrackSelectorModal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 7. Bottom Chrome Controls
              if (!isLocked)
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
                          top: 16,
                          left: 20,
                          right: 20,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xEE000000), Colors.transparent],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Scrubber row
                            Row(
                              children: [
                                Text(
                                  VideoEngineController.formatDuration(_controller.currentPosition),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      activeTrackColor: const Color(0xFF38BDF8),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: _controller.currentPosition.inMilliseconds.toDouble().clamp(
                                            0.0,
                                            _controller.duration.inMilliseconds.toDouble() > 0
                                                ? _controller.duration.inMilliseconds.toDouble()
                                                : 1.0,
                                          ),
                                      max: _controller.duration.inMilliseconds.toDouble() > 0
                                          ? _controller.duration.inMilliseconds.toDouble()
                                          : 1.0,
                                      onChanged: (val) {
                                        _controller.seekTo(Duration(milliseconds: val.toInt()));
                                        _resetChromeTimer();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  VideoEngineController.formatDuration(_controller.duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            // Action controls row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    // Play / Pause
                                    IconButton(
                                      iconSize: 32,
                                      icon: Icon(
                                        _controller.isPlaying
                                            ? Icons.pause_circle_filled_rounded
                                            : Icons.play_circle_filled_rounded,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                      onPressed: () {
                                        _controller.togglePlayPause();
                                        _resetChromeTimer();
                                      },
                                    ),
                                    // Skip back 10s
                                    IconButton(
                                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                      onPressed: () {
                                        _controller.seekRelative(const Duration(seconds: -10));
                                        _resetChromeTimer();
                                      },
                                    ),
                                    // Skip forward 10s
                                    IconButton(
                                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                      onPressed: () {
                                        _controller.seekRelative(const Duration(seconds: 10));
                                        _resetChromeTimer();
                                      },
                                    ),
                                    // A-B Repeat button
                                    TextButton(
                                      onPressed: _toggleABRepeat,
                                      child: Text(
                                        _loopPointA == null
                                            ? 'A-B'
                                            : (_loopPointB == null ? 'Set B' : 'Clear A-B'),
                                        style: TextStyle(
                                          color: _loopPointA != null ? const Color(0xFF38BDF8) : Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    // Speed Selector Pill
                                    PopupMenuButton<double>(
                                      initialValue: _controller.playbackSpeed,
                                      tooltip: 'Playback Speed',
                                      onSelected: (spd) {
                                        _controller.setPlaybackSpeed(spd);
                                        _resetChromeTimer();
                                      },
                                      color: const Color(0xFF1E293B),
                                      itemBuilder: (context) => [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map((s) {
                                        return PopupMenuItem(
                                          value: s,
                                          child: Text(
                                            '${s}x',
                                            style: TextStyle(
                                              color: s == _controller.playbackSpeed ? const Color(0xFF38BDF8) : Colors.white,
                                              fontWeight: s == _controller.playbackSpeed ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_controller.playbackSpeed}x',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Mute toggle
                                    IconButton(
                                      icon: Icon(
                                        _controller.isMuted || _controller.volume == 0
                                            ? Icons.volume_off_rounded
                                            : Icons.volume_up_rounded,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        _controller.toggleMute();
                                        _resetChromeTimer();
                                      },
                                    ),
                                    // Fullscreen toggle
                                    IconButton(
                                      icon: Icon(
                                        _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () {
                                        setState(() => _isFullscreen = !_isFullscreen);
                                        _resetChromeTimer();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViewport(dynamic nativeCtrl) {
    if (nativeCtrl != null && nativeCtrl is mkv.VideoController) {
      return mkv.Video(
        controller: nativeCtrl,
        fit: _getBoxFitForMode(_controller.aspectRatioMode),
      );
    }

    // High-tech simulated canvas fallback for test runs or environments without libmpv
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: const Icon(Icons.movie_filter_rounded, size: 54, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(height: 16),
          Text(
            widget.source.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hardware Video Canvas Active',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  BoxFit _getBoxFitForMode(VideoAspectRatioMode mode) {
    switch (mode) {
      case VideoAspectRatioMode.fill:
        return BoxFit.fill;
      case VideoAspectRatioMode.sixteenNine:
      case VideoAspectRatioMode.fourThree:
      case VideoAspectRatioMode.fit:
      case VideoAspectRatioMode.original:
      default:
        return BoxFit.contain;
    }
  }

  String _getSubtitleBadge() {
    if (_controller.subtitles.isNotEmpty) {
      return 'Subtitles: ${_controller.subtitles.length} cues loaded';
    }
    return 'Direct Hardware Decode';
  }

  void _openTrackSelectorModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final audioTracks = _controller.backend.audioTracks;
        final subTracks = _controller.backend.subtitleTracks;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tracks & Audio Stream',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Audio Tracks', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 6),
              if (audioTracks.isEmpty)
                const Text('Default Stereo Stream', style: TextStyle(color: Colors.white70, fontSize: 12))
              else
                ...audioTracks.asMap().entries.map((e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(e.value.toString(), style: const TextStyle(color: Colors.white)),
                      leading: const Icon(Icons.audiotrack_rounded, color: Color(0xFF38BDF8), size: 18),
                      onTap: () {
                        _controller.backend.selectAudioTrack(e.key);
                        Navigator.of(context).pop();
                      },
                    )),
              const Divider(color: Color(0xFF1E293B), height: 24),
              const Text('Subtitles', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 6),
              if (subTracks.isEmpty && _controller.subtitles.isEmpty)
                const Text('No subtitle streams found', style: TextStyle(color: Colors.white70, fontSize: 12))
              else if (_controller.subtitles.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Companion Subtitle (.srt)', style: TextStyle(color: Colors.white)),
                  leading: const Icon(Icons.subtitles_rounded, color: Color(0xFF38BDF8), size: 18),
                  trailing: const Icon(Icons.check_rounded, color: Color(0xFF38BDF8), size: 18),
                  onTap: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        );
      },
    );
  }
}
