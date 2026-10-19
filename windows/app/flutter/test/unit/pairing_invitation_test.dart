import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/pairing_invitation.dart';

void main() {
  setUp(() {
    PairingInvitation.resetReplayCacheForTesting();
  });

  group('PairingInvitation Cryptographic Schema & Security Tests', () {
    test('PairingInvitation.create produces fresh nonces, future expiry, and valid SAS code', () {
      final inv1 = PairingInvitation.create(
        peerId: 'peer-device-alpha',
        name: 'Pixel 9 Pro',
        fingerprint: 'ed25519:abcdef1234567890abcdef1234567890',
        connectionHints: ['192.168.1.50:8765'],
        securityLevel: 'STRONGBOX',
      );

      final inv2 = PairingInvitation.create(
        peerId: 'peer-device-alpha',
        name: 'Pixel 9 Pro',
        fingerprint: 'ed25519:abcdef1234567890abcdef1234567890',
        connectionHints: ['192.168.1.50:8765'],
        securityLevel: 'STRONGBOX',
      );

      // Distinct session IDs and nonces for freshness
      expect(inv1.sessionId, isNot(equals(inv2.sessionId)));
      expect(inv1.nonce, isNot(equals(inv2.nonce)));

      // Future expiry
      expect(inv1.isExpired, isFalse);
      expect(inv1.remainingTime.inSeconds, greaterThan(250));

      // 4-digit SAS verification code
      expect(inv1.sasCode.length, equals(4));
      expect(int.tryParse(inv1.sasCode), isNotNull);
    });

    test('Serialization and deserialization roundtrip preserves all fields', () {
      final original = PairingInvitation.create(
        peerId: 'peer-laptop-beta',
        name: 'ThinkPad X1',
        fingerprint: 'ed25519:99887766554433221100aabbccddeeff',
        connectionHints: ['10.0.0.12:8765', '192.168.49.1:8765'],
        securityLevel: 'TEE',
      );

      final jsonStr = original.toJsonString();
      final parsed = PairingInvitation.parse(jsonStr);

      expect(parsed.version, equals(1));
      expect(parsed.peerId, equals(original.peerId));
      expect(parsed.name, equals(original.name));
      expect(parsed.fingerprint, equals(original.fingerprint));
      expect(parsed.sessionId, equals(original.sessionId));
      expect(parsed.nonce, equals(original.nonce));
      expect(parsed.expiry, equals(original.expiry));
      expect(parsed.connectionHints, equals(original.connectionHints));
      expect(parsed.securityLevel, equals(original.securityLevel));
      expect(parsed.sasCode, equals(original.sasCode));
    });

    test('Rejects malformed JSON and missing fields safely', () {
      expect(() => PairingInvitation.parse('not-json'),
          throwsA(isA<InvalidInvitationException>()));

      expect(() => PairingInvitation.parse(jsonEncode({'v': 1, 'peerId': 'test'})),
          throwsA(isA<InvalidInvitationException>()));

      expect(() => PairingInvitation.parse(jsonEncode({
        'v': 99, // unsupported version
        'peerId': 'test',
        'name': 'Test',
        'fingerprint': 'fp',
        'sessionId': 's1',
        'nonce': 'n1',
        'expiry': DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      })), throwsA(isA<InvalidInvitationException>()));
    });

    test('Rejects expired invitations', () {
      final expiredJson = jsonEncode({
        'v': 1,
        'peerId': 'peer-expired',
        'name': 'Old Device',
        'fingerprint': 'ed25519:deadbeef',
        'sessionId': 'session-old-123',
        'nonce': 'nonce-old-123',
        'expiry': DateTime.now().subtract(const Duration(seconds: 10)).millisecondsSinceEpoch,
        'hints': [],
        'sec': 'SOFTWARE',
      });

      expect(() => PairingInvitation.parse(expiredJson),
          throwsA(isA<InvitationExpiredException>()));
    });

    test('Anti-replay protection rejects consumed invitations', () {
      final inv = PairingInvitation.create(
        peerId: 'peer-replay',
        name: 'Device A',
        fingerprint: 'ed25519:1234',
      );
      final jsonStr = inv.toJsonString();

      // First parse succeeds
      final parsed1 = PairingInvitation.parse(jsonStr);
      expect(parsed1.peerId, equals('peer-replay'));

      // Mark consumed
      parsed1.markConsumed();

      // Second parse of same session throws ReplayDetectedException
      expect(() => PairingInvitation.parse(jsonStr),
          throwsA(isA<ReplayDetectedException>()));
    });

    test('Supports legacy peerlink:// URI with backwards-compatible fallback', () {
      const uriStr = 'peerlink://connect?peer=peer-legacy-99&name=Office+PC&fp=ed25519:legacy99';
      final inv = PairingInvitation.parse(uriStr);

      expect(inv.peerId, equals('peer-legacy-99'));
      expect(inv.name, equals('Office PC'));
      expect(inv.fingerprint, equals('ed25519:legacy99'));
      expect(inv.isExpired, isFalse);
    });
  });
}
