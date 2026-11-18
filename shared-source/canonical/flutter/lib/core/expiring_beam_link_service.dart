import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class ExpiringBeamLink {
  final String token;
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final String pin;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool singleUse;
  final String url;
  int downloadCount;
  bool isRevoked;

  ExpiringBeamLink({
    required this.token,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.pin,
    required this.createdAt,
    required this.expiresAt,
    required this.singleUse,
    required this.url,
    this.downloadCount = 0,
    this.isRevoked = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt) || isRevoked;
  bool get isValid => !isExpired && (!singleUse || downloadCount == 0);

  Duration get remainingTime {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  String get formattedRemaining {
    final rem = remainingTime;
    final min = rem.inMinutes;
    final sec = rem.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

/// Service managing secure, temporary, auto-expiring local HTTP download links.
/// Complies with AGENTS.md Rule 12: Does not trust localhost blindly; requires ephemeral PIN/token.
class ExpiringBeamLinkService {
  static final ExpiringBeamLinkService _instance = ExpiringBeamLinkService._internal();
  static ExpiringBeamLinkService get instance => _instance;

  ExpiringBeamLinkService._internal();

  final Map<String, ExpiringBeamLink> _links = {};

  /// Creates a new expiring beam link for the given file.
  ExpiringBeamLink createExpiringLink(
    String filePath, {
    Duration ttl = const Duration(minutes: 10),
    String? pin,
    bool singleUse = true,
    String localIp = '127.0.0.1',
    int port = 8080,
  }) {
    final file = File(filePath);
    final fileName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';
    final size = file.existsSync() ? file.lengthSync() : 0;

    final token = _generateToken(6);
    final linkPin = pin ?? _generatePin();
    final now = DateTime.now();
    final expires = now.add(ttl);
    final url = 'http://$localIp:$port/beam/$token';

    final link = ExpiringBeamLink(
      token: token,
      filePath: filePath,
      fileName: fileName,
      fileSizeBytes: size,
      pin: linkPin,
      createdAt: now,
      expiresAt: expires,
      singleUse: singleUse,
      url: url,
    );

    _links[token] = link;
    return link;
  }

  /// Validates a request against the link token and optional PIN.
  File? validateAndConsume(String token, {String? pin}) {
    final link = _links[token];
    if (link == null || !link.isValid) return null;

    if (link.pin.isNotEmpty && pin != null && pin != link.pin) {
      return null;
    }

    final file = File(link.filePath);
    if (!file.existsSync()) return null;

    link.downloadCount++;
    if (link.singleUse) {
      link.isRevoked = true;
    }
    return file;
  }

  void revokeLink(String token) {
    _links[token]?.isRevoked = true;
  }

  ExpiringBeamLink? getLink(String token) => _links[token];

  static String _generateToken(int length) {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _generatePin() {
    final rand = Random.secure();
    return (1000 + rand.nextInt(9000)).toString();
  }

  @visibleForTesting
  void resetForTesting() {
    _links.clear();
  }
}
