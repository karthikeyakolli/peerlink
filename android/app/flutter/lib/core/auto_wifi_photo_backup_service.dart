import 'package:flutter/foundation.dart';

class AutoWifiPhotoBackupService extends ChangeNotifier {
  AutoWifiPhotoBackupService._();
  static final AutoWifiPhotoBackupService instance = AutoWifiPhotoBackupService._();

  final Set<String> _homeSsids = {};
  bool _isAutoBackupEnabled = false;

  bool get isAutoBackupEnabled => _isAutoBackupEnabled;
  Set<String> get homeSsids => Set.unmodifiable(_homeSsids);

  void setAutoBackupEnabled(bool enabled) {
    _isAutoBackupEnabled = enabled;
    notifyListeners();
  }

  void setHomeSsid(String ssid) {
    final clean = ssid.trim();
    if (clean.isNotEmpty) {
      _homeSsids.add(clean);
      notifyListeners();
    }
  }

  void removeHomeSsid(String ssid) {
    _homeSsids.remove(ssid.trim());
    notifyListeners();
  }

  bool isHomeSsid(String ssid) {
    return _homeSsids.contains(ssid.trim());
  }

  List<String> calculateDelta({
    required Map<String, String> localPhotos,
    required Set<String> remoteKnownHashes,
  }) {
    final delta = <String>[];
    for (final entry in localPhotos.entries) {
      final name = entry.key;
      final hash = entry.value;
      if (!remoteKnownHashes.contains(hash)) {
        delta.add(name);
      }
    }
    return delta;
  }
}
