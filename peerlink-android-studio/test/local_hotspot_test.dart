import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/components/local_hotspot_modal.dart';
import 'package:peerlink/platform/android_node_bridge.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  group('Direct Local Hotspot Mode Unit & Bridge Tests', () {
    test('startLocalHotspot returns valid profile with standard Wi-Fi QR token', () async {
      final info = await AndroidNodeBridge.instance.startLocalHotspot();
      expect(info, isNotNull);
      expect(info!['ssid'].toString().startsWith('PeerLink-Direct-'), isTrue);
      expect(info['passphrase'].toString().length, greaterThanOrEqualTo(8));
      expect(info['gatewayIp'], '192.168.49.1');
      expect(info['listenPort'], 52001);
      expect(info['wifiQr'].toString(), startsWith('WIFI:S:PeerLink-Direct-'));
      expect(info['peerlinkUri'].toString(), startsWith('peerlink://hotspot?'));
    });

    test('stopLocalHotspot succeeds cleanly', () async {
      final stopped = await AndroidNodeBridge.instance.stopLocalHotspot();
      expect(stopped, isTrue);
    });
  });

  group('LocalHotspotModal Widget Tests', () {
    testWidgets('Renders initial inactive state with explanatory AP bypass copy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocalHotspotModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Wi-Fi Hotspot'), findsOneWidget);
      expect(find.text('AP Isolation Bypass'), findsOneWidget);
      expect(find.textContaining('Bypasses client isolation on hotel'), findsOneWidget);
      expect(find.text('Activate Offline Hotspot'), findsOneWidget);
    });

    testWidgets('Activating hotspot displays real QR code and credentials card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocalHotspotModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Activate Offline Hotspot"
      await tester.tap(find.text('Activate Offline Hotspot'));
      await tester.pumpAndSettle();

      // Verify QR Code is rendered
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify credentials card displays SSID and Password
      expect(find.text('Network (SSID)'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Gateway IP'), findsOneWidget);
      expect(find.text('192.168.49.1:52001'), findsOneWidget);

      // Button should now allow stopping the hotspot
      final stopBtn = find.text('Stop Hotspot & Release Radio');
      expect(stopBtn, findsOneWidget);
      await tester.ensureVisible(stopBtn);
      await tester.pumpAndSettle();

      // Tap "Stop Hotspot & Release Radio"
      await tester.tap(stopBtn);
      await tester.pumpAndSettle();

      // Verify QR code is dismissed and button returns to Activate
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Activate Offline Hotspot'), findsOneWidget);
    });
  });
}
