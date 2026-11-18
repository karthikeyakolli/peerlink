import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

enum SmartContentType {
  url,
  wifiConfig,
  jsonCode,
  phoneNumber,
  emailAddress,
  plainText,
}

class WifiConfigData {
  final String ssid;
  final String password;
  final String authType;
  final bool hidden;

  const WifiConfigData({
    required this.ssid,
    required this.password,
    this.authType = 'WPA',
    this.hidden = false,
  });
}

class SmartContentResult {
  final String rawText;
  final SmartContentType type;
  final String displayTitle;
  final String displaySubtitle;
  final IconData icon;
  final Color accentColor;
  final WifiConfigData? wifiConfig;
  final String? formattedJson;
  final String primaryActionLabel;
  final IconData primaryActionIcon;

  const SmartContentResult({
    required this.rawText,
    required this.type,
    required this.displayTitle,
    required this.displaySubtitle,
    required this.icon,
    required this.accentColor,
    this.wifiConfig,
    this.formattedJson,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
  });
}

/// Smart Clipboard & Actionable Link Intelligence Engine.
/// Analyzes shared text snippets to recognize URLs, Wi-Fi credentials,
/// JSON payloads, and contact details for 1-tap contextual actions.
class SmartContentSniffer {
  static final SmartContentSniffer _instance = SmartContentSniffer._internal();
  static SmartContentSniffer get instance => _instance;

  SmartContentSniffer._internal();

  /// Sniffs the provided text and extracts structured intelligence and primary actions.
  SmartContentResult sniff(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return const SmartContentResult(
        rawText: '',
        type: SmartContentType.plainText,
        displayTitle: 'Empty Note',
        displaySubtitle: 'No content',
        icon: Icons.notes_rounded,
        accentColor: Color(0xFF64748B),
        primaryActionLabel: 'Copy',
        primaryActionIcon: Icons.copy_rounded,
      );
    }

    // 1. Wi-Fi Configuration (WIFI:S:ssid;T:WPA;P:password;;)
    if (text.toUpperCase().startsWith('WIFI:') && text.contains('S:')) {
      final wifi = _parseWifi(text);
      if (wifi != null) {
        return SmartContentResult(
          rawText: text,
          type: SmartContentType.wifiConfig,
          displayTitle: 'Wi-Fi: ${wifi.ssid}',
          displaySubtitle: 'Security: ${wifi.authType} • Password: ${wifi.password.isEmpty ? "None" : "••••••••"}',
          icon: Icons.wifi_rounded,
          accentColor: const Color(0xFF10B981),
          wifiConfig: wifi,
          primaryActionLabel: wifi.password.isNotEmpty ? 'Copy Wi-Fi Password' : 'Copy Network SSID',
          primaryActionIcon: Icons.wifi_password_rounded,
        );
      }
    }

    // 2. URL Link
    if (text.startsWith('http://') || text.startsWith('https://')) {
      String host = 'Link';
      try {
        final uri = Uri.parse(text);
        if (uri.host.isNotEmpty) {
          host = uri.host;
        }
      } catch (_) {}

      return SmartContentResult(
        rawText: text,
        type: SmartContentType.url,
        displayTitle: host,
        displaySubtitle: 'Web Link',
        icon: Icons.open_in_browser_rounded,
        accentColor: const Color(0xFF2563EB),
        primaryActionLabel: 'Open in Browser',
        primaryActionIcon: Icons.launch_rounded,
      );
    }

    // 3. Structured JSON
    if ((text.startsWith('{') && text.endsWith('}')) || (text.startsWith('[') && text.endsWith(']'))) {
      try {
        final decoded = jsonDecode(text);
        final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
        final itemCount = decoded is Map ? '${decoded.length} keys' : (decoded is List ? '${decoded.length} items' : 'Object');

        return SmartContentResult(
          rawText: text,
          type: SmartContentType.jsonCode,
          displayTitle: 'JSON Data ($itemCount)',
          displaySubtitle: 'Valid structured data payload',
          icon: Icons.data_object_rounded,
          accentColor: const Color(0xFF8B5CF6),
          formattedJson: formatted,
          primaryActionLabel: 'Copy Formatted JSON',
          primaryActionIcon: Icons.code_rounded,
        );
      } catch (_) {
        // Not valid JSON, continue
      }
    }

    // 4. Email Address
    final emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
    if (emailRegex.hasMatch(text)) {
      return SmartContentResult(
        rawText: text,
        type: SmartContentType.emailAddress,
        displayTitle: 'Email Address',
        displaySubtitle: text,
        icon: Icons.email_rounded,
        accentColor: const Color(0xFF0D9488),
        primaryActionLabel: 'Copy Email',
        primaryActionIcon: Icons.copy_rounded,
      );
    }

    // 5. Phone Number
    final phoneRegex = RegExp(r'^\+?[0-9\s\-\(\)]{7,20}$');
    if (phoneRegex.hasMatch(text) && text.replaceAll(RegExp(r'\D'), '').length >= 7) {
      return SmartContentResult(
        rawText: text,
        type: SmartContentType.phoneNumber,
        displayTitle: 'Phone Number',
        displaySubtitle: text,
        icon: Icons.phone_rounded,
        accentColor: const Color(0xFFF59E0B),
        primaryActionLabel: 'Copy Number',
        primaryActionIcon: Icons.phone_iphone_rounded,
      );
    }

    // 6. Plain Text / Notes
    final lineCount = '\n'.allMatches(text).length + 1;
    final snippet = text.length > 80 ? '${text.substring(0, 80)}...' : text;
    return SmartContentResult(
      rawText: text,
      type: SmartContentType.plainText,
      displayTitle: lineCount > 1 ? '$lineCount Lines of Text' : '${text.length} Characters',
      displaySubtitle: snippet.replaceAll('\n', ' '),
      icon: Icons.notes_rounded,
      accentColor: const Color(0xFF3B82F6),
      primaryActionLabel: 'Copy to Clipboard',
      primaryActionIcon: Icons.copy_rounded,
    );
  }

  /// Extracts standard Wi-Fi configuration parts.
  WifiConfigData? _parseWifi(String text) {
    try {
      final clean = text.substring(5); // Remove "WIFI:"
      final parts = clean.split(';');
      String ssid = '';
      String password = '';
      String type = 'WPA';
      bool hidden = false;

      for (final p in parts) {
        if (p.startsWith('S:')) {
          ssid = p.substring(2);
        } else if (p.startsWith('P:')) {
          password = p.substring(2);
        } else if (p.startsWith('T:')) {
          type = p.substring(2);
        } else if (p.startsWith('H:')) {
          hidden = p.substring(2).toLowerCase() == 'true';
        }
      }

      if (ssid.isNotEmpty) {
        return WifiConfigData(
          ssid: ssid,
          password: password,
          authType: type,
          hidden: hidden,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Platform-safe URL launcher using OS built-ins without unapproved 3rd party plugins.
  Future<bool> openUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
