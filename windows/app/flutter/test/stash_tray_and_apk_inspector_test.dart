import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_stash_tray_service.dart';
import 'package:peerlink/core/apk_inspector_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/archive_extractor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stash_apk_test_');
    FileStashTrayService.instance.resetForTesting();
  });

  tearDown(() {
    FileStashTrayService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Task 2 — FileStashTrayService Suite', () {
    test('stashes items, supports tag assignment and batch copy/zip', () async {
      final f1 = File('${tempDir.path}/photo.jpg')..writeAsStringSync('PHOTO_BYTES');
      final f2 = File('${tempDir.path}/doc.pdf')..writeAsStringSync('PDF_BYTES');

      final item1 = ReceivedFileItem(
        path: f1.path,
        name: 'photo.jpg',
        extension: '.jpg',
        sizeBytes: 11,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.photos,
      );
      final item2 = ReceivedFileItem(
        path: f2.path,
        name: 'doc.pdf',
        extension: '.pdf',
        sizeBytes: 9,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
      );

      final stash = FileStashTrayService.instance;
      stash.stashMultiple([item1, item2]);

      expect(stash.count, 2);
      expect(stash.isStashed(f1.path), isTrue);

      stash.assignColorTag(f1.path, 'emerald');
      expect(stash.getColorTag(f1.path), 'emerald');

      // Test batch copy to a new subfolder
      final targetFolder = '${tempDir.path}/batch_copied';
      final copiedCount = await stash.copyAllTo(targetFolder);
      expect(copiedCount, 2);
      expect(File('$targetFolder/photo.jpg').existsSync(), isTrue);
      expect(File('$targetFolder/doc.pdf').existsSync(), isTrue);

      // Test batch zip
      final zipPath = '${tempDir.path}/stashed_bundle.zip';
      final zipResult = await stash.compressAllIntoZip(zipPath);
      expect(zipResult, isNotNull);
      expect(File(zipResult!).existsSync(), isTrue);

      // Remove single item and clear
      stash.removeItem(f1.path);
      expect(stash.count, 1);
      stash.clearStash();
      expect(stash.isEmpty, isTrue);
    });
  });

  group('Task 2 — ApkInspectorService Suite', () {
    test('statically inspects APK structure without execution (Rule 10/11)', () async {
      // Create a mock APK containing AndroidManifest.xml and META-INF
      final manifestFile = File('${tempDir.path}/AndroidManifest.xml')
        ..writeAsStringSync('org.peerlink.testapp android.permission.INTERNET android.permission.CAMERA');
      final certFile = File('${tempDir.path}/CERT.RSA')..writeAsBytesSync([10, 20, 30, 40]);

      final apkPath = '${tempDir.path}/sample_test.apk';
      await ArchiveExtractorService.instance.createZip([manifestFile.path, certFile.path], apkPath);

      final details = await ApkInspectorService.instance.inspectApk(apkPath);

      expect(details.fileName, 'sample_test.apk');
      expect(details.isSigned, isTrue);
      expect(details.permissions.contains('android.permission.INTERNET'), isTrue);
      expect(details.permissions.contains('android.permission.CAMERA'), isTrue);
      expect(details.highRiskPermissions.contains('android.permission.CAMERA'), isTrue);
    });
  });
}
