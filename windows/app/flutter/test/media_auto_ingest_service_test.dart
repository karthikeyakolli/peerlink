import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/media_auto_ingest_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';

void main() {
  late Directory cameraDir;

  setUp(() {
    cameraDir = Directory.systemTemp.createTempSync('peerlink_camera_ingest_test_');
    MediaAutoIngestService.instance.resetForTesting();
    FileStagingService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
  });

  tearDown(() {
    MediaAutoIngestService.instance.stopDaemon();
    try {
      cameraDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('MediaAutoIngestService Unit Tests (Camera & Media Auto-Ingestion)', () {
    test('Configures directories and starts/stops background daemon', () {
      final service = MediaAutoIngestService.instance;
      expect(service.isRunning, isFalse);

      service.configure(
        directories: [cameraDir.path],
        targetPeerId: 'peer_my_desktop',
        requireWifiOnly: true,
        autoSend: true,
      );

      expect(service.monitoredFolders.length, equals(1));
      service.startDaemon(interval: const Duration(seconds: 1));
      expect(service.isRunning, isTrue);

      service.stopDaemon();
      expect(service.isRunning, isFalse);
    });

    test('Discovers and stages valid camera photos and videos', () async {
      final service = MediaAutoIngestService.instance;
      service.configure(
        directories: [cameraDir.path],
        targetPeerId: 'peer_my_desktop',
        requireWifiOnly: false,
        autoSend: true,
      );

      // Create a valid JPEG file
      final photo = File('${cameraDir.path}/IMG_20261115_Sunset.jpg');
      photo.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);

      // Create a valid PNG file
      final screenshot = File('${cameraDir.path}/Screenshot_20261115.png');
      screenshot.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      final event = await service.scanAndIngest();

      expect(event, isNotNull);
      expect(event!.fileCount, equals(2));
      expect(event.autoDispatched, isTrue);
      expect(event.targetPeerId, equals('peer_my_desktop'));

      // Verified in FileStagingService
      expect(FileStagingService.instance.count, equals(2));

      // Verified in OperationJournalService
      expect(OperationJournalService.instance.operations.length, equals(1));
      expect(OperationJournalService.instance.operations.first.summary, contains('Camera Auto-Ingestion: 2 item(s)'));
    });

    test('Defers ingestion when network is cellular and Wi-Fi is required', () async {
      final service = MediaAutoIngestService.instance;
      service.configure(
        directories: [cameraDir.path],
        targetPeerId: 'peer_my_desktop',
        requireWifiOnly: true,
      );

      // Simulate cellular network
      MediaAutoIngestService.testIsWifiConnected = false;

      final photo = File('${cameraDir.path}/IMG_Cellular.jpg');
      photo.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      final event = await service.scanAndIngest();

      // Ingestion must be deferred
      expect(event, isNull);
      expect(FileStagingService.instance.count, equals(0));

      // Reconnect to Wi-Fi
      MediaAutoIngestService.testIsWifiConnected = true;
      final retryEvent = await service.scanAndIngest();

      expect(retryEvent, isNotNull);
      expect(retryEvent!.fileCount, equals(1));
      expect(FileStagingService.instance.count, equals(1));
    });

    test('Rejects executable disguised as photo via MimeMagicSniffer (Rule 10)', () async {
      final service = MediaAutoIngestService.instance;
      service.configure(
        directories: [cameraDir.path],
        requireWifiOnly: false,
      );

      // Spoofed PE Windows binary with .jpg extension (MZ header)
      final spoofed = File('${cameraDir.path}/malicious_script.jpg');
      spoofed.writeAsBytesSync([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]);

      final event = await service.scanAndIngest();

      expect(event, isNull);
      expect(FileStagingService.instance.count, equals(0));
    });

    test('Deduplicates and does not re-stage unchanged photos', () async {
      final service = MediaAutoIngestService.instance;
      service.configure(
        directories: [cameraDir.path],
        requireWifiOnly: false,
      );

      final photo = File('${cameraDir.path}/Portrait_001.jpg');
      photo.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A]);

      final firstEvent = await service.scanAndIngest();
      expect(firstEvent, isNotNull);
      expect(firstEvent!.fileCount, equals(1));

      // Second scan on unchanged camera directory
      final secondEvent = await service.scanAndIngest();
      expect(secondEvent, isNull);
      expect(FileStagingService.instance.count, equals(1));
    });
  });
}
