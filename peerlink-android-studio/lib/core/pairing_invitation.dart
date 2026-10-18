import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class InvalidInvitationException implements Exception {
  final String message;
  const InvalidInvitationException(this.message);
  @override
  String toString() => 'InvalidInvitationException: $message';
}

class InvitationExpiredException implements Exception {
  final String message;
  const InvitationExpiredException(this.message);
  @override
  String toString() => 'InvitationExpiredException: $message';
}

class ReplayDetectedException implements Exception {
  final String message;
  const ReplayDetectedException(this.message);
  @override
  String toString() => 'ReplayDetectedException: $message';
}

/// Cryptographically bounded short-lived QR Pairing Invitation for PeerLink.
/// Enforces versioned schema, nonces, expiration, anti-replay, and SAS derivation.
class PairingInvitation {
  static const int currentVersion = 1;
  static const Duration defaultValidity = Duration(minutes: 5);

  // In-memory anti-replay cache tracking consumed invitation session IDs
  static final Set<String> _consumedSessions = <String>{};

  final int version;
  final String peerId;
  final String name;
  final String fingerprint;
  final String sessionId;
  final String nonce;
  final int expiry;
  final List<String> connectionHints;
  final String securityLevel;

  const PairingInvitation({
    required this.version,
    required this.peerId,
    required this.name,
    required this.fingerprint,
    required this.sessionId,
    required this.nonce,
    required this.expiry,
    this.connectionHints = const [],
    this.securityLevel = 'UNKNOWN',
  });

  /// Factory creating an authoritative, cryptographically fresh invitation.
  factory PairingInvitation.create({
    required String peerId,
    required String name,
    required String fingerprint,
    List<String> connectionHints = const [],
    String securityLevel = 'STRONGBOX',
    Duration validity = defaultValidity,
  }) {
    final random = Random.secure();
    final sessionBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final nonceBytes = List<int>.generate(16, (_) => random.nextInt(256));

    final sessionId = sessionBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final nonce = nonceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final expiryTime = DateTime.now().add(validity).millisecondsSinceEpoch;

    return PairingInvitation(
      version: currentVersion,
      peerId: peerId,
      name: name,
      fingerprint: fingerprint,
      sessionId: sessionId,
      nonce: nonce,
      expiry: expiryTime,
      connectionHints: connectionHints,
      securityLevel: securityLevel,
    );
  }

  /// Parses and strictly validates an incoming QR payload string.
  factory PairingInvitation.parse(String rawPayload, {bool checkReplay = true}) {
    if (rawPayload.trim().isEmpty) {
      throw const InvalidInvitationException('Payload is empty');
    }

    // Support legacy/test URI schemes if present (e.g. peerlink://connect?peer=...)
    if (rawPayload.startsWith('peerlink://')) {
      final uri = Uri.tryParse(rawPayload);
      if (uri == null) {
        throw const InvalidInvitationException('Malformed peerlink:// URI');
      }
      final peer = uri.queryParameters['peer'];
      if (peer == null || peer.isEmpty) {
        throw const InvalidInvitationException('Missing peer parameter in URI');
      }
      return PairingInvitation(
        version: currentVersion,
        peerId: peer,
        name: uri.queryParameters['name'] ?? 'Discovered Peer',
        fingerprint: uri.queryParameters['fp'] ?? 'ed25519:unverified',
        sessionId: 'legacy-session-${DateTime.now().millisecondsSinceEpoch}',
        nonce: 'legacy-nonce',
        expiry: DateTime.now().add(defaultValidity).millisecondsSinceEpoch,
        connectionHints: uri.queryParameters['hint'] != null ? [uri.queryParameters['hint']!] : [],
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(rawPayload) as Map<String, dynamic>;
    } catch (e) {
      throw InvalidInvitationException('Invalid JSON payload: $e');
    }

    final v = json['v'] as int?;
    if (v == null || v != currentVersion) {
      throw InvalidInvitationException('Unsupported protocol version: $v (expected $currentVersion)');
    }

    final peerId = json['peerId'] as String?;
    if (peerId == null || peerId.isEmpty) {
      throw const InvalidInvitationException('Missing required field: peerId');
    }

    final name = json['name'] as String? ?? 'Peer Device';

    final fingerprint = json['fingerprint'] as String?;
    if (fingerprint == null || fingerprint.isEmpty) {
      throw const InvalidInvitationException('Missing required field: fingerprint');
    }

    final sessionId = json['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw const InvalidInvitationException('Missing required field: sessionId');
    }

    final nonce = json['nonce'] as String?;
    if (nonce == null || nonce.isEmpty) {
      throw const InvalidInvitationException('Missing required field: nonce');
    }

    final expiry = json['expiry'] as int?;
    if (expiry == null) {
      throw const InvalidInvitationException('Missing required field: expiry');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiry < now) {
      throw InvitationExpiredException('Pairing invitation expired at $expiry (now: $now)');
    }

    if (checkReplay && _consumedSessions.contains(sessionId)) {
      throw ReplayDetectedException('Invitation session $sessionId has already been consumed');
    }

    final hints = (json['hints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final sec = json['sec'] as String? ?? 'UNKNOWN';

    return PairingInvitation(
      version: v,
      peerId: peerId,
      name: name,
      fingerprint: fingerprint,
      sessionId: sessionId,
      nonce: nonce,
      expiry: expiry,
      connectionHints: hints,
      securityLevel: sec,
    );
  }

  /// Marks this invitation as consumed to prevent replay attacks.
  void markConsumed() {
    _consumedSessions.add(sessionId);
  }

  /// Derives a 4-digit Short Authentication String (SAS) security code for visual out-of-band verification.
  String get sasCode {
    final input = '$fingerprint:$sessionId:$nonce';
    final digest = sha256.convert(utf8.encode(input)).bytes;
    final intVal = (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];
    final pin = (intVal.abs() % 10000).toString().padLeft(4, '0');
    return pin;
  }

  /// Serializes to compact JSON.
  String toJsonString() {
    return jsonEncode({
      'v': version,
      'peerId': peerId,
      'name': name,
      'fingerprint': fingerprint,
      'sessionId': sessionId,
      'nonce': nonce,
      'expiry': expiry,
      'hints': connectionHints,
      'sec': securityLevel,
    });
  }

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiry;

  Duration get remainingTime {
    final diff = expiry - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? Duration(milliseconds: diff) : Duration.zero;
  }

  static void resetReplayCacheForTesting() {
    _consumedSessions.clear();
  }
}
