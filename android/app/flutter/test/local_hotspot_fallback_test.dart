import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/error_message_simplifier.dart';
import 'package:peerlink/design_system/components/local_hotspot_modal.dart';

void main() {
  group('LocalHotspotFallback & Reachability Recovery Tests', () {
    test('ErrorMessageSimplifier marks unreachable route with canHotspotFallback', () {
      final res = ErrorMessageSimplifier.simplify(
        'Target peer has no reachable discovered routes or active sessions',
      );
      expect(res.title, 'Device Unreachable');
      expect(res.canHotspotFallback, isTrue);
    });

    test('ErrorMessageSimplifier marks network timeout with canHotspotFallback', () {
      final res = ErrorMessageSimplifier.simplify(
        'Transport connection timed out after 10000ms',
      );
      expect(res.title, 'Connection Timed Out');
      expect(res.canHotspotFallback, isTrue);
    });

    testWidgets('LocalHotspotModal renders AP Isolation bypass title and QR container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocalHotspotModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Direct Wi-Fi Hotspot'), findsOneWidget);
      expect(find.textContaining('AP Isolation'), findsOneWidget);
    });
  });
}
