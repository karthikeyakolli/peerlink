import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/features/home/home_screen.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
  });

  testWidgets('HomeScreen UX Simplification: removes fake devices, duplicate tools, and deferred experiments',
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

    // 2. Assert deferred unverified features are NOT present in primary navigation/shelf
    expect(find.text('Burn Beam'), findsNothing);
    expect(find.text('Web Beam'), findsNothing);
    expect(find.text('Hotspot P2P'), findsNothing);

    // 3. Assert no duplicate Quick Text
    expect(find.text('Quick Text'), findsNothing);

    // 4. Assert InstantBeamDeck displays clear empty state when no peers paired
    expect(find.textContaining('No paired devices', findRichText: true), findsOneWidget);

    // 5. Assert primary bilateral actions and storage modes are present
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('SEND'), findsOneWidget);
    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('SYNC'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
  });

  testWidgets('HomeScreen InstantBeam displays real paired device and does not fabricate transfers',
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

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Authoritative device should be visible
    expect(find.text('Office ThinkPad'), findsOneWidget);

    // Tap the peer without files staged
    await tester.tap(find.text('Office ThinkPad'));
    await tester.pump();

    // Must NOT fabricate a transfer
    expect(find.textContaining('Beaming 2 files directly'), findsNothing);
    // Must guide the user to select files via snackbar
    expect(find.textContaining('Select files to beam to Office ThinkPad'), findsOneWidget);
  });
}
