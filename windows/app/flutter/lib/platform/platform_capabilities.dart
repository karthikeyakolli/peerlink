import 'dart:io' show Platform;

class PlatformCapabilities {
  static bool? _overrideIsAndroid;
  static set overrideIsAndroid(bool? value) => _overrideIsAndroid = value;

  static bool get isDesktop =>
      _overrideIsAndroid == true ? false : (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get isAndroid => _overrideIsAndroid ?? Platform.isAndroid;

  static bool get isWindows => _overrideIsAndroid == true ? false : Platform.isWindows;

  static String get platformName {
    if (_overrideIsAndroid == true) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  static bool get usesDesktopJavaDaemon => isDesktop;
}
