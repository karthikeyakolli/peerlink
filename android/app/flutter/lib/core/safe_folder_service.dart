import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'app_settings_service.dart';
import 'received_files_service.dart';

class SafeFolderItem {
  final String id;
  final String originalName;
  final String originalPath;
  final int sizeBytes;
  final DateTime lockedAt;
  final String extension;

  const SafeFolderItem({
    required this.id,
    required this.originalName,
    required this.originalPath,
    required this.sizeBytes,
    required this.lockedAt,
    required this.extension,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalName': originalName,
        'originalPath': originalPath,
        'sizeBytes': sizeBytes,
        'lockedAt': lockedAt.toIso8601String(),
        'extension': extension,
      };

  factory SafeFolderItem.fromJson(Map<String, dynamic> map) => SafeFolderItem(
        id: map['id']?.toString() ?? '',
        originalName: map['originalName']?.toString() ?? 'file',
        originalPath: map['originalPath']?.toString() ?? '',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        lockedAt: DateTime.tryParse(map['lockedAt']?.toString() ?? '') ?? DateTime.now(),
        extension: map['extension']?.toString() ?? '',
      );
}

/// Strictly Local PIN-Protected Safe Folder Engine (PBKDF2-HMAC-SHA256 + Encrypt-then-MAC).
/// - Zero external cloud/Supabase storage (Rule 5)
/// - Zero AI authority over PIN, keys, or unlock state (Rule 11)
/// - Never auto-executes unlocked files (Rule 10)
/// - Encrypts both file payloads AND the filename index on disk.
class SafeFolderService {
  static final SafeFolderService _instance = SafeFolderService._internal();
  static SafeFolderService get instance => _instance;

  SafeFolderService._internal();

  static const int _pbkdf2Iterations = 10000;
  static const List<int> _magic = [0x50, 0x4C, 0x53, 0x46]; // "PLSF"
  static const int _formatVersion = 1;

  Uint8List? _unlockedMasterKey;
  int _failedAttempts = 0;

  Directory get _vaultDir =>
      Directory('${AppSettingsService.instance.saveLocation}${Platform.pathSeparator}.peerlink_safe_vault');

  File get _metaFile => File('${_vaultDir.path}${Platform.pathSeparator}vault_meta.json');
  File get _indexFile => File('${_vaultDir.path}${Platform.pathSeparator}vault_index.plsafe');
  File get _bioKeyFile => File('${_vaultDir.path}${Platform.pathSeparator}vault_biokey.plsafe');

  bool get isConfigured => _metaFile.existsSync();
  bool get isUnlocked => _unlockedMasterKey != null;
  bool get hasBiometricEnrolled => _bioKeyFile.existsSync();
  int get failedAttempts => _failedAttempts;

  /// Locks the Safe Folder immediately, wiping the derived master key from memory.
  void lock() {
    if (_unlockedMasterKey != null) {
      for (int i = 0; i < _unlockedMasterKey!.length; i++) {
        _unlockedMasterKey![i] = 0;
      }
      _unlockedMasterKey = null;
    }
  }

  /// Configures a brand-new Safe Folder PIN (4–12 digits/chars) and unlocks immediately.
  Future<void> setupPin(String pin) async {
    final trimmed = pin.trim();
    if (trimmed.length < 4) {
      throw ArgumentError('PIN must be at least 4 characters.');
    }
    if (!_vaultDir.existsSync()) {
      _vaultDir.createSync(recursive: true);
    }

    final salt = _randomBytes(16);
    final masterKey = _deriveMasterKey(trimmed, salt);
    final verifier = _hmacSha256(masterKey, utf8.encode('peerlink-safe-pin-verify-v1'));

    final meta = {
      'version': _formatVersion,
      'iterations': _pbkdf2Iterations,
      'saltB64': base64Encode(salt),
      'verifierB64': base64Encode(verifier),
      'createdAt': DateTime.now().toIso8601String(),
    };
    _metaFile.writeAsStringSync(jsonEncode(meta), flush: true);

    _unlockedMasterKey = masterKey;
    _failedAttempts = 0;
    _saveIndex(const []);
  }

  /// Verifies the PIN in constant time and unlocks the Safe Folder in memory.
  Future<bool> unlock(String pin) async {
    if (!isConfigured) return false;
    try {
      final meta = jsonDecode(_metaFile.readAsStringSync()) as Map<String, dynamic>;
      final salt = base64Decode(meta['saltB64'] as String);
      final expectedVerifier = base64Decode(meta['verifierB64'] as String);
      final candidateKey = _deriveMasterKey(pin.trim(), Uint8List.fromList(salt));
      final actualVerifier = _hmacSha256(candidateKey, utf8.encode('peerlink-safe-pin-verify-v1'));

      if (_constantTimeEquals(expectedVerifier, actualVerifier)) {
        _unlockedMasterKey = candidateKey;
        _failedAttempts = 0;
        return true;
      }
      _failedAttempts++;
      return false;
    } catch (_) {
      _failedAttempts++;
      return false;
    }
  }

  /// Enrolls local biometric token using authenticated master key.
  Future<bool> enrollBiometric(String pin) async {
    if (await unlock(pin)) {
      if (_unlockedMasterKey != null) {
        _bioKeyFile.writeAsBytesSync(_unlockedMasterKey!, flush: true);
        return true;
      }
    }
    return false;
  }

  /// Unlocks the Safe Folder when biometric challenge completes.
  Future<bool> unlockWithBiometric() async {
    if (!isConfigured || !_bioKeyFile.existsSync()) return false;
    try {
      final key = _bioKeyFile.readAsBytesSync();
      if (key.length == 32) {
        _unlockedMasterKey = Uint8List.fromList(key);
        _failedAttempts = 0;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Lists decrypted metadata of locked files (requires unlocked state).
  List<SafeFolderItem> listLockedFiles() {
    final key = _unlockedMasterKey;
    if (key == null) return const [];
    if (!_indexFile.existsSync()) return const [];
    try {
      final raw = _indexFile.readAsBytesSync();
      final plain = _decryptBytes(raw, key);
      final decoded = jsonDecode(utf8.decode(plain)) as List<dynamic>;
      return decoded
          .map((e) => SafeFolderItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lockedAt.compareTo(a.lockedAt));
    } catch (_) {
      return const [];
    }
  }

  /// Encrypts a file from disk into the Safe Folder and deletes the plaintext original.
  Future<SafeFolderItem> lockFile(String sourcePath) async {
    final key = _unlockedMasterKey;
    if (key == null) {
      throw StateError('Safe Folder is locked. Unlock with your PIN first.');
    }
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw ArgumentError('File not found: $sourcePath');
    }
    if (!_vaultDir.existsSync()) {
      _vaultDir.createSync(recursive: true);
    }

    final plainBytes = await src.readAsBytes();
    final encrypted = _encryptBytes(plainBytes, key);

    final id = _generateId();
    final fileName = src.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? 'file';
    final dot = fileName.lastIndexOf('.');
    final ext = dot != -1 ? fileName.substring(dot + 1) : '';

    final encFile = File('${_vaultDir.path}${Platform.pathSeparator}$id.plsafe');
    await encFile.writeAsBytes(encrypted, flush: true);

    final item = SafeFolderItem(
      id: id,
      originalName: fileName,
      originalPath: sourcePath,
      sizeBytes: plainBytes.length,
      lockedAt: DateTime.now(),
      extension: ext,
    );

    final current = List<SafeFolderItem>.from(listLockedFiles())..add(item);
    _saveIndex(current);

    // Remove plaintext original only after encrypted blob & index are durably flushed
    try {
      await src.delete();
    } catch (_) {}

    ReceivedFilesService.instance.notifyChanged();
    return item;
  }

  /// Authenticates and decrypts a locked file back to PeerLink Vault (or original directory).
  Future<String> restoreFile(String itemId) async {
    final key = _unlockedMasterKey;
    if (key == null) {
      throw StateError('Safe Folder is locked.');
    }
    final items = List<SafeFolderItem>.from(listLockedFiles());
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx == -1) {
      throw ArgumentError('Locked item not found.');
    }
    final item = items[idx];
    final encFile = File('${_vaultDir.path}${Platform.pathSeparator}${item.id}.plsafe');
    if (!encFile.existsSync()) {
      throw StateError('Encrypted payload missing on disk.');
    }

    final cipherBytes = await encFile.readAsBytes();
    final plainBytes = _decryptBytes(cipherBytes, key);

    // Restore to original parent if writable, otherwise PeerLink Vault root
    Directory destDir = File(item.originalPath).parent;
    if (!destDir.existsSync()) {
      destDir = ReceivedFilesService.instance.saveDirectory;
      if (!destDir.existsSync()) destDir.createSync(recursive: true);
    }

    String destPath = '${destDir.path}${Platform.pathSeparator}${item.originalName}';
    if (File(destPath).existsSync()) {
      destPath = '${destDir.path}${Platform.pathSeparator}restored_${DateTime.now().millisecondsSinceEpoch}_${item.originalName}';
    }

    await File(destPath).writeAsBytes(plainBytes, flush: true);

    try {
      await encFile.delete();
    } catch (_) {}
    items.removeAt(idx);
    _saveIndex(items);

    ReceivedFilesService.instance.notifyChanged();
    return destPath;
  }

  /// Permanently removes a locked item from the Safe Folder.
  Future<void> deleteLockedFile(String itemId) async {
    final key = _unlockedMasterKey;
    if (key == null) throw StateError('Safe Folder is locked.');
    final items = List<SafeFolderItem>.from(listLockedFiles());
    items.removeWhere((i) => i.id == itemId);
    final encFile = File('${_vaultDir.path}${Platform.pathSeparator}$itemId.plsafe');
    if (encFile.existsSync()) {
      await encFile.delete();
    }
    _saveIndex(items);
  }

  void _saveIndex(List<SafeFolderItem> items) {
    final key = _unlockedMasterKey;
    if (key == null) return;
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(items.map((e) => e.toJson()).toList())));
    final enc = _encryptBytes(jsonBytes, key);
    _indexFile.writeAsBytesSync(enc, flush: true);
  }

  /// PBKDF2-HMAC-SHA256 key derivation (RFC 2898, 32-byte key output).
  Uint8List _deriveMasterKey(String pin, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final block1 = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..[salt.length] = 0
      ..[salt.length + 1] = 0
      ..[salt.length + 2] = 0
      ..[salt.length + 3] = 1;

    var u = Uint8List.fromList(hmac.convert(block1).bytes);
    final out = Uint8List.fromList(u);

    for (int i = 1; i < _pbkdf2Iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  /// Authenticated Encrypt-then-MAC: [PLSF(4)] [ver(1)] [nonce(16)] [mac(32)] [ciphertext].
  Uint8List _encryptBytes(Uint8List plaintext, Uint8List masterKey) {
    final nonce = _randomBytes(16);
    final encKey = _hmacSha256(masterKey, [...utf8.encode('enc|'), ...nonce]);
    final macKey = _hmacSha256(masterKey, [...utf8.encode('mac|'), ...nonce]);

    final ciphertext = _xorKeystream(plaintext, encKey, nonce);

    final header = Uint8List(21);
    header.setRange(0, 4, _magic);
    header[4] = _formatVersion;
    header.setRange(5, 21, nonce);

    final macInput = BytesBuilder(copy: false)
      ..add(header)
      ..add(ciphertext);
    final tag = _hmacSha256(macKey, macInput.toBytes());

    final out = BytesBuilder(copy: false)
      ..add(header)
      ..add(tag)
      ..add(ciphertext);
    return out.toBytes();
  }

  /// Fail-closed authenticated decryption: verifies HMAC-SHA256 tag before decrypting.
  Uint8List _decryptBytes(Uint8List blob, Uint8List masterKey) {
    if (blob.length < 53) {
      throw const FormatException('Corrupted Safe Folder blob (too short).');
    }
    for (int i = 0; i < 4; i++) {
      if (blob[i] != _magic[i]) {
        throw const FormatException('Invalid Safe Folder file signature.');
      }
    }
    if (blob[4] != _formatVersion) {
      throw const FormatException('Unsupported Safe Folder format version.');
    }

    final header = Uint8List.sublistView(blob, 0, 21);
    final nonce = Uint8List.sublistView(blob, 5, 21);
    final expectedTag = Uint8List.sublistView(blob, 21, 53);
    final ciphertext = Uint8List.sublistView(blob, 53);

    final encKey = _hmacSha256(masterKey, [...utf8.encode('enc|'), ...nonce]);
    final macKey = _hmacSha256(masterKey, [...utf8.encode('mac|'), ...nonce]);

    final macInput = BytesBuilder(copy: false)
      ..add(header)
      ..add(ciphertext);
    final actualTag = _hmacSha256(macKey, macInput.toBytes());

    if (!_constantTimeEquals(expectedTag, actualTag)) {
      throw const FormatException('Integrity check failed: wrong key or tampered file.');
    }

    return _xorKeystream(ciphertext, encKey, nonce);
  }

  Uint8List _xorKeystream(Uint8List input, Uint8List encKey, Uint8List nonce) {
    final output = Uint8List(input.length);
    final hmac = Hmac(sha256, encKey);
    final blockInput = Uint8List(nonce.length + 4)..setAll(0, nonce);
    final counterView = ByteData.sublistView(blockInput, nonce.length, nonce.length + 4);

    int offset = 0;
    int counter = 0;
    while (offset < input.length) {
      counterView.setUint32(0, counter++, Endian.big);
      final keystreamBlock = hmac.convert(blockInput).bytes;
      final remaining = input.length - offset;
      final chunkLen = remaining < 32 ? remaining : 32;
      for (int i = 0; i < chunkLen; i++) {
        output[offset + i] = input[offset + i] ^ keystreamBlock[i];
      }
      offset += chunkLen;
    }
    return output;
  }

  Uint8List _hmacSha256(Uint8List key, List<int> data) {
    return Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);
  }

  Uint8List _randomBytes(int count) {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(count, (_) => rng.nextInt(256)));
  }

  String _generateId() {
    final bytes = _randomBytes(12);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
