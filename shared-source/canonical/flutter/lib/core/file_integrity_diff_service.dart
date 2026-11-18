import 'dart:io';
import 'package:crypto/crypto.dart';

class FileChecksumReport {
  final String filePath;
  final int sizeBytes;
  final String sha256Hex;
  final String md5Hex;

  const FileChecksumReport({
    required this.filePath,
    required this.sizeBytes,
    required this.sha256Hex,
    required this.md5Hex,
  });

  /// Constant-time comparison against a user-pasted SHA-256 or MD5 checksum string.
  bool matchesExpected(String expectedHex) {
    final clean = expectedHex.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return false;
    return _ctEq(clean, sha256Hex.toLowerCase()) || _ctEq(clean, md5Hex.toLowerCase());
  }

  bool _ctEq(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

enum DiffLineKind { unchanged, added, removed }

class DiffLine {
  final DiffLineKind kind;
  final int? leftLineNumber;
  final int? rightLineNumber;
  final String text;

  const DiffLine({
    required this.kind,
    this.leftLineNumber,
    this.rightLineNumber,
    required this.text,
  });
}

class TextDiffReport {
  final List<DiffLine> lines;
  final int addedCount;
  final int removedCount;
  final int unchangedCount;

  const TextDiffReport({
    required this.lines,
    required this.addedCount,
    required this.removedCount,
    required this.unchangedCount,
  });

  bool get isIdentical => addedCount == 0 && removedCount == 0;
}

/// Built-In File Integrity Verifier (SHA-256 & MD5) and Line-by-Line Text Diff Engine.
class FileIntegrityDiffService {
  static final FileIntegrityDiffService _instance = FileIntegrityDiffService._internal();
  static FileIntegrityDiffService get instance => _instance;

  FileIntegrityDiffService._internal();

  /// Computes exact SHA-256 and MD5 hashes for a file on disk.
  FileChecksumReport computeChecksumsSync(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return FileChecksumReport(
        filePath: filePath,
        sizeBytes: 0,
        sha256Hex: '',
        md5Hex: '',
      );
    }
    final bytes = file.readAsBytesSync();
    return FileChecksumReport(
      filePath: filePath,
      sizeBytes: bytes.length,
      sha256Hex: sha256.convert(bytes).toString(),
      md5Hex: md5.convert(bytes).toString(),
    );
  }

  /// Computes a clean LCS-based line-by-line diff between two text payloads (bounded to 400 lines).
  TextDiffReport diffText(String leftText, String rightText) {
    final left = leftText.replaceAll('\r\n', '\n').split('\n').take(400).toList();
    final right = rightText.replaceAll('\r\n', '\n').split('\n').take(400).toList();

    final m = left.length;
    final n = right.length;
    final dp = List<List<int>>.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = m - 1; i >= 0; i--) {
      for (int j = n - 1; j >= 0; j--) {
        if (left[i] == right[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else {
          dp[i][j] = dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }

    final result = <DiffLine>[];
    int i = 0, j = 0;
    int added = 0, removed = 0, unchanged = 0;

    while (i < m && j < n) {
      if (left[i] == right[j]) {
        result.add(DiffLine(
          kind: DiffLineKind.unchanged,
          leftLineNumber: i + 1,
          rightLineNumber: j + 1,
          text: left[i],
        ));
        unchanged++;
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        result.add(DiffLine(
          kind: DiffLineKind.removed,
          leftLineNumber: i + 1,
          text: left[i],
        ));
        removed++;
        i++;
      } else {
        result.add(DiffLine(
          kind: DiffLineKind.added,
          rightLineNumber: j + 1,
          text: right[j],
        ));
        added++;
        j++;
      }
    }

    while (i < m) {
      result.add(DiffLine(kind: DiffLineKind.removed, leftLineNumber: i + 1, text: left[i]));
      removed++;
      i++;
    }
    while (j < n) {
      result.add(DiffLine(kind: DiffLineKind.added, rightLineNumber: j + 1, text: right[j]));
      added++;
      j++;
    }

    return TextDiffReport(
      lines: result,
      addedCount: added,
      removedCount: removed,
      unchangedCount: unchanged,
    );
  }
}
