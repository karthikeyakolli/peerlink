import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_sharing_service.dart';
import 'package:peerlink/core/file_staging_service.dart';

void main() {
  group('AppSharingService Unit Tests', () {
    final service = AppSharingService.instance;

    setUp(() {
      service.setCustomAppsForTesting([
        const SharedAppInfo(
          packageName: 'com.example.calculator',
          appName: 'Calculator Pro',
          versionName: '2.1.0',
          sizeBytes: 15000000,
          apkPath: '/data/app/calculator.apk',
          isSystemApp: false,
        ),
        const SharedAppInfo(
          packageName: 'com.android.settings',
          appName: 'Settings',
          versionName: '14.0',
          sizeBytes: 30000000,
          apkPath: '/system/priv-app/Settings.apk',
          isSystemApp: true,
        ),
        const SharedAppInfo(
          packageName: 'org.videolan.vlc',
          appName: 'VLC Media Player',
          versionName: '3.5.4',
          sizeBytes: 45000000,
          apkPath: '/data/app/vlc.apk',
          isSystemApp: false,
        ),
      ]);
    });

    test('getInstalledApps filters out system apps by default', () async {
      final apps = await service.getInstalledApps();
      expect(apps.length, 2);
      expect(apps.map((a) => a.appName).toList(), ['Calculator Pro', 'VLC Media Player']);
    });

    test('getInstalledApps includes system apps when requested', () async {
      final apps = await service.getInstalledApps(includeSystem: true);
      expect(apps.length, 3);
      expect(apps.any((a) => a.packageName == 'com.android.settings'), isTrue);
    });

    test('getInstalledApps filters by search keyword', () async {
      final apps = await service.getInstalledApps(searchFilter: 'vlc');
      expect(apps.length, 1);
      expect(apps.first.appName, 'VLC Media Player');
    });

    test('stageAppForSending stages apk path in FileStagingService', () {
      FileStagingService.instance.clear();
      final targetApp = const SharedAppInfo(
        packageName: 'com.example.test',
        appName: 'Test App',
        versionName: '1.0',
        sizeBytes: 5000,
        apkPath: '/data/app/test.apk',
      );

      final result = service.stageAppForSending(targetApp);
      expect(result, isTrue);
      expect(FileStagingService.instance.stagedFiles.map((f) => f.path), contains('/data/app/test.apk'));
    });
  });
}
