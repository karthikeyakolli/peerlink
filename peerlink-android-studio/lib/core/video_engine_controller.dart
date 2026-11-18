import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum VideoAspectRatioMode {
  fit,
  fill,
  sixteenNine,
  fourThree,
  original,
}

class SubtitleCue {
  final int index;
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });

  bool contains(Duration position) {
    return position >= start && position <= end;
  }
}

class VideoEngineController extends ChangeNotifier {
  Duration duration;
  Duration currentPosition;
  double playbackSpeed;
  bool isLooping;
  bool isPlaying;
  double volume;
  bool isMuted;
  double brightness;
  bool isLocked;
  String? gestureHudMessage;
  Timer? _hudTimer;
  VideoAspectRatioMode aspectRatioMode;
  List<SubtitleCue> subtitles;
  String? subtitleSourcePath;

  VideoEngineController({
    this.duration = Duration.zero,
    this.currentPosition = Duration.zero,
    this.playbackSpeed = 1.0,
    this.isLooping = false,
    this.isPlaying = false,
    this.volume = 1.0,
    this.isMuted = false,
    this.brightness = 1.0,
    this.isLocked = false,
    this.gestureHudMessage,
    this.aspectRatioMode = VideoAspectRatioMode.fit,
    List<SubtitleCue>? subtitles,
    this.subtitleSourcePath,
  }) : subtitles = subtitles ?? [];

  String? get activeSubtitleText => getSubtitleAt(currentPosition);

  void setPlaybackSpeed(double speed) {
    if (speed <= 0) return;
    playbackSpeed = speed;
    notifyListeners();
  }

  void seekRelative(Duration offset) {
    final newMs = (currentPosition.inMilliseconds + offset.inMilliseconds);
    final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 86400000;
    final clampedMs = newMs.clamp(0, maxMs);
    currentPosition = Duration(milliseconds: clampedMs);
    notifyListeners();
  }

  void seekTo(Duration target) {
    final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 86400000;
    final clampedMs = target.inMilliseconds.clamp(0, maxMs);
    currentPosition = Duration(milliseconds: clampedMs);
    notifyListeners();
  }

  void toggleAspectRatio() {
    switch (aspectRatioMode) {
      case VideoAspectRatioMode.fit:
        aspectRatioMode = VideoAspectRatioMode.fill;
        break;
      case VideoAspectRatioMode.fill:
        aspectRatioMode = VideoAspectRatioMode.sixteenNine;
        break;
      case VideoAspectRatioMode.sixteenNine:
        aspectRatioMode = VideoAspectRatioMode.fourThree;
        break;
      case VideoAspectRatioMode.fourThree:
        aspectRatioMode = VideoAspectRatioMode.original;
        break;
      case VideoAspectRatioMode.original:
        aspectRatioMode = VideoAspectRatioMode.fit;
        break;
    }
    notifyListeners();
  }

  void toggleLoop() {
    isLooping = !isLooping;
    notifyListeners();
  }

  void togglePlayPause() {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  void setVolume(double val) {
    volume = val.clamp(0.0, 1.0);
    if (volume > 0) isMuted = false;
    notifyListeners();
  }

  void toggleMute() {
    isMuted = !isMuted;
    notifyListeners();
  }

  void setBrightness(double val) {
    brightness = val.clamp(0.05, 1.0);
    notifyListeners();
  }

  void toggleScreenLock() {
    isLocked = !isLocked;
    setGestureHud(isLocked ? '🔒 Controls Locked' : '🔓 Controls Unlocked');
    notifyListeners();
  }

  void setGestureHud(String msg, {Duration duration = const Duration(milliseconds: 1400)}) {
    _hudTimer?.cancel();
    gestureHudMessage = msg;
    notifyListeners();
    _hudTimer = Timer(duration, () {
      gestureHudMessage = null;
      notifyListeners();
    });
  }

  void clearGestureHud() {
    _hudTimer?.cancel();
    gestureHudMessage = null;
    notifyListeners();
  }

  void handleVerticalDragLeft(double deltaY) {
    if (isLocked) return;
    final delta = -deltaY / 200.0;
    setBrightness((brightness + delta).clamp(0.05, 1.0));
    setGestureHud('☀️ Brightness: ${(brightness * 100).round()}%');
  }

  void handleVerticalDragRight(double deltaY) {
    if (isLocked) return;
    final delta = -deltaY / 200.0;
    setVolume((volume + delta).clamp(0.0, 1.0));
    setGestureHud('🔊 Volume: ${(volume * 100).round()}%');
  }

  void handleHorizontalDrag(double deltaX) {
    if (isLocked) return;
    final offsetSec = (deltaX / 12.0).round();
    if (offsetSec == 0) return;
    seekRelative(Duration(seconds: offsetSec));
    final sign = offsetSec > 0 ? '+' : '';
    setGestureHud('$sign${offsetSec}s (${formatDuration(currentPosition)})');
  }

  void handleDoubleTap(bool isRightSide) {
    if (isLocked) return;
    if (isRightSide) {
      seekRelative(const Duration(seconds: 10));
      setGestureHud('⏩ +10s (${formatDuration(currentPosition)})');
    } else {
      seekRelative(const Duration(seconds: -10));
      setGestureHud('⏪ -10s (${formatDuration(currentPosition)})');
    }
  }

  static String formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    super.dispose();
  }

  String? getSubtitleAt(Duration position) {
    for (final cue in subtitles) {
      if (cue.contains(position)) {
        return cue.text;
      }
    }
    return null;
  }

  bool loadSubtitleFromFileSync(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final content = file.readAsStringSync();
      loadSubtitlesFromString(content);
      subtitleSourcePath = path;
      return true;
    } catch (_) {
      return false;
    }
  }

  void loadSubtitlesFromString(String content) {
    final parsed = <SubtitleCue>[];
    // Normalize newlines
    final clean = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = clean.split(RegExp(r'\n\s*\n'));

    for (final rawBlock in blocks) {
      final lines = rawBlock.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) continue;

      int idx = 0;
      int? cueNumber;
      final firstLine = lines[0].trim();
      final parsedNum = int.tryParse(firstLine);
      if (parsedNum != null) {
        cueNumber = parsedNum;
        idx = 1;
      } else {
        cueNumber = parsed.length + 1;
      }

      if (idx >= lines.length) continue;
      final timeLine = lines[idx];
      final timeMatch = RegExp(
        r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{3})',
      ).firstMatch(timeLine);

      if (timeMatch == null) continue;

      final start = _parseSrtTime(
        int.parse(timeMatch.group(1)!),
        int.parse(timeMatch.group(2)!),
        int.parse(timeMatch.group(3)!),
        int.parse(timeMatch.group(4)!),
      );

      final end = _parseSrtTime(
        int.parse(timeMatch.group(5)!),
        int.parse(timeMatch.group(6)!),
        int.parse(timeMatch.group(7)!),
        int.parse(timeMatch.group(8)!),
      );

      final textLines = lines.sublist(idx + 1);
      final text = textLines.join('\n').trim();

      if (text.isNotEmpty) {
        parsed.add(SubtitleCue(
          index: cueNumber,
          start: start,
          end: end,
          text: text,
        ));
      }
    }

    subtitles = parsed;
    notifyListeners();
  }

  static Duration _parseSrtTime(int hours, int minutes, int seconds, int millis) {
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }

  static String? findCompanionSubtitlePath(String videoPath) {
    final videoFile = File(videoPath);
    final dir = videoFile.parent;
    final nameWithoutExt = videoFile.uri.pathSegments.last.replaceAll(
      RegExp(r'\.[^.]+$'),
      '',
    );

    final candidates = [
      '${dir.path}${Platform.pathSeparator}$nameWithoutExt.srt',
      '${dir.path}${Platform.pathSeparator}$nameWithoutExt.en.srt',
      '${dir.path}${Platform.pathSeparator}$nameWithoutExt.sub',
      '${dir.path}${Platform.pathSeparator}$nameWithoutExt.vtt',
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) {
        return c;
      }
    }
    return null;
  }
}
