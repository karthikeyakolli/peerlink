import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/features/files/files_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    FileStagingService.instance.resetForTesting();
    tempDir = Directory.systemTemp.createTempSync('peerlink_dir_test_');
  });

  tearDown(() {
    FileStagingService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Single file staging computes size correctly', () {
    final file = File('${tempDir.path}/test_doc.txt');
    file.writeAsStringSync('Hello PeerLink 12345');

    FileStagingService.instance.addPaths([file.path]);

    expect(FileStagingService.instance.count, equals(1));
    final item = FileStagingService.instance.stagedFiles.first;
    expect(item.name, equals('test_doc.txt'));
    expect(item.isDirectory, isFalse);
    expect(item.sizeBytes, equals(file.lengthSync()));
    expect(item.formattedSize, contains('B'));
  });

  test('Directory staging recursively calculates file count and total size', () {
    final subDirA = Directory('${tempDir.path}/folder_a')..createSync();
    final subDirB = Directory('${tempDir.path}/folder_a/nested_b')..createSync();

    final f1 = File('${subDirA.path}/file1.bin')..writeAsBytesSync(List.filled(1024, 1));
    final f2 = File('${subDirB.path}/file2.bin')..writeAsBytesSync(List.filled(2048, 2));

    FileStagingService.instance.addPaths([subDirA.path]);

    expect(FileStagingService.instance.count, equals(1));
    final item = FileStagingService.instance.stagedFiles.first;
    expect(item.isDirectory, isTrue);
    expect(item.fileCount, equals(2));
    expect(item.sizeBytes, equals(1024 + 2048));
    expect(item.formattedSize, equals('2 files (3.0 KB)'));
  });

  test('Empty directory staging displays Folder', () {
    final emptyDir = Directory('${tempDir.path}/empty_dir')..createSync();

    FileStagingService.instance.addPaths([emptyDir.path]);

    final item = FileStagingService.instance.stagedFiles.first;
    expect(item.isDirectory, isTrue);
    expect(item.fileCount, equals(0));
    expect(item.formattedSize, equals('Folder'));
  });

  testWidgets('FilesScreen restores and displays staged directory with file count and size', (tester) async {
    final subDir = Directory('${tempDir.path}/my_bundle')..createSync();
    File('${subDir.path}/a.txt').writeAsStringSync('12345');
    File('${subDir.path}/b.txt').writeAsStringSync('67890');

    FileStagingService.instance.addPaths([subDir.path]);

    await tester.pumpWidget(
      const MaterialApp(
        home: FilesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('my_bundle'), findsOneWidget);
    expect(find.text('2 files (10 B)'), findsOneWidget);
    expect(find.byIcon(Icons.folder_rounded), findsWidgets);
  });
}
