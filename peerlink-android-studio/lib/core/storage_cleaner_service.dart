import 'dart:io';
import 'package:flutter/foundation.dart';
import 'received_files_service.dart';

enum JunkCategory {
  orphanedFragment,
  zeroByteFile,
  duplicateCopy,
  emptyDirectory,
}

class ScrubItem {
  final String path;
  final String name;
  final int sizeBytes;
  final JunkCategory category;
  final DateTime lastModified;

  const ScrubItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.category,
    required this.lastModified,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class StorageScrubSummary {
  final List<ScrubItem> items;
  final int totalSizeBytes;

  const StorageScrubSummary({
    required this.items,
    required this.totalSizeBytes,
  });

  int get count => items.length;

  List<ScrubItem> get fragments =>
      items.where((i) => i.category == JunkCategory.orphanedFragment).toList();

  List<ScrubItem> get zeroByteFiles =>
      items.where((i) => i.category == JunkCategory.zeroByteFile).toList();

  List<ScrubItem> get duplicateCopies =>
      items.where((i) => i.category == JunkCategory.duplicateCopy).toList();

  List<ScrubItem> get emptyDirectories =>
      items.where((i) => i.category == JunkCategory.emptyDirectory).toList();

  String get formattedTotalSize {
    if (totalSizeBytes <= 0) return '0 B';
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (totalSizeBytes < 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class StorageCleanerService {
  static final StorageCleanerService instance = StorageCleanerService._internal();
  StorageCleanerService._internal();

  static final RegExp _duplicatePattern = RegExp(
    r'(\(\d+\)| - Copy|\.copy\d*)\.[^.]+$',
    caseSensitive: false,
  );

  Future<StorageScrubSummary> scanJunk({Directory? targetDir}) async {
    final root = targetDir ?? ReceivedFilesService.instance.saveDirectory;
    final found = <ScrubItem>[];
    int totalBytes = 0;

    if (!root.existsSync()) {
      return StorageScrubSummary(items: found, totalSizeBytes: 0);
    }

    void scan(Directory dir, int depth) {
      if (depth > 4) return;
      List<FileSystemEntity> entities;
      try {
        entities = dir.listSync(recursive: false, followLinks: false);
      } catch (_) {
        return;
      }

      int nonHiddenChildren = 0;

      for (final entity in entities) {
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '')
            : '';

        if (name.isEmpty || name.startsWith('.')) continue;
        nonHiddenChildren++;

        if (entity is Directory) {
          // Check if directory is completely empty
          try {
            final children = entity.listSync(recursive: false);
            if (children.isEmpty) {
              found.add(ScrubItem(
                path: entity.path,
                name: name,
                sizeBytes: 0,
                category: JunkCategory.emptyDirectory,
                lastModified: DateTime.now(),
              ));
            } else {
              scan(entity, depth + 1);
            }
          } catch (_) {}
        } else if (entity is File) {
          try {
            final stat = entity.statSync();
            final lower = name.toLowerCase();

            if (lower.endsWith('.part') ||
                lower.endsWith('.tmp') ||
                lower.endsWith('.corrupt') ||
                lower.endsWith('.download')) {
              found.add(ScrubItem(
                path: entity.path,
                name: name,
                sizeBytes: stat.size,
                category: JunkCategory.orphanedFragment,
                lastModified: stat.modified,
              ));
              totalBytes += stat.size;
            } else if (stat.size == 0) {
              found.add(ScrubItem(
                path: entity.path,
                name: name,
                sizeBytes: 0,
                category: JunkCategory.zeroByteFile,
                lastModified: stat.modified,
              ));
            } else if (_duplicatePattern.hasMatch(name)) {
              found.add(ScrubItem(
                path: entity.path,
                name: name,
                sizeBytes: stat.size,
                category: JunkCategory.duplicateCopy,
                lastModified: stat.modified,
              ));
              totalBytes += stat.size;
            }
          } catch (_) {}
        }
      }
    }

    scan(root, 0);

    return StorageScrubSummary(
      items: found,
      totalSizeBytes: totalBytes,
    );
  }

  Future<int> purgeItems(List<ScrubItem> items, {bool moveToTrash = true}) async {
    int purgedCount = 0;
    for (final item in items) {
      try {
        if (moveToTrash) {
          await ReceivedFilesService.instance.moveToTrash(item.path);
          purgedCount++;
        } else {
          final f = File(item.path);
          if (f.existsSync()) {
            f.deleteSync();
            purgedCount++;
          } else {
            final d = Directory(item.path);
            if (d.existsSync()) {
              d.deleteSync(recursive: false);
              purgedCount++;
            }
          }
        }
      } catch (_) {}
    }
    return purgedCount;
  }
}
