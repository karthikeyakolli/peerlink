import 'dart:io';
import 'package:crypto/crypto.dart';

enum DiffLineType {
  unchanged,
  added,
  deleted,
}

class DiffLine {
  final DiffLineType type;
  final String text;
  final int? leftLineNumber;
  final int? rightLineNumber;

  const DiffLine({
    required this.type,
    required this.text,
    this.leftLineNumber,
    this.rightLineNumber,
  });
}

class DuplicateGroup {
  final String sha256Hash;
  final int sizeBytes;
  final List<File> files;

  const DuplicateGroup({
    required this.sha256Hash,
    required this.sizeBytes,
    required this.files,
  });

  int get wastedBytes => sizeBytes * (files.length - 1);

  String get formattedWastedSize {
    final wasted = wastedBytes;
    if (wasted < 1024) return '$wasted B';
    if (wasted < 1024 * 1024) return '${(wasted / 1024).toStringAsFixed(1)} KB';
    return '${(wasted / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Exact Byte-Level Duplicate Finder & Pure Dart Visual Diff Engine.
class DuplicateDiffService {
  static final DuplicateDiffService _instance = DuplicateDiffService._internal();
  static DuplicateDiffService get instance => _instance;

  DuplicateDiffService._internal();

  /// Scans the given directory paths and identifies byte-for-byte SHA-256 duplicates.
  Future<List<DuplicateGroup>> findDuplicates(List<String> directoryPaths) async {
    final sizeMap = <int, List<File>>{};

    for (final dirPath in directoryPaths) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File) {
            final len = entity.lengthSync();
            if (len > 0) {
              sizeMap.putIfAbsent(len, () => []).add(entity);
            }
          }
        }
      } catch (_) {}
    }

    final duplicateGroups = <DuplicateGroup>[];

    // Only compute hashes for candidate files that share an exact byte size
    for (final entry in sizeMap.entries) {
      if (entry.value.length < 2) continue;

      final hashMap = <String, List<File>>{};
      for (final file in entry.value) {
        try {
          final bytes = file.readAsBytesSync();
          final hash = sha256.convert(bytes).toString();
          hashMap.putIfAbsent(hash, () => []).add(file);
        } catch (_) {}
      }

      for (final hashEntry in hashMap.entries) {
        if (hashEntry.value.length > 1) {
          duplicateGroups.add(DuplicateGroup(
            sha256Hash: hashEntry.key,
            sizeBytes: entry.key,
            files: hashEntry.value,
          ));
        }
      }
    }

    return duplicateGroups;
  }

  /// Computes a line-by-line diff between two text documents in pure Dart.
  List<DiffLine> computeLineDiff(String leftText, String rightText) {
    final leftLines = leftText.replaceAll('\r\n', '\n').split('\n');
    final rightLines = rightText.replaceAll('\r\n', '\n').split('\n');

    final diffs = <DiffLine>[];
    int l = 0;
    int r = 0;

    while (l < leftLines.length && r < rightLines.length) {
      if (leftLines[l] == rightLines[r]) {
        diffs.add(DiffLine(
          type: DiffLineType.unchanged,
          text: leftLines[l],
          leftLineNumber: l + 1,
          rightLineNumber: r + 1,
        ));
        l++;
        r++;
      } else {
        // Look ahead in right
        final lookAheadRight = rightLines.indexOf(leftLines[l], r);
        final lookAheadLeft = leftLines.indexOf(rightLines[r], l);

        if (lookAheadRight != -1 && (lookAheadLeft == -1 || lookAheadRight - r <= lookAheadLeft - l)) {
          while (r < lookAheadRight) {
            diffs.add(DiffLine(
              type: DiffLineType.added,
              text: rightLines[r],
              rightLineNumber: r + 1,
            ));
            r++;
          }
        } else if (lookAheadLeft != -1) {
          while (l < lookAheadLeft) {
            diffs.add(DiffLine(
              type: DiffLineType.deleted,
              text: leftLines[l],
              leftLineNumber: l + 1,
            ));
            l++;
          }
        } else {
          // Both different
          diffs.add(DiffLine(
            type: DiffLineType.deleted,
            text: leftLines[l],
            leftLineNumber: l + 1,
          ));
          diffs.add(DiffLine(
            type: DiffLineType.added,
            text: rightLines[r],
            rightLineNumber: r + 1,
          ));
          l++;
          r++;
        }
      }
    }

    while (l < leftLines.length) {
      diffs.add(DiffLine(
        type: DiffLineType.deleted,
        text: leftLines[l],
        leftLineNumber: l + 1,
      ));
      l++;
    }

    while (r < rightLines.length) {
      diffs.add(DiffLine(
        type: DiffLineType.added,
        text: rightLines[r],
        rightLineNumber: r + 1,
      ));
      r++;
    }

    return diffs;
  }
}
