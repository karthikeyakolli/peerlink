import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/batch_renamer_service.dart';
import 'package:peerlink/core/storage_cleaner_service.dart';

void main() {
  group('StorageCleanerService Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_cleaner_test_');
      // Create various test files
      File('${tempDir.path}/normal.txt').writeAsStringSync('normal file');
      File('${tempDir.path}/broken.tmp').writeAsStringSync('temp junk');
      File('${tempDir.path}/stream.part').writeAsStringSync('partial chunk');
      File('${tempDir.path}/zero.dat').writeAsBytesSync([]);
      File('${tempDir.path}/photo (1).jpg').writeAsStringSync('duplicate photo');
      File('${tempDir.path}/document - Copy.pdf').writeAsStringSync('duplicate doc');
      Directory('${tempDir.path}/empty_dir').createSync();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('scanJunk classifies orphaned fragments, zero-byte stubs, duplicates, and empty dirs', () async {
      final summary = await StorageCleanerService.instance.scanJunk(targetDir: tempDir);

      expect(summary.count, 6);
      expect(summary.fragments.length, 2); // .tmp, .part
      expect(summary.zeroByteFiles.length, 1); // zero.dat
      expect(summary.duplicateCopies.length, 2); // (1), - Copy
      expect(summary.emptyDirectories.length, 1); // empty_dir
      expect(summary.totalSizeBytes, greaterThan(0));
    });

    test('purgeItems permanently or safely purges identified junk', () async {
      final summary = await StorageCleanerService.instance.scanJunk(targetDir: tempDir);
      final purged = await StorageCleanerService.instance.purgeItems(summary.items, moveToTrash: false);

      expect(purged, 6);
      // Verify normal.txt was NOT touched
      expect(File('${tempDir.path}/normal.txt').existsSync(), isTrue);
      // Verify junk items are gone
      expect(File('${tempDir.path}/broken.tmp').existsSync(), isFalse);
      expect(File('${tempDir.path}/zero.dat').existsSync(), isFalse);
      expect(Directory('${tempDir.path}/empty_dir').existsSync(), isFalse);
    });
  });

  group('BatchRenamerService Tests', () {
    late Directory tempDir;
    late List<String> paths;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_rename_test_');
      final f1 = File('${tempDir.path}/photo_a.jpg')..writeAsStringSync('1');
      final f2 = File('${tempDir.path}/photo_b.jpg')..writeAsStringSync('2');
      paths = [f1.path, f2.path];
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('previewPlan applies prefix, suffix, and sequential numbering', () {
      final plan = BatchRenamerService.instance.previewPlan(
        paths: paths,
        prefix: 'Trip_',
        suffix: '_HQ',
        useSequence: true,
        sequenceStartIndex: 1,
      );

      expect(plan.modifiedCount, 2);
      expect(plan.hasAnyCollision, isFalse);
      expect(plan.entries[0].newName, 'Trip_photo_a_HQ_01.jpg');
      expect(plan.entries[1].newName, 'Trip_photo_b_HQ_02.jpg');
    });

    test('previewPlan detects search and replace and case transform', () {
      final plan = BatchRenamerService.instance.previewPlan(
        paths: paths,
        search: 'photo_',
        replace: 'Image_',
        caseMode: RenameCaseMode.uppercase,
      );

      expect(plan.entries[0].newName, 'IMAGE_A.jpg');
      expect(plan.entries[1].newName, 'IMAGE_B.jpg');
    });

    test('executePlan renames files correctly on disk', () async {
      final plan = BatchRenamerService.instance.previewPlan(
        paths: paths,
        prefix: 'Renamed_',
      );

      final count = await BatchRenamerService.instance.executePlan(plan);
      expect(count, 2);
      expect(File('${tempDir.path}/Renamed_photo_a.jpg').existsSync(), isTrue);
      expect(File('${tempDir.path}/Renamed_photo_b.jpg').existsSync(), isTrue);
      expect(File(paths[0]).existsSync(), isFalse);
    });
  });
}
