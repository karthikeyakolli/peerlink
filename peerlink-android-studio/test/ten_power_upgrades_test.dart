import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/batch_rename_service.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/exif_scrubber_service.dart';
import 'package:peerlink/core/file_integrity_diff_service.dart';
import 'package:peerlink/core/inbox_routing_service.dart';
import 'package:peerlink/core/lan_media_stream_service.dart';
import 'package:peerlink/core/storage_analyzer_service.dart';
import 'package:peerlink/core/universal_clipboard_service.dart';
import 'package:peerlink/core/web_beam_server_service.dart';
import 'package:peerlink/design_system/components/auto_sort_rules_sheet.dart';
import 'package:peerlink/design_system/components/batch_rename_dialog.dart';
import 'package:peerlink/design_system/components/file_hash_diff_sheet.dart';
import 'package:peerlink/design_system/components/universal_clipboard_sheet.dart';
import 'package:peerlink/features/devices/devices_screen.dart';

void main() {
  group('#1 Universal Clipboard Sync', () {
    setUp(() {
      UniversalClipboardService.instance.clearHistory();
      UniversalClipboardService.instance.setSyncEnabled(false);
    });

    test('marks 6-digit OTP as auto-expiring and stores history cleanly', () {
      final clip = UniversalClipboardService.instance;
      clip.setSyncEnabled(true);
      final otp = clip.recordSyncedClip('482910', sourceDevice: 'Phone');
      final link = clip.recordSyncedClip('https://peerlink.local/doc', sourceDevice: 'Laptop');

      expect(otp.autoExpire, isTrue);
      expect(otp.expiresAt, isNotNull);
      expect(link.autoExpire, isFalse);
      expect(clip.activeEntries.length, 2);
      expect(clip.activeEntries.first.text, 'https://peerlink.local/doc');
    });

    testWidgets('UniversalClipboardSheet toggles sync and pushes clips with zero gradients/shadows', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UniversalClipboardSheet())));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('universal_clipboard_input_field')), 'Hello synced clipboard');
      await tester.tap(find.byKey(const Key('universal_clipboard_push_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hello synced clipboard'), findsOneWidget);
      _assertZeroGradientsOrShadows(tester);
    });
  });

  group('#3 Visual Storage Analyzer & SHA-256 Duplicate Cleaner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_analyzer_v2_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('computes category bytes, largest folders, and exact SHA-256 duplicates', () async {
      final sub = Directory('${tempDir.path}/Trips')..createSync();
      File('${sub.path}/a.jpg').writeAsBytesSync(List<int>.filled(4096, 7));
      File('${sub.path}/a_copy.jpg').writeAsBytesSync(List<int>.filled(4096, 7));
      File('${tempDir.path}/notes.txt').writeAsStringSync('hello world storage analyzer');

      final report = await StorageAnalyzerService.instance.analyzeStorage(customDirectory: tempDir);
      expect(report.totalScannedBytes, greaterThan(8000));
      expect(report.categoryBytes.isNotEmpty, isTrue);
      expect(report.largestFolders.first.name, 'Trips');
      expect(report.duplicateGroups.length, 1);
      expect(report.duplicateGroups.first.files.length, 2);
    });
  });

  group('#4 Batch File Renamer with Live Preview', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_batch_rename_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('applies sequential numbering cleanly and preserves extensions', () async {
      final f1 = File('${tempDir.path}/IMG_991.jpg')..writeAsBytesSync([1, 2]);
      final f2 = File('${tempDir.path}/IMG_992.jpg')..writeAsBytesSync([3, 4]);

      final preview = BatchRenameService.instance.buildPreview(
        [f1.path, f2.path],
        const BatchRenameRule(
          useSequentialNumbering: true,
          sequenceBaseName: 'Holiday_',
          startNumber: 1,
          padWidth: 3,
        ),
      );
      expect(preview[0].newName, 'Holiday_001.jpg');
      expect(preview[1].newName, 'Holiday_002.jpg');

      final result = await BatchRenameService.instance.applyRename(preview);
      expect(result.renamedCount, 2);
      expect(File('${tempDir.path}/Holiday_001.jpg').existsSync(), isTrue);
      expect(File('${tempDir.path}/Holiday_002.jpg').existsSync(), isTrue);
    });

    testWidgets('BatchRenameDialog renders live preview cleanly', (tester) async {
      final f1 = File('${tempDir.path}/doc.txt')..writeAsStringSync('x');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BatchRenameDialog(paths: [f1.path]))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('batch_prefix_field')), '2026_');
      await tester.pumpAndSettle();
      expect(find.text('2026_doc.txt'), findsOneWidget);
      _assertZeroGradientsOrShadows(tester);
    });
  });

  group('#5 Direct IP Connect Fallback & Pinned Trusted Devices', () {
    testWidgets('DevicesScreen pins direct IP peer via Direct IP dialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DevicesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('devices_direct_ip_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('direct_ip_host_field')), '192.168.1.99');
      await tester.enterText(find.byKey(const Key('direct_ip_name_field')), 'Studio PC');
      await tester.tap(find.byKey(const Key('direct_ip_connect_submit_button')));
      await tester.pumpAndSettle();

      expect(DeviceTrustService.instance.isPinned('192.168.1.99:8765'), isTrue);
      expect(
        DeviceTrustService.instance.sortedDevices.any((d) => d.name == 'Studio PC'),
        isTrue,
      );
    });
  });

  group('#6 Stream Without Downloading (HTTP 206 Range + Rule 12 Token)', () {
    late Directory tempDir;
    HttpOverrides? prevOverrides;

    setUp(() {
      prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      tempDir = Directory.systemTemp.createTempSync('peerlink_lan_stream_');
    });

    tearDown(() async {
      await LanMediaStreamService.instance.stopHosting();
      HttpOverrides.global = prevOverrides;
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('enforces token auth (403 on bad token) and serves 206 Partial Content byte ranges', () async {
      File('${tempDir.path}/movie.mp4').writeAsBytesSync(utf8.encode('0123456789ABCDEFGHIJ'));

      final state = await LanMediaStreamService.instance.startHostingFolder(directoryPath: tempDir.path);
      expect(state.isHosting, isTrue);

      final client = HttpClient();
      try {
        // Failure path (Rule 12): missing/invalid token must return 403 Forbidden
        final badReq = await client.getUrl(Uri.parse('http://127.0.0.1:${state.port}/api/list?token=wrong'));
        final badRes = await badReq.close();
        expect(badRes.statusCode, HttpStatus.forbidden);
        await badRes.drain();

        // Valid API directory listing
        final items = await LanMediaStreamService.instance.fetchRemoteDirectory(
          'http://127.0.0.1:${state.port}/?token=${state.token}',
        );
        expect(items.length, 1);
        expect(items.first.name, 'movie.mp4');

        // Valid HTTP 206 Range request (first 10 bytes)
        final rangeReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:${state.port}/stream?token=${state.token}&path=movie.mp4'),
        );
        rangeReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-9');
        final rangeRes = await rangeReq.close();
        expect(rangeRes.statusCode, HttpStatus.partialContent);
        final body = await utf8.decoder.bind(rangeRes).join();
        expect(body, '0123456789');
      } finally {
        client.close(force: true);
      }
    });
  });

  group('#7 Upgraded Web Beam (Media Gallery + Download All ZIP + Burn After Download)', () {
    late Directory tempDir;
    HttpOverrides? prevOverrides;

    setUp(() {
      prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      tempDir = Directory.systemTemp.createTempSync('peerlink_web_beam_v2_');
    });

    tearDown(() async {
      await WebBeamServerService.instance.stop();
      HttpOverrides.global = prevOverrides;
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('serves media gallery HTML, valid ZIP bundle, and auto-stops on burn-after-download', () async {
      final img = File('${tempDir.path}/pic.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      final txt = File('${tempDir.path}/readme.txt')..writeAsStringSync('Web Beam Gallery Test');

      final session = await WebBeamServerService.instance.start(
        paths: [img.path, txt.path],
        preferredPort: 0,
        overrideHostIp: '127.0.0.1',
        burnAfterDownload: true,
      );
      expect(session.isRunning, isTrue);

      final client = HttpClient();
      try {
        // Portal HTML includes gallery img + Download All as ZIP
        final htmlReq = await client.getUrl(Uri.parse(session.portalUrl));
        final htmlRes = await htmlReq.close();
        expect(htmlRes.statusCode, HttpStatus.ok);
        final html = await utf8.decoder.bind(htmlRes).join();
        expect(html, contains('Download All as ZIP'));
        expect(html, contains('/preview/0?token='));
        expect(html, contains('Burn After Download'));

        // Download All as ZIP returns real PKZIP header & triggers burn-after-download stop
        final zipReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:${session.port}/download-all.zip?token=${session.token}'),
        );
        final zipRes = await zipReq.close();
        expect(zipRes.statusCode, HttpStatus.ok);
        final zipBytes = await zipRes.expand((b) => b).toList();
        expect(zipBytes.length, greaterThan(22));
        expect(zipBytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]); // PK\x03\x04

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(WebBeamServerService.instance.currentState.isRunning, isFalse);
      } finally {
        client.close(force: true);
      }
    });
  });

  group('#8 Privacy EXIF / GPS Scrubber', () {
    test('strips APP1 EXIF/GPS segment from JPEG while keeping SOI, SOS, and EOI intact', () {
      // Minimal synthetic JPEG: SOI + APP1(EXIF GPS payload) + SOS + image data + EOI
      final exifPayload = utf8.encode('Exif\x00\x00GPS_LAT_17.3850');
      final app1Len = exifPayload.length + 2;
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xE1, (app1Len >> 8) & 0xFF, app1Len & 0xFF, ...exifPayload, // APP1 EXIF
        0xFF, 0xDA, 0x00, 0x02, 0xAA, 0xBB, // SOS + scan bytes
        0xFF, 0xD9, // EOI
      ]);

      final res = ExifScrubberService.instance.scrubJpegBytes(jpeg);
      expect(res.stripped, contains('APP1 (EXIF/GPS/XMP)'));
      expect(res.bytes.sublist(0, 2), [0xFF, 0xD8]);
      expect(res.bytes.sublist(res.bytes.length - 2), [0xFF, 0xD9]);
      expect(String.fromCharCodes(res.bytes), isNot(contains('GPS_LAT')));
    });

    test('strips PNG eXIf and tEXt metadata chunks while keeping IHDR and IEND', () {
      List<int> makeChunk(String type, List<int> data) {
        final len = ByteData(4)..setUint32(0, data.length, Endian.big);
        return [...len.buffer.asUint8List(), ...utf8.encode(type), ...data, 0, 0, 0, 0];
      }

      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        ...makeChunk('IHDR', [1, 2, 3]),
        ...makeChunk('tEXt', utf8.encode('Author\x00SecretCamera')),
        ...makeChunk('eXIf', utf8.encode('GPS_COORDS')),
        ...makeChunk('IEND', []),
      ]);

      final res = ExifScrubberService.instance.scrubPngBytes(png);
      expect(res.stripped, containsAll(['PNG tEXt', 'PNG eXIf']));
      expect(String.fromCharCodes(res.bytes), isNot(contains('SecretCamera')));
      expect(String.fromCharCodes(res.bytes), contains('IHDR'));
      expect(String.fromCharCodes(res.bytes), contains('IEND'));
    });
  });

  group('#9 Deterministic Auto-Sort Inbox Rules', () {
    late Directory tempVault;
    late String previousSaveLocation;

    setUp(() {
      previousSaveLocation = AppSettingsService.instance.saveLocation;
      tempVault = Directory.systemTemp.createTempSync('peerlink_autosort_');
      AppSettingsService.instance.saveLocation = tempVault.path;
    });

    tearDown(() {
      AppSettingsService.instance.saveLocation = previousSaveLocation;
      try {
        if (tempVault.existsSync()) tempVault.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('routes root Vault photos and PDFs deterministically into subfolders', () async {
      File('${tempVault.path}/beach.jpg').writeAsBytesSync([1, 2, 3]);
      File('${tempVault.path}/invoice.pdf').writeAsBytesSync([4, 5, 6]);

      final planned = InboxRoutingService.instance.previewAutoSort(vaultDir: tempVault);
      expect(planned.length, 2);

      final moved = await InboxRoutingService.instance.applyAutoSort(vaultDir: tempVault);
      expect(moved, 2);
      expect(File('${tempVault.path}/Pictures/beach.jpg').existsSync(), isTrue);
      expect(File('${tempVault.path}/Documents/invoice.pdf').existsSync(), isTrue);
    });

    testWidgets('AutoSortRulesSheet renders dry-run preview cleanly', (tester) async {
      File('${tempVault.path}/sample.pdf').writeAsBytesSync([1, 2]);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AutoSortRulesSheet())));
      await tester.pumpAndSettle();

      expect(find.text('Auto-Sort Inbox Rules'), findsOneWidget);
      expect(find.text('sample.pdf'), findsOneWidget);
      _assertZeroGradientsOrShadows(tester);
    });
  });

  group('#10 File Hash Verifier (SHA-256 / MD5) & Text Diff Viewer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_hash_diff_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('verifies SHA-256/MD5 checksums and computes line-by-line LCS text diff', () {
      final f = File('${tempDir.path}/payload.txt')..writeAsStringSync('peerlink');
      final report = FileIntegrityDiffService.instance.computeChecksumsSync(f.path);
      expect(report.sha256Hex.length, 64);
      expect(report.md5Hex.length, 32);
      expect(report.matchesExpected(report.sha256Hex), isTrue);
      expect(report.matchesExpected('0000000000000000'), isFalse);

      final diff = FileIntegrityDiffService.instance.diffText('line1\nold line\nline3', 'line1\nnew line\nline3');
      expect(diff.addedCount, 1);
      expect(diff.removedCount, 1);
      expect(diff.unchangedCount, 2);
    });

    testWidgets('FileHashDiffSheet verifies checksum match & renders text diff cleanly', (tester) async {
      final left = File('${tempDir.path}/a.txt')..writeAsStringSync('alpha\nbeta');
      final right = File('${tempDir.path}/b.txt')..writeAsStringSync('alpha\ngamma');
      final expectedSha = FileIntegrityDiffService.instance.computeChecksumsSync(left.path).sha256Hex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileHashDiffSheet(primaryFilePath: left.path, primaryFileName: 'a.txt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expected_checksum_field')), expectedSha);
      await tester.pumpAndSettle();
      expect(find.textContaining('Checksum Verified'), findsOneWidget);
      _assertZeroGradientsOrShadows(tester);

      // Diff view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileHashDiffSheet(
              primaryFilePath: left.path,
              primaryFileName: 'a.txt',
              compareFilePath: right.path,
              compareFileName: 'b.txt',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('text_diff_container')), findsOneWidget);
      expect(find.text('+1 added'), findsOneWidget);
      expect(find.text('-1 removed'), findsOneWidget);
    });
  });
}

void _assertZeroGradientsOrShadows(WidgetTester tester) {
  for (final w in tester.allWidgets) {
    if (w is Container && w.decoration is BoxDecoration) {
      final dec = w.decoration as BoxDecoration;
      expect(dec.gradient, isNull);
      expect(dec.boxShadow, isNull);
    }
  }
}
