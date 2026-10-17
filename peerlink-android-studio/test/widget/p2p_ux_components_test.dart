import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/components/send_receive_hero.dart';
import 'package:peerlink/design_system/components/media_category_bar.dart';
import 'package:peerlink/design_system/components/radar_sonar_view.dart';
import 'package:peerlink/design_system/components/transfer_speedometer.dart';
import 'package:peerlink/design_system/components/glass_container.dart';
import 'package:peerlink/design_system/components/instant_beam_deck.dart';
import 'package:peerlink/design_system/components/interactive_glass_card.dart';
import 'package:peerlink/features/search/search_screen.dart';
import 'package:peerlink/features/settings/settings_screen.dart';

void main() {
  group('P2P Sharing UX Components (SHAREit / AirDrop Reverse-Engineered)', () {
    testWidgets('SendReceiveHero triggers onSend and onReceive callbacks',
        (tester) async {
      bool sendTapped = false;
      bool receiveTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SendReceiveHero(
              onSendPressed: () => sendTapped = true,
              onReceivePressed: () => receiveTapped = true,
              discoveredPeersCount: 3,
            ),
          ),
        ),
      );

      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
      expect(find.text('3 nearby'), findsOneWidget);

      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(sendTapped, isTrue);

      await tester.tap(find.text('Receive'));
      await tester.pump();
      expect(receiveTapped, isTrue);
    });

    testWidgets('MediaCategoryBar renders all 6 media categories and handles taps',
        (tester) async {
      MediaCategoryType? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaCategoryBar(
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);

      await tester.tap(find.text('Photos'));
      await tester.pump();
      expect(selected, MediaCategoryType.photos);
    });

    testWidgets('RadarSonarView renders central node and orbiting peers',
        (tester) async {
      RadarPeerInfo? chosenPeer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: RadarSonarView(
                localDeviceName: 'Pixel 9',
                discoveredPeers: const [
                  RadarPeerInfo(
                    id: 'p1',
                    name: 'MacBook Pro',
                    deviceType: 'laptop',
                    isTrusted: true,
                  ),
                ],
                onPeerSelected: (peer) => chosenPeer = peer,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pixel 9'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);

      await tester.tap(find.text('MacBook Pro'));
      await tester.pump();
      expect(chosenPeer?.id, 'p1');
    });

    testWidgets('TransferSpeedometer displays speed, ETA, and dual progress',
        (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferSpeedometer(
              fileName: 'large_presentation.mp4',
              currentItemIndex: 2,
              totalItems: 4,
              currentFileProgress: 0.5,
              totalBatchProgress: 0.75,
              speedMbps: 54.2,
              etaSeconds: 12,
              peerName: 'Desktop PC',
              isSender: true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('54.2'), findsOneWidget);
      expect(find.text('MB/s'), findsOneWidget);
      expect(find.text('large_presentation.mp4'), findsOneWidget);
      expect(find.text('2 of 4'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('12s remaining'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(cancelled, isTrue);
    });

    testWidgets('GlassContainer renders child with frosted backdrop styling',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              glowColor: Color(0xFF2563EB),
              child: Text('Frosted Content'),
            ),
          ),
        ),
      );

      expect(find.text('Frosted Content'), findsOneWidget);
    });

    testWidgets('InstantBeamDeck renders 1-tap devices and triggers tap callback',
        (tester) async {
      BeamPeerItem? tappedPeer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstantBeamDeck(
              nearbyPeers: const [
                BeamPeerItem(
                  peerId: 'peer-test-1',
                  name: 'MacBook Pro',
                  deviceType: 'laptop',
                  fingerprint: 'ed25519:7fa8...91b2',
                  isPaired: true,
                ),
              ],
              onPeerTap: (p) => tappedPeer = p,
            ),
          ),
        ),
      );

      expect(find.text('Instant Beam'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('1-TAP SHARE'), findsOneWidget);

      await tester.tap(find.text('MacBook Pro'));
      await tester.pump();
      expect(tappedPeer?.name, 'MacBook Pro');
    });

    testWidgets('InteractiveGlassCard triggers onTap and renders child correctly',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveGlassCard(
              glowColor: const Color(0xFF8B5CF6),
              onTap: () => tapped = true,
              child: const Text('Interactive Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Card Content'), findsOneWidget);
      await tester.tap(find.text('Interactive Card Content'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('SearchScreen filters items on user text query',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SearchScreen(),
          ),
        ),
      );

      expect(find.text('Cross-Device Omni-Search'), findsOneWidget);
      expect(find.text('PeerLink_Architecture_Spec.pdf'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Financial');
      await tester.pump();

      expect(find.text('Q3_Financial_Summary.xlsx'), findsOneWidget);
      expect(find.text('PeerLink_Architecture_Spec.pdf'), findsNothing);
    });

    testWidgets('SettingsScreen renders Zero-Trust Invariant Enforcement header',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('Settings & Zero-Trust Safety'), findsOneWidget);
      expect(find.text('Zero-Trust Invariant Enforcement'), findsOneWidget);
      expect(find.text('Trust & Devices'), findsOneWidget);
      expect(find.text('Safety & Antimalware'), findsOneWidget);
    });
  });
}
