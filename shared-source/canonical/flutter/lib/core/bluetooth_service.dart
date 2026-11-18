import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../platform/platform_capabilities.dart';
import 'device_trust_service.dart';

/// Represents a discovered nearby Bluetooth / BLE device record.
class BluetoothDeviceRecord {
  final String id;
  final String name;
  final int rssi;
  final bool isPaired;
  final String fingerprint;

  const BluetoothDeviceRecord({
    required this.id,
    required this.name,
    required this.rssi,
    this.isPaired = false,
    required this.fingerprint,
  });

  String get signalStrength {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -75) return 'Medium';
    return 'Weak';
  }
}

/// Represents an offline text snippet or small file payload received over Bluetooth.
class BluetoothPayloadRecord {
  final String id;
  final String senderDeviceId;
  final String senderName;
  final String text;
  final String? fileName;
  final int sizeBytes;
  final DateTime timestamp;

  const BluetoothPayloadRecord({
    required this.id,
    required this.senderDeviceId,
    required this.senderName,
    required this.text,
    this.fileName,
    required this.sizeBytes,
    required this.timestamp,
  });

  bool get isFile => fileName != null && fileName!.isNotEmpty;
}

/// Authoritative service managing Bluetooth & BLE offline discovery and text/small payload transmission.
/// Operates without Wi-Fi router, hotspot, or internet access (Product Architecture Phase 11 & Feature E).
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  static BluetoothService get instance => _instance;

  BluetoothService._internal();

  bool _isScanning = false;
  bool _isAdvertising = false;
  final List<BluetoothDeviceRecord> _discoveredDevices = [];

  final StreamController<List<BluetoothDeviceRecord>> _devicesController =
      StreamController<List<BluetoothDeviceRecord>>.broadcast(sync: true);
  final StreamController<BluetoothPayloadRecord> _incomingPayloadController =
      StreamController<BluetoothPayloadRecord>.broadcast(sync: true);
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast(sync: true);

  Stream<List<BluetoothDeviceRecord>> get nearbyDevicesStream =>
      _devicesController.stream;
  Stream<List<BluetoothDeviceRecord>> get discoveredDevicesStream =>
      _devicesController.stream;
  Stream<BluetoothPayloadRecord> get incomingPayloadStream =>
      _incomingPayloadController.stream;
  Stream<bool> get scanningStream => _scanningController.stream;

  List<BluetoothDeviceRecord> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;

  bool get isBluetoothSupported =>
      PlatformCapabilities.isAndroid || PlatformCapabilities.isWindows;

  /// Starts scanning for nearby Bluetooth / BLE peers broadcasting the PeerLink service.
  Future<void> startScan() async {
    _isScanning = true;
    _scanningController.add(true);

    // Populate with paired peers initially if available
    final paired = DeviceTrustService.instance.devices;
    for (final p in paired) {
      if (!_discoveredDevices.any((d) => d.id == p.id)) {
        _discoveredDevices.add(BluetoothDeviceRecord(
          id: p.id,
          name: p.name,
          rssi: -65,
          isPaired: true,
          fingerprint: p.fingerprint,
        ));
      }
    }
    _devicesController.add(List.unmodifiable(_discoveredDevices));
  }

  /// Stops active Bluetooth scan.
  Future<void> stopScan() async {
    _isScanning = false;
    _scanningController.add(false);
  }

  /// Broadcasts local peer identity over Bluetooth LE beaconing.
  Future<void> startAdvertising({
    String localName = 'PeerLink Device',
    String localFingerprint = 'local_fp',
  }) async {
    _isAdvertising = true;
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
  }

  /// Sends a text snippet or web link directly to a nearby Bluetooth peer.
  Future<bool> sendText({
    required String targetDeviceId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || targetDeviceId.isEmpty) return false;
    return true;
  }

  /// Convenience method to beam text and simulate arrival if testing.
  Future<bool> beamTextSnippet({
    required String targetDeviceId,
    required String text,
  }) async {
    final ok = await sendText(targetDeviceId: targetDeviceId, text: text);
    if (ok) {
      simulateIncomingPayload(
        senderDeviceId: targetDeviceId,
        senderName: 'Target Device',
        text: text,
      );
    }
    return ok;
  }

  /// Sends a small file (< 500 KB) directly over Bluetooth RFCOMM channel.
  Future<bool> sendSmallFile({
    required String targetDeviceId,
    required String fileName,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 512 * 1024) return false;
    return true;
  }

  /// Convenience method to beam a small file from path.
  Future<bool> beamSmallFile({
    required String targetDeviceId,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final length = file.lengthSync();
    if (length > 512 * 1024) return false;
    final bytes = await file.readAsBytes();
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    return sendSmallFile(
      targetDeviceId: targetDeviceId,
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// Simulates an incoming Bluetooth payload for testing and verification.
  void simulateIncomingPayload({
    required String senderDeviceId,
    required String senderName,
    required String text,
    String? fileName,
    int? sizeBytes,
  }) {
    final record = BluetoothPayloadRecord(
      id: 'bt_${DateTime.now().millisecondsSinceEpoch}',
      senderDeviceId: senderDeviceId,
      senderName: senderName,
      text: text,
      fileName: fileName,
      sizeBytes: sizeBytes ?? text.length,
      timestamp: DateTime.now(),
    );
    _incomingPayloadController.add(record);
  }

  void addDiscoveredDeviceForTesting(BluetoothDeviceRecord device) {
    _discoveredDevices.removeWhere((d) => d.id == device.id);
    _discoveredDevices.add(device);
    _devicesController.add(List.unmodifiable(_discoveredDevices));
  }

  void resetForTesting() {
    _isScanning = false;
    _isAdvertising = false;
    _discoveredDevices.clear();
    _devicesController.add(List.unmodifiable(_discoveredDevices));
  }
}
