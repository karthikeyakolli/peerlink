import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/platform/platform_capabilities.dart';

void main() {
  setUp(() {
    AppSettingsService.instance.resetForTesting();
    FileStagingService.instance.resetForTesting();
    PlatformCapabilities.overrideIsAndroid = null;
  });

  tearDown(() {
    PlatformCapabilities.overrideIsAndroid = null;
  });

  group('AppSettingsService Unit Tests', () {
    test('Default values adhere to platform capabilities', () {
      final service = AppSettingsService.instance;
      expect(service.autoAcceptFromTrusted, isTrue);
      expect(service.soundNotifications, isTrue);
      expect(service.startOnBoot, isFalse);
      expect(service.minimizeToTray, isTrue);
      expect(service.autoSyncEnabled, isTrue);
      expect(service.autoSyncIntervalSeconds, equals(120));
      expect(service.aiAssistantEnabled, isTrue);
      expect(service.geminiApiKey, isEmpty);
      expect(service.aiSensitiveDisclosureAuthorized, isFalse);
      expect(service.aiOfflineOnly, isFalse);
      expect(service.dropZoneEnabled, isFalse);
      expect(service.dropZonePath, contains('DropBox'));
      expect(service.dropZoneTargetPeerId, isNull);
      expect(service.dropZoneAutoDispatch, isFalse);
      expect(service.themeMode, equals(ThemeMode.light));
      expect(service.saveLocation.isNotEmpty, isTrue);
      expect(service.deviceName.isNotEmpty, isTrue);
    });

    test('Custom device name and save location mutation and reset', () {
      final service = AppSettingsService.instance;
      service.deviceName = 'My Custom Rig';
      expect(service.deviceName, equals('My Custom Rig'));

      service.saveLocation = 'D:\\CustomTransfers';
      expect(service.saveLocation, equals('D:\\CustomTransfers'));

      service.resetForTesting();
      expect(service.deviceName, isNot(equals('My Custom Rig')));
      expect(service.saveLocation, isNot(equals('D:\\CustomTransfers')));
    });

    test('Toggle preferences mutate state and emit notifications', () async {
      final service = AppSettingsService.instance;
      bool notified = false;
      final sub = service.changeStream.listen((_) => notified = true);

      service.autoAcceptFromTrusted = false;
      expect(service.autoAcceptFromTrusted, isFalse);
      expect(notified, isTrue);

      notified = false;
      service.soundNotifications = false;
      expect(service.soundNotifications, isFalse);
      expect(notified, isTrue);

      notified = false;
      service.startOnBoot = true;
      expect(service.startOnBoot, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.minimizeToTray = false;
      expect(service.minimizeToTray, isFalse);
      expect(notified, isTrue);

      notified = false;
      service.autoSyncEnabled = false;
      expect(service.autoSyncEnabled, isFalse);
      expect(notified, isTrue);

      notified = false;
      service.autoSyncIntervalSeconds = 300;
      expect(service.autoSyncIntervalSeconds, equals(300));
      expect(notified, isTrue);

      notified = false;
      service.aiAssistantEnabled = false;
      expect(service.aiAssistantEnabled, isFalse);
      expect(notified, isTrue);

      notified = false;
      service.geminiApiKey = 'test_api_key_123';
      expect(service.geminiApiKey, equals('test_api_key_123'));
      expect(notified, isTrue);

      notified = false;
      service.aiSensitiveDisclosureAuthorized = true;
      expect(service.aiSensitiveDisclosureAuthorized, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.aiOfflineOnly = true;
      expect(service.aiOfflineOnly, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.dropZoneEnabled = true;
      expect(service.dropZoneEnabled, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.dropZonePath = 'D:\\DropBox';
      expect(service.dropZonePath, equals('D:\\DropBox'));
      expect(notified, isTrue);

      notified = false;
      service.dropZoneTargetPeerId = 'peer_phone_123';
      expect(service.dropZoneTargetPeerId, equals('peer_phone_123'));
      expect(notified, isTrue);

      notified = false;
      service.dropZoneAutoDispatch = true;
      expect(service.dropZoneAutoDispatch, isTrue);
      expect(notified, isTrue);

      // Light mode is permanently forced — dark and system requests remain ThemeMode.light
      service.themeMode = ThemeMode.dark;
      expect(service.themeMode, equals(ThemeMode.light));

      service.setThemeModeFromString('light');
      expect(service.themeMode, equals(ThemeMode.light));

      service.setThemeModeFromString('system');
      expect(service.themeMode, equals(ThemeMode.light));

      await sub.cancel();
    });

    test('clearTemporaryCache empties FileStagingService', () {
      final service = AppSettingsService.instance;
      FileStagingService.instance.addPaths(['mock_chunk_1.bin', 'mock_chunk_2.bin']);
      expect(FileStagingService.instance.count, equals(2));

      final clearedCount = service.clearTemporaryCache();
      expect(clearedCount, equals(2));
      expect(FileStagingService.instance.count, equals(0));
    });

    test('Android capability override produces Android defaults', () {
      PlatformCapabilities.overrideIsAndroid = true;
      final service = AppSettingsService.instance;
      expect(service.deviceName, equals('Android Peer'));
      expect(service.saveLocation, equals('/storage/emulated/0/Download/PeerLink'));
    });
  });
}
