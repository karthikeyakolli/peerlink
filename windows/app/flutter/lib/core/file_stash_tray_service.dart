import 'dart:io';
import 'package:flutter/foundation.dart';
import 'archive_extractor_service.dart';
import 'received_files_service.dart';

/// Service managing multi-folder stashed items for batch operations.
/// Allows picking files across multiple folders and executing unified actions.
class FileStashTrayService {
  static final FileStashTrayService _instance = FileStashTrayService._internal();
  static FileStashTrayService get instance => _instance;

  FileStashTrayService._internal();

  final List<ReceivedFileItem> _stashed = [];
  final Map<String, String> _colorTags = {}; // filePath -> tag ('blue', 'emerald', 'amber', 'purple', 'rose')

  final ValueNotifier<List<ReceivedFileItem>> stashedItemsNotifier = ValueNotifier<List<ReceivedFileItem>>([]);
  final ValueNotifier<Map<String, String>> colorTagsNotifier = ValueNotifier<Map<String, String>>({});

  List<ReceivedFileItem> get stashedItems => List.unmodifiable(_stashed);
  int get count => _stashed.length;
  bool get isEmpty => _stashed.isEmpty;

  void stashItem(ReceivedFileItem item) {
    if (!_stashed.any((i) => i.path == item.path)) {
      _stashed.add(item);
      stashedItemsNotifier.value = List.from(_stashed);
    }
  }

  void stashMultiple(List<ReceivedFileItem> items) {
    for (final it in items) {
      if (!_stashed.any((i) => i.path == it.path)) {
        _stashed.add(it);
      }
    }
    stashedItemsNotifier.value = List.from(_stashed);
  }

  void removeItem(String path) {
    _stashed.removeWhere((i) => i.path == path);
    stashedItemsNotifier.value = List.from(_stashed);
  }

  void clearStash() {
    _stashed.clear();
    stashedItemsNotifier.value = [];
  }

  bool isStashed(String path) {
    return _stashed.any((i) => i.path == path);
  }

  void assignColorTag(String path, String colorTag) {
    if (colorTag.isEmpty) {
      _colorTags.remove(path);
    } else {
      _colorTags[path] = colorTag;
    }
    colorTagsNotifier.value = Map.from(_colorTags);
  }

  String? getColorTag(String path) => _colorTags[path];

  /// Copies all stashed files to the destination directory.
  Future<int> copyAllTo(String destinationDirectory) async {
    final destDir = Directory(destinationDirectory);
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    int copied = 0;
    for (final item in _stashed) {
      final srcFile = File(item.path);
      if (srcFile.existsSync()) {
        final targetPath = '${destDir.path}/${item.name}';
        srcFile.copySync(targetPath);
        copied++;
      }
    }
    return copied;
  }

  /// Moves all stashed files to the destination directory.
  Future<int> moveAllTo(String destinationDirectory) async {
    final destDir = Directory(destinationDirectory);
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    int moved = 0;
    for (final item in _stashed) {
      final srcFile = File(item.path);
      if (srcFile.existsSync()) {
        final targetPath = '${destDir.path}/${item.name}';
        srcFile.renameSync(targetPath);
        moved++;
      }
    }
    clearStash();
    return moved;
  }

  /// Compresses all stashed files into a single ZIP archive.
  Future<String?> compressAllIntoZip(String outputZipPath) async {
    if (_stashed.isEmpty) return null;
    final filePaths = _stashed.map((i) => i.path).where((p) => File(p).existsSync()).toList();
    if (filePaths.isEmpty) return null;

    final out = await ArchiveExtractorService.instance.createZip(filePaths, outputZipPath);
    return out;
  }

  @visibleForTesting
  void resetForTesting() {
    _stashed.clear();
    _colorTags.clear();
    stashedItemsNotifier.value = [];
    colorTagsNotifier.value = {};
  }
}
