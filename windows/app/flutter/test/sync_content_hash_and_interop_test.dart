import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/sync_backup_service.dart';
import 'package:peerlink/core/web_beam_server_service.dart';
import 'package:peerlink/design_system/components/contextual_share_sheet.dart';
import 'package:peerlink/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real Content-Hash Cross-Device Sync Engine (Rules 7, 8, 9)', () {
    late Directory tempSyncDir;

    setUp(() {
      SyncBackupService.instance.resetForTesting();
      tempSyncDir = Directory.systemTemp.createTempSync('peerlink_real_sync_test_');
    });

    tearDown(() {
      SyncBackupService.instance.resetForTesting();
      try {
        if (tempSyncDir.existsSync()) tempSyncDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Detects content mutation even when byte length is identical and pushes ONLY deltas', () async {
      final fileA = File('${tempSyncDir.path}/alpha.txt')..writeAsStringSync('AAAA');
      final fileB = File('${tempSyncDir.path}/beta.txt')..writeAsStringSync('1111');

      final pushedBatches = <({String peerId, List<String> paths})>[];
      SyncBackupService.instance.onPushDeltaFiles = (peerId, paths) async {
        pushedBatches.add((peerId: peerId, paths: List<String>.from(paths)));
        return true;
      };

      SyncBackupService.instance.addSpace(SyncSpace(
        id: 'sp_win_sync',
        name: 'Work Docs',
        localPath: tempSyncDir.path,
        remotePeerId: 'win_desktop_01',
        mode: SyncMode.twoWaySync,
        status: SyncStatus.inSync,
        fileCount: 2,
        lastSyncTime: 'Never',
      ));

      // First sync pushes both initial files
      final firstOk = await SyncBackupService.instance.performAutomatedSync('sp_win_sync');
      expect(firstOk, isTrue);
      expect(pushedBatches.length, 1);
      expect(pushedBatches.first.peerId, 'win_desktop_01');
      expect(pushedBatches.first.paths.length, 2);

      // Re-sync with zero changes pushes NOTHING
      final secondOk = await SyncBackupService.instance.performAutomatedSync('sp_win_sync');
      expect(secondOk, isTrue);
      expect(pushedBatches.length, 1);

      // Mutate alpha.txt with SAME byte length ('AAAA' -> 'BBBB')
      fileA.writeAsStringSync('BBBB');
      final diffs = SyncBackupService.instance.computeDryRun(SyncBackupService.instance.spaces.first);
      expect(diffs.any((d) => d.type == 'MODIFIED' && d.relativePath == 'alpha.txt'), isTrue);

      // Third sync pushes ONLY alpha.txt (not beta.txt)
      final thirdOk = await SyncBackupService.instance.performAutomatedSync('sp_win_sync');
      expect(thirdOk, isTrue);
      expect(pushedBatches.length, 2);
      expect(pushedBatches.last.paths.length, 1);
      expect(pushedBatches.last.paths.first.endsWith('alpha.txt'), isTrue);
      expect(fileB.existsSync(), isTrue);
    });
  });

  group('Bi-Directional Web Beam HTTP Upload & Security Tests (Rule 12)', () {
    late Directory tempVault;
    late File seedFile;
    HttpOverrides? previousOverrides;

    setUp(() {
      previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      AppSettingsService.instance.resetForTesting();
      tempVault = Directory.systemTemp.createTempSync('peerlink_webbeam_upload_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
      seedFile = File('${tempVault.path}/outbound.txt')..writeAsStringSync('from phone');
    });

    tearDown(() async {
      await WebBeamServerService.instance.stop();
      HttpOverrides.global = previousOverrides;
      try {
        if (tempVault.existsSync()) tempVault.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('POST /upload streams file into Vault with valid token, rejects unauthorized, sanitizes traversal', () async {
      final state = await WebBeamServerService.instance.start(
        paths: [seedFile.path],
        preferredPort: 0,
        overrideHostIp: '127.0.0.1',
      );
      expect(state.isRunning, isTrue);

      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      // 1. Unauthorized upload MUST be rejected with 403 Forbidden (Rule 12)
      final badReq = await client.postUrl(
        Uri.parse('http://127.0.0.1:${state.port}/upload?token=invalid&name=hack.txt'),
      );
      badReq.add(utf8.encode('blocked'));
      final badRes = await badReq.close();
      expect(badRes.statusCode, HttpStatus.forbidden);
      expect(File('${tempVault.path}/hack.txt').existsSync(), isFalse);

      // 2. Authorized upload with path traversal attempt MUST land safely inside Vault
      final payload = 'Hello from Windows PC over Wi-Fi!';
      final okReq = await client.postUrl(
        Uri.parse('http://127.0.0.1:${state.port}/upload?token=${state.token}&name=../../windows_note.txt'),
      );
      okReq.add(utf8.encode(payload));
      final okRes = await okReq.close();
      final body = await okRes.transform(utf8.decoder).join();
      expect(okRes.statusCode, HttpStatus.ok);

      final parsed = jsonDecode(body) as Map<String, dynamic>;
      expect(parsed['ok'], isTrue);
      expect(parsed['name'], 'windows_note.txt');

      final saved = File('${ReceivedFilesService.instance.saveDirectory.path}/windows_note.txt');
      expect(saved.existsSync(), isTrue);
      expect(saved.readAsStringSync(), payload);
      expect(WebBeamServerService.instance.currentState.uploadCount, 1);

      // 3. Uploading same filename again MUST non-destructively suffix instead of overwriting
      final dupReq = await client.postUrl(
        Uri.parse('http://127.0.0.1:${state.port}/upload?token=${state.token}&name=windows_note.txt'),
      );
      dupReq.add(utf8.encode('second version'));
      final dupRes = await dupReq.close();
      expect(dupRes.statusCode, HttpStatus.ok);

      final savedDup = File('${ReceivedFilesService.instance.saveDirectory.path}/windows_note (1).txt');
      expect(savedDup.existsSync(), isTrue);
      expect(savedDup.readAsStringSync(), 'second version');
      expect(saved.readAsStringSync(), payload);
    });
  });

  group('Cross-App Share Sheet & Folder Sync Navigation UI Tests', () {
    testWidgets('AppBar Folder Sync opens Spaces and ContextualShareSheet exposes Quick Share & Other Apps',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const app_main.PeerLinkApp());
      await tester.pumpAndSettle();

      // 1. Folder Sync button is accessible in 1 tap from File Manager AppBar
      final syncBtn = find.byKey(const Key('appbar_sync_spaces_button'));
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pumpAndSettle();

      // Back to Files
      await tester.tap(find.text('Files').last);
      await tester.pumpAndSettle();

      // 2. Open ContextualShareSheet and verify Quick Share + Other Apps channels
      await tester.tap(find.byKey(const Key('appbar_contextual_share_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('contextual_channel_quick_share')), findsOneWidget);
      expect(find.byKey(const Key('contextual_channel_other_apps')), findsOneWidget);
      expect(find.byType(ContextualShareSheet), findsOneWidget);

      // 3. Enforce flat minimalist light-only rules (no gradients, no boxShadow)
      for (final container in tester.widgetList<Container>(find.byType(Container))) {
        final dec = container.decoration;
        if (dec is BoxDecoration) {
          expect(dec.gradient, isNull);
          expect(dec.boxShadow, isNull);
        }
      }
    });
  });
}
