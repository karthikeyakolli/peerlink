import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/design_system/components/quick_drop_peer_carousel.dart';

void main() {
  group('QuickDropPeerCarousel Widget Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('quick_drop_test_');
      FileStagingService.instance.clear();
    });

    tearDown(() {
      FileStagingService.instance.clear();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders empty scanner card and triggers QR pair callback', (tester) async {
      bool qrTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickDropPeerCarousel(
              overridePeers: const [],
              onPairQrPressed: () => qrTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nearby Quick-Drop'), findsOneWidget);
      expect(find.text('Scanning nearby Wi-Fi...'), findsOneWidget);
      expect(find.byKey(const Key('quick_drop_pair_qr_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_drop_pair_qr_button')));
      await tester.pumpAndSettle();

      expect(qrTapped, isTrue);
    });

    testWidgets('renders horizontal peer cards with device icons and status', (tester) async {
      final peers = [
        const QuickDropPeerItem(
          id: 'peer_phone_1',
          name: 'Pixel 8 Pro',
          deviceType: 'phone',
          isTrusted: true,
          isOnline: true,
        ),
        const QuickDropPeerItem(
          id: 'peer_laptop_1',
          name: 'OMEN Laptop',
          deviceType: 'laptop',
          isTrusted: false,
          isOnline: true,
        ),
      ];

      QuickDropPeerItem? tappedPeer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickDropPeerCarousel(
              overridePeers: peers,
              onPeerTapped: (p) => tappedPeer = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nearby Quick-Drop'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Pixel 8 Pro'), findsOneWidget);
      expect(find.text('OMEN Laptop'), findsOneWidget);
      expect(find.text('Trusted'), findsOneWidget);
      expect(find.text('Beam'), findsOneWidget);

      // Tap first peer
      await tester.tap(find.text('Pixel 8 Pro'));
      await tester.pumpAndSettle();

      expect(tappedPeer?.id, equals('peer_phone_1'));
    });

    testWidgets('updates action badge to "Drop (N)" when files are staged', (tester) async {
      final testFile = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
      FileStagingService.instance.addPaths([testFile.path]);

      final peers = [
        const QuickDropPeerItem(
          id: 'peer_phone_1',
          name: 'Pixel 8 Pro',
          deviceType: 'phone',
          isTrusted: true,
          isOnline: true,
        ),
      ];

      QuickDropPeerItem? droppedPeer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickDropPeerCarousel(
              overridePeers: peers,
              onQuickDrop: (p) => droppedPeer = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drop (1)'), findsOneWidget);

      // Tap to drop
      await tester.tap(find.text('Pixel 8 Pro'));
      await tester.pumpAndSettle();

      expect(droppedPeer?.id, equals('peer_phone_1'));
    });
  });
}
