import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/hotspot_tether_qr_service.dart';
import 'package:peerlink/core/network_diagnostic_service.dart';

void main() {
  group('HotspotTetherQrService Tests', () {
    test('creates and parses valid hotspot tether URI payload', () {
      final payload = HotspotTetherQrService.instance.createPayload(
        ssid: 'PeerLink-Direct-99',
        passphrase: 'secure_secret_pass',
        ipAddress: '192.168.49.1',
        port: 53317,
        nodeId: 'node_alpha_123',
        publicKey: 'pubkey_hex_456',
      );

      final uriString = payload.toUriString();
      expect(uriString, startsWith('peerlink-tether://connect?'));
      expect(uriString, contains('ssid=PeerLink-Direct-99'));

      final parsed = HotspotTetherPayload.fromUriString(uriString);
      expect(parsed, isNotNull);
      expect(parsed!.ssid, 'PeerLink-Direct-99');
      expect(parsed.passphrase, 'secure_secret_pass');
      expect(parsed.ipAddress, '192.168.49.1');
      expect(parsed.port, 53317);
      expect(parsed.nodeId, 'node_alpha_123');
      expect(parsed.publicKey, 'pubkey_hex_456');
    });

    test('fromUriString returns null on invalid or non-tether URI', () {
      expect(HotspotTetherPayload.fromUriString('https://google.com'), isNull);
      expect(HotspotTetherPayload.fromUriString('peerlink-tether://connect?invalid=1'), isNull);
    });
  });

  group('NetworkDiagnosticService Tests', () {
    test('diagnose returns valid diagnostic report without throwing', () async {
      final diag = await NetworkDiagnosticService.instance.diagnose();

      expect(diag.interfaceName, isNotEmpty);
      expect(diag.ipAddress, isNotEmpty);
      expect(diag.frequencyBand, isNotEmpty);
      expect(diag.estimatedSpeedMbps, greaterThan(0));
      expect(diag.recommendation, isNotEmpty);
    });
  });
}
