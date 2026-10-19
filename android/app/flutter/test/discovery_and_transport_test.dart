import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/platform/android_node_bridge.dart';
import 'package:peerlink/design_system/components/radar_sonar_view.dart';

void main() {
  group('Phase 4: DiscoveredPeer and Route Data Model', () {
    test('Deserializes rich multi-route DiscoveredPeer from native map', () {
      final rawMap = {
        'peerId': 'peer_desktop_01',
        'name': 'Studio Workstation',
        'host': '192.168.1.120',
        'port': 8765,
        'technology': 'NSD_MDNS, WIFI_DIRECT',
        'technologies': ['NSD_MDNS', 'WIFI_DIRECT'],
        'transports': ['QUIC', 'TCP_TLS'],
        'connectionState': 'AUTHENTICATED_CONNECTED',
        'lastSeenMs': 1718000000000,
        'routes': [
          {
            'host': '192.168.1.120',
            'port': 8765,
            'technology': 'NSD_MDNS',
            'transports': ['QUIC', 'TCP_TLS'],
            'priority': 1,
            'lastSeenMs': 1718000000000,
            'isHealthy': true,
          },
          {
            'host': '192.168.49.1',
            'port': 8765,
            'technology': 'WIFI_DIRECT',
            'transports': ['TCP_TLS'],
            'priority': 2,
            'lastSeenMs': 1718000000000,
            'isHealthy': true,
          },
        ],
      };

      final peer = DiscoveredPeer.fromMap(rawMap);

      expect(peer.peerId, equals('peer_desktop_01'));
      expect(peer.name, equals('Studio Workstation'));
      expect(peer.host, equals('192.168.1.120'));
      expect(peer.port, equals(8765));
      expect(peer.technologies, containsAll(['NSD_MDNS', 'WIFI_DIRECT']));
      expect(peer.transports, containsAll(['QUIC', 'TCP_TLS']));
      expect(peer.isConnected, isTrue);
      expect(peer.routes.length, equals(2));
      expect(peer.routes[0].priority, equals(1));
      expect(peer.routes[1].priority, equals(2));
      expect(peer.routes[1].technology, equals('WIFI_DIRECT'));
    });

    test('DiscoveredPeer defaults to unauthenticated DISCOVERED state', () {
      final rawMap = {
        'peerId': 'peer_unauth_02',
        'name': 'Nearby Phone',
        'host': '192.168.1.150',
        'port': 8765,
        'technology': 'NSD_MDNS',
      };

      final peer = DiscoveredPeer.fromMap(rawMap);

      expect(peer.connectionState, equals('DISCOVERED'));
      expect(peer.isConnected, isFalse);
    });
  });

  group('Phase 4: RadarSonarView Discovery & Fallback Route UX', () {
    testWidgets('Renders discovered peers with count and device names', (tester) async {
      final peers = [
        const RadarPeerInfo(
          id: 'peer-1',
          name: 'MacBook Pro',
          deviceType: 'laptop',
          isTrusted: true,
          ip: '192.168.1.10',
          technology: 'NSD_MDNS',
        ),
        const RadarPeerInfo(
          id: 'peer-2',
          name: 'Pixel 9 Phone',
          deviceType: 'phone',
          isTrusted: false,
          ip: '192.168.49.2',
          technology: 'WIFI_DIRECT',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: RadarSonarView(
                discoveredPeers: peers,
                onPeerSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2 device(s) found'), findsOneWidget);
    });

    testWidgets('Opens manual IP fallback dialog and triggers callback', (tester) async {
      String? submittedIp;
      int? submittedPort;
      String? submittedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: RadarSonarView(
                discoveredPeers: const [],
                onPeerSelected: (_) {},
                onAddManualEndpoint: (ip, port, name) {
                  submittedIp = ip;
                  submittedPort = port;
                  submittedName = name;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Searching nearby...'), findsOneWidget);
      expect(find.text('Add IP'), findsOneWidget);

      // Tap 'Add IP' button
      await tester.tap(find.text('Add IP'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add Manual Endpoint'), findsOneWidget);

      // Enter IP address
      await tester.enterText(
        find.widgetWithText(TextField, 'Remote IP Address'),
        '10.0.0.55',
      );

      // Enter optional name
      await tester.enterText(
        find.widgetWithText(TextField, 'Device Name (Optional)'),
        'Lab Workstation',
      );

      // Submit
      await tester.tap(find.text('Add Route'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(submittedIp, equals('10.0.0.55'));
      expect(submittedPort, equals(8765));
      expect(submittedName, equals('Lab Workstation'));
    });
  });
}
