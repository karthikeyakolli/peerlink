import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/sync_backup_service.dart';
import 'package:peerlink/features/spaces/spaces_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_autosync_test_');
    AppSettingsService.instance.resetForTesting();
    SyncBackupService.instance.resetForTesting();
  });

  tearDown(() {
    SyncBackupService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Automated Background Sync Engine', () {
    test('startBackgroundWatcher enables watching and registers space watchers', () {
      final sync = SyncBackupService.instance;
      expect(sync.isWatching, isFalse);

      final spaceDir = Directory('${tempDir.path}/space_a')..createSync();
      File('${spaceDir.path}/doc1.txt').writeAsStringSync('Hello World');

      sync.addSpace(
        SyncSpace(
          id: 'space_a',
          name: 'Auto Space A',
          localPath: spaceDir.path,
          remotePeerId: 'peer_node_01',
          mode: SyncMode.twoWaySync,
          status: SyncStatus.inSync,
          fileCount: 1,
          lastSyncTime: 'Initial',
        ),
      );

      sync.startBackgroundWatcher();
      expect(sync.isWatching, isTrue);

      sync.stopBackgroundWatcher();
      expect(sync.isWatching, isFalse);
    });

    test('computeSpaceMerkleRoot calculates deterministic SHA-256 Merkle root', () {
      final sync = SyncBackupService.instance;
      final spaceDir = Directory('${tempDir.path}/merkle_test')..createSync();

      final rootEmpty = sync.computeSpaceMerkleRoot(spaceDir.path);
      expect(rootEmpty, startsWith('SHA256:'));

      final file1 = File('${spaceDir.path}/file1.txt');
      file1.writeAsStringSync('Content One');

      final rootOne = sync.computeSpaceMerkleRoot(spaceDir.path);
      expect(rootOne, isNot(equals(rootEmpty)));

      final file2 = File('${spaceDir.path}/file2.txt');
      file2.writeAsStringSync('Content Two');

      final rootTwo = sync.computeSpaceMerkleRoot(spaceDir.path);
      expect(rootTwo, isNot(equals(rootOne)));
    });

    test('performAutomatedSync reconciles files and marks status inSync', () async {
      final sync = SyncBackupService.instance;
      final spaceDir = Directory('${tempDir.path}/reconcile_test')..createSync();
      File('${spaceDir.path}/alpha.txt').writeAsStringSync('Alpha');
      File('${spaceDir.path}/beta.txt').writeAsStringSync('Beta');

      sync.addSpace(
        SyncSpace(
          id: 'space_rec',
          name: 'Reconcile Space',
          localPath: spaceDir.path,
          remotePeerId: 'peer_node_02',
          mode: SyncMode.twoWaySync,
          status: SyncStatus.syncing,
          fileCount: 0,
          lastSyncTime: 'Never',
        ),
      );

      final ok = await sync.performAutomatedSync('space_rec');
      expect(ok, isTrue);

      final updated = sync.spaces.firstWhere((s) => s.id == 'space_rec');
      expect(updated.status, equals(SyncStatus.inSync));
      expect(updated.fileCount, equals(2));
      expect(updated.lastSyncTime, contains('Just now (Auto)'));
    });

    test('Mass-change protection: sudden deletion pauses sync and creates auto-snapshot', () async {
      final sync = SyncBackupService.instance;
      final spaceDir = Directory('${tempDir.path}/mass_del_test')..createSync();

      // Create 10 files
      for (int i = 0; i < 10; i++) {
        File('${spaceDir.path}/item_$i.dat').writeAsStringSync('payload $i');
      }

      sync.addSpace(
        SyncSpace(
          id: 'space_mass',
          name: 'Protected Vault',
          localPath: spaceDir.path,
          remotePeerId: 'peer_node_03',
          mode: SyncMode.twoWaySync,
          status: SyncStatus.inSync,
          fileCount: 10,
          lastSyncTime: 'Earlier',
        ),
      );

      // Delete 8 files (drops from 10 to 2, > 30% drop)
      for (int i = 0; i < 8; i++) {
        File('${spaceDir.path}/item_$i.dat').deleteSync();
      }

      final ok = await sync.performAutomatedSync('space_mass');
      expect(ok, isFalse); // Rejected due to mass-change hold

      final updated = sync.spaces.firstWhere((s) => s.id == 'space_mass');
      expect(updated.status, equals(SyncStatus.massChangePaused));

      // Assert automatic snapshot was saved
      expect(sync.snapshots, isNotEmpty);
      expect(sync.snapshots.first.name, contains('Mass-Change Safety Hold'));
    });

    test('triggerAutomatedSyncSweep sweeps active spaces', () async {
      final sync = SyncBackupService.instance;
      final spaceDir = Directory('${tempDir.path}/sweep_test')..createSync();
      File('${spaceDir.path}/sweep_file.txt').writeAsStringSync('Sweep');

      sync.addSpace(
        SyncSpace(
          id: 'space_sweep',
          name: 'Sweep Space',
          localPath: spaceDir.path,
          remotePeerId: 'peer_node_04',
          mode: SyncMode.oneWayPush,
          status: SyncStatus.syncing,
          fileCount: 1,
          lastSyncTime: 'Never',
        ),
      );

      await sync.triggerAutomatedSyncSweep();

      final updated = sync.spaces.firstWhere((s) => s.id == 'space_sweep');
      expect(updated.status, equals(SyncStatus.inSync));
    });
  });

  group('SpacesScreen Automated UI Controls', () {
    testWidgets('SpacesScreen renders Sync Now button for configured space', (tester) async {
      final spaceDir = Directory('${tempDir.path}/ui_space')..createSync();
      File('${spaceDir.path}/note.txt').writeAsStringSync('My Note');

      SyncBackupService.instance.addSpace(
        SyncSpace(
          id: 'space_ui',
          name: 'UI Auto Space',
          localPath: spaceDir.path,
          remotePeerId: 'peer_laptop',
          mode: SyncMode.twoWaySync,
          status: SyncStatus.inSync,
          fileCount: 1,
          lastSyncTime: '5m ago',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SpacesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('UI Auto Space'), findsOneWidget);
      expect(find.text('Preview Dry-Run'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);

      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('synchronized successfully'), findsOneWidget);
    });
  });
}
