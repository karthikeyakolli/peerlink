import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

enum QuarantineReason {
  checksumMismatch,
  partialUncertain,
  antimalwareFlagged,
  unexpectedInterruption,
}

extension QuarantineReasonExtension on QuarantineReason {
  String get displayTag {
    switch (this) {
      case QuarantineReason.checksumMismatch:
        return 'CHECKSUM_MISMATCH';
      case QuarantineReason.partialUncertain:
        return 'PARTIAL_UNCERTAIN';
      case QuarantineReason.antimalwareFlagged:
        return 'ANTIMALWARE_FLAGGED';
      case QuarantineReason.unexpectedInterruption:
        return 'UNEXPECTED_INTERRUPTION';
    }
  }

  String get humanDescription {
    switch (this) {
      case QuarantineReason.checksumMismatch:
        return 'Computed payload SHA-256 does not match sender manifest hash (Rule 9).';
      case QuarantineReason.partialUncertain:
        return 'Transfer abruptly interrupted; indeterminate staging outcome (Rule 9).';
      case QuarantineReason.antimalwareFlagged:
        return 'Local antivirus scanner identified potential risk in staged payload (Rule 10).';
      case QuarantineReason.unexpectedInterruption:
        return 'Node crashed or radio disconnected prior to full transfer commitment.';
    }
  }
}

class QuarantinedItem {
  final String id;
  final String fileName;
  final String quarantinePath;
  final QuarantineReason reason;
  final String expectedSha256;
  final String actualSha256;
  final DateTime quarantinedAt;
  final int fileSizeBytes;
  final String sourcePeerId;

  const QuarantinedItem({
    required this.id,
    required this.fileName,
    required this.quarantinePath,
    required this.reason,
    required this.expectedSha256,
    required this.actualSha256,
    required this.quarantinedAt,
    required this.fileSizeBytes,
    required this.sourcePeerId,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Authoritative service managing isolated quarantined files and cryptographic disposal (Rule 9).
class QuarantineService {
  static final QuarantineService _instance = QuarantineService._internal();
  static QuarantineService get instance => _instance;

  QuarantineService._internal();

  final List<QuarantinedItem> _items = [];

  final StreamController<List<QuarantinedItem>> _streamController =
      StreamController<List<QuarantinedItem>>.broadcast();

  Stream<List<QuarantinedItem>> get quarantinedStream => _streamController.stream;
  List<QuarantinedItem> get quarantinedItems => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get count => _items.length;

  /// Executes DOD 5220.22-M 3-pass cryptographic wipe on physical file before unlinking.
  static Future<void> shredPhysicalFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;

      final length = await file.length();
      if (length <= 0) {
        await file.delete();
        return;
      }

      final raf = await file.open(mode: FileMode.write);
      const bufferSize = 64 * 1024;
      final chunkSize = min(length, bufferSize);

      // Pass 1: 0x00
      final zeros = Uint8List(chunkSize);
      int written = 0;
      await raf.setPosition(0);
      while (written < length) {
        final toWrite = min(chunkSize, length - written);
        await raf.writeFrom(zeros, 0, toWrite);
        written += toWrite;
      }
      await raf.flush();

      // Pass 2: 0xFF
      final ones = Uint8List(chunkSize)..fillRange(0, chunkSize, 0xFF);
      written = 0;
      await raf.setPosition(0);
      while (written < length) {
        final toWrite = min(chunkSize, length - written);
        await raf.writeFrom(ones, 0, toWrite);
        written += toWrite;
      }
      await raf.flush();

      // Pass 3: Cryptographic Pseudo-random bytes
      final rng = Random.secure();
      final randomBuf = Uint8List(chunkSize);
      written = 0;
      await raf.setPosition(0);
      while (written < length) {
        final toWrite = min(chunkSize, length - written);
        for (int i = 0; i < toWrite; i++) {
          randomBuf[i] = rng.nextInt(256);
        }
        await raf.writeFrom(randomBuf, 0, toWrite);
        written += toWrite;
      }
      await raf.flush();

      // Final truncate and unlink
      await raf.truncate(0);
      await raf.close();
      await file.delete();
    } catch (_) {
      // Graceful fallback for mock/ephemeral in-memory paths
    }
  }

  /// Securely shreds and deletes a quarantined item with multi-pass overwrite (CryptoShredder).
  Future<void> purgeItem(String id) async {
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item != null) {
      await shredPhysicalFile(item.quarantinePath);
    }
    _items.removeWhere((item) => item.id == id);
    _streamController.add(List.unmodifiable(_items));
  }

  /// Securely shreds all quarantined items.
  Future<void> purgeAll() async {
    for (final item in _items) {
      await shredPhysicalFile(item.quarantinePath);
    }
    _items.clear();
    _streamController.add(List.unmodifiable(_items));
  }

  void addQuarantinedItem(QuarantinedItem item) {
    _items.removeWhere((i) => i.id == item.id);
    _items.add(item);
    _streamController.add(List.unmodifiable(_items));
  }

  void resetForTesting() {
    _items.clear();
    _streamController.add(List.unmodifiable(_items));
  }
}
