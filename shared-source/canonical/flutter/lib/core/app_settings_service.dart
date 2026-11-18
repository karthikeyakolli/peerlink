import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../platform/platform_capabilities.dart';
import 'file_staging_service.dart';

/// Authoritative service managing user-configurable settings, storage directories,
/// device identity labels, and runtime preferences for Windows and Android.
class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  static AppSettingsService get instance => _instance;

  AppSettingsService._internal();

  String? _customSaveLocation;
  String? _customDeviceName;
  bool _autoAcceptFromTrusted = true;
  bool _soundNotifications = true;
  bool _startOnBoot = false;
  bool _minimizeToTray = true;
  bool _autoSyncEnabled = true;
  int _autoSyncIntervalSeconds = 120;
  bool _aiAssistantEnabled = true;
  String _geminiApiKey = '';
  bool _aiSensitiveDisclosureAuthorized = false;
  bool _aiOfflineOnly = false;
  bool _dropZoneEnabled = false;
  String? _dropZonePath;
  String? _dropZoneTargetPeerId;
  bool _dropZoneAutoDispatch = false;
  ThemeMode _themeMode = ThemeMode.light;

  final StreamController<void> _changeController =
      StreamController<void>.broadcast(sync: true);

  Stream<void> get changeStream => _changeController.stream;

  /// Active theme mode — permanently forced to minimalist Light Mode only.
  ThemeMode get themeMode => ThemeMode.light;

  set themeMode(ThemeMode mode) {
    // Dark mode is intentionally removed; force light mode unconditionally.
    if (_themeMode != ThemeMode.light) {
      _themeMode = ThemeMode.light;
      _notify();
    }
  }

  void setThemeModeFromString(String modeStr) {
    themeMode = ThemeMode.light;
  }

  /// Whether a custom save location has been explicitly configured (or overridden in tests).
  bool get hasCustomSaveLocation =>
      _customSaveLocation != null && _customSaveLocation!.isNotEmpty;

  /// Default and custom directory where received transfers are saved.
  String get saveLocation {
    if (_customSaveLocation != null && _customSaveLocation!.isNotEmpty) {
      return _customSaveLocation!;
    }
    try {
      if (PlatformCapabilities.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.isNotEmpty) {
          return '$userProfile\\Downloads\\PeerLink';
        }
        return 'C:\\Downloads\\PeerLink';
      } else if (PlatformCapabilities.isAndroid) {
        return '/storage/emulated/0/Download/PeerLink';
      }
    } catch (_) {}
    return 'Downloads/PeerLink';
  }

  set saveLocation(String path) {
    final trimmed = path.trim();
    if (trimmed.isNotEmpty) {
      _customSaveLocation = trimmed;
      _notify();
    }
  }

  /// Display name used to announce this device to peers during discovery and pairing.
  String get deviceName {
    if (_customDeviceName != null && _customDeviceName!.isNotEmpty) {
      return _customDeviceName!;
    }
    try {
      if (PlatformCapabilities.isAndroid) {
        return 'Android Peer';
      } else if (PlatformCapabilities.isWindows) {
        final computerName = Platform.environment['COMPUTERNAME'];
        if (computerName != null && computerName.isNotEmpty) {
          return computerName;
        }
        return 'Windows PC';
      }
    } catch (_) {}
    return 'PeerLink Device';
  }

  set deviceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      _customDeviceName = trimmed;
      _notify();
    }
  }

  /// Whether files from verified trusted peers are accepted automatically.
  bool get autoAcceptFromTrusted => _autoAcceptFromTrusted;
  set autoAcceptFromTrusted(bool value) {
    if (_autoAcceptFromTrusted != value) {
      _autoAcceptFromTrusted = value;
      _notify();
    }
  }

  /// Whether sound and alert notifications are played on transfer events.
  bool get soundNotifications => _soundNotifications;
  set soundNotifications(bool value) {
    if (_soundNotifications != value) {
      _soundNotifications = value;
      _notify();
    }
  }

  /// Windows: Whether PeerLink starts minimized in the background on system boot.
  bool get startOnBoot => _startOnBoot;
  set startOnBoot(bool value) {
    if (_startOnBoot != value) {
      _startOnBoot = value;
      _notify();
    }
  }

  /// Windows: Whether closing the window minimizes to the system notification tray.
  bool get minimizeToTray => _minimizeToTray;
  set minimizeToTray(bool value) {
    if (_minimizeToTray != value) {
      _minimizeToTray = value;
      _notify();
    }
  }

  /// Whether Spaces automatically sync in the background when changes are detected.
  bool get autoSyncEnabled => _autoSyncEnabled;
  set autoSyncEnabled(bool value) {
    if (_autoSyncEnabled != value) {
      _autoSyncEnabled = value;
      _notify();
    }
  }

  /// Heartbeat interval in seconds for automated background sync verification.
  int get autoSyncIntervalSeconds => _autoSyncIntervalSeconds;
  set autoSyncIntervalSeconds(int value) {
    if (_autoSyncIntervalSeconds != value) {
      _autoSyncIntervalSeconds = value;
      _notify();
    }
  }

  /// Whether the Non-Authoritative AI Smart Assistant is enabled.
  bool get aiAssistantEnabled => _aiAssistantEnabled;
  set aiAssistantEnabled(bool value) {
    if (_aiAssistantEnabled != value) {
      _aiAssistantEnabled = value;
      _notify();
    }
  }

  /// Optional Gemini API Key for online cloud-assisted smart summaries.
  String get geminiApiKey => _geminiApiKey;
  set geminiApiKey(String value) {
    if (_geminiApiKey != value) {
      _geminiApiKey = value;
      _notify();
    }
  }

  /// Whether user explicitly authorized sharing sensitive metadata with external LLMs.
  bool get aiSensitiveDisclosureAuthorized => _aiSensitiveDisclosureAuthorized;
  set aiSensitiveDisclosureAuthorized(bool value) {
    if (_aiSensitiveDisclosureAuthorized != value) {
      _aiSensitiveDisclosureAuthorized = value;
      _notify();
    }
  }

  /// Forces AI operations to run in 100% offline deterministic rule-based mode.
  bool get aiOfflineOnly => _aiOfflineOnly;
  set aiOfflineOnly(bool value) {
    if (_aiOfflineOnly != value) {
      _aiOfflineOnly = value;
      _notify();
    }
  }

  /// Whether the background Drop-Zone / Quick-Beam daemon is enabled.
  bool get dropZoneEnabled => _dropZoneEnabled;
  set dropZoneEnabled(bool value) {
    if (_dropZoneEnabled != value) {
      _dropZoneEnabled = value;
      _notify();
    }
  }

  /// Custom path for the monitored Drop-Zone directory.
  String get dropZonePath => _dropZonePath ?? '$saveLocation/DropBox';
  set dropZonePath(String? value) {
    if (_dropZonePath != value) {
      _dropZonePath = value;
      _notify();
    }
  }

  /// Paired peer ID to automatically beam dropped files to.
  String? get dropZoneTargetPeerId => _dropZoneTargetPeerId;
  set dropZoneTargetPeerId(String? value) {
    if (_dropZoneTargetPeerId != value) {
      _dropZoneTargetPeerId = value;
      _notify();
    }
  }

  /// If true, automatically beams dropped files immediately without staging prompt.
  bool get dropZoneAutoDispatch => _dropZoneAutoDispatch;
  set dropZoneAutoDispatch(bool value) {
    if (_dropZoneAutoDispatch != value) {
      _dropZoneAutoDispatch = value;
      _notify();
    }
  }

  /// Opens the current save location in the native operating system file explorer.
  Future<bool> openSaveLocation() async {
    try {
      if (PlatformCapabilities.isWindows) {
        final dir = Directory(saveLocation);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        await Process.run('explorer.exe', [saveLocation]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Clears temporary staging files from memory and draft cache.
  int clearTemporaryCache() {
    final count = FileStagingService.instance.count;
    FileStagingService.instance.clear();
    return count;
  }

  void _notify() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  void resetForTesting() {
    _customSaveLocation = null;
    _customDeviceName = null;
    _autoAcceptFromTrusted = true;
    _soundNotifications = true;
    _startOnBoot = false;
    _minimizeToTray = true;
    _autoSyncEnabled = true;
    _autoSyncIntervalSeconds = 120;
    _aiAssistantEnabled = true;
    _geminiApiKey = '';
    _aiSensitiveDisclosureAuthorized = false;
    _aiOfflineOnly = false;
    _dropZoneEnabled = false;
    _dropZonePath = null;
    _dropZoneTargetPeerId = null;
    _dropZoneAutoDispatch = false;
    _themeMode = ThemeMode.light;
    _notify();
  }
}
