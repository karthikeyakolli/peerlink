import 'dart:convert';
import 'dart:io';

class HotspotTetherPayload {
  final String version;
  final String ssid;
  final String passphrase;
  final String ipAddress;
  final int port;
  final String nodeId;
  final String publicKey;

  const HotspotTetherPayload({
    this.version = 'v1',
    required this.ssid,
    required this.passphrase,
    required this.ipAddress,
    required this.port,
    required this.nodeId,
    required this.publicKey,
  });

  String toUriString() {
    final query = Uri(queryParameters: {
      'v': version,
      'ssid': ssid,
      'pass': passphrase,
      'ip': ipAddress,
      'port': port.toString(),
      'node': nodeId,
      'key': publicKey,
    }).query;
    return 'peerlink-tether://connect?$query';
  }

  static HotspotTetherPayload? fromUriString(String rawUri) {
    try {
      final uri = Uri.parse(rawUri);
      if (uri.scheme != 'peerlink-tether') return null;
      final params = uri.queryParameters;
      final ssid = params['ssid'];
      final pass = params['pass'];
      final ip = params['ip'];
      final portStr = params['port'];
      final node = params['node'];
      final key = params['key'];

      if (ssid == null || pass == null || ip == null || portStr == null || node == null || key == null) {
        return null;
      }

      return HotspotTetherPayload(
        version: params['v'] ?? 'v1',
        ssid: ssid,
        passphrase: pass,
        ipAddress: ip,
        port: int.tryParse(portStr) ?? 53317,
        nodeId: node,
        publicKey: key,
      );
    } catch (_) {
      return null;
    }
  }
}

class HotspotTetherQrService {
  static final HotspotTetherQrService instance = HotspotTetherQrService._internal();
  HotspotTetherQrService._internal();

  HotspotTetherPayload createPayload({
    required String ssid,
    required String passphrase,
    required String ipAddress,
    required int port,
    required String nodeId,
    required String publicKey,
  }) {
    return HotspotTetherPayload(
      ssid: ssid,
      passphrase: passphrase,
      ipAddress: ipAddress,
      port: port,
      nodeId: nodeId,
      publicKey: publicKey,
    );
  }

  Future<bool> verifyConnection(HotspotTetherPayload payload, {Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final socket = await Socket.connect(payload.ipAddress, payload.port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
