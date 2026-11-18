import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/features/files/received_vault_view.dart';

void main() {
  group('Google Files Style Full File Manager Tests', () {
    late Directory tempVault;

    setUp(() {
      tempVault = Directory.systemTemp.createTempSync('google_files_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
      FileStagingService.instance.clear();
    });

    tearDown(() {
      try {
        if (tempVault.existsSync()) {
          tempVault.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders Storage Scope Switcher between Vault and Device Storage', (tester) async {
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

      // Verify both storage scope buttons are rendered
      expect(find.byKey(const Key('vault_storage_scope_vault')), findsOneWidget);
      expect(find.byKey(const Key('vault_storage_scope_device')), findsOneWidget);
      expect(find.text('PeerLink Vault'), findsWidgets);
      expect(find.text('Device Storage'), findsWidgets);

      // Switch to Device Storage
      await tester.tap(find.byKey(const Key('vault_storage_scope_device')));
      await tester.pumpAndSettle();

      expect(find.text('Device Storage'), findsWidgets);

      // Switch back to PeerLink Vault
      await tester.tap(find.byKey(const Key('vault_storage_scope_vault')));
      await tester.pumpAndSettle();

      expect(find.text('Storage Overview'), findsOneWidget);
    });

    testWidgets('file action menu contains Open with App, Share, Stage, Rename, Details, Reveal, Delete', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testFile = File('${tempVault.path}${Platform.pathSeparator}document.pdf');
      testFile.writeAsBytesSync([10, 20, 30, 40]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('document.pdf'), findsWidgets);

      // Scroll to menu button and tap
      final menuFinder = find.byKey(const Key('menu_document.pdf'));
      await tester.ensureVisible(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      // Verify all Google Files operations are listed
      expect(find.text('Open with App'), findsOneWidget);
      expect(find.text('Share...'), findsOneWidget);
      expect(find.text('Stage to Beam'), findsOneWidget);
      expect(find.text('Preview / Inspect'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('File Details'), findsOneWidget);
      expect(find.text('Reveal in System'), findsOneWidget);
      expect(find.text('Delete File'), findsOneWidget);
    });

    testWidgets('Stages file to Beam from action menu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testFile = File('${tempVault.path}${Platform.pathSeparator}beam_me.txt');
      testFile.writeAsStringSync('Hello PeerLink');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menuFinder = find.byKey(const Key('menu_beam_me.txt'));
      await tester.ensureVisible(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stage to Beam'));
      await tester.pumpAndSettle();

      expect(FileStagingService.instance.stagedFiles.any((f) => f.name == 'beam_me.txt'), isTrue);
      expect(find.text('Staged "beam_me.txt" to beam!'), findsOneWidget);
    });

    testWidgets('Renames file in place via Rename Dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final oldFile = File('${tempVault.path}${Platform.pathSeparator}report_draft.docx');
      oldFile.writeAsStringSync('Draft contents');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menuFinder = find.byKey(const Key('menu_report_draft.docx'));
      await tester.ensureVisible(menuFinder);
      await tester.pumpAndSettle();

      // Open menu and tap Rename
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rename_dialog')), findsOneWidget);
      expect(find.byKey(const Key('rename_text_field')), findsOneWidget);

      // Enter new file name
      await tester.enterText(find.byKey(const Key('rename_text_field')), 'report_final.docx');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rename_confirm_button')));
      await tester.pumpAndSettle();

      // Verify old file no longer exists and new file exists on disk
      expect(File('${tempVault.path}/report_draft.docx').existsSync(), isFalse);
      expect(File('${tempVault.path}/report_final.docx').existsSync(), isTrue);
      expect(find.text('Renamed to "report_final.docx"'), findsOneWidget);
      expect(find.text('report_final.docx'), findsWidgets);
    });

    testWidgets('Opens File Details dialog with metadata and copyable path', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sampleFile = File('${tempVault.path}${Platform.pathSeparator}photo.png');
      sampleFile.writeAsBytesSync(List.filled(2048, 42));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menuFinder = find.byKey(const Key('menu_photo.png'));
      await tester.ensureVisible(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('File Details'));
      await tester.pumpAndSettle();

      // Check properties sheet
      expect(find.text('File Location'), findsOneWidget);
      expect(find.textContaining('photo.png'), findsWidgets);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Last Modified'), findsOneWidget);
      expect(find.text('Stage'), findsOneWidget);
    });

    testWidgets('Grid View displays card action menu with same operations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      File('${tempVault.path}${Platform.pathSeparator}song.mp3').writeAsBytesSync([1, 2, 3]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to and toggle to Grid View
      final gridToggleFinder = find.byTooltip('Grid View');
      await tester.ensureVisible(gridToggleFinder);
      await tester.pumpAndSettle();
      await tester.tap(gridToggleFinder);
      await tester.pumpAndSettle();

      // Verify grid menu button is present on the card
      final gridMenuFinder = find.byKey(const Key('grid_menu_song.mp3'));
      await tester.ensureVisible(gridMenuFinder);
      await tester.pumpAndSettle();
      expect(gridMenuFinder, findsOneWidget);

      await tester.tap(gridMenuFinder);
      await tester.pumpAndSettle();

      expect(find.text('Open with App'), findsOneWidget);
      expect(find.text('Share...'), findsOneWidget);
      expect(find.text('Stage to Beam'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('File Details'), findsOneWidget);
    });
  });
}
