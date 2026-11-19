import 'dart:io';
import 'package:flutter/foundation.dart';
import 'models/file_item.dart';
import 'received_files_service.dart';

enum DeviceMediaFilter {
  all,
  photos,
  videos,
  audio,
  documents,
}

/// Service that scans and synchronizes media files directly from System Device Storage
/// (Pictures, Videos, Music, Downloads, DCIM) across Windows and Android platforms.
/// Breaks free from vault-only isolation, enabling direct playback and gallery browsing.
class SystemMediaScannerService {
  SystemMediaScannerService._();
  static final SystemMediaScannerService instance = SystemMediaScannerService._();

  List<ReceivedFileItem> _cachedDeviceFiles = [];
  DateTime? _lastScanTime;
  bool _isScanning = false;

  bool get isScanning => _isScanning;
  List<ReceivedFileItem> get cachedFiles => List.unmodifiable(_cachedDeviceFiles);
  DateTime? get lastScanTime => _lastScanTime;

  /// Scans device storage for media files with caching.
  Future<List<ReceivedFileItem>> scanDeviceStorage({
    bool forceRefresh = false,
    DeviceMediaFilter filter = DeviceMediaFilter.all,
    Directory? customRootDir,
  }) async {
    if (!forceRefresh && _cachedDeviceFiles.isNotEmpty && _lastScanTime != null) {
      if (DateTime.now().difference(_lastScanTime!) < const Duration(seconds: 30)) {
        return _applyFilter(_cachedDeviceFiles, filter);
      }
    }

    _isScanning = true;
    final results = <ReceivedFileItem>[];
    final seenPaths = <String>{};

    try {
      final roots = <Directory>[];

      if (customRootDir != null) {
        roots.add(customRootDir);
      } else if (Platform.isAndroid) {
        // Android standard public media folders
        const androidPaths = [
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/DCIM/Camera',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
        ];
        for (final p in androidPaths) {
          final dir = Directory(p);
          if (dir.existsSync()) roots.add(dir);
        }
      } else if (Platform.isWindows) {
        // Windows user profile standard folders
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final winPaths = [
            '$userProfile\\Pictures',
            '$userProfile\\Videos',
            '$userProfile\\Music',
            '$userProfile\\Downloads',
            '$userProfile\\Documents',
          ];
          for (final p in winPaths) {
            final dir = Directory(p);
            if (dir.existsSync()) roots.add(dir);
          }
        }
      } else {
        // Linux / macOS fallback
        final home = Platform.environment['HOME'];
        if (home != null) {
          final paths = [
            '$home/Pictures',
            '$home/Videos',
            '$home/Music',
            '$home/Downloads',
            '$home/Documents',
          ];
          for (final p in paths) {
            final dir = Directory(p);
            if (dir.existsSync()) roots.add(dir);
          }
        }
      }

      // If no standard roots found or empty (e.g. test environment), scan current directory or system temp
      if (roots.isEmpty) {
        roots.add(Directory.current);
      }

      for (final root in roots) {
        if (!root.existsSync()) continue;
        _scanDirectory(root, results, seenPaths, maxDepth: 2, currentDepth: 0);
        if (results.length >= 500) break; // Limit to 500 items for snappy performance
      }

      // Sort newest first
      results.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      _cachedDeviceFiles = results;
      _lastScanTime = DateTime.now();
    } catch (e) {
      debugPrint('SystemMediaScannerService error during scan: $e');
    } finally {
      _isScanning = false;
    }

    return _applyFilter(_cachedDeviceFiles, filter);
  }

  void _scanDirectory(
    Directory dir,
    List<ReceivedFileItem> results,
    Set<String> seenPaths, {
    required int maxDepth,
    required int currentDepth,
  }) {
    if (currentDepth > maxDepth || results.length >= 500) return;

    try {
      final entries = dir.listSync(followLinks: false);
      for (final entry in entries) {
        if (results.length >= 500) break;
        final normPath = entry.path.replaceAll('\\', '/');

        // Ignore hidden, system, or cache directories
        final name = entry.uri.pathSegments.isNotEmpty
            ? entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '')
            : '';
        if (name.startsWith('.') || name.startsWith('\$') || name == 'node_modules' || name == 'build') {
          continue;
        }

        if (entry is Directory) {
          _scanDirectory(entry, results, seenPaths, maxDepth: maxDepth, currentDepth: currentDepth + 1);
        } else if (entry is File) {
          if (!seenPaths.add(normPath)) continue;

          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
          final mime = _guessMimeType(ext);

          // Only keep media and document files
          if (!_isMediaOrDoc(ext, mime)) continue;

          int sizeBytes = 0;
          try {
            sizeBytes = entry.lengthSync();
          } catch (_) {}

          DateTime mod = DateTime.now();
          try {
            mod = entry.lastModifiedSync();
          } catch (_) {}

          final category = ReceivedFilesService.instance.classifyExtension(ext);

          results.add(ReceivedFileItem(
            name: name,
            path: entry.path,
            sizeBytes: sizeBytes,
            extension: ext,
            category: category,
            lastModified: mod,
            isDirectory: false,
          ));
        }
      }
    } catch (_) {
      // Ignore permission or file-lock errors gracefully
    }
  }

  bool _isMediaOrDoc(String ext, String mime) {
    if (mime.startsWith('image/') || mime.startsWith('video/') || mime.startsWith('audio/')) {
      return true;
    }
    const mediaExts = {
      'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif', 'tiff', 'svg',
      'mp4', 'mkv', 'avi', 'mov', 'webm', '3gp', 'flv', 'wmv',
      'mp3', 'm4a', 'wav', 'flac', 'aac', 'ogg', 'opus', 'wma',
      'pdf', 'docx', 'doc', 'pptx', 'ppt', 'xlsx', 'xls', 'txt', 'md'
    };
    return mediaExts.contains(ext);
  }

  String _guessMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  List<ReceivedFileItem> _applyFilter(List<ReceivedFileItem> files, DeviceMediaFilter filter) {
    switch (filter) {
      case DeviceMediaFilter.photos:
        return files.where((f) => f.isImage).toList();
      case DeviceMediaFilter.videos:
        return files.where((f) => f.isVideo).toList();
      case DeviceMediaFilter.audio:
        return files.where((f) => f.isAudio).toList();
      case DeviceMediaFilter.documents:
        return files.where((f) => f.isDocument).toList();
      case DeviceMediaFilter.all:
      default:
        return files;
    }
  }
}
