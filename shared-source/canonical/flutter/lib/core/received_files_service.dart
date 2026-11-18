import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'app_settings_service.dart';
import 'archive_extractor_service.dart';
import 'file_staging_service.dart';
import '../platform/platform_capabilities.dart';
import '../platform/android_node_bridge.dart';

class TrashItem {
  final String trashPath;
  final String originalPath;
  final String name;
  final int sizeBytes;
  final DateTime deletedAt;
  final bool isDirectory;

  const TrashItem({
    required this.trashPath,
    required this.originalPath,
    required this.name,
    required this.sizeBytes,
    required this.deletedAt,
    this.isDirectory = false,
  });

  String get formattedSize {
    if (isDirectory) return 'Folder';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum ReceivedFileCategory {
  photos,
  videos,
  audio,
  documents,
  apps,
  archives,
  other,
}

class ReceivedFileItem {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;
  final ReceivedFileCategory category;
  final String extension;
  final bool isDirectory;
  final int childCount;

  const ReceivedFileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    required this.category,
    required this.extension,
    this.isDirectory = false,
    this.childCount = 0,
  });

  String get formattedSize {
    if (isDirectory) {
      return '$childCount ${childCount == 1 ? "item" : "items"}';
    }
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool get isFolder => isDirectory;
  bool get isImage => category == ReceivedFileCategory.photos;
  bool get isVideo => category == ReceivedFileCategory.videos;
  bool get isAudio => category == ReceivedFileCategory.audio;
  bool get isDocument => category == ReceivedFileCategory.documents;
  bool get isApp => category == ReceivedFileCategory.apps;
  bool get isArchive => category == ReceivedFileCategory.archives;
}

class StorageBreakdown {
  final int receivedBytes;
  final int stagingBytes;
  final int fileCount;
  final int stagingCount;

  const StorageBreakdown({
    required this.receivedBytes,
    required this.stagingBytes,
    required this.fileCount,
    required this.stagingCount,
  });

  int get totalManagedBytes => receivedBytes + stagingBytes;

  String get formattedReceivedSize => _format(receivedBytes);
  String get formattedStagingSize => _format(stagingBytes);
  String get formattedTotalSize => _format(totalManagedBytes);

  static String _format(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Result of intelligent file destination resolution, detecting SHA-256 duplicates
/// or generating collision-free auto-versioned names: name (1).ext
class FileDestinationResolution {
  final String path;
  final String resolvedName;
  final String originalName;
  final bool isDuplicate;
  final bool wasRenamed;
  final String? sha256;

  const FileDestinationResolution({
    required this.path,
    required this.resolvedName,
    required this.originalName,
    required this.isDuplicate,
    required this.wasRenamed,
    this.sha256,
  });
}

/// Service managing received files, categorized browsing, direct file actions,
/// and storage hygiene/cleanup for PeerLink.
class ReceivedFilesService {
  static final ReceivedFilesService _instance = ReceivedFilesService._internal();
  static ReceivedFilesService get instance => _instance;

  ReceivedFilesService._internal();

  final StreamController<void> _changeController =
      StreamController<void>.broadcast(sync: true);

  Stream<void> get changeStream => _changeController.stream;

  /// Notifies all Vault views to reload files from disk immediately.
  void notifyChanged() => _changeController.add(null);

  Directory get saveDirectory => Directory(AppSettingsService.instance.saveLocation);

  /// Resolves the category based on file extension.
  ReceivedFileCategory classifyExtension(String ext) {
    final clean = ext.toLowerCase().replaceAll('.', '').trim();
    switch (clean) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
      case 'heic':
        return ReceivedFileCategory.photos;
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'avi':
      case 'webm':
      case 'flv':
      case '3gp':
        return ReceivedFileCategory.videos;
      case 'mp3':
      case 'm4a':
      case 'wav':
      case 'flac':
      case 'ogg':
      case 'aac':
        return ReceivedFileCategory.audio;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
      case 'odt':
      case 'md':
      case 'csv':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return ReceivedFileCategory.documents;
      case 'apk':
      case 'aab':
      case 'exe':
      case 'msi':
      case 'appimage':
      case 'dmg':
      case 'deb':
      case 'rpm':
        return ReceivedFileCategory.apps;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return ReceivedFileCategory.archives;
      default:
        return ReceivedFileCategory.other;
    }
  }

  static const Set<String> _skipScanDirs = {
    '.git',
    '.dart_tool',
    '.peerlink_trash',
    '.peerlink_safe_vault',
    'peerlink_staging',
    'peerlink_quarantine',
    'node_modules',
    'AppData',
    'Application Data',
    'Local Settings',
    'NTUSER.DAT',
  };

  /// Lists all received files and folders in the configured save directory (or sub-directory)
  /// with smart recursive category scanning (so Photos/Videos/Audio/Docs/Apps/Archives/Downloads
  /// find real files across subfolders, DCIM/Pictures/Downloads, and Android MediaStore).
  Future<List<ReceivedFileItem>> getReceivedFiles({
    String? searchFilter,
    ReceivedFileCategory? categoryFilter,
    String? subDirectoryRelativePath,
    bool includeDirectories = true,
    Directory? baseDirectory,
    bool showHidden = false,
    bool downloadsOnly = false,
  }) async {
    Directory targetDir = baseDirectory ?? saveDirectory;
    if (subDirectoryRelativePath != null && subDirectoryRelativePath.trim().isNotEmpty) {
      final cleanSub = subDirectoryRelativePath.trim().replaceAll('\\', '/');
      targetDir = Directory('${(baseDirectory ?? saveDirectory).path}/$cleanSub');
    }

    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (_) {
        return [];
      }
    }

    final query = (searchFilter != null && searchFilter.trim().isNotEmpty)
        ? searchFilter.trim().toLowerCase()
        : null;

    // Smart recursive category discovery when a category or Downloads filter is active!
    if (categoryFilter != null || downloadsOnly) {
      return _scanByCategory(
        rootDir: targetDir,
        categoryFilter: categoryFilter,
        downloadsOnly: downloadsOnly,
        query: query,
        showHidden: showHidden,
        isDeviceScope: baseDirectory != null,
      );
    }

    final items = <ReceivedFileItem>[];
    final seenPaths = <String>{};

    void collectFromDirectory(Directory dir) {
      if (!dir.existsSync()) return;
      try {
        final entities = dir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          final normPath = entity.path.replaceAll('\\', '/').toLowerCase();
          if (!seenPaths.add(normPath)) continue;

          final entityName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'item')
              : 'item';

          // Exclude internal temporary, quarantine, trash, and staging artifacts
          if (entityName.endsWith('.part') ||
              entityName.endsWith('.tmp') ||
              entityName.endsWith('.corrupt') ||
              (!showHidden && entityName.startsWith('.')) ||
              entityName == '.peerlink_trash' ||
              entityName == '.peerlink_safe_vault' ||
              entityName == 'peerlink_staging' ||
              entityName == 'peerlink_quarantine') {
            continue;
          }

          if (query != null && !entityName.toLowerCase().contains(query)) {
            continue;
          }

          if (entity is Directory) {
            if (!includeDirectories) continue;

            int count = 0;
            try {
              final children = entity.listSync(recursive: false);
              count = children.where((c) {
                final seg = c.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
                return !seg.startsWith('.') &&
                    !seg.endsWith('.part') &&
                    !seg.endsWith('.tmp') &&
                    !seg.endsWith('.corrupt');
              }).length;
            } catch (_) {}

            final stat = entity.statSync();
            items.add(ReceivedFileItem(
              path: entity.path,
              name: entityName,
              sizeBytes: 0,
              lastModified: stat.modified,
              category: ReceivedFileCategory.other,
              extension: '',
              isDirectory: true,
              childCount: count,
            ));
          } else if (entity is File) {
            final stat = entity.statSync();
            final extIndex = entityName.lastIndexOf('.');
            final ext = extIndex != -1 ? entityName.substring(extIndex + 1) : '';
            final category = classifyExtension(ext);

            items.add(ReceivedFileItem(
              path: entity.path,
              name: entityName,
              sizeBytes: stat.size,
              lastModified: stat.modified,
              category: category,
              extension: ext,
              isDirectory: false,
              childCount: 0,
            ));
          }
        }
      } catch (_) {}
    }

    collectFromDirectory(targetDir);

    // Merge any OS/daemon fallback received directories when viewing the PeerLink Vault root
    // so transferred files are 100% visible even under scoped storage or legacy Windows paths.
    if (baseDirectory == null &&
        (subDirectoryRelativePath == null || subDirectoryRelativePath.trim().isEmpty)) {
      final fallbackDirs = await _resolveFallbackReceivedDirectories();
      for (final fbDir in fallbackDirs) {
        collectFromDirectory(fbDir);
      }
    }

    // Sort: directories first, then by lastModified descending
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return b.lastModified.compareTo(a.lastModified);
    });
    return items;
  }

  /// Resolves secondary OS/native received directories (Android internal fallback
  /// `filesDir/received` or legacy Windows `%LOCALAPPDATA%\PeerLink\received`) when
  /// using the default PeerLink Vault location, ensuring transferred files never hide.
  Future<List<Directory>> _resolveFallbackReceivedDirectories() async {
    if (AppSettingsService.instance.hasCustomSaveLocation) {
      return const [];
    }
    final primaryNorm = saveDirectory.path.replaceAll('\\', '/').toLowerCase();
    final extras = <Directory>[];
    final seen = <String>{primaryNorm};

    if (PlatformCapabilities.isAndroid) {
      try {
        final nativeDir = await AndroidNodeBridge.instance.getReceivedDirectory();
        if (nativeDir != null && nativeDir.isNotEmpty) {
          final norm = nativeDir.replaceAll('\\', '/').toLowerCase();
          if (seen.add(norm)) {
            final d = Directory(nativeDir);
            if (d.existsSync()) extras.add(d);
          }
        }
      } catch (_) {}
    } else if (PlatformCapabilities.isWindows) {
      try {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          final legacyPath = '$localAppData\\PeerLink\\received';
          final norm = legacyPath.replaceAll('\\', '/').toLowerCase();
          if (seen.add(norm)) {
            final d = Directory(legacyPath);
            if (d.existsSync()) extras.add(d);
          }
        }
      } catch (_) {}
    }
    return extras;
  }

  /// Recursively scans matching files for a selected category (Photos, Videos, Audio, Docs,
  /// Apps, Archives, Downloads) across nested folders and Android MediaStore.
  Future<List<ReceivedFileItem>> _scanByCategory({
    required Directory rootDir,
    required ReceivedFileCategory? categoryFilter,
    required bool downloadsOnly,
    required String? query,
    required bool showHidden,
    required bool isDeviceScope,
  }) async {
    final results = <ReceivedFileItem>[];
    final seenPaths = <String>{};
    const int maxItems = 400;

    // 1. Determine smart scan roots so Device Storage scans real media folders fast
    final scanRoots = <Directory>[];
    final normRoot = rootDir.path.replaceAll('\\', '/');
    final isAndroidStorageRoot = normRoot == '/storage/emulated/0';
    final isWindowsUserHome = Platform.isWindows &&
        isDeviceScope &&
        (Platform.environment['USERPROFILE'] != null &&
            rootDir.path.toLowerCase() == Platform.environment['USERPROFILE']!.toLowerCase());

    if (downloadsOnly) {
      if (isAndroidStorageRoot) {
        scanRoots.add(Directory('/storage/emulated/0/Download'));
        scanRoots.add(saveDirectory);
      } else if (isWindowsUserHome) {
        scanRoots.add(Directory('${rootDir.path}\\Downloads'));
        scanRoots.add(saveDirectory);
      } else {
        scanRoots.add(rootDir);
      }
    } else if (isAndroidStorageRoot) {
      final candidateSubdirs = switch (categoryFilter) {
        ReceivedFileCategory.photos => ['DCIM', 'Pictures', 'Download', 'WhatsApp/Media', 'Android/media/com.whatsapp/WhatsApp/Media'],
        ReceivedFileCategory.videos => ['DCIM', 'Movies', 'Pictures', 'Download', 'WhatsApp/Media'],
        ReceivedFileCategory.audio => ['Music', 'Recordings', 'Audio', 'Podcasts', 'Download'],
        ReceivedFileCategory.documents => ['Documents', 'Download'],
        ReceivedFileCategory.apps => ['Download', 'Documents'],
        ReceivedFileCategory.archives => ['Download', 'Documents'],
        _ => ['Download', 'Documents', 'DCIM', 'Pictures', 'Movies', 'Music'],
      };
      for (final sub in candidateSubdirs) {
        final d = Directory('/storage/emulated/0/$sub');
        if (d.existsSync()) scanRoots.add(d);
      }
      if (saveDirectory.existsSync()) scanRoots.add(saveDirectory);
    } else if (isWindowsUserHome) {
      final candidateSubdirs = switch (categoryFilter) {
        ReceivedFileCategory.photos => ['Pictures', 'Downloads', 'Desktop'],
        ReceivedFileCategory.videos => ['Videos', 'Downloads', 'Desktop'],
        ReceivedFileCategory.audio => ['Music', 'Downloads'],
        ReceivedFileCategory.documents => ['Documents', 'Downloads', 'Desktop'],
        ReceivedFileCategory.apps => ['Downloads', 'Desktop'],
        ReceivedFileCategory.archives => ['Downloads', 'Documents', 'Desktop'],
        _ => ['Downloads', 'Documents', 'Pictures', 'Desktop'],
      };
      for (final sub in candidateSubdirs) {
        final d = Directory('${rootDir.path}\\$sub');
        if (d.existsSync()) scanRoots.add(d);
      }
      if (saveDirectory.existsSync()) scanRoots.add(saveDirectory);
    } else {
      scanRoots.add(rootDir);
      if (!isDeviceScope) {
        final fallbackDirs = await _resolveFallbackReceivedDirectories();
        scanRoots.addAll(fallbackDirs);
      }
    }

    // 2. Bounded recursive filesystem walk across selected roots (depth-capped to avoid looper stalls)
    void walkDir(Directory dir, int depth) {
      if (depth > 2 || results.length >= maxItems) return;
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(recursive: false, followLinks: false);
      } catch (_) {
        return;
      }
      for (final entity in children) {
        if (results.length >= maxItems) break;
        final entityName = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'item')
            : 'item';

        if (entityName.endsWith('.part') ||
            entityName.endsWith('.tmp') ||
            entityName.endsWith('.corrupt') ||
            (!showHidden && entityName.startsWith('.')) ||
            _skipScanDirs.contains(entityName)) {
          continue;
        }

        if (entity is Directory) {
          // Avoid descending into Android/data or Android/obb
          final normPath = entity.path.replaceAll('\\', '/');
          if (normPath.endsWith('/Android/data') || normPath.endsWith('/Android/obb')) {
            continue;
          }
          walkDir(entity, depth + 1);
        } else if (entity is File) {
          if (query != null && !entityName.toLowerCase().contains(query)) continue;
          final extIndex = entityName.lastIndexOf('.');
          final ext = extIndex != -1 ? entityName.substring(extIndex + 1) : '';
          final cat = classifyExtension(ext);
          if (!downloadsOnly && categoryFilter != null && cat != categoryFilter) {
            continue;
          }
          final canonical = entity.path;
          if (!seenPaths.add(canonical)) continue;
          try {
            final stat = entity.statSync();
            results.add(ReceivedFileItem(
              path: canonical,
              name: entityName,
              sizeBytes: stat.size,
              lastModified: stat.modified,
              category: cat,
              extension: ext,
              isDirectory: false,
              childCount: 0,
            ));
          } catch (_) {}
        }
      }
    }

    for (final r in scanRoots) {
      if (r.existsSync()) {
        walkDir(r, 0);
      }
    }

    // 3. On Android Device Storage, also merge native MediaStore query so photos/videos/audio
    // work reliably even under Scoped Storage before MANAGE_EXTERNAL_STORAGE is granted.
    if (PlatformCapabilities.isAndroid && isDeviceScope && results.length < maxItems) {
      final mediaKey = downloadsOnly
          ? 'downloads'
          : (categoryFilter?.name ?? 'other');
      final mediaEntries = await AndroidNodeBridge.instance.queryDeviceMediaByCategory(
        mediaKey,
        limit: maxItems - results.length,
      );
      for (final m in mediaEntries) {
        final p = m['path'] as String? ?? '';
        final name = m['name'] as String? ?? '';
        if (p.isEmpty || name.isEmpty) continue;
        if (query != null && !name.toLowerCase().contains(query)) continue;
        if (!seenPaths.add(p)) continue;
        final extIndex = name.lastIndexOf('.');
        final ext = extIndex != -1 ? name.substring(extIndex + 1) : '';
        final cat = categoryFilter ?? classifyExtension(ext);
        final modMs = (m['modifiedMs'] as num?)?.toInt() ?? 0;
        results.add(ReceivedFileItem(
          path: p,
          name: name,
          sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
          lastModified: modMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(modMs)
              : DateTime.now(),
          category: cat,
          extension: ext,
          isDirectory: false,
          childCount: 0,
        ));
      }
    }

    results.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return results;
  }

  /// Safe local Recycle Bin directory (non-destructive undo delete).
  Directory get trashDirectory {
    final dir = Directory('${saveDirectory.path}${Platform.pathSeparator}.peerlink_trash');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  /// Moves a file or directory to PeerLink's local Recycle Bin with restore metadata.
  /// Returns the trash path if moved, or null on failure.
  Future<String?> moveToTrash(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.notFound) return null;

      final tDir = trashDirectory;
      final base = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final trashTargetPath = '${tDir.path}${Platform.pathSeparator}${stamp}_$base';
      final isDir = type == FileSystemEntityType.directory;
      int sizeBytes = 0;

      if (isDir) {
        final srcDir = Directory(path);
        try {
          srcDir.renameSync(trashTargetPath);
        } catch (_) {
          // Cross-filesystem fallback: copy then delete
          _copyDirectoryRecursively(srcDir, Directory(trashTargetPath));
          srcDir.deleteSync(recursive: true);
        }
      } else {
        final srcFile = File(path);
        sizeBytes = srcFile.lengthSync();
        try {
          srcFile.renameSync(trashTargetPath);
        } catch (_) {
          await srcFile.copy(trashTargetPath);
          srcFile.deleteSync();
        }
      }

      // Persist original-path metadata sidecar for 1-tap Undo/Restore
      final metaFile = File('$trashTargetPath.meta.json');
      await metaFile.writeAsString(jsonEncode({
        'originalPath': path,
        'name': base,
        'sizeBytes': sizeBytes,
        'deletedAtMs': stamp,
        'isDirectory': isDir,
      }));

      _changeController.add(null);
      return trashTargetPath;
    } catch (_) {
      return null;
    }
  }

  /// Lists all items currently in PeerLink's Recycle Bin (newest deleted first).
  Future<List<TrashItem>> listTrashItems() async {
    final tDir = trashDirectory;
    if (!tDir.existsSync()) return const [];
    final items = <TrashItem>[];
    try {
      for (final entity in tDir.listSync(recursive: false, followLinks: false)) {
        if (entity.path.endsWith('.meta.json')) continue;
        final metaFile = File('${entity.path}.meta.json');
        String origPath = '${saveDirectory.path}${Platform.pathSeparator}${entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'item')}';
        String name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'item');
        int sizeBytes = entity is File ? entity.lengthSync() : 0;
        DateTime deletedAt = entity.statSync().modified;
        bool isDir = entity is Directory;

        if (metaFile.existsSync()) {
          try {
            final map = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
            origPath = map['originalPath'] as String? ?? origPath;
            name = map['name'] as String? ?? name;
            sizeBytes = (map['sizeBytes'] as num?)?.toInt() ?? sizeBytes;
            final ms = (map['deletedAtMs'] as num?)?.toInt();
            if (ms != null) deletedAt = DateTime.fromMillisecondsSinceEpoch(ms);
            isDir = map['isDirectory'] as bool? ?? isDir;
          } catch (_) {}
        }

        items.add(TrashItem(
          trashPath: entity.path,
          originalPath: origPath,
          name: name,
          sizeBytes: sizeBytes,
          deletedAt: deletedAt,
          isDirectory: isDir,
        ));
      }
    } catch (_) {}
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  /// Restores a trashed item back to its original path (non-destructively suffixing if a collision exists).
  Future<String?> restoreFromTrash(String trashPath) async {
    try {
      final type = FileSystemEntity.typeSync(trashPath);
      if (type == FileSystemEntityType.notFound) return null;

      final metaFile = File('$trashPath.meta.json');
      String destPath = '${saveDirectory.path}${Platform.pathSeparator}restored_item';
      if (metaFile.existsSync()) {
        try {
          final map = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
          destPath = map['originalPath'] as String? ?? destPath;
        } catch (_) {}
      }

      // Ensure parent exists
      final parentDir = Directory(File(destPath).parent.path);
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      // Non-destructive collision avoidance
      String finalDest = destPath;
      if (FileSystemEntity.typeSync(finalDest) != FileSystemEntityType.notFound) {
        final dot = destPath.lastIndexOf('.');
        final sep = destPath.lastIndexOf(RegExp(r'[\\/]'));
        final hasExt = dot > sep;
        final stem = hasExt ? destPath.substring(0, dot) : destPath;
        final ext = hasExt ? destPath.substring(dot) : '';
        int idx = 1;
        while (FileSystemEntity.typeSync(finalDest) != FileSystemEntityType.notFound) {
          finalDest = '$stem (restored $idx)$ext';
          idx++;
        }
      }

      if (type == FileSystemEntityType.directory) {
        final srcDir = Directory(trashPath);
        try {
          srcDir.renameSync(finalDest);
        } catch (_) {
          _copyDirectoryRecursively(srcDir, Directory(finalDest));
          srcDir.deleteSync(recursive: true);
        }
      } else {
        final srcFile = File(trashPath);
        try {
          srcFile.renameSync(finalDest);
        } catch (_) {
          await srcFile.copy(finalDest);
          srcFile.deleteSync();
        }
      }

      if (metaFile.existsSync()) {
        try {
          metaFile.deleteSync();
        } catch (_) {}
      }
      _changeController.add(null);
      return finalDest;
    } catch (_) {
      return null;
    }
  }

  /// Permanently empties PeerLink's Recycle Bin.
  Future<int> emptyTrash() async {
    final tDir = trashDirectory;
    if (!tDir.existsSync()) return 0;
    int removed = 0;
    try {
      for (final entity in tDir.listSync(recursive: false, followLinks: false)) {
        try {
          final isMeta = entity.path.endsWith('.meta.json');
          entity.deleteSync(recursive: true);
          if (!isMeta) removed++;
        } catch (_) {}
      }
    } catch (_) {}
    _changeController.add(null);
    return removed;
  }

  /// Deletes a received file or directory permanently from disk.
  Future<bool> deleteFile(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        final dir = Directory(path);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
          _changeController.add(null);
          return true;
        }
      } else if (type == FileSystemEntityType.file) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
          _changeController.add(null);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Reveals the file in the operating system's native file manager.
  Future<bool> revealInFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', path]);
        return true;
      } else if (Platform.isLinux) {
        final parent = File(path).parent.path;
        await Process.run('xdg-open', [parent]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
        return true;
      } else if (Platform.isAndroid) {
        return await AndroidNodeBridge.instance.revealInFolder(path);
      }
    } catch (_) {}
    return false;
  }

  /// Opens a file with the operating system's associated default application (e.g. video player, audio player, gallery, PDF reader).
  Future<bool> openFileWithDefaultApp(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      } else if (Platform.isAndroid) {
        return await AndroidNodeBridge.instance.openFile(path);
      }
    } catch (_) {}
    return false;
  }

  /// Shares a file via the operating system's native share sheet.
  Future<bool> shareFile(String path) async {
    try {
      if (Platform.isAndroid) {
        return await AndroidNodeBridge.instance.shareFile(path);
      }
    } catch (_) {}
    return false;
  }

  /// Safely renames a file or directory in place without changing its directory location.
  Future<bool> renameFile(String oldPath, String newName) async {
    try {
      final trimmedName = newName.trim();
      if (trimmedName.isEmpty) return false;
      final file = File(oldPath);
      if (file.existsSync()) {
        final parent = file.parent.path;
        final targetPath = '$parent${Platform.pathSeparator}$trimmedName';
        if (!File(targetPath).existsSync()) {
          file.renameSync(targetPath);
          if (Platform.isAndroid) {
            AndroidNodeBridge.instance.scanMediaFile(targetPath);
          }
          _changeController.add(null);
          return true;
        }
      } else if (Directory(oldPath).existsSync()) {
        final dir = Directory(oldPath);
        final parent = dir.parent.path;
        final targetPath = '$parent${Platform.pathSeparator}$trimmedName';
        if (!Directory(targetPath).existsSync()) {
          dir.renameSync(targetPath);
          _changeController.add(null);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Creates a new subfolder in the specified parent path.
  Future<bool> createFolder(String parentPath, String folderName) async {
    try {
      final clean = folderName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      if (clean.isEmpty) return false;
      final newDir = Directory('$parentPath${Platform.pathSeparator}$clean');
      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
        _changeController.add(null);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Copies a file or directory to a target destination directory.
  Future<bool> copyEntity(String sourcePath, String targetDirectoryPath) async {
    try {
      final destDir = Directory(targetDirectoryPath);
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }
      final file = File(sourcePath);
      if (file.existsSync()) {
        final name = file.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final targetPath = '${destDir.path}${Platform.pathSeparator}$name';
        file.copySync(targetPath);
        if (Platform.isAndroid) {
          AndroidNodeBridge.instance.scanMediaFile(targetPath);
        }
        _changeController.add(null);
        return true;
      } else if (Directory(sourcePath).existsSync()) {
        final dir = Directory(sourcePath);
        _copyDirectoryRecursively(dir, destDir);
        _changeController.add(null);
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _copyDirectoryRecursively(Directory source, Directory destination) {
    final folderName = source.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final newDir = Directory('${destination.path}${Platform.pathSeparator}$folderName');
    if (!newDir.existsSync()) newDir.createSync(recursive: true);

    for (final entity in source.listSync(recursive: false)) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is File) {
        final destFilePath = '${newDir.path}${Platform.pathSeparator}$name';
        entity.copySync(destFilePath);
        if (Platform.isAndroid) {
          AndroidNodeBridge.instance.scanMediaFile(destFilePath);
        }
      } else if (entity is Directory) {
        _copyDirectoryRecursively(entity, newDir);
      }
    }
  }

  /// Moves a file or directory to a target destination directory (Cut & Paste).
  Future<bool> moveEntity(String sourcePath, String targetDirectoryPath) async {
    try {
      final destDir = Directory(targetDirectoryPath);
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }
      final file = File(sourcePath);
      if (file.existsSync()) {
        final name = file.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final targetPath = '${destDir.path}${Platform.pathSeparator}$name';
        try {
          file.renameSync(targetPath);
        } catch (_) {
          file.copySync(targetPath);
          file.deleteSync();
        }
        if (Platform.isAndroid) {
          AndroidNodeBridge.instance.scanMediaFile(targetPath);
        }
        _changeController.add(null);
        return true;
      } else if (Directory(sourcePath).existsSync()) {
        final dir = Directory(sourcePath);
        final folderName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final targetPath = '${destDir.path}${Platform.pathSeparator}$folderName';
        try {
          dir.renameSync(targetPath);
        } catch (_) {
          _copyDirectoryRecursively(dir, destDir);
          dir.deleteSync(recursive: true);
        }
        _changeController.add(null);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Compresses a set of files or directories into a ZIP archive.
  Future<String?> compressToZip(List<String> sourcePaths, String outputZipPath) async {
    try {
      final path = await ArchiveExtractorService.instance.createZip(sourcePaths, outputZipPath);
      if (Platform.isAndroid) {
        AndroidNodeBridge.instance.scanMediaFile(path);
      }
      _changeController.add(null);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Extracts an archive into a target directory.
  Future<String?> extractArchive(String archivePath, String targetDirectoryPath) async {
    try {
      final dir = await ArchiveExtractorService.instance.extractArchive(
        archivePath,
        targetDirectory: targetDirectoryPath,
      );
      _changeController.add(null);
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Computes the SHA-256 hash of a file asynchronously.
  Future<String> calculateSha256(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '';
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  /// Calculates the storage breakdown of received files and staging cache.
  Future<StorageBreakdown> getStorageBreakdown() async {
    int receivedBytes = 0;
    int fileCount = 0;
    int stagingBytes = 0;
    int stagingCount = 0;

    final dir = saveDirectory;
    if (dir.existsSync()) {
      try {
        final entities = dir.listSync(recursive: false);
        for (final entity in entities) {
          if (entity is File) {
            final stat = entity.statSync();
            if (entity.path.endsWith('.part') ||
                entity.path.endsWith('.tmp') ||
                entity.path.endsWith('.corrupt')) {
              stagingBytes += stat.size;
              stagingCount++;
            } else {
              receivedBytes += stat.size;
              fileCount++;
            }
          }
        }
      } catch (_) {}
    }

    return StorageBreakdown(
      receivedBytes: receivedBytes,
      stagingBytes: stagingBytes,
      fileCount: fileCount,
      stagingCount: stagingCount,
    );
  }

  /// Purges orphaned staging files (.part, .tmp, .corrupt) to free up storage space.
  Future<int> purgeStagingCache() async {
    int purgedCount = 0;
    final dir = saveDirectory;
    if (dir.existsSync()) {
      try {
        final entities = dir.listSync(recursive: false);
        for (final entity in entities) {
          if (entity is File &&
              (entity.path.endsWith('.part') ||
                  entity.path.endsWith('.tmp') ||
                  entity.path.endsWith('.corrupt'))) {
            try {
              entity.deleteSync();
              purgedCount++;
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    _changeController.add(null);
    return purgedCount;
  }

  /// Resolves an intelligent, collision-free destination in the save vault.
  /// If an identical file (matching SHA-256) already exists, flags it as duplicate (0 bytes wasted).
  /// If a different file with the same name exists, auto-versions: name (1).ext, name (2).ext.
  Future<FileDestinationResolution> resolveUniqueDestination(
    String targetName, {
    List<int>? fileBytes,
    String? sourceFilePath,
    String? expectedSha256,
  }) async {
    final dir = saveDirectory;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final sanitizedName = targetName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final initialFile = File('${dir.path}${Platform.pathSeparator}$sanitizedName');

    if (!initialFile.existsSync()) {
      return FileDestinationResolution(
        path: initialFile.path,
        resolvedName: sanitizedName,
        originalName: targetName,
        isDuplicate: false,
        wasRenamed: false,
        sha256: expectedSha256,
      );
    }

    // File exists. Compute hash to verify if it is an identical duplicate.
    String? incomingHash = expectedSha256;
    if (incomingHash == null) {
      if (fileBytes != null) {
        incomingHash = sha256.convert(fileBytes).toString();
      } else if (sourceFilePath != null && File(sourceFilePath).existsSync()) {
        final bytes = File(sourceFilePath).readAsBytesSync();
        incomingHash = sha256.convert(bytes).toString();
      }
    }

    if (incomingHash != null) {
      final existingBytes = initialFile.readAsBytesSync();
      final existingHash = sha256.convert(existingBytes).toString();
      if (existingHash.toLowerCase() == incomingHash.toLowerCase()) {
        return FileDestinationResolution(
          path: initialFile.path,
          resolvedName: sanitizedName,
          originalName: targetName,
          isDuplicate: true,
          wasRenamed: false,
          sha256: existingHash,
        );
      }
    }

    // Name conflict with different content: auto-version name (1).ext
    final dotIndex = sanitizedName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? sanitizedName.substring(0, dotIndex) : sanitizedName;
    final extension = dotIndex != -1 ? sanitizedName.substring(dotIndex) : '';

    int counter = 1;
    while (true) {
      final candidateName = '$baseName ($counter)$extension';
      final candidateFile = File('${dir.path}${Platform.pathSeparator}$candidateName');
      if (!candidateFile.existsSync()) {
        return FileDestinationResolution(
          path: candidateFile.path,
          resolvedName: candidateName,
          originalName: targetName,
          isDuplicate: false,
          wasRenamed: true,
          sha256: incomingHash,
        );
      }
      if (incomingHash != null) {
        final candBytes = candidateFile.readAsBytesSync();
        final candHash = sha256.convert(candBytes).toString();
        if (candHash.toLowerCase() == incomingHash.toLowerCase()) {
          return FileDestinationResolution(
            path: candidateFile.path,
            resolvedName: candidateName,
            originalName: targetName,
            isDuplicate: true,
            wasRenamed: true,
            sha256: candHash,
          );
        }
      }
      counter++;
    }
  }

  /// Saves incoming file payload with smart deduplication and conflict auto-rename.
  Future<FileDestinationResolution> commitReceivedFile({
    required String fileName,
    required List<int> bytes,
    String? expectedSha256,
  }) async {
    final resolution = await resolveUniqueDestination(
      fileName,
      fileBytes: bytes,
      expectedSha256: expectedSha256,
    );

    if (!resolution.isDuplicate) {
      final file = File(resolution.path);
      file.writeAsBytesSync(bytes, flush: true);
    }

    _changeController.add(null);
    return resolution;
  }
}
