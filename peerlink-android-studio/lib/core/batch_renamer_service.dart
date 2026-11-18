import 'dart:io';

enum RenameCaseMode {
  none,
  lowercase,
  uppercase,
  titleCase,
}

class RenameEntry {
  final String oldPath;
  final String newPath;
  final String oldName;
  final String newName;
  final bool hasCollision;

  const RenameEntry({
    required this.oldPath,
    required this.newPath,
    required this.oldName,
    required this.newName,
    required this.hasCollision,
  });

  bool get isModified => oldName != newName;
}

class BatchRenamePlan {
  final List<RenameEntry> entries;
  final bool hasAnyCollision;

  const BatchRenamePlan({
    required this.entries,
    required this.hasAnyCollision,
  });

  int get modifiedCount => entries.where((e) => e.isModified && !e.hasCollision).length;
}

class BatchRenamerService {
  static final BatchRenamerService instance = BatchRenamerService._internal();
  BatchRenamerService._internal();

  BatchRenamePlan previewPlan({
    required List<String> paths,
    String prefix = '',
    String suffix = '',
    String search = '',
    String replace = '',
    bool useSequence = false,
    int sequenceStartIndex = 1,
    int sequenceDigits = 2,
    RenameCaseMode caseMode = RenameCaseMode.none,
  }) {
    final entries = <RenameEntry>[];
    final targetNames = <String>{};
    bool anyCollision = false;

    int seqIndex = sequenceStartIndex;

    for (final path in paths) {
      final file = File(path);
      final dirPath = file.parent.path;
      final originalFullName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'file')
          : 'file';

      final dotIdx = originalFullName.lastIndexOf('.');
      final hasExt = dotIdx != -1 && dotIdx > 0;
      final baseName = hasExt ? originalFullName.substring(0, dotIdx) : originalFullName;
      final ext = hasExt ? originalFullName.substring(dotIdx) : '';

      String transformed = baseName;

      // 1. Search & Replace
      if (search.isNotEmpty) {
        transformed = transformed.replaceAll(search, replace);
      }

      // 2. Case transformation
      switch (caseMode) {
        case RenameCaseMode.lowercase:
          transformed = transformed.toLowerCase();
          break;
        case RenameCaseMode.uppercase:
          transformed = transformed.toUpperCase();
          break;
        case RenameCaseMode.titleCase:
          transformed = transformed.split(RegExp(r'[\s_\-]+')).map((word) {
            if (word.isEmpty) return '';
            return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
          }).join(' ');
          break;
        case RenameCaseMode.none:
          break;
      }

      // 3. Prefix & Suffix
      if (prefix.isNotEmpty) {
        transformed = '$prefix$transformed';
      }
      if (suffix.isNotEmpty) {
        transformed = '$transformed$suffix';
      }

      // 4. Sequential numbering
      if (useSequence) {
        final padded = seqIndex.toString().padLeft(sequenceDigits, '0');
        transformed = '${transformed}_$padded';
        seqIndex++;
      }

      final candidateFullName = '$transformed$ext';
      final candidatePath = '$dirPath${Platform.pathSeparator}$candidateFullName';

      // Check collision
      bool collision = false;
      if (candidateFullName != originalFullName) {
        if (!targetNames.add(candidateFullName.toLowerCase()) ||
            File(candidatePath).existsSync() ||
            Directory(candidatePath).existsSync()) {
          collision = true;
          anyCollision = true;
        }
      }

      entries.add(RenameEntry(
        oldPath: path,
        newPath: candidatePath,
        oldName: originalFullName,
        newName: candidateFullName,
        hasCollision: collision,
      ));
    }

    return BatchRenamePlan(
      entries: entries,
      hasAnyCollision: anyCollision,
    );
  }

  Future<int> executePlan(BatchRenamePlan plan) async {
    int renamedCount = 0;
    for (final entry in plan.entries) {
      if (!entry.isModified || entry.hasCollision) continue;
      try {
        final f = File(entry.oldPath);
        if (f.existsSync()) {
          f.renameSync(entry.newPath);
          renamedCount++;
        } else {
          final d = Directory(entry.oldPath);
          if (d.existsSync()) {
            d.renameSync(entry.newPath);
            renamedCount++;
          }
        }
      } catch (_) {}
    }
    return renamedCount;
  }
}
