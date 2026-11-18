import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/document_inspector_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';
import 'package:peerlink/features/files/received_vault_view.dart';

/// Builds a valid minimal PKZIP archive (supports STORED and DEFLATE entries)
/// so we can test real .docx / .pptx / .xlsx extraction in pure Dart.
Uint8List _buildTestZip(Map<String, List<int>> files, {bool deflate = false}) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  int entryCount = 0;

  for (final entry in files.entries) {
    final nameBytes = utf8.encode(entry.key);
    final rawData = Uint8List.fromList(entry.value);
    final payload = deflate
        ? Uint8List.fromList(ZLibEncoder(raw: true).convert(rawData))
        : rawData;
    final method = deflate ? 8 : 0;
    final localOffset = out.length;

    // Local File Header (30 bytes)
    final lh = ByteData(30);
    lh.setUint32(0, 0x04034b50, Endian.little);
    lh.setUint16(4, 20, Endian.little);
    lh.setUint16(8, method, Endian.little);
    lh.setUint32(18, payload.length, Endian.little);
    lh.setUint32(22, rawData.length, Endian.little);
    lh.setUint16(26, nameBytes.length, Endian.little);
    out.add(lh.buffer.asUint8List());
    out.add(nameBytes);
    out.add(payload);

    // Central Directory Header (46 bytes)
    final cd = ByteData(46);
    cd.setUint32(0, 0x02014b50, Endian.little);
    cd.setUint16(4, 20, Endian.little);
    cd.setUint16(6, 20, Endian.little);
    cd.setUint16(10, method, Endian.little);
    cd.setUint32(20, payload.length, Endian.little);
    cd.setUint32(24, rawData.length, Endian.little);
    cd.setUint16(28, nameBytes.length, Endian.little);
    cd.setUint32(42, localOffset, Endian.little);
    central.add(cd.buffer.asUint8List());
    central.add(nameBytes);
    entryCount++;
  }

  final cdOffset = out.length;
  final cdBytes = central.toBytes();
  out.add(cdBytes);

  // End of Central Directory (22 bytes)
  final eocd = ByteData(22);
  eocd.setUint32(0, 0x06054b50, Endian.little);
  eocd.setUint16(8, entryCount, Endian.little);
  eocd.setUint16(10, entryCount, Endian.little);
  eocd.setUint32(12, cdBytes.length, Endian.little);
  eocd.setUint32(16, cdOffset, Endian.little);
  out.add(eocd.buffer.asUint8List());

  return out.toBytes();
}

void main() {
  group('Universal Document & Binary Inspector Service', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_universal_viewer_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('extracts readable paragraphs from DEFLATE-compressed DOCX archive', () async {
      const wordXml =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<w:document><w:body>'
          '<w:p><w:r><w:t>PeerLink Architecture &amp; Report</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Verified zero-loss transfer complete.</w:t></w:r></w:p>'
          '</w:body></w:document>';
      final docxBytes = _buildTestZip(
        {'word/document.xml': utf8.encode(wordXml)},
        deflate: true,
      );
      final docxFile = File('${tempDir.path}/report.docx')..writeAsBytesSync(docxBytes);

      final preview = await DocumentInspectorService.instance.extractOfficeText(docxFile.path, 'docx');
      expect(preview.hasContent, isTrue);
      expect(preview.documentType, contains('DOCX'));
      expect(preview.extractedText, contains('PeerLink Architecture & Report'));
      expect(preview.extractedText, contains('Verified zero-loss transfer complete.'));
    });

    test('parses CSV with quoted commas into clean headers and rows', () {
      const csvRaw = 'Name,Role,City\n"Alice, A.",Engineer,Hyderabad\nBob,Designer,Bengaluru\n';
      final parsed = DocumentInspectorService.instance.parseCsvTable(csvRaw);
      expect(parsed.headers, ['Name', 'Role', 'City']);
      expect(parsed.rows.length, 2);
      expect(parsed.rows[0], ['Alice, A.', 'Engineer', 'Hyderabad']);
      expect(parsed.rows[1], ['Bob', 'Designer', 'Bengaluru']);
    });

    test('pretty prints JSON and detects magic-byte binary signatures', () {
      final pretty = DocumentInspectorService.instance.prettyPrintJson('{"peer":"ok","v":2}');
      expect(pretty, contains('\n  "peer": "ok"'));

      final pngFile = File('${tempDir.path}/mystery.dat')
        ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01]);
      final inspection = DocumentInspectorService.instance.inspectBinaryFile(pngFile.path);
      expect(inspection.detectedType, 'PNG Image');
      expect(inspection.magicHex, startsWith('89 50 4E 47'));
      expect(inspection.hexLines, isNotEmpty);
    });
  });

  group('MediaPreviewModal Universal Engine Widget Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_modal_universal_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders CSV file as interactive DataTable with zero gradients/shadows', (tester) async {
      final csvFile = File('${tempDir.path}/metrics.csv')
        ..writeAsStringSync('Metric,Value\nThroughput,420 MB/s\nLoss,0%\n');
      final item = ReceivedFileItem(
        path: csvFile.path,
        name: 'metrics.csv',
        sizeBytes: csvFile.lengthSync(),
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
        extension: 'csv',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 480, height: 860, child: MediaPreviewModal(fileItem: item)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('csv_data_table')), findsOneWidget);
      expect(find.text('Throughput'), findsOneWidget);
      expect(find.text('420 MB/s'), findsOneWidget);

      // Verify strict minimalist light surface: zero gradients, zero BoxShadows
      for (final w in tester.allWidgets) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          expect(dec.gradient, isNull);
          expect(dec.boxShadow, isNull);
        }
      }
    });

    testWidgets('renders Office DOCX text directly in-app', (tester) async {
      const wordXml = '<w:document><w:body><w:p><w:r><w:t>Live Office Preview Works</w:t></w:r></w:p></w:body></w:document>';
      final docxFile = File('${tempDir.path}/brief.docx')
        ..writeAsBytesSync(_buildTestZip({'word/document.xml': utf8.encode(wordXml)}, deflate: true));

      final item = ReceivedFileItem(
        path: docxFile.path,
        name: 'brief.docx',
        sizeBytes: docxFile.lengthSync(),
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
        extension: 'docx',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 480, height: 860, child: MediaPreviewModal(fileItem: item)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('office_document_reader')), findsOneWidget);
      expect(find.textContaining('Live Office Preview Works'), findsOneWidget);
    });

    testWidgets('renders Universal Binary Inspector with Magic-Byte detection & Hex dump', (tester) async {
      final binFile = File('${tempDir.path}/blob.custombin')
        ..writeAsBytesSync([0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x00, 0x01, 0x02]);
      final item = ReceivedFileItem(
        path: binFile.path,
        name: 'blob.custombin',
        sizeBytes: binFile.lengthSync(),
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.other,
        extension: 'custombin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 480, height: 860, child: MediaPreviewModal(fileItem: item)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SQLite 3 Database'), findsOneWidget);
      expect(find.byKey(const Key('binary_hex_dump')), findsOneWidget);
    });
  });

  group('Transferred File Visibility & Auto-Refresh Verification', () {
    late Directory tempVault;
    late String previousSaveLocation;

    setUp(() {
      previousSaveLocation = AppSettingsService.instance.saveLocation;
      tempVault = Directory.systemTemp.createTempSync('peerlink_visibility_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
    });

    tearDown(() {
      AppSettingsService.instance.saveLocation = previousSaveLocation;
      try {
        if (tempVault.existsSync()) tempVault.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('ReceivedVaultView automatically surfaces newly transferred file on transferCompleted event', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 430, height: 900, child: ReceivedVaultView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('freshly_beamed.txt'), findsNothing);

      // Simulate daemon completing an inbound file write into the PeerLink Vault
      File('${tempVault.path}/freshly_beamed.txt')
          .writeAsStringSync('Verified real-time visibility payload!');

      // Notify vault listeners of completed transfer
      ReceivedFilesService.instance.notifyChanged();

      await tester.pumpAndSettle();

      expect(find.text('freshly_beamed.txt'), findsWidgets);
    });
  });
}
