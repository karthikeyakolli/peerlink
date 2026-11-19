import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peerlink/core/services/virus_scanner_service.dart';
import 'package:peerlink/core/services/torrent_download_service.dart';
import 'package:peerlink/design_system/components/torrent_downloader_sheet.dart';
import 'package:peerlink/design_system/components/virus_scanner_sheet.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/features/media/media_hub_flow_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_torrent_test_');
  });

  tearDown(() {
    TorrentDownloadService.instance.clearAll();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('VirusScannerService Unit Tests (Zero-Trust Security & Antivirus)', () {
    final scanner = VirusScannerService.instance;

    test('Clean image and video bytes return ThreatLevel.clean with 0 threats', () {
      // Synthetic genuine JPEG header
      final cleanJpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB,
      ]);
      final report = scanner.scanBytes(cleanJpeg, 'landscape.jpg');
      expect(report.isClean, isTrue);
      expect(report.threatLevel, equals(ThreatLevel.clean));
      expect(report.sha256.length, equals(64));
      expect(report.md5.length, equals(32));
      expect(report.summary, contains('0 threats detected'));
    });

    test('Detects official EICAR antivirus test signature and returns ThreatLevel.malicious', () {
      final eicarBytes = Uint8List.fromList(VirusScannerService.eicarSignature.codeUnits);
      final report = scanner.scanBytes(eicarBytes, 'eicar_sample.com');
      expect(report.isClean, isFalse);
      expect(report.threatLevel, equals(ThreatLevel.malicious));
      expect(report.threatName, equals('EICAR.StandardAntivirusTestSignature'));
    });

    test('Traps disguised PE/MZ executable masquerading as a JPEG or MP4', () {
      // Executable MZ header inside a file named vacation_photo.jpg
      final disguisedBytes = Uint8List.fromList([
        0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00,
      ]);
      final report = scanner.scanBytes(disguisedBytes, 'vacation_photo.jpg');
      expect(report.isClean, isFalse);
      expect(report.threatLevel, equals(ThreatLevel.malicious));
      expect(report.threatName, contains('MasqueradedExecutable'));
    });

    test('Traps double extension malware trap (e.g. blockbuster_movie.mp4.exe)', () {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final report = scanner.scanBytes(dummyBytes, 'blockbuster_movie.mp4.exe');
      expect(report.isClean, isFalse);
      expect(report.threatLevel, equals(ThreatLevel.malicious));
      expect(report.threatName, equals('Trojan.DisguisedDoubleExtension'));
    });

    test('Entropy calculator correctly identifies low and high entropy distributions', () {
      final zeroBytes = Uint8List.fromList(List.filled(256, 0));
      final zeroEntropy = scanner.calculateEntropy(zeroBytes);
      expect(zeroEntropy, equals(0.0));

      final uniformBytes = Uint8List.fromList(List.generate(256, (i) => i));
      final uniformEntropy = scanner.calculateEntropy(uniformBytes);
      expect(uniformEntropy, closeTo(8.0, 0.01));
    });
  });

  group('TorrentDownloadService Unit Tests (Web Swarm & Torrent Engine)', () {
    final torrentService = TorrentDownloadService.instance;

    test('Parses Magnet URI components accurately', () {
      const magnet = 'magnet:?xt=urn:btih:DD8255ECDC7CA55FB0BBF81323D87062DB1F6D1C&dn=Big_Buck_Bunny.mp4&xl=85000000&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337';
      final parsed = TorrentDownloadService.parseMagnetUri(magnet);

      expect(parsed['infoHash'], equals('DD8255ECDC7CA55FB0BBF81323D87062DB1F6D1C'));
      expect(parsed['name'], equals('Big_Buck_Bunny.mp4'));
      expect(parsed['size'], equals('85000000'));
      expect(parsed['trackers'], contains('tracker.opentrackr.org'));
    });

    test('Adds magnet link, progresses download, and maintains telemetry', () {
      const magnet = 'magnet:?xt=urn:btih:3B879FBC9B7B9EF896E3B5E408544C06CFB332B7&dn=Hubble_HDR.jpg&xl=14200000';
      final item = torrentService.addMagnetLink(magnet, startImmediately: true);

      expect(item.id, equals('3B879FBC9B7B9EF896E3B5E408544C06CFB332B7'));
      expect(item.name, equals('Hubble_HDR.jpg'));
      expect(item.totalBytes, equals(14200000));
      expect(item.status, isNot(equals(TorrentStatus.error)));

      torrentService.pauseTorrent(item.id);
      expect(item.status, equals(TorrentStatus.paused));

      torrentService.resumeTorrent(item.id);
      expect(item.status, equals(TorrentStatus.downloading));

      torrentService.cancelTorrent(item.id);
      expect(torrentService.activeTorrents.any((t) => t.id == item.id), isFalse);
    });
  });

  group('Torrent & Antivirus Widget Integration Tests', () {
    testWidgets('TorrentDownloaderSheet renders magnet input, presets, and download action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TorrentDownloaderSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Torrent & Web Downloader'), findsOneWidget);
      expect(find.byKey(const Key('torrent_magnet_input_field')), findsOneWidget);
      expect(find.byKey(const Key('add_torrent_button')), findsOneWidget);
      expect(find.byKey(const Key('preset_Big Buck Bunny (4K 60fps Video)')), findsOneWidget);
      expect(find.byKey(const Key('preset_NASA Hubble Deep Field (HDR Photo)')), findsOneWidget);
    });

    testWidgets('VirusScannerSheet renders checklist, hashes, and clean status', (tester) async {
      final tempFile = File('${tempDir.path}/sample_clean.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);

      final dummyReport = VirusScanReport(
        fileName: 'sample_clean.jpg',
        filePath: tempFile.path,
        fileSizeBytes: 10,
        threatLevel: ThreatLevel.clean,
        summary: 'Virus-Free: Multi-vector heuristic & signature analysis completed. 0 threats detected.',
        entropy: 3.12,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        md5: 'd41d8cd98f00b204e9800998ecf8427e',
        scanDurationMs: 4,
        scannedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VirusScannerSheet(filePath: tempFile.path, initialReport: dummyReport),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Virus-Free Antivirus Audit'), findsOneWidget);
      expect(find.text('Security Inspection Checklist'), findsOneWidget);
      expect(find.text('Cryptographic Hashes'), findsOneWidget);
    });

    testWidgets('MediaHubFlowView renders Torrent Downloader and Virus Scan buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaHubFlowView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open_torrent_downloader_button')), findsOneWidget);
      expect(find.byKey(const Key('open_virus_scanner_button')), findsOneWidget);
    });
  });
}
