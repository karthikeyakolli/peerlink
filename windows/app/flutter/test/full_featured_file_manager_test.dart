import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/features/files/received_vault_view.dart';

void main() {
  group('Full-Featured Real File Manager UI/UX & Operations Tests', () {
    late Directory tempVault;

    setUp(() {
      tempVault = Directory.systemTemp.createTempSync('full_file_manager_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
      FileStagingService.instance.clear();

      // Seed sample files
      File('${tempVault.path}/notes.txt').writeAsStringSync('Notes for meeting');
      File('${tempVault.path}/photo.png').writeAsBytesSync([1, 2, 3, 4]);
      File('${tempVault.path}/.hidden_config').writeAsStringSync('secret=123');
    });

    tearDown(() {
      try {
        if (tempVault.existsSync()) {
          tempVault.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('Creates a new folder via New Folder dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify New Folder button is rendered
      final newFolderBtn = find.byKey(const Key('vault_new_folder_button'));
      expect(newFolderBtn, findsOneWidget);

      await tester.tap(newFolderBtn);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('New Folder'), findsOneWidget);
      expect(find.byKey(const Key('create_folder_input')), findsOneWidget);

      // Enter folder name and submit
      await tester.enterText(find.byKey(const Key('create_folder_input')), 'Documents');
      await tester.tap(find.byKey(const Key('create_folder_confirm')));
      await tester.pumpAndSettle();

      // Verify folder was created on disk and appears in UI
      expect(Directory('${tempVault.path}/Documents').existsSync(), isTrue);
      expect(find.text('Documents'), findsWidgets);
    });

    testWidgets('Copies a file to a new subfolder using Cut/Copy/Paste engine', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Create destination subfolder
      Directory('${tempVault.path}/Backup').createSync();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu on notes.txt
      final menuBtn = find.byKey(const Key('menu_notes.txt'));
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Tap Copy to...
      expect(find.text('Copy to...'), findsOneWidget);
      await tester.tap(find.text('Copy to...'));
      await tester.pumpAndSettle();

      // Floating paste bar must appear
      expect(find.byKey(const Key('vault_paste_floating_bar')), findsOneWidget);
      expect(find.textContaining('Copying 1 item(s)'), findsOneWidget);

      // Drill down into Backup subfolder
      await tester.tap(find.widgetWithText(ListTile, 'Backup'));
      await tester.pumpAndSettle();

      // Tap Paste Here
      expect(find.byKey(const Key('vault_paste_here_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vault_paste_here_button')));
      await tester.pumpAndSettle();

      // Verify file was copied into Backup
      expect(File('${tempVault.path}/Backup/notes.txt').existsSync(), isTrue);
      // Original file still exists (because it was a Copy, not a Cut)
      expect(File('${tempVault.path}/notes.txt').existsSync(), isTrue);
    });

    testWidgets('Compresses files to ZIP archive and extracts it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open menu on notes.txt
      await tester.tap(find.byKey(const Key('menu_notes.txt')));
      await tester.pumpAndSettle();

      // Tap Compress to ZIP
      expect(find.text('Compress to ZIP'), findsOneWidget);
      await tester.tap(find.text('Compress to ZIP'));
      await tester.pumpAndSettle();

      // Confirm compression in dialog
      expect(find.byKey(const Key('compress_zip_confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('compress_zip_confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify ZIP was created on disk
      expect(File('${tempVault.path}/notes.zip').existsSync(), isTrue);
      expect(find.text('notes.zip'), findsWidgets);

      // Open menu on notes.zip
      final zipMenuFinder = find.byKey(const Key('menu_notes.zip'));
      await tester.ensureVisible(zipMenuFinder);
      await tester.tap(zipMenuFinder);
      await tester.pumpAndSettle();

      // Verify Extract Archive option is available for .zip files
      expect(find.text('Extract Archive'), findsOneWidget);
      await tester.tap(find.text('Extract Archive'));
      await tester.pumpAndSettle();

      // Confirm extraction
      expect(find.byKey(const Key('extract_zip_confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('extract_zip_confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify contents extracted into 'notes' folder
      expect(Directory('${tempVault.path}/notes').existsSync(), isTrue);
    });

    testWidgets('Multi-select batch mode supports Batch Copy, Move, and Compress', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Activate multi-select mode
      await tester.tap(find.byKey(const Key('toggle_multi_select_button')));
      await tester.pumpAndSettle();

      // Select All
      await tester.tap(find.byKey(const Key('select_all_checkbox')));
      await tester.pumpAndSettle();

      // Verify batch action buttons are present
      expect(find.byKey(const Key('batch_copy_button')), findsOneWidget);
      expect(find.byKey(const Key('batch_move_button')), findsOneWidget);
      expect(find.byKey(const Key('batch_compress_button')), findsOneWidget);
      expect(find.byKey(const Key('batch_beam_button')), findsOneWidget);
      expect(find.byKey(const Key('batch_delete_button')), findsOneWidget);
    });

    testWidgets('Toggles Show Hidden Files in Sort & View Options menu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default, hidden file .hidden_config is NOT shown
      expect(find.text('.hidden_config'), findsNothing);

      // Open sort & options menu
      final sortBtn = find.byKey(const Key('vault_sort_menu_button'));
      await tester.ensureVisible(sortBtn);
      await tester.tap(sortBtn);
      await tester.pumpAndSettle();

      // Tap Show Hidden Files
      expect(find.text('Show Hidden Files'), findsOneWidget);
      await tester.tap(find.text('Show Hidden Files'));
      await tester.pumpAndSettle();

      // Verify .hidden_config is now listed
      final hiddenItem = find.text('.hidden_config');
      await tester.ensureVisible(hiddenItem.first);
      expect(hiddenItem, findsWidgets);
    });
  });
}
