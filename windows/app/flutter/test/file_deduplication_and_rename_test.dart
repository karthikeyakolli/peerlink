import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';

void main() {
  group('Smart File Deduplication & Conflict Auto-Rename Tests', () {
    late Directory tempDir;
    late ReceivedFilesService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dedup_test_');
      AppSettingsService.instance.saveLocation = tempDir.path;
      service = ReceivedFilesService.instance;
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('saves brand new file with no renaming or duplicate flag', () async {
      final res = await service.commitReceivedFile(
        fileName: 'report.pdf',
        bytes: [1, 2, 3, 4, 5],
      );

      expect(res.isDuplicate, isFalse);
      expect(res.wasRenamed, isFalse);
      expect(res.resolvedName, equals('report.pdf'));
      expect(File(res.path).existsSync(), isTrue);
      expect(File(res.path).readAsBytesSync(), equals([1, 2, 3, 4, 5]));
    });

    test('detects identical SHA-256 file as duplicate without rewriting', () async {
      // First save
      final res1 = await service.commitReceivedFile(
        fileName: 'photo.jpg',
        bytes: [10, 20, 30, 40],
      );
      expect(res1.isDuplicate, isFalse);

      // Second save with identical content
      final res2 = await service.commitReceivedFile(
        fileName: 'photo.jpg',
        bytes: [10, 20, 30, 40],
      );

      expect(res2.isDuplicate, isTrue);
      expect(res2.wasRenamed, isFalse);
      expect(res2.resolvedName, equals('photo.jpg'));
      expect(res2.path, equals(res1.path));
    });

    test('auto-versions conflicting file with different contents to (1) and (2)', () async {
      // First save
      final res1 = await service.commitReceivedFile(
        fileName: 'data.txt',
        bytes: [1, 1, 1],
      );
      expect(res1.resolvedName, equals('data.txt'));

      // Second save with same name but different content
      final res2 = await service.commitReceivedFile(
        fileName: 'data.txt',
        bytes: [2, 2, 2],
      );
      expect(res2.isDuplicate, isFalse);
      expect(res2.wasRenamed, isTrue);
      expect(res2.resolvedName, equals('data (1).txt'));
      expect(File(res2.path).existsSync(), isTrue);

      // Third save with same name and yet another different content
      final res3 = await service.commitReceivedFile(
        fileName: 'data.txt',
        bytes: [3, 3, 3],
      );
      expect(res3.isDuplicate, isFalse);
      expect(res3.wasRenamed, isTrue);
      expect(res3.resolvedName, equals('data (2).txt'));
      expect(File(res3.path).existsSync(), isTrue);
    });

    test('resolves unique destination from existing file path', () async {
      final sampleSource = File('${tempDir.path}/source.bin')..writeAsBytesSync([9, 8, 7]);

      final res = await service.resolveUniqueDestination(
        'source.bin',
        sourceFilePath: sampleSource.path,
      );

      // Since source.bin already exists at that path in the vault with the same bytes
      expect(res.isDuplicate, isTrue);
    });
  });
}
