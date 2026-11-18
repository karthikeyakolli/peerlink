import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/network_utils.dart';

void main() {
  test('NetworkUtils resolves valid IP address', () async {
    final ip = await NetworkUtils.getLocalIpAddress();
    expect(ip, isNotEmpty);
    expect(ip, isNot(equals('192.168.1.100'))); // Must not be the old bogus hardcoded value
    print('Resolved local IP: $ip');
  });
}
