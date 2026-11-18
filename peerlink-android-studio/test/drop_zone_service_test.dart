import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/drop_zone_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_dropzone_test_');
    DropZoneService.instance.resetForTesting();
    FileStagingService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
    AppSettingsService.instance.resetForTesting();
  });

  tearDown(() {
    DropZoneService.instance.stopWatcher();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DropZoneService Unit Tests (Quick-Beam Watcher Daemon)', () {
    test('Configures, starts, and stops drop zone watchers', () {
      final service = DropZoneService.instance;
      expect(service.isRunning, isFalse);

      service.configureDropZone(
        SmartDropZoneConfig(
          id: 'test_zone',
          folderPath: tempDir.path,
          targetPeerId: 'peer_laptop',
          autoDispatch: false,
          enabled: true,
        ),
      );

      expect(service.zones.length, equals(1));
      expect(service.zones.first.id, equals('test_zone'));

      service.startWatcher();
      expect(service.isRunning, isTrue);

      service.stopWatcher();
      expect(service.isRunning, isFalse);
    });

    test('Ignores temporary and partial write files (Rule 10 Safety)', () async {
      final service = DropZoneService.instance;
      service.configureDropZone(
        SmartDropZoneConfig(
          id: 'zone_filter_test',
          folderPath: tempDir.path,
          targetPeerId: 'peer_phone',
          autoDispatch: true,
          enabled: true,
        ),
      );

      // Create incomplete .part and .tmp files
      final partFile = File('${tempDir.path}/video_stream.mp4.part');
      partFile.writeAsStringSync('partial chunk 1234');

      final tmpFile = File('${tempDir.path}/download.tmp');
      tmpFile.writeAsStringSync('temporary cache');

      final emptyFile = File('${tempDir.path}/zero_byte.pdf');
      emptyFile.writeAsStringSync('');

      final events = await service.sweepDropZones();

      // None of the temporary or zero-byte files should be processed
      expect(events, isEmpty);
      expect(FileStagingService.instance.count, equals(0));
      expect(OperationJournalService.instance.operations, isEmpty);
    });

    test('Deposited valid file is staged into FileStagingService', () async {
      final service = DropZoneService.instance;
      service.configureDropZone(
        SmartDropZoneConfig(
          id: 'zone_stage_test',
          folderPath: tempDir.path,
          autoDispatch: false,
          enabled: true,
        ),
      );

      final validFile = File('${tempDir.path}/quarterly_earnings.xlsx');
      validFile.writeAsStringSync('Financial report data for 2026');

      final events = await service.sweepDropZones();

      expect(events.length, equals(1));
      expect(events.first.fileName, equals('quarterly_earnings.xlsx'));
      expect(events.first.autoDispatched, isFalse);

      // Staged in FileStagingService
      expect(FileStagingService.instance.count, equals(1));
      expect(FileStagingService.instance.stagedFiles.first.name, equals('quarterly_earnings.xlsx'));
    });

    test('Auto-dispatch logs send operation in OperationJournalService', () async {
      final service = DropZoneService.instance;
      service.configureDropZone(
        SmartDropZoneConfig(
          id: 'zone_autodispatch_test',
          folderPath: tempDir.path,
          targetPeerId: 'peer_office_pc',
          autoDispatch: true,
          enabled: true,
        ),
      );

      final dropFile = File('${tempDir.path}/presentation_deck.pdf');
      dropFile.writeAsStringSync('Slide 1: PeerLink Architecture Overview');

      final events = await service.sweepDropZones();

      expect(events.length, equals(1));
      expect(events.first.autoDispatched, isTrue);
      expect(events.first.targetPeerId, equals('peer_office_pc'));

      // Check Journal recorded auto-send intent
      final ops = OperationJournalService.instance.operations;
      expect(ops.length, equals(1));
      expect(ops.first.type, equals(OperationType.send));
      expect(ops.first.peerId, equals('peer_office_pc'));
      expect(ops.first.summary, contains('Auto-Beam: presentation_deck.pdf'));
    });

    test('Prevents duplicate re-dispatch of unchanged files', () async {
      final service = DropZoneService.instance;
      service.configureDropZone(
        SmartDropZoneConfig(
          id: 'zone_dedup_test',
          folderPath: tempDir.path,
          autoDispatch: false,
          enabled: true,
        ),
      );

      final testFile = File('${tempDir.path}/design_specs.docx');
      testFile.writeAsStringSync('Specifications document content');

      final firstEvents = await service.sweepDropZones();
      expect(firstEvents.length, equals(1));

      // Second sweep on unchanged file must yield 0 new events
      final secondEvents = await service.sweepDropZones();
      expect(secondEvents, isEmpty);
      expect(FileStagingService.instance.count, equals(1));
    });
  });
}
