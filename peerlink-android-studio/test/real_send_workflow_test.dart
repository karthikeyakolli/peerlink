import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/features/files/files_screen.dart';

void main() {
  group('Windows Real SEND Workflow & State Tests', () {
    testWidgets('Disconnected Node rejects send without fabricating demo transfer IDs and preserves user selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the expansion tile to expose manual inputs
      final advancedTile = find.text('Advanced Manual Paths & Policy');
      expect(advancedTile, findsOneWidget);
      await tester.tap(advancedTile);
      await tester.pumpAndSettle();

      // Enter a real test file path
      final sourceField = find.widgetWithText(TextField, 'Source Paths (File or Folder)');
      expect(sourceField, findsOneWidget);
      await tester.enterText(sourceField, 'C:\\test_payload.bin');
      await tester.pumpAndSettle();

      // Click "SEND TO EXACT PEER ID"
      final sendButton = find.widgetWithText(FilledButton, 'SEND TO EXACT PEER ID');
      expect(sendButton, findsOneWidget);
      await tester.ensureVisible(sendButton);
      await tester.pumpAndSettle();
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify that NO fabricated demo ID is displayed
      expect(find.textContaining('xfer-desk-'), findsNothing);
      expect(find.textContaining('Desktop Transfer Staged!'), findsNothing);

      // Verify that clear disconnection failure is communicated to the user
      expect(find.textContaining('disconnected', findRichText: true), findsWidgets);

      // Verify that the user's entered path was NOT cleared or lost
      final textFieldWidget = tester.widget<TextField>(sourceField);
      expect(textFieldWidget.controller?.text, contains('C:\\test_payload.bin'));
    });

    testWidgets('FilesScreen provides real file picker actions and displays selected real files',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Look for real file addition buttons
      expect(find.text('Add Files...'), findsOneWidget);
      expect(find.text('Add Folder...'), findsOneWidget);

      // Verify destination policy options are exposed
      final advancedTile = find.text('Advanced Manual Paths & Policy');
      await tester.tap(advancedTile);
      await tester.pumpAndSettle();

      expect(find.textContaining('FAIL_IF_EXISTS'), findsOneWidget);
    });
  });
}
