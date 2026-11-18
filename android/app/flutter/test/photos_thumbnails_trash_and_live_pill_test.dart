import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/sync_backup_service.dart';
import 'package:peerlink/design_system/components/active_transfer_pill.dart';
import 'package:peerlink/features/files/received_vault_view.dart';
import 'package:peerlink/platform/android_node_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Recursive Photo/Category Discovery & Real Thumbnails', () {
    late Directory tempVault;

    setUp(() {
      AppSettingsService.instance.resetForTesting();
      tempVault = Directory.systemTemp.createTempSync('peerlink_photo_cat_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;

      // Nest photos inside subdirectories (just like DCIM/Camera and Vault/Vacation)
      final nestedPhotos = Directory('${tempVault.path}/DCIM/Camera')..createSync(recursive: true);
      final nestedDocs = Directory('${tempVault.path}/Work/Reports')..createSync(recursive: true);
      File('${nestedPhotos.path}/sunset.jpg').writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      File('${nestedPhotos.path}/portrait.png').writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);
      File('${nestedDocs.path}/budget.pdf').writeAsStringSync('%PDF-1.4');
    });

    tearDown(() {
      try {
        if (tempVault.existsSync()) tempVault.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('getReceivedFiles finds nested photos recursively when categoryFilter == photos', () async {
      final photos = await ReceivedFilesService.instance.getReceivedFiles(
        categoryFilter: ReceivedFileCategory.photos,
      );
      expect(photos.length, 2);
      expect(photos.map((p) => p.name).toSet(), {'sunset.jpg', 'portrait.png'});

      final docs = await ReceivedFilesService.instance.getReceivedFiles(
        categoryFilter: ReceivedFileCategory.documents,
      );
      expect(docs.length, 1);
      expect(docs.first.name, 'budget.pdf');
    });

    testWidgets('Tapping Photos category shows nested photos in Grid View without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReceivedVaultView()),
        ),
      );
      await tester.pumpAndSettle();

      final photosTile = find.byKey(const Key('vault_category_photos'));
      expect(photosTile, findsOneWidget);
      await tester.tap(photosTile);
      await tester.pumpAndSettle();

      expect(find.text('sunset.jpg'), findsWidgets);
      expect(find.text('portrait.png'), findsWidgets);
      expect(find.text('budget.pdf'), findsNothing);
    });
  });

  group('Safe Local Recycle Bin (Undo Delete & Collision-Safe Restore)', () {
    late Directory tempVault;

    setUp(() {
      AppSettingsService.instance.resetForTesting();
      tempVault = Directory.systemTemp.createTempSync('peerlink_trash_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
    });

    tearDown(() {
      try {
        if (tempVault.existsSync()) tempVault.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('moveToTrash -> listTrashItems -> restoreFromTrash (collision safe) -> emptyTrash', () async {
      final svc = ReceivedFilesService.instance;
      final file = File('${tempVault.path}/important.txt')..writeAsStringSync('original data');

      final trashPath = await svc.moveToTrash(file.path);
      expect(trashPath, isNotNull);
      expect(file.existsSync(), isFalse);

      final trashed = await svc.listTrashItems();
      expect(trashed.length, 1);
      expect(trashed.first.name, 'important.txt');

      // Recreate a new file at the original path to test non-destructive restore!
      File('${tempVault.path}/important.txt').writeAsStringSync('newer data');
      final restoredPath = await svc.restoreFromTrash(trashPath!);
      expect(restoredPath, isNotNull);
      expect(restoredPath, contains('restored 1'));
      expect(File(restoredPath!).readAsStringSync(), 'original data');
      expect(File('${tempVault.path}/important.txt').readAsStringSync(), 'newer data');

      // Move again and empty trash
      await svc.moveToTrash(restoredPath);
      expect((await svc.listTrashItems()).length, 1);
      final removed = await svc.emptyTrash();
      expect(removed, 1);
      expect(await svc.listTrashItems(), isEmpty);
    });
  });

  group('ActiveTransferPill Live Transfer Bar', () {
    setUp(() => AndroidNodeBridge.instance.resetForTesting());
    tearDown(() => AndroidNodeBridge.instance.resetForTesting());

    testWidgets('Shows live progress and completion cleanly with zero gradients or shadows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Spacer(),
                ActiveTransferPill(),
              ],
            ),
          ),
        ),
      );

      // Hidden when idle
      expect(find.byKey(const Key('active_transfer_pill')), findsNothing);

      // Emit transferStarted + transferProgress
      AndroidNodeBridge.instance.emitEventForTesting({
        'type': 'transferStarted',
        'transferId': 'tx_live_1',
        'fileName': 'holiday_4k.mp4',
        'totalBytes': 10485760,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('active_transfer_pill')), findsOneWidget);
      expect(find.text('holiday_4k.mp4'), findsOneWidget);

      AndroidNodeBridge.instance.emitEventForTesting({
        'type': 'transferProgress',
        'transferId': 'tx_live_1',
        'percent': 62,
        'transferredBytes': 6500000,
        'totalBytes': 10485760,
      });
      await tester.pump();
      expect(find.textContaining('62%'), findsOneWidget);

      // Enforce flat light-only rules
      for (final c in tester.widgetList<Container>(find.byType(Container))) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          expect(d.gradient, isNull);
          expect(d.boxShadow, isNull);
        }
      }

      // Emit transferCompleted -> shows complete message cleanly
      AndroidNodeBridge.instance.emitEventForTesting({
        'type': 'transferCompleted',
        'transferId': 'tx_live_1',
        'success': true,
      });
      await tester.pump();
      expect(find.text('Transfer complete'), findsOneWidget);

      // Drain auto-dismiss timer cleanly
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('active_transfer_pill')), findsNothing);
    });
  });

  group('2-Way Sync Pull & Offline Conflict Preservation (Rules 7 & 9)', () {
    late Directory tempSync;

    setUp(() {
      SyncBackupService.instance.resetForTesting();
      tempSync = Directory.systemTemp.createTempSync('peerlink_2way_sync_test_');
    });

    tearDown(() {
      SyncBackupService.instance.resetForTesting();
      try {
        if (tempSync.existsSync()) tempSync.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('reconcileRemoteManifest pushes local, pulls remote, and preserves .conflict on divergence', () async {
      File('${tempSync.path}/shared.txt').writeAsStringSync('v1');
      File('${tempSync.path}/local_only.txt').writeAsStringSync('from phone');

      final pulledLists = <List<String>>[];
      SyncBackupService.instance.onPushDeltaFiles = (_, __) async => true;
      SyncBackupService.instance.onPullRemoteFiles = (_, rels) async {
        pulledLists.add(List<String>.from(rels));
        return true;
      };

      SyncBackupService.instance.addSpace(SyncSpace(
        id: 'sp_2way',
        name: 'Two-Way Docs',
        localPath: tempSync.path,
        remotePeerId: 'win_pc_01',
        mode: SyncMode.twoWaySync,
        status: SyncStatus.inSync,
        fileCount: 2,
        lastSyncTime: 'Never',
      ));

      // Establish baseline
      await SyncBackupService.instance.performAutomatedSync('sp_2way');

      // Now BOTH local and remote modify shared.txt differently while remote adds win_doc.pdf
      File('${tempSync.path}/shared.txt').writeAsStringSync('local_edit');
      final result = await SyncBackupService.instance.reconcileRemoteManifest('sp_2way', {
        'shared.txt': 'remote_diverged_sha256_hash',
        'local_only.txt': SyncBackupService.instance.computeContentManifest(tempSync.path)['local_only.txt']!,
        'win_doc.pdf': 'remote_new_file_sha256_hash',
      });

      expect(result.pulled, contains('win_doc.pdf'));
      expect(pulledLists.last, contains('win_doc.pdf'));
      expect(result.conflicts, contains('shared.txt'));
      expect(File('${tempSync.path}/shared.txt.conflict').existsSync(), isTrue);
      expect(SyncBackupService.instance.spaces.first.status, SyncStatus.conflictDetected);
    });
  });
}
