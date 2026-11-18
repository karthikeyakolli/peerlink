import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/quick_text_service.dart';
import 'package:peerlink/design_system/components/quick_text_share_modal.dart';

void main() {
  setUp(() {
    QuickTextService.instance.resetForTesting();
    DeviceTrustService.instance.resetForTesting();
  });

  group('QuickTextShareModal Widget Tests', () {
    testWidgets('QuickTextShareModal renders input, detects URLs, and sends text',
        (WidgetTester tester) async {
      String? sentText;
      String? sentTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => QuickTextShareModal.show(
                  context,
                  initialPeerId: 'target_laptop',
                  onSendText: (txt, peer) {
                    sentText = txt;
                    sentTarget = peer;
                  },
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify modal headers and components
      expect(find.text('Quick Text & Link Share'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('0 characters'), findsOneWidget);

      // Enter normal text
      await tester.enterText(find.byType(TextField), 'Hello from PeerLink!');
      await tester.pump();

      expect(find.text('20 characters'), findsOneWidget);
      expect(find.text('URL Link Detected'), findsNothing);

      // Enter a URL
      await tester.enterText(find.byType(TextField), 'https://peerlink.local/sync');
      await tester.pump();

      expect(find.text('URL Link Detected'), findsOneWidget);

      // Tap Send Text or Link
      await tester.tap(find.text('Send Text or Link'));
      await tester.pumpAndSettle();

      // Assert callbacks
      expect(sentText, equals('https://peerlink.local/sync'));
      expect(sentTarget, equals('target_laptop'));
      expect(QuickTextService.instance.history.length, equals(1));
    });

    testWidgets('showIncomingText displays text with copy action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => QuickTextShareModal.showIncomingText(
                  context,
                  senderName: 'Work Laptop',
                  text: 'https://example.com/document.pdf',
                ),
                child: const Text('Show Incoming'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Incoming'));
      await tester.pumpAndSettle();

      expect(find.text('Text from Work Laptop'), findsOneWidget);
      expect(find.text('https://example.com/document.pdf'), findsOneWidget);
      expect(find.text('Web Link Detected'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Text from Work Laptop'), findsNothing);
    });
  });
}
