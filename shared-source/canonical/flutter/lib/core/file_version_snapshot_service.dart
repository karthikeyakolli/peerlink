import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class FileVersionSnapshot {
  final String id;
  final String filePath;
  final DateTime timestamp;
  final String reason;
  final int byteSize;
  final String snapshotFilePath;

  const FileVersionSnapshot({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.reason,
    required this.byteSize,
    required this.snapshotFilePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'reason': reason,
        'byteSize': byteSize,
        'snapshotFilePath': snapshotFilePath,
      };

  factory FileVersionSnapshot.fromJson(Map<String, dynamic> json) => FileVersionSnapshot(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        reason: json['reason'] as String,
        byteSize: (json['byteSize'] as num).toInt(),
        snapshotFilePath: json['snapshotFilePath'] as String,
      );
}

class FileVersionSnapshotService extends ChangeNotifier {
  FileVersionSnapshotService._();
  static final FileVersionSnapshotService instance = FileVersionSnapshotService._();

  Directory _getVersionsDir(File target) {
    final parent = target.parent;
    final dir = Directory('${parent.path}${Platform.pathSeparator}.peerlink_versions${Platform.pathSeparator}${target.uri.pathSegments.last}');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  File _getMetaFile(File target) {
    final dir = _getVersionsDir(target);
    return File('${dir.path}${Platform.pathSeparator}revisions.json');
  }

  FileVersionSnapshot? recordSnapshot(File target, {String reason = 'Edit'}) {
    if (!target.existsSync()) return null;

    final bytes = target.readAsBytesSync();
    final versionsDir = _getVersionsDir(target);
    final now = DateTime.now();
    final id = 'rev_${now.millisecondsSinceEpoch}';
    final snapshotFile = File('${versionsDir.path}${Platform.pathSeparator}$id.bak');
    snapshotFile.writeAsBytesSync(bytes, flush: true);

    final snapshot = FileVersionSnapshot(
      id: id,
      filePath: target.path,
      timestamp: now,
      reason: reason,
      byteSize: bytes.length,
      snapshotFilePath: snapshotFile.path,
    );

    final metaFile = _getMetaFile(target);
    final existing = getSnapshots(target);
    final updated = [snapshot, ...existing].take(10).toList();

    metaFile.writeAsStringSync(
      jsonEncode(updated.map((s) => s.toJson()).toList()),
      flush: true,
    );

    notifyListeners();
    return snapshot;
  }

  List<FileVersionSnapshot> getSnapshots(File target) {
    final metaFile = _getMetaFile(target);
    if (!metaFile.existsSync()) return const [];

    try {
      final raw = metaFile.readAsStringSync();
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => FileVersionSnapshot.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  bool restoreSnapshot(File target, FileVersionSnapshot snapshot) {
    final backup = File(snapshot.snapshotFilePath);
    if (!backup.existsSync()) return false;

    try {
      final bytes = backup.readAsBytesSync();
      // Atomic write via temp file
      final tmp = File('${target.path}.peerlink_restore.tmp');
      tmp.writeAsBytesSync(bytes, flush: true);
      if (target.existsSync()) target.deleteSync();
      tmp.renameSync(target.path);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
