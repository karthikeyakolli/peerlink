import 'dart:io';
import 'package:flutter/foundation.dart';

class UsbTurboModeService extends ChangeNotifier {
  UsbTurboModeService._();
  static final UsbTurboModeService instance = UsbTurboModeService._();

  bool _isTurboEnabled = false;
  bool get isTurboEnabled => _isTurboEnabled;

  void setTurboEnabled(bool enabled) {
    _isTurboEnabled = enabled;
    notifyListeners();
  }

  bool isWiredSubnet(String ip) {
    final clean = ip.trim();
    if (clean.startsWith('192.168.42.') || clean.startsWith('192.168.43.')) {
      return true;
    }
    if (clean == '127.0.0.1' || clean == 'localhost') {
      return true;
    }
    return false;
  }

  String estimateThroughputLabel({required bool isWired}) {
    if (isWired || _isTurboEnabled) {
      return 'Gigabit Wired Link (Up to 2.5 Gbps)';
    }
    return 'Wi-Fi Direct / Local AP (High-Speed LAN)';
  }

  Future<String?> detectWiredInterfaceIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (isWiredSubnet(addr.address)) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
