import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/features/files/received_vault_view.dart';

void main() {
  group('Nested Vault Folder Hierarchy & Breadcrumb Navigation Tests', () {
    late Directory tempDir;
    final service = ReceivedFilesService.instance;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_hierarchy_test_');
      AppSettingsService.instance.saveLocation = tempDir.path;
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('ReceivedFilesService resolves directories, child counts, and nested subpaths', () async {
      // Create nested folder structure:
      // tempDir/
      //   root_doc.txt
      //   Projects/
      //     Mobile/
      //       app.apk
      //   Photos/
      //     beach.jpg
      File('${tempDir.path}/root_doc.txt').writeAsStringSync('Root Doc');
      final projectsDir = Directory('${tempDir.path}/Projects')..createSync(recursive: true);
      final mobileDir = Directory('${projectsDir.path}/Mobile')..createSync(recursive: true);
      File('${mobileDir.path}/app.apk').writeAsBytesSync([1, 2, 3]);

      final photosDir = Directory('${tempDir.path}/Photos')..createSync(recursive: true);
      File('${photosDir.path}/beach.jpg').writeAsBytesSync([4, 5]);

      // 1. Root level query
      final rootItems = await service.getReceivedFiles();
      expect(rootItems.any((i) => i.name == 'Projects' && i.isDirectory), isTrue);
      expect(rootItems.any((i) => i.name == 'Photos' && i.isDirectory), isTrue);
      expect(rootItems.any((i) => i.name == 'root_doc.txt' && !i.isDirectory), isTrue);

      final photosItem = rootItems.firstWhere((i) => i.name == 'Photos');
      expect(photosItem.childCount, 1);
      expect(photosItem.formattedSize, '1 item');

      // 2. Query into 'Projects'
      final projectItems = await service.getReceivedFiles(subDirectoryRelativePath: 'Projects');
      expect(projectItems.length, 1);
      expect(projectItems.first.name, 'Mobile');
      expect(projectItems.first.isDirectory, isTrue);

      // 3. Query into 'Projects/Mobile'
      final mobileItems = await service.getReceivedFiles(subDirectoryRelativePath: 'Projects/Mobile');
      expect(mobileItems.length, 1);
      expect(mobileItems.first.name, 'app.apk');
      expect(mobileItems.first.isDirectory, isFalse);

      // 4. Recursive folder deletion
      final deleted = await service.deleteFile(photosDir.path);
      expect(deleted, isTrue);
      expect(photosDir.existsSync(), isFalse);
    });

    testWidgets('ReceivedVaultView displays folders, allows drill-down and breadcrumb back navigation', (tester) async {
      final docsDir = Directory('${tempDir.path}/Documents')..createSync(recursive: true);
      File('${docsDir.path}/contract.pdf').writeAsBytesSync([1, 2, 3]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check folder item is rendered
      final docsFinder = find.text('Documents');
      expect(docsFinder, findsOneWidget);
      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);

      // Scroll to Documents folder and tap to drill down
      await tester.ensureVisible(docsFinder);
      await tester.pumpAndSettle();
      await tester.tap(docsFinder);
      await tester.pumpAndSettle();

      // Verify breadcrumbs bar appears with 'Vault' and 'Documents'
      expect(find.byKey(const Key('vault_breadcrumbs_bar')), findsOneWidget);
      expect(find.text('contract.pdf'), findsOneWidget);

      // Tap 'Up' button in breadcrumbs to navigate back
      final upButton = find.byKey(const Key('vault_back_up_button'));
      expect(upButton, findsOneWidget);
      await tester.tap(upButton);
      await tester.pumpAndSettle();

      // Verify we are back at the root
      expect(find.text('Documents'), findsOneWidget);
      expect(find.byKey(const Key('vault_breadcrumbs_bar')), findsNothing);
    });
  });
}
