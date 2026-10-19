import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:peerlink/design_system/components/qr_pairing_sheet.dart';
import 'package:peerlink/core/pairing_invitation.dart';
import 'package:peerlink/core/device_trust_service.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
    PairingInvitation.resetReplayCacheForTesting();
  });

  group('Phase 3 Acceptance Gate: Authenticated QR Invitations & Pairing Tests', () {
    testWidgets('QrPairingSheet: Show QR renders real QrImageView, SAS PIN, and expiry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrPairingSheet(
              deviceName: 'Pixel 9 Pro Primary',
              peerId: 'peer-auth-999',
              fingerprint: 'ed25519:abcdef1234567890abcdef1234567890',
              localIp: '192.168.1.150:8765',
              initialTab: 0,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Assert real QrImageView is rendered (NOT _SimulatedQrPainter)
      expect(find.byType(QrImageView), findsOneWidget);

      // 2. Assert device name and SAS PIN are visible
      expect(find.text('Pixel 9 Pro Primary'), findsOneWidget);
      expect(find.textContaining('SAS PIN:'), findsOneWidget);

      // 3. Assert live expiry countdown is visible
      expect(find.textContaining('Expires in 0'), findsOneWidget);

      // 4. Assert simulated QR painter no longer exists
      expect(find.text('Simulate Instant Scan'), findsNothing);
    });

    testWidgets('QrPairingSheet: Manual fallback validates invitation, shows SAS PIN, and pairs device',
        (WidgetTester tester) async {
      String? completedPayload;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrPairingSheet(
              deviceName: 'Pixel 9 Receiver',
              peerId: 'peer-rx-100',
              fingerprint: 'ed25519:rxfingerprint1234',
              initialTab: 1, // Scan tab
              onQrScanned: (payload) {
                completedPayload = payload;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open manual entry
      expect(find.text('Enter Invitation Manually / Paste'), findsOneWidget);
      await tester.tap(find.text('Enter Invitation Manually / Paste'));
      await tester.pumpAndSettle();

      // 1. Test invalid payload rejection
      await tester.enterText(find.byType(TextField), 'invalid-payload-string');
      await tester.tap(find.text('Verify & Pair'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid JSON payload'), findsOneWidget);

      // 2. Test valid invitation acceptance
      final validInvitation = PairingInvitation.create(
        peerId: 'peer-sender-remote-77',
        name: 'Office ThinkPad',
        fingerprint: 'ed25519:senderfingerprint7777',
        connectionHints: ['192.168.1.80:8765'],
        securityLevel: 'STRONGBOX',
      );

      await tester.enterText(find.byType(TextField), validInvitation.toJsonString());
      await tester.tap(find.text('Verify & Pair'));
      await tester.pumpAndSettle();

      // 3. Assert Verified Pairing Candidate dialog appears
      expect(find.text('Verify Pairing Candidate'), findsOneWidget);
      expect(find.text('Office ThinkPad'), findsOneWidget);
      expect(find.text('peer-sender-remote-77'), findsOneWidget);
      expect(find.text(validInvitation.sasCode), findsOneWidget);

      // 4. Confirm pairing
      await tester.tap(find.text('Trust & Pair'));
      await tester.pumpAndSettle();

      // Assert device is registered in authoritative DeviceTrustService
      expect(DeviceTrustService.instance.devices.any((d) => d.id == 'peer-sender-remote-77'), isTrue);
      expect(completedPayload, equals(validInvitation.toJsonString()));
    });

    testWidgets('QrPairingSheet: Hotspot Direct generates real Wi-Fi QR code and dynamic credentials',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrPairingSheet(
              deviceName: 'Pixel 9 Hotspot',
              peerId: 'peer-hotspot-555',
              fingerprint: 'ed25519:hotspot555',
              initialTab: 2, // Hotspot tab
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Assert dynamic SSID is generated from actual peer ID (not hardcoded fake SSID)
      expect(find.textContaining('PeerLink-PEER-H'), findsOneWidget);
      expect(find.text('PeerLink-Direct-94A2'), findsNothing);

      // 2. Start hotspot
      await tester.tap(find.text('Start Direct Hotspot (Offline Mode)'));
      await tester.pumpAndSettle();

      // 3. Real Wi-Fi QR code is generated for cameras to join
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('BROADCASTING'), findsOneWidget);
    });
  });
}
