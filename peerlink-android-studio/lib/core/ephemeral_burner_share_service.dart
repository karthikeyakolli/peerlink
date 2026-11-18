import 'dart:io';
import 'dart:math';

class BurnerToken {
  final String id;
  final String originalPath;
  final String fileName;
  final int sizeBytes;
  final String? pin;
  final DateTime expiresAt;
  int viewCount;
  final int maxViews;
  bool isRevoked;

  BurnerToken({
    required this.id,
    required this.originalPath,
    required this.fileName,
    required this.sizeBytes,
    this.pin,
    required this.expiresAt,
    this.viewCount = 0,
    this.maxViews = 1,
    this.isRevoked = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt) || isRevoked || viewCount >= maxViews;
}

class BurnerAccessResult {
  final bool isAuthorized;
  final String? errorMessage;
  final List<int>? fileBytes;
  final String? fileName;

  const BurnerAccessResult({
    required this.isAuthorized,
    this.errorMessage,
    this.fileBytes,
    this.fileName,
  });
}

class EphemeralBurnerShareService {
  static final EphemeralBurnerShareService instance = EphemeralBurnerShareService._internal();
  EphemeralBurnerShareService._internal();

  final Map<String, BurnerToken> _tokens = {};

  BurnerToken createBurnerShare({
    required String filePath,
    String? pin,
    Duration validDuration = const Duration(minutes: 5),
    int maxViews = 1,
  }) {
    final file = File(filePath);
    final size = file.existsSync() ? file.lengthSync() : 0;
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'document')
        : 'document';

    final id = 'burner_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final token = BurnerToken(
      id: id,
      originalPath: filePath,
      fileName: name,
      sizeBytes: size,
      pin: pin?.trim().isNotEmpty == true ? pin!.trim() : null,
      expiresAt: DateTime.now().add(validDuration),
      maxViews: maxViews,
    );

    _tokens[id] = token;
    return token;
  }

  BurnerAccessResult accessBurnerShare(String tokenId, {String? pin}) {
    final token = _tokens[tokenId];
    if (token == null) {
      return const BurnerAccessResult(isAuthorized: false, errorMessage: 'Burner link not found.');
    }

    if (token.isExpired) {
      _tokens.remove(tokenId);
      return const BurnerAccessResult(
        isAuthorized: false,
        errorMessage: 'This file has already self-destructed or expired.',
      );
    }

    if (token.pin != null && token.pin != pin?.trim()) {
      return const BurnerAccessResult(
        isAuthorized: false,
        errorMessage: 'Incorrect 4-digit security PIN.',
      );
    }

    final file = File(token.originalPath);
    if (!file.existsSync()) {
      return const BurnerAccessResult(isAuthorized: false, errorMessage: 'Source file is no longer available.');
    }

    final bytes = file.readAsBytesSync();
    token.viewCount++;

    return BurnerAccessResult(
      isAuthorized: true,
      fileBytes: bytes,
      fileName: token.fileName,
    );
  }

  void revokeBurnerShare(String tokenId) {
    final token = _tokens.remove(tokenId);
    token?.isRevoked = true;
  }
}
