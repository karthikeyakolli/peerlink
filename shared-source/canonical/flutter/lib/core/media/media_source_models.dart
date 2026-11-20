import 'dart:io';

enum MediaOrigin {
  deviceStorage,
  vaultStorage,
  remotePeer,
}

enum MediaKind {
  photo,
  video,
  audio,
}

class MediaItem {
  final String id;
  final String name;
  final String path;
  final MediaOrigin origin;
  final MediaKind kind;
  final int sizeBytes;
  final DateTime lastModified;
  final DateTime dateTaken;
  final Duration? duration;
  final int? width;
  final int? height;
  final String? mimeType;
  final String? peerId;
  final String? peerName;
  final bool isFavorite;
  final Map<String, String> metadata;

  const MediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.origin,
    required this.kind,
    required this.sizeBytes,
    required this.lastModified,
    required this.dateTaken,
    this.duration,
    this.width,
    this.height,
    this.mimeType,
    this.peerId,
    this.peerName,
    this.isFavorite = false,
    this.metadata = const {},
  });

  MediaItem copyWith({
    String? id,
    String? name,
    String? path,
    MediaOrigin? origin,
    MediaKind? kind,
    int? sizeBytes,
    DateTime? lastModified,
    DateTime? dateTaken,
    Duration? duration,
    int? width,
    int? height,
    String? mimeType,
    String? peerId,
    String? peerName,
    bool? isFavorite,
    Map<String, String>? metadata,
  }) {
    return MediaItem(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      origin: origin ?? this.origin,
      kind: kind ?? this.kind,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastModified: lastModified ?? this.lastModified,
      dateTaken: dateTaken ?? this.dateTaken,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      mimeType: mimeType ?? this.mimeType,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      isFavorite: isFavorite ?? this.isFavorite,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isPhoto => kind == MediaKind.photo;
  bool get isVideo => kind == MediaKind.video;
  bool get isAudio => kind == MediaKind.audio;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final totalSec = duration!.inSeconds;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get resolutionString {
    if (width != null && height != null) {
      final mp = (width! * height!) / 1000000.0;
      if (mp >= 1.0) {
        return '$width × $height (${mp.toStringAsFixed(1)} MP)';
      }
      return '$width × $height';
    }
    return 'Resolution unknown';
  }

  String get parentDirectoryName {
    final sep = Platform.pathSeparator;
    final parts = path.split(sep);
    if (parts.length > 1) {
      return parts[parts.length - 2];
    }
    return 'Media';
  }
}
