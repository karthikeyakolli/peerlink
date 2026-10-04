import 'dart:io' show Platform;

class PlatformCapabilities {
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool get isAndroid => Platform.isAndroid;

  static bool get isWindows => Platform.isWindows;

  static String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  static bool get usesDesktopJavaDaemon => isDesktop;
}
