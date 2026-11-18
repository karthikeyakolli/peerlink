import 'dart:io';

/// Utility for discovering real local network interfaces and IP addresses
/// for zero-config Wi-Fi / LAN P2P operations.
class NetworkUtils {
  /// Returns the device's authoritative local private IPv4 address on Wi-Fi or LAN.
  /// Ignores loopback, APIPA (169.254.x.x), and inactive interfaces.
  static Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Pass 1: Prioritize Wi-Fi, Android WLAN/Hotspot (wlan0, ap0, swlan0), or Ethernet with RFC 1918 addresses
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        final isPreferred = name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('wlan') ||
            name.contains('swlan') ||
            name.startsWith('ap') ||
            name.contains('eth') ||
            name.startsWith('en');
        if (isPreferred) {
          for (final addr in interface.addresses) {
            if (_isRfc1918PrivateAddress(addr.address)) {
              return addr.address;
            }
          }
        }
      }

      // Pass 2: Any adapter with an RFC 1918 private address (e.g. 192.168.x.x, 10.x.x.x, 172.16-31.x.x)
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (_isRfc1918PrivateAddress(addr.address)) {
            return addr.address;
          }
        }
      }

      // Pass 3: Any non-loopback IPv4 address not starting with 169.254
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}

    return '127.0.0.1';
  }

  static bool _isRfc1918PrivateAddress(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }
}
