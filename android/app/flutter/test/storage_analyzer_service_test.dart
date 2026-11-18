import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/storage_analyzer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_storage_clean_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('StorageAnalyzerService detects cache fragments, APKs, large files, and duplicates', () async {
    final service = StorageAnalyzerService.instance;

    // 1. Create a cache fragment
    final cacheFile = File('${tempDir.path}/download.part');
    cacheFile.writeAsBytesSync(List.filled(1024 * 10, 1)); // 10 KB

    // 2. Create an APK installer
    final apkFile = File('${tempDir.path}/app_release.apk');
    apkFile.writeAsBytesSync(List.filled(1024 * 50, 2)); // 50 KB

    // 3. Create two duplicate files
    final originalFile = File('${tempDir.path}/document_v1.pdf');
    final duplicateFile = File('${tempDir.path}/document_copy.pdf');
    final content = List.generate(1024 * 20, (i) => i % 256); // 20 KB identical content
    originalFile.writeAsBytesSync(content);
    duplicateFile.writeAsBytesSync(content);

    // 4. Create a large file
    final largeFile = File('${tempDir.path}/big_dataset.dat');
    largeFile.writeAsBytesSync(List.filled(1024 * 1024 * 2, 3)); // 2 MB

    // Run analysis with threshold = 1 MB (so big_dataset.dat triggers as large)
    final report = await service.analyzeStorage(
      largeFileThresholdBytes: 1024 * 1024,
      customDirectory: tempDir,
    );

    expect(report.cacheFragments.length, 1);
    expect(report.cacheFragments.first.name, 'download.part');

    expect(report.redundantApks.length, 1);
    expect(report.redundantApks.first.name, 'app_release.apk');

    expect(report.duplicateGroups.length, 1);
    expect(report.duplicateGroups.first.files.length, 2);
    expect(report.duplicateGroups.first.reclaimableBytes, 1024 * 20);

    expect(report.largeFiles.length, 1);
    expect(report.largeFiles.first.name, 'big_dataset.dat');

    expect(report.totalReclaimableBytes, greaterThan(0));
    expect(report.formattedReclaimableBytes.isNotEmpty, true);

    // Test Purge
    final purged = await service.purgeAllCacheFragments(report.cacheFragments);
    expect(purged, 1);
    expect(cacheFile.existsSync(), false);
  });
}
