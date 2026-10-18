import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/features/devices/devices_screen.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
  });

  testWidgets('DevicesScreen: eliminates fake devices, synthetic latency, and fake fingerprints',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DevicesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Assert NO hardcoded fake devices
    expect(find.text('MacBook Pro 16" (Work)'), findsNothing);
    expect(find.text('Pixel 8 Pro (Personal)'), findsNothing);
    expect(find.text('Bob (Guest Project Share)'), findsNothing);

    // 2. Assert NO synthetic latency or fake fingerprints
    expect(find.text('1.8 ms'), findsNothing);
    expect(find.text('SHA256:7b9a4f2e1c8d0e3a5f6b9c8d7e6f5a4b'), findsNothing);
    expect(find.text('SHA256:9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c'), findsNothing);

    // 3. Shows empty state when no devices paired
    expect(find.textContaining('No paired devices', findRichText: true), findsOneWidget);
  });

  testWidgets('DevicesScreen: pairing persists device and revocation removes device authoritatively',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DevicesScreen(),
      ),
    );
    await tester.pump();

    // Open Pair Device Dialog
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();

    // Enter device ID and name
    await tester.enterText(find.byType(TextField).first, 'peer_backup_box');
    await tester.enterText(find.byType(TextField).last, 'Home NAS Storage');
    await tester.pump();

    // Tap Verify & Trust
    await tester.tap(find.text('Verify & Trust'));
    await tester.pumpAndSettle();

    // Assert device is stored in DeviceTrustService
    expect(DeviceTrustService.instance.devices.length, 1);
    expect(DeviceTrustService.instance.devices.first.name, 'Home NAS Storage');
    expect(find.text('Home NAS Storage'), findsOneWidget);

    // Tap Revoke Trust
    await tester.tap(find.text('Revoke Trust'));
    await tester.pumpAndSettle();

    // Confirm revocation in dialog
    expect(find.text('Revoke Device Trust?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke Trust'));
    await tester.pumpAndSettle();

    // Assert device is removed from DeviceTrustService
    expect(DeviceTrustService.instance.devices.isEmpty, isTrue);
    expect(find.text('Home NAS Storage'), findsNothing);
  });

  testWidgets('DevicesScreen: Access/Browse enforces connectivity and scoped capabilities',
      (WidgetTester tester) async {
    // Add an offline device
    DeviceTrustService.instance.pairDevice(
      const PairedDevice(
        id: 'peer-offline-phone',
        name: 'Offline Tablet',
        deviceType: 'Tablet',
        fingerprint: 'ed25519:tablet112233',
        trustLevel: DeviceTrustLevel.trustedPeer,
        isOnline: false,
        lastSeen: 'Offline (2 hours ago)',
        scopedCapabilities: ['READ'],
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: DevicesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Offline Tablet'), findsOneWidget);

    // Tap Access / Browse
    await tester.tap(find.text('Access / Browse'));
    await tester.pumpAndSettle();

    // Must clearly state that peer is offline
    expect(find.textContaining('Device is currently offline', findRichText: true), findsOneWidget);
  });
}
