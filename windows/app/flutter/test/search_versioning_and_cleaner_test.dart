import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/offline_full_text_search_service.dart';
import 'package:peerlink/core/file_version_snapshot_service.dart';
import 'package:peerlink/core/photo_burst_blur_cleaner_service.dart';
import 'package:peerlink/core/auto_wifi_photo_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peerlink_task4_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('OfflineFullTextSearchService Tests', () {
    test('indexes files, finds matching words with snippet extraction, and handles empty hits', () {
      final searcher = OfflineFullTextSearchService.instance;
      searcher.clearIndex();

      final fileA = File('${tempDir.path}/quarterly_review.txt')
        ..writeAsStringSync('Financial report for Q4 2026. Total revenue reached record milestone.');
      final fileB = File('${tempDir.path}/todo.md')
        ..writeAsStringSync('# Project Checklist\n- Review encrypted vault architecture\n- Prepare release notes');

      searcher.indexFile(fileA.path, fileA.readAsStringSync());
      searcher.indexFile(fileB.path, fileB.readAsStringSync());

      // Search for "revenue"
      final results1 = searcher.search('revenue');
      expect(results1.isNotEmpty, isTrue);
      expect(results1.first.filePath, fileA.path);
      expect(results1.first.snippet, contains('Total revenue reached'));

      // Search for "vault"
      final results2 = searcher.search('vault');
      expect(results2.isNotEmpty, isTrue);
      expect(results2.first.filePath, fileB.path);
      expect(results2.first.snippet, contains('encrypted vault'));

      // Search for nonexistent word
      final results3 = searcher.search('nonexistent_gibberish_term');
      expect(results3.isEmpty, isTrue);

      searcher.clearIndex();
    });
  });

  group('FileVersionSnapshotService Time-Machine Tests', () {
    test('records snapshots, lists revisions, and restores previous versions atomically', () {
      final snapshotService = FileVersionSnapshotService.instance;
      final targetFile = File('${tempDir.path}/my_notes.txt');

      // Version 1
      targetFile.writeAsStringSync('Version 1: Initial rough draft');
      final s1 = snapshotService.recordSnapshot(targetFile, reason: 'Initial Save');
      expect(s1, isNotNull);

      // Version 2
      sleep(const Duration(milliseconds: 10));
      targetFile.writeAsStringSync('Version 2: Substantial edits made');
      final s2 = snapshotService.recordSnapshot(targetFile, reason: 'Manual Edit');
      expect(s2, isNotNull);

      final snapshots = snapshotService.getSnapshots(targetFile);
      expect(snapshots.length, greaterThanOrEqualTo(2));

      // Restore Version 1
      final restored = snapshotService.restoreSnapshot(targetFile, s1!);
      expect(restored, isTrue);
      expect(targetFile.readAsStringSync(), 'Version 1: Initial rough draft');

      // Restore Version 2
      final restoredV2 = snapshotService.restoreSnapshot(targetFile, s2!);
      expect(restoredV2, isTrue);
      expect(targetFile.readAsStringSync(), 'Version 2: Substantial edits made');
    });
  });

  group('PhotoBurstBlurCleanerService Tests', () {
    test('identifies burst photos within 2-second intervals and picks candidate best shot', () {
      final cleaner = PhotoBurstBlurCleanerService.instance;
      final now = DateTime.now();

      final burst1 = PhotoMetadata(
        path: '${tempDir.path}/IMG_001.jpg',
        timestamp: now,
        sizeBytes: 1024 * 1024 * 3,
      );
      final burst2 = PhotoMetadata(
        path: '${tempDir.path}/IMG_002.jpg',
        timestamp: now.add(const Duration(milliseconds: 800)),
        sizeBytes: 1024 * 1024 * 4, // larger size -> candidate best shot
      );
      final burst3 = PhotoMetadata(
        path: '${tempDir.path}/IMG_003.jpg',
        timestamp: now.add(const Duration(milliseconds: 1500)),
        sizeBytes: 1024 * 1024 * 3,
      );
      final standalone = PhotoMetadata(
        path: '${tempDir.path}/IMG_999.jpg',
        timestamp: now.add(const Duration(seconds: 40)),
        sizeBytes: 1024 * 1024 * 2,
      );

      final clusters = cleaner.clusterBurstPhotos([burst1, burst2, burst3, standalone]);
      expect(clusters.length, 1); // 1 burst cluster of 3 photos

      final burstCluster = clusters.first;
      expect(burstCluster.photos.length, 3);
      expect(burstCluster.bestPhoto.path, burst2.path); // photo with largest detail
      expect(burstCluster.redundantPhotos.length, 2);
    });
  });

  group('AutoWifiPhotoBackupService Tests', () {
    test('manages designated home SSIDs and calculates backup deltas', () {
      final backup = AutoWifiPhotoBackupService.instance;

      backup.setHomeSsid('Home_WiFi_5G');
      expect(backup.isHomeSsid('Home_WiFi_5G'), isTrue);
      expect(backup.isHomeSsid('Airport_Free_WiFi'), isFalse);

      final localPhotos = {
        'photo1.jpg': 'hash_aaa',
        'photo2.jpg': 'hash_bbb',
        'photo3.jpg': 'hash_ccc',
      };

      final remoteKnownHashes = {'hash_aaa'}; // Remote PC already has photo1

      final delta = backup.calculateDelta(
        localPhotos: localPhotos,
        remoteKnownHashes: remoteKnownHashes,
      );

      expect(delta.length, 2);
      expect(delta.contains('photo2.jpg'), isTrue);
      expect(delta.contains('photo3.jpg'), isTrue);
      expect(delta.contains('photo1.jpg'), isFalse);
    });
  });
}
