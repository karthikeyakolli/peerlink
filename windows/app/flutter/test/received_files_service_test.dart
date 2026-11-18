import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';

void main() {
  group('ReceivedFilesService Unit Tests', () {
    late Directory tempDir;
    final service = ReceivedFilesService.instance;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_received_test_');
      AppSettingsService.instance.saveLocation = tempDir.path;
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('classifyExtension categorizes known file formats accurately', () {
      expect(service.classifyExtension('jpg'), ReceivedFileCategory.photos);
      expect(service.classifyExtension('.PNG'), ReceivedFileCategory.photos);
      expect(service.classifyExtension('mp4'), ReceivedFileCategory.videos);
      expect(service.classifyExtension('.MKV'), ReceivedFileCategory.videos);
      expect(service.classifyExtension('mp3'), ReceivedFileCategory.audio);
      expect(service.classifyExtension('flac'), ReceivedFileCategory.audio);
      expect(service.classifyExtension('pdf'), ReceivedFileCategory.documents);
      expect(service.classifyExtension('docx'), ReceivedFileCategory.documents);
      expect(service.classifyExtension('apk'), ReceivedFileCategory.apps);
      expect(service.classifyExtension('exe'), ReceivedFileCategory.apps);
      expect(service.classifyExtension('zip'), ReceivedFileCategory.archives);
      expect(service.classifyExtension('7z'), ReceivedFileCategory.archives);
      expect(service.classifyExtension('unknown_xyz'), ReceivedFileCategory.other);
    });

    test('getReceivedFiles lists files and excludes staging artifacts', () async {
      // Create regular received files
      File('${tempDir.path}/vacation_photo.jpg').writeAsBytesSync([1, 2, 3, 4]);
      File('${tempDir.path}/budget_report.pdf').writeAsBytesSync([5, 6, 7]);
      File('${tempDir.path}/podcast.mp3').writeAsBytesSync([8, 9]);

      // Create staging/temporary files that should be ignored
      File('${tempDir.path}/unfinished_download.part').writeAsBytesSync([0, 0]);
      File('${tempDir.path}/temp_cache.tmp').writeAsBytesSync([0]);
      File('${tempDir.path}/quarantine.corrupt').writeAsBytesSync([0]);

      final allFiles = await service.getReceivedFiles();
      expect(allFiles.length, 3);
      expect(allFiles.map((f) => f.name).toSet(), containsAll(['vacation_photo.jpg', 'budget_report.pdf', 'podcast.mp3']));

      // Test category filter
      final photos = await service.getReceivedFiles(categoryFilter: ReceivedFileCategory.photos);
      expect(photos.length, 1);
      expect(photos.first.name, 'vacation_photo.jpg');

      // Test search filter
      final searchResult = await service.getReceivedFiles(searchFilter: 'budget');
      expect(searchResult.length, 1);
      expect(searchResult.first.name, 'budget_report.pdf');
    });

    test('deleteFile removes target file and triggers change event', () async {
      final testFile = File('${tempDir.path}/to_be_deleted.txt')..writeAsStringSync('Hello');
      expect(testFile.existsSync(), isTrue);

      bool changeNotified = false;
      final sub = service.changeStream.listen((_) {
        changeNotified = true;
      });

      final deleted = await service.deleteFile(testFile.path);
      expect(deleted, isTrue);
      expect(testFile.existsSync(), isFalse);
      expect(changeNotified, isTrue);

      await sub.cancel();
    });

    test('getStorageBreakdown and purgeStagingCache cleanly report and free cache', () async {
      File('${tempDir.path}/keep_me.pdf').writeAsBytesSync(List.filled(1000, 1));
      File('${tempDir.path}/junk_cache.part').writeAsBytesSync(List.filled(2000, 0));

      final breakdownBefore = await service.getStorageBreakdown();
      expect(breakdownBefore.fileCount, 1);
      expect(breakdownBefore.receivedBytes, 1000);
      expect(breakdownBefore.stagingBytes, 2000);

      final purged = await service.purgeStagingCache();
      expect(purged, 1);

      final breakdownAfter = await service.getStorageBreakdown();
      expect(breakdownAfter.fileCount, 1);
      expect(breakdownAfter.receivedBytes, 1000);
      expect(breakdownAfter.stagingBytes, 0);
    });
  });
}
