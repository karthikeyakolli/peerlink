import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Metadata representation of an audio track.
class AudioTrack {
  final String filePath;
  final String fileName;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Uint8List? albumArtBytes;

  const AudioTrack({
    required this.filePath,
    required this.fileName,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.albumArtBytes,
  });

  String get displayTitle => title.isNotEmpty ? title : fileName;
  String get displayArtist => artist.isNotEmpty ? artist : 'Unknown Artist';

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

enum AudioLoopMode {
  off,
  all,
  one,
}

/// Robust, pure-Dart audio playback state and ID3 metadata engine.
/// Operates 100% offline without external network or heavy dependencies.
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  static AudioPlayerService get instance => _instance;

  AudioPlayerService._internal();

  final List<AudioTrack> _queue = [];
  int _currentIndex = -1;
  Timer? _playbackTimer;

  final ValueNotifier<AudioTrack?> currentTrackNotifier = ValueNotifier<AudioTrack?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<AudioLoopMode> loopModeNotifier = ValueNotifier<AudioLoopMode>(AudioLoopMode.off);
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<List<AudioTrack>> queueNotifier = ValueNotifier<List<AudioTrack>>([]);

  List<AudioTrack> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack => currentTrackNotifier.value;
  bool get isPlaying => isPlayingNotifier.value;
  Duration get position => positionNotifier.value;

  /// Loads a list of audio files into the playlist queue and starts playback.
  Future<void> loadFolderQueue(List<String> filePaths, {int initialIndex = 0}) async {
    _queue.clear();
    for (final path in filePaths) {
      final track = await parseAudioMetadata(path);
      _queue.add(track);
    }
    queueNotifier.value = List.from(_queue);

    if (_queue.isNotEmpty) {
      _currentIndex = initialIndex.clamp(0, _queue.length - 1);
      _selectTrack(_currentIndex);
      play();
    } else {
      _currentIndex = -1;
      currentTrackNotifier.value = null;
      stop();
    }
  }

  void _selectTrack(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    currentTrackNotifier.value = _queue[_currentIndex];
    positionNotifier.value = Duration.zero;
  }

  void play() {
    if (_queue.isEmpty || _currentIndex < 0) return;
    isPlayingNotifier.value = true;
    _startPlaybackTimer();
  }

  void pause() {
    isPlayingNotifier.value = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void togglePlayPause() {
    if (isPlayingNotifier.value) {
      pause();
    } else {
      play();
    }
  }

  void stop() {
    pause();
    positionNotifier.value = Duration.zero;
  }

  void seekTo(Duration newPosition) {
    final track = currentTrack;
    if (track == null) return;
    final clampedSeconds = newPosition.inSeconds.clamp(0, track.duration.inSeconds);
    positionNotifier.value = Duration(seconds: clampedSeconds);
  }

  void skipNext() {
    if (_queue.isEmpty) return;
    if (isShuffleNotifier.value && _queue.length > 1) {
      final rand = Random();
      int next = rand.nextInt(_queue.length);
      while (next == _currentIndex) {
        next = rand.nextInt(_queue.length);
      }
      _selectTrack(next);
    } else {
      int next = _currentIndex + 1;
      if (next >= _queue.length) {
        if (loopModeNotifier.value == AudioLoopMode.all) {
          next = 0;
        } else {
          pause();
          return;
        }
      }
      _selectTrack(next);
    }
    play();
  }

  void skipPrevious() {
    if (_queue.isEmpty) return;
    // If more than 3 seconds in, restart track
    if (positionNotifier.value.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }
    int prev = _currentIndex - 1;
    if (prev < 0) {
      prev = _queue.length - 1;
    }
    _selectTrack(prev);
    play();
  }

  void toggleShuffle() {
    isShuffleNotifier.value = !isShuffleNotifier.value;
  }

  void cycleLoopMode() {
    switch (loopModeNotifier.value) {
      case AudioLoopMode.off:
        loopModeNotifier.value = AudioLoopMode.all;
        break;
      case AudioLoopMode.all:
        loopModeNotifier.value = AudioLoopMode.one;
        break;
      case AudioLoopMode.one:
        loopModeNotifier.value = AudioLoopMode.off;
        break;
    }
  }

  void setPlaybackSpeed(double speed) {
    speedNotifier.value = speed.clamp(0.5, 2.0);
  }

  void closeMiniPlayer() {
    stop();
    _queue.clear();
    _currentIndex = -1;
    currentTrackNotifier.value = null;
    queueNotifier.value = [];
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!isPlayingNotifier.value) {
        timer.cancel();
        return;
      }
      final track = currentTrack;
      if (track == null) return;

      final addMs = (250 * speedNotifier.value).round();
      final newPosMs = positionNotifier.value.inMilliseconds + addMs;

      if (newPosMs >= track.duration.inMilliseconds) {
        if (loopModeNotifier.value == AudioLoopMode.one) {
          positionNotifier.value = Duration.zero;
        } else {
          skipNext();
        }
      } else {
        positionNotifier.value = Duration(milliseconds: newPosMs);
      }
    });
  }

  /// Parses ID3v2 / RIFF WAV headers to extract audio track metadata in pure Dart.
  static Future<AudioTrack> parseAudioMetadata(String filePath) async {
    final file = File(filePath);
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : filePath;

    if (!file.existsSync()) {
      return AudioTrack(
        filePath: filePath,
        fileName: fileName,
        title: fileName,
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        duration: const Duration(minutes: 3),
      );
    }

    try {
      final bytes = await file.readAsBytes();
      String title = '';
      String artist = '';
      String album = '';
      Uint8List? albumArt;
      Duration duration = const Duration(minutes: 3); // Default fallback duration

      // 1. Check for ID3v2 header (0x49 0x44 0x33 "ID3")
      if (bytes.length >= 10 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        final majorVersion = bytes[3];
        final id3Size = ((bytes[6] & 0x7F) << 21) |
            ((bytes[7] & 0x7F) << 14) |
            ((bytes[8] & 0x7F) << 7) |
            (bytes[9] & 0x7F);

        int offset = 10;
        final maxOffset = min(bytes.length, 10 + id3Size);

        while (offset + 10 < maxOffset) {
          final frameId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
          if (frameId.codeUnits.any((c) => c == 0)) break; // padding reached

          int frameSize = 0;
          if (majorVersion >= 4) {
            // ID3v2.4 syncsafe integer
            frameSize = ((bytes[offset + 4] & 0x7F) << 21) |
                ((bytes[offset + 5] & 0x7F) << 14) |
                ((bytes[offset + 6] & 0x7F) << 7) |
                (bytes[offset + 7] & 0x7F);
          } else {
            // ID3v2.3 32-bit big endian
            final bd = ByteData.sublistView(bytes, offset + 4, offset + 8);
            frameSize = bd.getUint32(0, Endian.big);
          }

          final dataStart = offset + 10;
          final dataEnd = min(dataStart + frameSize, maxOffset);

          if (dataEnd > dataStart) {
            final frameData = bytes.sublist(dataStart, dataEnd);
            if (frameId == 'TIT2') {
              title = _decodeId3Text(frameData);
            } else if (frameId == 'TPE1') {
              artist = _decodeId3Text(frameData);
            } else if (frameId == 'TALB') {
              album = _decodeId3Text(frameData);
            } else if (frameId == 'APIC' && albumArt == null) {
              albumArt = _extractApicImage(frameData);
            }
          }

          offset = dataEnd;
        }
      }

      // 2. Check for RIFF WAVE header
      if (bytes.length >= 44 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE') {
        int offset = 12;
        int sampleRate = 44100;
        int byteRate = 176400;
        int dataSize = bytes.length - 44;

        while (offset + 8 < bytes.length) {
          final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
          final bd = ByteData.sublistView(bytes, offset + 4, offset + 8);
          final chunkSize = bd.getUint32(0, Endian.little);

          if (chunkId == 'fmt ' && offset + 8 + chunkSize <= bytes.length) {
            final fmtData = ByteData.sublistView(bytes, offset + 8, offset + 8 + chunkSize);
            sampleRate = fmtData.getUint32(4, Endian.little);
            byteRate = fmtData.getUint32(8, Endian.little);
          } else if (chunkId == 'data') {
            dataSize = chunkSize;
          }
          offset += 8 + chunkSize;
        }

        if (byteRate > 0) {
          duration = Duration(seconds: (dataSize / byteRate).round());
        }
      }

      final cleanBase = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      return AudioTrack(
        filePath: filePath,
        fileName: fileName,
        title: title.isNotEmpty ? title : cleanBase,
        artist: artist.isNotEmpty ? artist : 'Local Audio',
        album: album.isNotEmpty ? album : 'PeerLink Collection',
        duration: duration,
        albumArtBytes: albumArt,
      );
    } catch (_) {
      return AudioTrack(
        filePath: filePath,
        fileName: fileName,
        title: fileName,
        artist: 'Local Audio',
        album: 'PeerLink Vault',
        duration: const Duration(minutes: 3),
      );
    }
  }

  static String _decodeId3Text(Uint8List data) {
    if (data.isEmpty) return '';
    final encoding = data[0];
    final payload = data.sublist(1);
    if (payload.isEmpty) return '';

    try {
      if (encoding == 0) {
        // ISO-8859-1
        return latin1.decode(payload).replaceAll('\x00', '').trim();
      } else if (encoding == 1 || encoding == 2) {
        // UTF-16
        final trimmed = payload.where((b) => b != 0).toList();
        return utf8.decode(trimmed, allowMalformed: true).trim();
      } else {
        // UTF-8
        return utf8.decode(payload, allowMalformed: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {
      return '';
    }
  }

  static Uint8List? _extractApicImage(Uint8List data) {
    if (data.length < 10) return null;
    // Skip encoding byte
    int mimeEnd = 1;
    while (mimeEnd < data.length && data[mimeEnd] != 0) {
      mimeEnd++;
    }
    if (mimeEnd >= data.length - 2) return null;

    // picture type
    final picTypeIdx = mimeEnd + 1;
    // skip description null-terminated string
    int descEnd = picTypeIdx + 1;
    while (descEnd < data.length && data[descEnd] != 0) {
      descEnd++;
    }
    final imageStart = descEnd + 1;
    if (imageStart < data.length) {
      return data.sublist(imageStart);
    }
    return null;
  }

  @visibleForTesting
  void resetForTesting() {
    stop();
    _queue.clear();
    _currentIndex = -1;
    currentTrackNotifier.value = null;
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
    isShuffleNotifier.value = false;
    loopModeNotifier.value = AudioLoopMode.off;
    speedNotifier.value = 1.0;
    queueNotifier.value = [];
  }
}
