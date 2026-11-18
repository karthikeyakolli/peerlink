import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/smart_content_sniffer.dart';
import 'package:peerlink/design_system/components/smart_clipboard_banner.dart';

void main() {
  group('SmartClipboardBanner Widget Tests', () {
    testWidgets('renders smart clipboard banner with sniffer details and triggers callbacks', (tester) async {
      final sniffed = SmartContentSniffer.instance.sniff('https://github.com/peerlink/desktop');
      bool beamed = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SmartClipboardBanner(
                content: sniffed,
                targetPeerName: 'Pixel 8 Pro',
                onBeam: () => beamed = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('github.com'), findsOneWidget);
      expect(find.text('Clip'), findsOneWidget);
      expect(find.text('Beam directly to Pixel 8 Pro'), findsOneWidget);
      expect(find.byKey(const Key('smart_clipboard_beam_button')), findsOneWidget);
      expect(find.byKey(const Key('smart_clipboard_dismiss_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('smart_clipboard_beam_button')));
      await tester.pumpAndSettle();
      expect(beamed, isTrue);

      await tester.tap(find.byKey(const Key('smart_clipboard_dismiss_button')));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });
  });
}
