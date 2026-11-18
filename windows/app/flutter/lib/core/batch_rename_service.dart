import 'dart:io';
import 'received_files_service.dart';

class BatchRenameRule {
  final String prefix;
  final String suffix;
  final String findText;
  final String replaceText;
  final bool useSequentialNumbering;
  final String sequenceBaseName;
  final int startNumber;
  final int padWidth;

  const BatchRenameRule({
    this.prefix = '',
    this.suffix = '',
    this.findText = '',
    this.replaceText = '',
    this.useSequentialNumbering = false,
    this.sequenceBaseName = 'File_',
    this.startNumber = 1,
    this.padWidth = 3,
  });
}

class BatchRenamePreviewEntry {
  final String originalPath;
  final String originalName;
  final String newName;
  final String targetPath;
  final bool hasCollision;
  final bool isUnchanged;

  const BatchRenamePreviewEntry({
    required this.originalPath,
    required this.originalName,
    required this.newName,
    required this.targetPath,
    required this.hasCollision,
    required this.isUnchanged,
  });
}

class BatchRenameResult {
  final int renamedCount;
  final int skippedCount;
  final List<String> errors;

  const BatchRenameResult({
    required this.renamedCount,
    required this.skippedCount,
    required this.errors,
  });
}

/// Deterministic Batch File Renamer with Live Preview & Collision Detection.
/// Supports Prefix, Suffix, Find & Replace, and Sequential Numbering (Trip_001.jpg).
class BatchRenameService {
  static final BatchRenameService _instance = BatchRenameService._internal();
  static BatchRenameService get instance => _instance;

  BatchRenameService._internal();

  /// Computes a dry-run preview of all target filenames without mutating disk.
  List<BatchRenamePreviewEntry> buildPreview(
    List<String> paths,
    BatchRenameRule rule,
  ) {
    final entries = <BatchRenamePreviewEntry>[];
    final proposedTargetPaths = <String>{};
    final sourcePathSet = paths.map((p) => p.toLowerCase()).toSet();

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final entity = File(path);
      final parentPath = entity.parent.path;
      final sep = Platform.pathSeparator;
      final segments = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
      final originalName = segments.isNotEmpty ? segments.last : path;

      final dotIdx = originalName.lastIndexOf('.');
      final hasExt = dotIdx > 0 && dotIdx < originalName.length - 1;
      final stem = hasExt ? originalName.substring(0, dotIdx) : originalName;
      final ext = hasExt ? originalName.substring(dotIdx) : '';

      String newStem;
      if (rule.useSequentialNumbering) {
        final numStr = (rule.startNumber + i).toString().padLeft(rule.padWidth.clamp(1, 6), '0');
        final base = rule.sequenceBaseName.trim().isEmpty ? 'File_' : rule.sequenceBaseName;
        newStem = '$base$numStr';
      } else {
        newStem = stem;
        if (rule.findText.isNotEmpty) {
          newStem = newStem.replaceAll(rule.findText, rule.replaceText);
        }
        newStem = '${rule.prefix}$newStem${rule.suffix}';
      }

      // Sanitize invalid filesystem characters
      newStem = newStem.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      if (newStem.isEmpty) newStem = stem;

      final newName = '$newStem$ext';
      final targetPath = '$parentPath$sep$newName';
      final lowerTarget = targetPath.toLowerCase();
      final unchanged = originalName == newName;

      final collidesInBatch = !proposedTargetPaths.add(lowerTarget);
      final collidesOnDisk =
          !unchanged && !sourcePathSet.contains(lowerTarget) && File(targetPath).existsSync();

      entries.add(BatchRenamePreviewEntry(
        originalPath: path,
        originalName: originalName,
        newName: newName,
        targetPath: targetPath,
        hasCollision: collidesInBatch || collidesOnDisk,
        isUnchanged: unchanged,
      ));
    }

    return entries;
  }

  /// Applies a validated preview safely using a two-phase temp rename to handle
  /// cyclic/swapped target names cleanly without overwriting any user file.
  Future<BatchRenameResult> applyRename(List<BatchRenamePreviewEntry> preview) async {
    int renamed = 0;
    int skipped = 0;
    final errors = <String>[];

    final actionable = preview.where((e) => !e.isUnchanged && !e.hasCollision).toList();
    skipped = preview.length - actionable.length;
    if (actionable.isEmpty) {
      return BatchRenameResult(renamedCount: 0, skippedCount: skipped, errors: errors);
    }

    // Phase 1: move each file to a unique temporary sibling path
    final staged = <({String tempPath, BatchRenamePreviewEntry entry})>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < actionable.length; i++) {
      final entry = actionable[i];
      final src = File(entry.originalPath);
      if (!src.existsSync()) {
        errors.add('Missing: ${entry.originalName}');
        continue;
      }
      final tmpPath = '${src.parent.path}${Platform.pathSeparator}.pl_ren_${stamp}_$i.tmp';
      try {
        src.renameSync(tmpPath);
        staged.add((tempPath: tmpPath, entry: entry));
      } catch (e) {
        errors.add('${entry.originalName}: $e');
      }
    }

    // Phase 2: move from temp sibling path to final target path
    for (final item in staged) {
      try {
        File(item.tempPath).renameSync(item.entry.targetPath);
        renamed++;
      } catch (e) {
        // Attempt rollback to original path
        try {
          File(item.tempPath).renameSync(item.entry.originalPath);
        } catch (_) {}
        errors.add('${item.entry.newName}: $e');
      }
    }

    if (renamed > 0) {
      ReceivedFilesService.instance.notifyChanged();
    }

    return BatchRenameResult(
      renamedCount: renamed,
      skippedCount: skipped,
      errors: errors,
    );
  }
}
