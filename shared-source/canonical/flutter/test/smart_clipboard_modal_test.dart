import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/components/quick_text_share_modal.dart';

void main() {
  group('QuickTextShareModal & Smart Intelligence UI Tests', () {
    testWidgets('Renders incoming text modal with Open in Browser for URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    QuickTextShareModal.showIncomingText(
                      ctx,
                      senderName: 'Pixel 9 Pro',
                      text: 'https://docs.peerlink.org/architecture',
                    );
                  },
                  child: const Text('Trigger Incoming'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap trigger button
      await tester.tap(find.text('Trigger Incoming'));
      await tester.pumpAndSettle();

      // Check URL was detected and actionable button is displayed
      expect(find.text('Text from Pixel 9 Pro'), findsOneWidget);
      expect(find.text('docs.peerlink.org'), findsOneWidget);
      expect(find.byKey(const Key('incoming_open_browser_button')), findsOneWidget);
      expect(find.byKey(const Key('incoming_copy_raw_button')), findsOneWidget);
    });

    testWidgets('Renders incoming text modal with Copy Password for Wi-Fi QR snippet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    QuickTextShareModal.showIncomingText(
                      ctx,
                      senderName: 'Home Router',
                      text: 'WIFI:S:PeerLink_5G;T:WPA;P:SuperSecretPass;;',
                    );
                  },
                  child: const Text('Trigger Incoming Wi-Fi'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap trigger button
      await tester.tap(find.text('Trigger Incoming Wi-Fi'));
      await tester.pumpAndSettle();

      // Verify Wi-Fi intelligence UI
      expect(find.text('Wi-Fi: PeerLink_5G'), findsOneWidget);
      expect(find.byKey(const Key('incoming_copy_wifi_button')), findsOneWidget);
    });

    testWidgets('Composing text shows live smart content detection pill', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickTextShareModal(
              initialText: 'https://peerlink.org',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure URL chip is rendered
      expect(find.text('URL Link Detected'), findsOneWidget);
    });
  });
}
