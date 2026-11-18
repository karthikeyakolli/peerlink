import 'dart:io';
import 'package:flutter/foundation.dart';
import 'file_staging_service.dart';
import '../platform/platform_capabilities.dart';

/// Service managing 1-tap Camera & Photos delta backup presets.
/// Identifies newly taken or modified photos (e.g., today's photos) and stages
/// only the unsynced delta into the beam tray.
class PhotoBackupPresetService {
  static final PhotoBackupPresetService _instance = PhotoBackupPresetService._internal();
  static PhotoBackupPresetService get instance => _instance;

  PhotoBackupPresetService._internal();

  /// Returns candidate camera / pictures directories on the current OS.
  List<Directory> getCandidatePhotoDirectories() {
    final list = <Directory>[];

    if (PlatformCapabilities.isAndroid) {
      list.add(Directory('/storage/emulated/0/DCIM/Camera'));
      list.add(Directory('/storage/emulated/0/Pictures'));
      list.add(Directory('/sdcard/DCIM/Camera'));
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        list.add(Directory('$userProfile\\Pictures\\Camera Roll'));
        list.add(Directory('$userProfile\\Pictures'));
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        list.add(Directory('$home/Pictures'));
      }
    }

    return list.where((d) => d.existsSync()).toList();
  }

  /// Scans for photos modified after [since] (default: start of today, or last 24h).
  Future<List<File>> scanNewPhotos({
    DateTime? since,
    Directory? customDir,
  }) async {
    final threshold = since ?? DateTime.now().subtract(const Duration(hours: 24));
    final targetDirs = customDir != null ? [customDir] : getCandidatePhotoDirectories();
    final newPhotos = <File>[];

    final photoExts = {'jpg', 'jpeg', 'png', 'heic', 'webp', 'dng', 'raw'};

    for (final dir in targetDirs) {
      if (!dir.existsSync()) continue;
      try {
        final entities = dir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.path.split(RegExp(r'[\\/]')).last;
            final dot = name.lastIndexOf('.');
            final ext = dot != -1 ? name.substring(dot + 1).toLowerCase() : '';

            if (photoExts.contains(ext)) {
              final stat = entity.statSync();
              if (stat.modified.isAfter(threshold)) {
                newPhotos.add(entity);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning photo dir ${dir.path}: $e');
      }
    }

    // Sort newest first
    newPhotos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return newPhotos;
  }

  /// Automatically stages new photos into FileStagingService.
  Future<int> stageNewPhotos({
    DateTime? since,
    Directory? customDir,
  }) async {
    final photos = await scanNewPhotos(since: since, customDir: customDir);
    if (photos.isNotEmpty) {
      FileStagingService.instance.addPaths(photos.map((f) => f.path).toList());
    }
    return photos.length;
  }
}
