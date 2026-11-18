import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/archive_extractor_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';

/// Helper to generate a minimal valid uncompressed ZIP file in bytes.
Uint8List createMockZipBytes(Map<String, String> fileContents) {
  final buffer = BytesBuilder();

  for (final entry in fileContents.entries) {
    final fileNameBytes = utf8.encode(entry.key);
    final contentBytes = utf8.encode(entry.value);
    final compSize = contentBytes.length;
    final uncompSize = contentBytes.length;

    // Local file header (30 bytes + name + data)
    final localHeader = ByteData(30);
    localHeader.setUint32(0, 0x04034b50, Endian.little); // Signature
    localHeader.setUint16(4, 20, Endian.little); // Version needed
    localHeader.setUint16(6, 0, Endian.little); // Flags
    localHeader.setUint16(8, 0, Endian.little); // Compression (0 = store)
    localHeader.setUint16(10, 0, Endian.little); // Mod time
    localHeader.setUint16(12, 0, Endian.little); // Mod date
    localHeader.setUint32(14, 0, Endian.little); // CRC-32 (mock 0)
    localHeader.setUint32(18, compSize, Endian.little); // Comp size
    localHeader.setUint32(22, uncompSize, Endian.little); // Uncomp size
    localHeader.setUint16(26, fileNameBytes.length, Endian.little); // Filename length
    localHeader.setUint16(28, 0, Endian.little); // Extra length

    buffer.add(localHeader.buffer.asUint8List());
    buffer.add(fileNameBytes);
    buffer.add(contentBytes);
  }

  return buffer.toBytes();
}

void main() {
  group('ArchiveExtractorService Unit & Widget Tests', () {
    late Directory tempDir;
    late String zipPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_zip_test_');
      final zipBytes = createMockZipBytes({
        'hello.txt': 'Hello, PeerLink!',
        'subfolder/data.json': '{"key":"value"}',
      });
      final zipFile = File('${tempDir.path}/bundle.zip');
      zipFile.writeAsBytesSync(zipBytes);
      zipPath = zipFile.path;
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('inspectArchive parses entries, sizes, and file counts accurately', () async {
      final details = await ArchiveExtractorService.instance.inspectArchive(zipPath);
      expect(details.fileCount, 2);
      expect(details.entries.any((e) => e.path == 'hello.txt'), isTrue);
      expect(details.entries.any((e) => e.path == 'subfolder/data.json'), isTrue);
      expect(details.totalUncompressedSize, greaterThan(0));
    });

    test('createZip compresses files into valid PKZIP and extractArchive unpacks them', () async {
      final file1 = File('${tempDir.path}/test_a.txt')..writeAsStringSync('Alpha text content');
      final file2 = File('${tempDir.path}/test_b.json')..writeAsStringSync('{"status":"ok"}');
      final outZip = '${tempDir.path}/packed_archive.zip';

      final resultPath = await ArchiveExtractorService.instance.createZip([file1.path, file2.path], outZip);
      expect(File(resultPath).existsSync(), isTrue);

      final inspect = await ArchiveExtractorService.instance.inspectArchive(resultPath);
      expect(inspect.fileCount, 2);
      expect(inspect.entries.any((e) => e.name == 'test_a.txt'), isTrue);
      expect(inspect.entries.any((e) => e.name == 'test_b.json'), isTrue);

      final extractedDir = await ArchiveExtractorService.instance.extractArchive(resultPath);
      expect(Directory(extractedDir).existsSync(), isTrue);
      expect(File('$extractedDir/test_a.txt').existsSync(), isTrue);
      expect(File('$extractedDir/test_a.txt').readAsStringSync(), 'Alpha text content');
    });

    testWidgets('MediaPreviewModal renders ZIP archive inspector and Extract All button', (tester) async {
      const details = ArchiveDetails(
        archivePath: 'mock_path/bundle.zip',
        entries: [
          ArchiveEntry(
            path: 'hello.txt',
            name: 'hello.txt',
            compressedSize: 16,
            uncompressedSize: 16,
            isDirectory: false,
          ),
          ArchiveEntry(
            path: 'subfolder/data.json',
            name: 'data.json',
            compressedSize: 15,
            uncompressedSize: 15,
            isDirectory: false,
          ),
        ],
        totalUncompressedSize: 31,
        totalCompressedSize: 31,
        fileCount: 2,
        folderCount: 0,
      );

      final item = ReceivedFileItem(
        path: zipPath,
        name: 'bundle.zip',
        sizeBytes: 500,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.archives,
        extension: 'zip',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaPreviewModal(
              fileItem: item,
              initialArchiveDetails: details,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header, file list, and Extract button are rendered
      expect(find.text('ZIP Archive Inspector'), findsOneWidget);
      expect(find.byKey(const Key('extract_archive_button')), findsOneWidget);
      expect(find.text('hello.txt', skipOffstage: false), findsOneWidget);
      expect(find.text('subfolder/data.json', skipOffstage: false), findsOneWidget);
    });
  });
}
