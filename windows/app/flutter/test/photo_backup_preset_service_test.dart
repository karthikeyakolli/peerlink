import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/photo_backup_preset_service.dart';
import 'package:peerlink/design_system/components/photo_backup_preset_card.dart';

void main() {
  group('PhotoBackupPresetService & Card Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('photo_backup_test_');
      FileStagingService.instance.clear();
    });

    tearDown(() {
      FileStagingService.instance.clear();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('scans only recent photos and ignores non-photos', () async {
      // 1. Create a recent photo
      final recentPhoto = File('${tempDir.path}/IMG_001.jpg')..writeAsBytesSync([1, 2, 3]);

      // 2. Create a non-photo file
      final document = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello');

      // 3. Create an old photo (modified 3 days ago)
      final oldPhoto = File('${tempDir.path}/IMG_OLD.png')..writeAsBytesSync([4, 5, 6]);
      oldPhoto.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));

      final results = await PhotoBackupPresetService.instance.scanNewPhotos(
        customDir: tempDir,
        since: DateTime.now().subtract(const Duration(hours: 12)),
      );

      expect(results.length, equals(1));
      expect(results.first.path.replaceAll('/', '\\'), equals(recentPhoto.path.replaceAll('/', '\\')));
    });

    test('stageNewPhotos stages detected photos into FileStagingService', () async {
      final photo1 = File('${tempDir.path}/P1.jpg')..writeAsBytesSync([1]);
      final photo2 = File('${tempDir.path}/P2.webp')..writeAsBytesSync([2]);

      final count = await PhotoBackupPresetService.instance.stageNewPhotos(
        customDir: tempDir,
        since: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(count, equals(2));
      expect(FileStagingService.instance.count, equals(2));
    });

    testWidgets('PhotoBackupPresetCard renders and stages photos upon tap', (tester) async {
      File('${tempDir.path}/P_CARD.jpg').writeAsBytesSync([1, 2, 3]);

      int stagedCallbackCount = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: PhotoBackupPresetCard(
                customScanDir: tempDir,
                onPhotosStaged: (count) => stagedCallbackCount = count,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Camera Backup'), findsOneWidget);
      expect(find.byKey(const Key('stage_photos_preset_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('stage_photos_preset_button')));
      await tester.pumpAndSettle();

      expect(stagedCallbackCount, equals(1));
      expect(FileStagingService.instance.count, equals(1));
    });
  });
}
