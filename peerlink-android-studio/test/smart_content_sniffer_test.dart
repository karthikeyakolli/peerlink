import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/smart_content_sniffer.dart';

void main() {
  group('SmartContentSniffer Unit Tests', () {
    final sniffer = SmartContentSniffer.instance;

    test('sniffs URL links accurately', () {
      final res = sniffer.sniff('https://github.com/google/peerlink');
      expect(res.type, SmartContentType.url);
      expect(res.displayTitle, 'github.com');
      expect(res.primaryActionLabel, 'Open in Browser');
      expect(res.primaryActionIcon, Icons.launch_rounded);
    });

    test('sniffs Wi-Fi QR/text payloads and extracts credentials', () {
      final res = sniffer.sniff('WIFI:S:MyGuestWifi;T:WPA;P:SuperSecret123;H:false;;');
      expect(res.type, SmartContentType.wifiConfig);
      expect(res.wifiConfig, isNotNull);
      expect(res.wifiConfig!.ssid, 'MyGuestWifi');
      expect(res.wifiConfig!.password, 'SuperSecret123');
      expect(res.wifiConfig!.authType, 'WPA');
      expect(res.primaryActionLabel, 'Copy Wi-Fi Password');
    });

    test('sniffs JSON payloads and pretty-prints them', () {
      const jsonText = '{"name":"Alice","role":"Engineer","active":true}';
      final res = sniffer.sniff(jsonText);
      expect(res.type, SmartContentType.jsonCode);
      expect(res.formattedJson, contains('\n  "name": "Alice"'));
      expect(res.primaryActionLabel, 'Copy Formatted JSON');
    });

    test('sniffs email addresses', () {
      final res = sniffer.sniff('developer@peerlink.org');
      expect(res.type, SmartContentType.emailAddress);
      expect(res.displayTitle, 'Email Address');
      expect(res.primaryActionLabel, 'Copy Email');
    });

    test('sniffs phone numbers', () {
      final res = sniffer.sniff('+1-800-555-0199');
      expect(res.type, SmartContentType.phoneNumber);
      expect(res.displayTitle, 'Phone Number');
      expect(res.primaryActionLabel, 'Copy Number');
    });

    test('falls back to plain text note', () {
      final res = sniffer.sniff('Remember to buy milk on the way home.');
      expect(res.type, SmartContentType.plainText);
      expect(res.primaryActionLabel, 'Copy to Clipboard');
    });
  });
}
