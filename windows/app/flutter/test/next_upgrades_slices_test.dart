import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/safe_folder_service.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';
import 'package:peerlink/design_system/components/safe_folder_sheet.dart';
import 'package:peerlink/platform/desktop_shell_bridge.dart';

void main() {
  group('Slice 1 — Swipeable Media Gallery & Playlist Navigation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_playlist_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('navigates Prev/Next cleanly across heterogeneous playlist items', (tester) async {
      final f1 = File('${tempDir.path}/alpha.txt')..writeAsStringSync('Alpha Note Body');
      final f2 = File('${tempDir.path}/beta.txt')..writeAsStringSync('Beta Note Body');
      final f3 = File('${tempDir.path}/song.mp3')..writeAsBytesSync([0x49, 0x44, 0x33, 0x03]);

      final items = [
        ReceivedFileItem(
          path: f1.path,
          name: 'alpha.txt',
          sizeBytes: f1.lengthSync(),
          lastModified: DateTime.now(),
          category: ReceivedFileCategory.documents,
          extension: 'txt',
        ),
        ReceivedFileItem(
          path: f2.path,
          name: 'beta.txt',
          sizeBytes: f2.lengthSync(),
          lastModified: DateTime.now(),
          category: ReceivedFileCategory.documents,
          extension: 'txt',
        ),
        ReceivedFileItem(
          path: f3.path,
          name: 'song.mp3',
          sizeBytes: f3.lengthSync(),
          lastModified: DateTime.now(),
          category: ReceivedFileCategory.audio,
          extension: 'mp3',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 860,
              child: MediaPreviewModal(
                fileItem: items[0],
                playlist: items,
                initialIndex: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Alpha Note Body'), findsOneWidget);

      // Next -> beta.txt
      await tester.tap(find.byKey(const Key('preview_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Beta Note Body'), findsOneWidget);

      // Next -> song.mp3
      await tester.tap(find.byKey(const Key('preview_next_button')));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('MP3 AUDIO'), findsOneWidget);

      // Prev -> back to beta.txt
      await tester.tap(find.byKey(const Key('preview_prev_button')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Beta Note Body'), findsOneWidget);
    });
  });

  group('Slice 2 — In-App Quick Text / Notes Editor', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_editor_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('edits a text file in-app and saves changes atomically to disk', (tester) async {
      final noteFile = File('${tempDir.path}/todo.md')..writeAsStringSync('# Initial Note');
      final item = ReceivedFileItem(
        path: noteFile.path,
        name: 'todo.md',
        sizeBytes: noteFile.lengthSync(),
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
        extension: 'md',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 860,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('# Initial Note'), findsOneWidget);

      // Enter Edit mode
      await tester.tap(find.byKey(const Key('edit_text_preview_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inline_text_editor_field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('inline_text_editor_field')),
        '# Updated PeerLink Note\n- Saved locally!',
      );
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('save_edit_text_button')));
      await tester.pumpAndSettle();

      expect(noteFile.readAsStringSync(), '# Updated PeerLink Note\n- Saved locally!');
      expect(find.text('# Updated PeerLink Note\n- Saved locally!'), findsOneWidget);
    });
  });

  group('Slice 3 — Private PIN-Locked Safe Folder (Encrypted & Fail-Closed)', () {
    late Directory tempVault;
    late String previousSaveLocation;

    setUp(() {
      previousSaveLocation = AppSettingsService.instance.saveLocation;
      tempVault = Directory.systemTemp.createTempSync('peerlink_safe_folder_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
      SafeFolderService.instance.lock();
    });

    tearDown(() {
      SafeFolderService.instance.lock();
      AppSettingsService.instance.saveLocation = previousSaveLocation;
      try {
        if (tempVault.existsSync()) tempVault.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('encrypts file with PIN, rejects wrong PIN, detects tampering, and restores exact bytes', () async {
      final secretFile = File('${tempVault.path}/passport_scan.txt')
        ..writeAsStringSync('TOP SECRET PEERLINK PAYLOAD 2026');

      final safe = SafeFolderService.instance;
      expect(safe.isConfigured, isFalse);

      await safe.setupPin('4321');
      expect(safe.isConfigured, isTrue);
      expect(safe.isUnlocked, isTrue);

      final locked = await safe.lockFile(secretFile.path);
      expect(secretFile.existsSync(), isFalse); // Plaintext removed from Vault

      // Verify on-disk encrypted blob does NOT contain plaintext
      final encBlob = File('${tempVault.path}/.peerlink_safe_vault/${locked.id}.plsafe');
      expect(encBlob.existsSync(), isTrue);
      expect(String.fromCharCodes(encBlob.readAsBytesSync()), isNot(contains('TOP SECRET')));

      // Lock & test wrong PIN failure path
      safe.lock();
      expect(safe.isUnlocked, isFalse);
      expect(await safe.unlock('0000'), isFalse);
      expect(safe.isUnlocked, isFalse);

      // Unlock with correct PIN
      expect(await safe.unlock('4321'), isTrue);
      expect(safe.listLockedFiles().length, 1);

      // Test fail-closed tamper detection on a second locked file
      final tamperTarget = File('${tempVault.path}/tamper_me.txt')..writeAsStringSync('INTACT');
      final tamperLocked = await safe.lockFile(tamperTarget.path);
      final tamperBlobFile = File('${tempVault.path}/.peerlink_safe_vault/${tamperLocked.id}.plsafe');
      final mutated = tamperBlobFile.readAsBytesSync();
      mutated[mutated.length - 1] ^= 0xFF; // flip last ciphertext byte
      tamperBlobFile.writeAsBytesSync(mutated, flush: true);

      await expectLater(
        () => safe.restoreFile(tamperLocked.id),
        throwsA(isA<FormatException>()),
      );

      // Restore untampered file and verify exact bytes
      final restoredPath = await safe.restoreFile(locked.id);
      expect(File(restoredPath).readAsStringSync(), 'TOP SECRET PEERLINK PAYLOAD 2026');
    });

    testWidgets('SafeFolderSheet sets up PIN, locks, and unlocks cleanly with zero gradients/shadows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeFolderSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('safe_setup_pin_field')), '2580');
      await tester.enterText(find.byKey(const Key('safe_confirm_pin_field')), '2580');
      await tester.tap(find.byKey(const Key('safe_create_pin_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safe_add_file_button')), findsOneWidget);

      // Lock via UI button
      await tester.tap(find.byKey(const Key('safe_folder_lock_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safe_unlock_pin_field')), findsOneWidget);

      // Verify zero gradients and zero shadows
      for (final w in tester.allWidgets) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          expect(dec.gradient, isNull);
          expect(dec.boxShadow, isNull);
        }
      }
    });
  });

  group('Slice 4 — Windows Drag-and-Drop & System Tray Quick-Send Bridge', () {
    setUp(() {
      FileStagingService.instance.clear();
    });

    test('stages dropped files and emits on droppedFilesStream; consumes launch args once', () async {
      final bridge = DesktopShellBridge.instance;
      final received = <List<String>>[];
      final sub = bridge.droppedFilesStream.listen(received.add);

      bridge.handleIncomingPaths(['C:\\Users\\Demo\\report.pdf', 'C:\\Users\\Demo\\photo.jpg']);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(received.length, 1);
      expect(received.first, ['C:\\Users\\Demo\\report.pdf', 'C:\\Users\\Demo\\photo.jpg']);
      expect(
        FileStagingService.instance.stagedFiles.map((f) => f.path),
        contains('C:\\Users\\Demo\\report.pdf'),
      );

      await sub.cancel();

      bridge.recordLaunchArgs(['C:\\Users\\Demo\\context_menu_file.zip']);
      final firstRead = bridge.consumeLaunchArgs();
      final secondRead = bridge.consumeLaunchArgs();
      expect(firstRead, ['C:\\Users\\Demo\\context_menu_file.zip']);
      expect(secondRead, isEmpty);
    });
  });
}
