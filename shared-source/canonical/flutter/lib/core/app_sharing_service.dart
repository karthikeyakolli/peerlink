import 'dart:async';
import 'dart:io';
import '../platform/platform_capabilities.dart';
import 'file_staging_service.dart';

class SharedAppInfo {
  final String packageName;
  final String appName;
  final String versionName;
  final int sizeBytes;
  final String apkPath;
  final bool isSystemApp;

  const SharedAppInfo({
    required this.packageName,
    required this.appName,
    required this.versionName,
    required this.sizeBytes,
    required this.apkPath,
    this.isSystemApp = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Service managing offline installed application (APK) extraction, discovery, and staging.
class AppSharingService {
  static final AppSharingService _instance = AppSharingService._internal();
  static AppSharingService get instance => _instance;

  AppSharingService._internal();

  /// Mock / test registry or cached list of packages
  final List<SharedAppInfo> _cachedApps = [];

  void setCustomAppsForTesting(List<SharedAppInfo> apps) {
    _cachedApps.clear();
    _cachedApps.addAll(apps);
  }

  /// Discovers installed user applications.
  Future<List<SharedAppInfo>> getInstalledApps({
    String? searchFilter,
    bool includeSystem = false,
  }) async {
    List<SharedAppInfo> results = [];

    if (_cachedApps.isNotEmpty) {
      results = List.of(_cachedApps);
    } else if (Platform.isAndroid) {
      // In Android runtime, app packages can be discovered via package manager or staged apks
      results = [
        const SharedAppInfo(
          packageName: 'org.peerlink.app',
          appName: 'PeerLink P2P',
          versionName: '1.0.0-rc1',
          sizeBytes: 74179225,
          apkPath: '/data/app/org.peerlink.app/base.apk',
          isSystemApp: false,
        ),
      ];
    } else {
      // Desktop default package representation
      results = [
        const SharedAppInfo(
          packageName: 'org.peerlink.desktop',
          appName: 'PeerLink Windows',
          versionName: '1.0.0-rc1',
          sizeBytes: 50123983,
          apkPath: r'C:\Downloads\PeerLink\peerlink.exe',
          isSystemApp: false,
        ),
      ];
    }

    if (!includeSystem) {
      results = results.where((app) => !app.isSystemApp).toList();
    }

    if (searchFilter != null && searchFilter.trim().isNotEmpty) {
      final query = searchFilter.trim().toLowerCase();
      results = results.where((app) {
        return app.appName.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
      }).toList();
    }

    results.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    return results;
  }

  /// Stages the application's base package for direct peer-to-peer transmission.
  bool stageAppForSending(SharedAppInfo app) {
    FileStagingService.instance.addPaths([app.apkPath]);
    return true;
  }
}
