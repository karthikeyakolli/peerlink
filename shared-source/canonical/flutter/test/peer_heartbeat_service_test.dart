import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/peer_heartbeat_service.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
    PeerHeartbeatService.instance.resetForTesting();
  });

  tearDown(() {
    PeerHeartbeatService.instance.stopHeartbeat();
  });

  group('PeerHeartbeatService Unit Tests (Heartbeat & Auto-Reconnection)', () {
    test('Starts and stops heartbeat daemon', () {
      final service = PeerHeartbeatService.instance;
      expect(service.isRunning, isFalse);

      service.startHeartbeat(interval: const Duration(seconds: 1));
      expect(service.isRunning, isTrue);

      service.stopHeartbeat();
      expect(service.isRunning, isFalse);
    });

    test('Probes reachable peer and marks online in DeviceTrustService', () async {
      final trust = DeviceTrustService.instance;
      final heartbeat = PeerHeartbeatService.instance;

      trust.pairDevice(
        const PairedDevice(
          id: 'peer_home_nas',
          name: 'Home NAS',
          deviceType: 'desktop',
          fingerprint: 'ed25519:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: false,
        ),
      );

      expect(trust.devices.first.isOnline, isFalse);

      // Simulate ping succeeding
      PeerHeartbeatService.testPingHandler = (id) => true;

      final events = await heartbeat.probeAllPeers();

      expect(events.length, equals(1));
      expect(events.first.peerId, equals('peer_home_nas'));
      expect(events.first.isOnline, isTrue);

      // Verified updated in DeviceTrustService
      expect(trust.devices.first.isOnline, isTrue);
      expect(trust.devices.first.lastSeen, contains('Online now'));
    });

    test('Transitions peer to offline after consecutive probe failures', () async {
      final trust = DeviceTrustService.instance;
      final heartbeat = PeerHeartbeatService.instance;

      trust.pairDevice(
        const PairedDevice(
          id: 'peer_tablet',
          name: 'Tablet',
          deviceType: 'tablet',
          fingerprint: 'ed25519:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
          lastSeen: 'Online now',
        ),
      );

      // Simulate probe failure
      PeerHeartbeatService.testPingHandler = (id) => false;

      // First failure: still tolerated
      final firstEvents = await heartbeat.probeAllPeers();
      expect(firstEvents, isEmpty);
      expect(trust.devices.first.isOnline, isTrue);

      // Second consecutive failure: marks offline
      final secondEvents = await heartbeat.probeAllPeers();
      expect(secondEvents.length, equals(1));
      expect(secondEvents.first.isOnline, isFalse);
      expect(trust.devices.first.isOnline, isFalse);
      expect(trust.devices.first.lastSeen, equals('Offline'));
    });
  });
}
