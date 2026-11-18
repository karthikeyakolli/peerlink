import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/error_message_simplifier.dart';

void main() {
  group('ErrorMessageSimplifier Tests', () {
    test('Translates Screenshot 1 Unauthorized Handshake Rejection cleanly', () {
      const raw =
          'Transfer tx_92a689104ba14e929b8464995ce18914 failed: java.io.IOException: Handshake rejected by remote peer: Handshake rejected [ERROR_CODE_UNAUTHORIZED] (ID: tx_92a689104ba14e929b8464995ce18914)';

      final simplified = ErrorMessageSimplifier.simplify(raw, transferId: 'tx_92a689104ba14e929b8464995ce18914');

      expect(simplified.title, equals('Device Not Paired'));
      expect(
        simplified.oneLineMessage,
        equals('The remote device has not paired with you yet.'),
      );
      expect(
        simplified.suggestedAction,
        contains('Pair both devices first by scanning the QR code'),
      );
      expect(simplified.canPair, isTrue);
      expect(simplified.isRetryable, isFalse);
      expect(simplified.icon, equals(Icons.phonelink_lock_rounded));
      expect(simplified.technicalDetails, contains('ERROR_CODE_UNAUTHORIZED'));
    });

    test('Translates Screenshot 2 Target Peer JSON Route lookup failure cleanly', () {
      const raw =
          'Target peer {"v":1,"peerId":"peer_desktop_primary","name":"Android Peer","fingerprint":"ed25519:00a48e0da5ed3997...bb27ae00","sessionId":"b50b6d81d2a9744dde4cf68b2d2f514e","nonce":"1383e9556a7c927f323507b9e37054bb","expiry":1794734499008,"hints":["192.168.1.100"],"sec":"STRONGBOX"} has no reachable discovered routes or active sessions';

      final simplified = ErrorMessageSimplifier.simplify(raw);

      // Either Invalid Peer Token or Device Unreachable (both are clean)
      expect(
        simplified.title,
        anyOf(equals('Invalid Peer Token'), equals('Device Unreachable')),
      );
      expect(
        simplified.oneLineMessage,
        anyOf(
          equals('Unrecognized pairing token format.'),
          equals('Cannot reach the other device over your local Wi-Fi.'),
        ),
      );
      expect(simplified.canPair, isTrue);
    });

    test('Translates Connection Refused cleanly', () {
      const raw = 'java.net.ConnectException: Connection refused (ECONNREFUSED)';
      final simplified = ErrorMessageSimplifier.simplify(raw);

      expect(simplified.title, equals('PeerLink Not Open'));
      expect(
        simplified.oneLineMessage,
        equals('PeerLink is not open or running on the other device.'),
      );
      expect(simplified.isRetryable, isTrue);
    });

    test('Translates Timeout cleanly', () {
      const raw = 'java.net.SocketTimeoutException: Connect timed out';
      final simplified = ErrorMessageSimplifier.simplify(raw);

      expect(simplified.title, equals('Connection Timed Out'));
      expect(
        simplified.oneLineMessage,
        equals('The remote device took too long to respond.'),
      );
      expect(simplified.isRetryable, isTrue);
    });

    test('Translates Declined transfer cleanly', () {
      const raw = 'Transfer was declined by user';
      final simplified = ErrorMessageSimplifier.simplify(raw);

      expect(simplified.title, equals('Transfer Declined'));
      expect(
        simplified.oneLineMessage,
        equals('The transfer was declined on the receiving device.'),
      );
      expect(simplified.isRetryable, isTrue);
    });

    test('Translates Storage full cleanly', () {
      const raw = 'java.io.IOException: ENOSPC: no space left on device';
      final simplified = ErrorMessageSimplifier.simplify(raw);

      expect(simplified.title, equals('Insufficient Storage'));
      expect(
        simplified.oneLineMessage,
        equals('Not enough free storage space on the destination device.'),
      );
      expect(simplified.isRetryable, isTrue);
    });

    test('Translates Quarantine safety cleanly', () {
      const raw = 'SECURITY_VERDICT_QUARANTINED: malware detected in archive';
      final simplified = ErrorMessageSimplifier.simplify(raw);

      expect(simplified.title, equals('Blocked for Safety'));
      expect(
        simplified.oneLineMessage,
        equals('Transfer blocked because the file failed safety scanning.'),
      );
      expect(simplified.isRetryable, isFalse);
    });
  });
}
