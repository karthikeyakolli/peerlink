import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';

enum DeviceTrustLevel {
  trustedPeer,
  temporaryGuest,
}

class PairedDevice {
  final String id;
  final String name;
  final String deviceType;
  final String fingerprint;
  final DeviceTrustLevel trustLevel;
  final bool isOnline;
  final String lastSeen;
  final List<String> scopedCapabilities;

  const PairedDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.fingerprint,
    required this.trustLevel,
    this.isOnline = false,
    this.lastSeen = 'Offline',
    this.scopedCapabilities = const ['READ', 'WRITE'],
  });

  PairedDevice copyWith({
    String? id,
    String? name,
    String? deviceType,
    String? fingerprint,
    DeviceTrustLevel? trustLevel,
    bool? isOnline,
    String? lastSeen,
    List<String>? scopedCapabilities,
  }) {
    return PairedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      fingerprint: fingerprint ?? this.fingerprint,
      trustLevel: trustLevel ?? this.trustLevel,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      scopedCapabilities: scopedCapabilities ?? this.scopedCapabilities,
    );
  }
}

class DeviceTrustService {
  static final DeviceTrustService _instance = DeviceTrustService._internal();
  static DeviceTrustService get instance => _instance;

  final List<PairedDevice> _devices = [];
  final StreamController<List<PairedDevice>> _devicesController =
      StreamController<List<PairedDevice>>.broadcast();

  DeviceTrustService._internal();

  Stream<List<PairedDevice>> get devicesStream => _devicesController.stream;
  List<PairedDevice> get devices => List.unmodifiable(_devices);

  void pairDevice(PairedDevice device) {
    _devices.removeWhere((d) => d.id == device.id);
    _devices.add(device);
    _devicesController.add(List.unmodifiable(_devices));
  }

  void revokeDevice(String peerId) {
    _devices.removeWhere((d) => d.id == peerId);
    _devicesController.add(List.unmodifiable(_devices));
  }

  void updateTrustLevel(String peerId, DeviceTrustLevel newLevel) {
    final index = _devices.indexWhere((d) => d.id == peerId);
    if (index != -1) {
      final existing = _devices[index];
      _devices[index] = existing.copyWith(trustLevel: newLevel);
      _devicesController.add(List.unmodifiable(_devices));
    }
  }

  String getLocalFingerprint(String? peerId) {
    final effectiveId = peerId ?? 'peer_local_primary';
    final bytes = utf8.encode(effectiveId);
    final digest = sha256.convert(bytes);
    final hexStr = digest.toString();
    return 'ed25519:${hexStr.substring(0, 16)}...${hexStr.substring(hexStr.length - 8)}';
  }

  void resetForTesting() {
    _devices.clear();
    _devicesController.add(List.unmodifiable(_devices));
  }
}
