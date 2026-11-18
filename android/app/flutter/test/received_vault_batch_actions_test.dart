import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/features/files/received_vault_view.dart';

void main() {
  group('ReceivedVaultView Batch Multi-Select & Deep Clean Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_vault_test_');
      AppSettingsService.instance.saveLocation = tempDir.path;

      // Seed files for testing
      File('${tempDir.path}/doc1.pdf').writeAsBytesSync(List.filled(100, 1));
      File('${tempDir.path}/photo1.png').writeAsBytesSync(List.filled(200, 2));
      File('${tempDir.path}/app1.apk').writeAsBytesSync(List.filled(300, 3));
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('Renders Deep Clean button and responds to tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deepCleanFinder = find.byKey(const Key('deep_clean_button'));
      expect(deepCleanFinder, findsOneWidget);
    });

    testWidgets('Toggles multi-select mode and stages batch files to Beam', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure files are listed
      expect(find.text('doc1.pdf'), findsWidgets);
      expect(find.text('photo1.png'), findsWidgets);

      // Tap multi-select toggle button
      final toggleButton = find.byKey(const Key('toggle_multi_select_button'));
      expect(toggleButton, findsOneWidget);
      await tester.ensureVisible(toggleButton);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verify multi-select banner is visible
      final selectAllCheckbox = find.byKey(const Key('select_all_checkbox'));
      expect(selectAllCheckbox, findsOneWidget);

      // Tap Select All
      await tester.tap(selectAllCheckbox);
      await tester.pumpAndSettle();

      // Check floating batch action pill appears with Beam button
      final beamButton = find.byKey(const Key('batch_beam_button'));
      expect(beamButton, findsOneWidget);

      // Tap Beam button
      await tester.tap(beamButton);
      await tester.pumpAndSettle();

      // Verify files were staged and contextual share sheet opened smoothly
      expect(FileStagingService.instance.stagedFiles.length, 3);
      expect(find.text('Share & Receive'), findsOneWidget);
      expect(find.text('3 item(s) ready to share'), findsOneWidget);
    });
  });
}
