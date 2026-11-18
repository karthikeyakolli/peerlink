import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/lan_benchmark_service.dart';
import 'package:peerlink/core/duplicate_diff_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lan_diff_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Task 3 — LanBenchmarkService Suite', () {
    test('runs throughput benchmark and produces diagnostic metrics', () async {
      final result = await LanBenchmarkService.instance.runBenchmark(durationMs: 500);

      expect(result.throughputMBps > 0, isTrue);
      expect(result.latencyMs >= 0, isTrue);
      expect(result.diagnosticAdvice.isNotEmpty, isTrue);
      expect(result.formattedSpeed.contains('MB/s'), isTrue);
    });
  });

  group('Task 3 — DuplicateDiffService Suite', () {
    test('identifies exact byte-for-byte SHA-256 duplicates across folders', () async {
      final subDir1 = Directory('${tempDir.path}/folder1')..createSync();
      final subDir2 = Directory('${tempDir.path}/folder2')..createSync();

      final f1 = File('${subDir1.path}/doc.txt')..writeAsStringSync('EXACT_MATCH_CONTENT');
      final f2 = File('${subDir2.path}/copy_of_doc.txt')..writeAsStringSync('EXACT_MATCH_CONTENT');
      final f3 = File('${subDir2.path}/different.txt')..writeAsStringSync('SOMETHING_ELSE');

      final duplicates = await DuplicateDiffService.instance.findDuplicates([subDir1.path, subDir2.path]);

      expect(duplicates.length, 1);
      expect(duplicates.first.files.length, 2);
      expect(duplicates.first.wastedBytes > 0, isTrue);
      expect(duplicates.first.formattedWastedSize.isNotEmpty, isTrue);
    });

    test('computes accurate line-by-line diff between two documents', () {
      const left = 'Line 1\nLine 2\nLine 3\nLine 4';
      const right = 'Line 1\nLine 2 Modified\nLine 3\nLine 5';

      final diffs = DuplicateDiffService.instance.computeLineDiff(left, right);

      expect(diffs.any((d) => d.type == DiffLineType.unchanged && d.text == 'Line 1'), isTrue);
      expect(diffs.any((d) => d.type == DiffLineType.unchanged && d.text == 'Line 3'), isTrue);
      expect(diffs.any((d) => d.type == DiffLineType.added && d.text == 'Line 2 Modified'), isTrue);
      expect(diffs.any((d) => d.type == DiffLineType.deleted && d.text == 'Line 2'), isTrue);
    });
  });
}
