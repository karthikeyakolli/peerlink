import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/features/home/home_screen.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
  });

  testWidgets('HomeScreen UX Simplification: removes fake devices, duplicate tools, and Instant Beam',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Assert NO hardcoded fake devices or fake fingerprints
    expect(find.text('MacBook Pro'), findsNothing);
    expect(find.text('Pixel 9'), findsNothing);
    expect(find.text('Ubuntu Studio'), findsNothing);
    expect(find.text('ed25519:7fa8...91b2'), findsNothing);

    // 2. Assert Instant Beam branding and panel are removed completely
    expect(find.textContaining('Instant Beam'), findsNothing);
    expect(find.text('Quick Share Media'), findsNothing);

    // 3. Assert deferred unverified features are NOT present
    expect(find.text('Burn Beam'), findsNothing);
    expect(find.text('Web Beam'), findsNothing);
    expect(find.text('Hotspot P2P'), findsNothing);
    expect(find.text('Quick Text'), findsNothing);

    // 4. Assert Nearby & Paired Devices displays clear empty state when no peers paired
    expect(find.textContaining('No paired devices', findRichText: true), findsOneWidget);

    // 5. Assert primary bilateral actions and storage modes are present
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('SEND'), findsOneWidget);
    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('SYNC'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
  });

  testWidgets('HomeScreen displays real paired device and does not fabricate transfers',
      (WidgetTester tester) async {
    // Add an authoritative paired device
    DeviceTrustService.instance.pairDevice(
      const PairedDevice(
        id: 'peer-auth-laptop',
        name: 'Office ThinkPad',
        deviceType: 'laptop',
        fingerprint: 'ed25519:auth99881122',
        trustLevel: DeviceTrustLevel.trustedPeer,
        isOnline: true,
        lastSeen: 'Active now',
      ),
    );

    int? navigatedTab;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(onNavigate: (tab) => navigatedTab = tab),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Authoritative device should be visible
    expect(find.text('Office ThinkPad'), findsOneWidget);
    expect(find.text('Send Files'), findsOneWidget);

    // Tap Send Files
    await tester.tap(find.text('Send Files'));
    await tester.pump();

    // Navigates to Files tab (index 2)
    expect(navigatedTab, 2);

    // Must NOT fabricate a transfer
    expect(find.textContaining('Beaming 2 files directly'), findsNothing);
  });
}
