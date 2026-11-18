import 'dart:async';
import 'dart:io';

/// Represents a file or folder staged in the persistent draft tray.
class StagedFileItem {
  final String path;
  final String name;
  final int sizeBytes;
  final bool isDirectory;
  final int fileCount;
  bool selected;

  StagedFileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.isDirectory,
    this.fileCount = 0,
    this.selected = true,
  });

  String get formattedSize {
    if (isDirectory) {
      if (fileCount == 0 && sizeBytes == 0) return 'Folder';
      final sizeStr = _formatBytes(sizeBytes);
      return fileCount == 1 ? '1 file ($sizeStr)' : '$fileCount files ($sizeStr)';
    }
    return _formatBytes(sizeBytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Authoritative singleton service managing persistent draft file selections across screens.
/// Prevents accidental selection loss when users navigate between tabs (Product Feature Inventory §5).
class FileStagingService {
  static final FileStagingService _instance = FileStagingService._internal();
  static FileStagingService get instance => _instance;

  FileStagingService._internal();

  final List<StagedFileItem> _stagedFiles = [];
  final StreamController<List<StagedFileItem>> _stagingController =
      StreamController<List<StagedFileItem>>.broadcast();

  Stream<List<StagedFileItem>> get stagedFilesStream => _stagingController.stream;
  List<StagedFileItem> get stagedFiles => List.unmodifiable(_stagedFiles);

  bool get isEmpty => _stagedFiles.isEmpty;
  bool get isNotEmpty => _stagedFiles.isNotEmpty;

  int get count => _stagedFiles.length;

  int get selectedCount => _stagedFiles.where((f) => f.selected).length;

  int get totalBytes => _stagedFiles
      .where((f) => f.selected)
      .fold<int>(0, (sum, f) => sum + f.sizeBytes);

  String get formattedTotalBytes {
    final bytes = totalBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void addPaths(List<String> paths) {
    bool changed = false;
    for (final p in paths) {
      if (p.trim().isEmpty) continue;
      final cleanPath = p.trim();
      final isContentUri = cleanPath.startsWith('content://');
      final f = File(cleanPath);
      final d = Directory(cleanPath);
      String name = cleanPath.split(RegExp(r'[\\/]')).last;
      int size = 0;
      bool isDir = false;
      int fileCount = 0;

      if (!isContentUri) {
        if (d.existsSync()) {
          isDir = true;
          int count = 0;
          try {
            for (final entity in d.listSync(recursive: true, followLinks: false)) {
              if (entity is File) {
                size += entity.lengthSync();
                count++;
              }
            }
          } catch (_) {}
          fileCount = count;
        } else if (f.existsSync()) {
          try {
            size = f.lengthSync();
          } catch (_) {}
        }
      } else {
        if (name.contains('%2F') || name.contains('%2f')) {
          name = Uri.decodeComponent(name).split('/').last;
        }
        size = 1024 * 500; // Estimated baseline for SAF content URIs
      }

      if (!_stagedFiles.any((item) => item.path == cleanPath)) {
        _stagedFiles.add(StagedFileItem(
          path: cleanPath,
          name: name.isEmpty ? cleanPath : name,
          sizeBytes: size,
          isDirectory: isDir,
          fileCount: fileCount,
        ));
        changed = true;
      }
    }

    if (changed) {
      _notify();
    }
  }

  void remove(StagedFileItem file) {
    final removed = _stagedFiles.remove(file);
    if (removed) {
      _notify();
    }
  }

  void removePath(String path) {
    _stagedFiles.removeWhere((f) => f.path == path);
    _notify();
  }

  void toggleSelection(StagedFileItem file) {
    file.selected = !file.selected;
    _notify();
  }

  void clear() {
    if (_stagedFiles.isNotEmpty) {
      _stagedFiles.clear();
      _notify();
    }
  }

  void _notify() {
    _stagingController.add(List.unmodifiable(_stagedFiles));
  }

  void resetForTesting() {
    _stagedFiles.clear();
    _notify();
  }
}
