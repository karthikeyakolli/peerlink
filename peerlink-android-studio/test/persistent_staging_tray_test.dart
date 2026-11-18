import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/app/peerlink_app.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/design_system/components/persistent_staged_tray.dart';

void main() {
  setUp(() {
    FileStagingService.instance.resetForTesting();
    DeviceTrustService.instance.resetForTesting();
  });

  group('FileStagingService Unit Tests', () {
    test('addPaths stages files, dedupes, and calculates formatted byte sizes', () {
      final service = FileStagingService.instance;
      expect(service.isEmpty, isTrue);

      service.addPaths([
        'content://com.android.providers.media.documents/document/image%3A1024',
        'content://com.android.providers.media.documents/document/video%3A2048',
      ]);

      expect(service.count, 2);
      expect(service.selectedCount, 2);
      expect(service.isNotEmpty, isTrue);

      // Adding duplicate path should not increase count
      service.addPaths([
        'content://com.android.providers.media.documents/document/image%3A1024',
      ]);
      expect(service.count, 2);

      // Verify formatted size
      expect(service.formattedTotalBytes, isNotEmpty);
    });

    test('remove and clear methods update state reactively', () {
      final service = FileStagingService.instance;
      service.addPaths(['/path/file_a.pdf', '/path/file_b.png']);
      expect(service.count, 2);

      service.removePath('/path/file_a.pdf');
      expect(service.count, 1);
      expect(service.stagedFiles.first.path, '/path/file_b.png');

      service.clear();
      expect(service.isEmpty, isTrue);
    });

    test('toggleSelection toggles file selection and adjusts totals', () {
      final service = FileStagingService.instance;
      service.addPaths(['/path/item.bin']);
      expect(service.selectedCount, 1);

      final item = service.stagedFiles.first;
      service.toggleSelection(item);
      expect(service.selectedCount, 0);

      service.toggleSelection(item);
      expect(service.selectedCount, 1);
    });
  });

  group('PersistentStagedTray Widget Tests', () {
    testWidgets('Renders nothing when staging service is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersistentStagedTray(onReviewPressed: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PersistentStagedTray), findsOneWidget);
      expect(find.textContaining('items staged'), findsNothing);
    });

    testWidgets('Renders floating tray with badge when files staged, handles clear & review',
        (WidgetTester tester) async {
      final service = FileStagingService.instance;
      service.addPaths(['content://media/photos/sample.jpg']);

      bool reviewPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersistentStagedTray(
              onReviewPressed: () => reviewPressed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify tray content is visible
      expect(find.textContaining('1 item staged'), findsOneWidget);
      expect(find.text('Review & Send'), findsOneWidget);

      // Tap Review & Send
      await tester.tap(find.text('Review & Send'));
      await tester.pumpAndSettle();
      expect(reviewPressed, isTrue);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Verify tray disappears when cleared
      expect(service.isEmpty, isTrue);
      expect(find.text('Review & Send'), findsNothing);
    });
  });

  group('MainNavigationShell Contextual Staging Integration', () {
    testWidgets('Staged files display persistent tray over Files and open ContextualShareSheet on tap',
        (WidgetTester tester) async {
      // Stage files in singleton service
      FileStagingService.instance.addPaths([
        'content://media/documents/report.pdf',
        'content://media/documents/data.xlsx',
      ]);

      await tester.pumpWidget(
        const PeerLinkApp(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // User starts on Files (File Manager Home) tab (_currentIndex == 0)
      // Floating tray MUST appear over Files because files are staged
      expect(find.textContaining('2 items staged'), findsOneWidget);
      expect(find.text('Review & Send'), findsOneWidget);

      // Tap "Review & Send" on Files Home screen
      await tester.tap(find.text('Review & Send'));
      await tester.pumpAndSettle();

      // Verify contextual share sheet opens smoothly over File Manager with staged files loaded
      expect(find.text('Share & Receive'), findsOneWidget);
      expect(find.text('2 item(s) ready to share'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('data.xlsx'), findsOneWidget);
    });
  });
}
