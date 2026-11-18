import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/pdf_power_suite_service.dart';
import 'package:peerlink/core/expiring_beam_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pdf_beam_test_');
    ExpiringBeamLinkService.instance.resetForTesting();
  });

  tearDown(() {
    ExpiringBeamLinkService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Task 4 — PdfPowerSuiteService Suite', () {
    test('merges multiple text files into a valid multi-page PDF 1.4', () async {
      final doc1 = File('${tempDir.path}/page1.txt')..writeAsStringSync('First Page Content');
      final doc2 = File('${tempDir.path}/page2.txt')..writeAsStringSync('Second Page Content');

      final mergedPdfPath = '${tempDir.path}/merged_output.pdf';
      final result = await PdfPowerSuiteService.instance.mergePdfs([doc1.path, doc2.path], mergedPdfPath);

      expect(result.pageCount, 2);
      expect(result.hasWatermark, isFalse);

      final mergedFile = File(mergedPdfPath);
      expect(mergedFile.existsSync(), isTrue);
      final pdfContent = mergedFile.readAsStringSync();
      expect(pdfContent.startsWith('%PDF-1.4'), isTrue);
      expect(pdfContent.contains('First Page Content'), isTrue);
      expect(pdfContent.contains('Second Page Content'), isTrue);
      expect(pdfContent.contains('%%EOF'), isTrue);
    });

    test('adds subtle watermark stamp overlay to PDF', () async {
      final doc = File('${tempDir.path}/confidential_doc.txt')..writeAsStringSync('Top Secret Specs');
      final watermarkedPdfPath = '${tempDir.path}/watermarked.pdf';

      final result = await PdfPowerSuiteService.instance.addWatermark(
        doc.path,
        'CONFIDENTIAL',
        watermarkedPdfPath,
      );

      expect(result.hasWatermark, isTrue);
      final pdfFile = File(watermarkedPdfPath);
      expect(pdfFile.existsSync(), isTrue);
      final pdfContent = pdfFile.readAsStringSync();
      expect(pdfContent.contains('CONFIDENTIAL'), isTrue);
      expect(pdfContent.contains('Top Secret Specs'), isTrue);
    });
  });

  group('Task 4 — ExpiringBeamLinkService Suite', () {
    test('creates expiring link with PIN and enforces single-use auto-destruct', () {
      final dummyFile = File('${tempDir.path}/shared.zip')..writeAsStringSync('ZIP_DATA');

      final service = ExpiringBeamLinkService.instance;
      final link = service.createExpiringLink(dummyFile.path, ttl: const Duration(minutes: 5), pin: '1234');

      expect(link.token.length, 6);
      expect(link.pin, '1234');
      expect(link.isValid, isTrue);
      expect(link.isExpired, isFalse);
      expect(link.url.contains('/beam/${link.token}'), isTrue);

      // Access with invalid PIN should fail
      final invalid = service.validateAndConsume(link.token, pin: '9999');
      expect(invalid, isNull);

      // Access with valid PIN succeeds
      final consumed = service.validateAndConsume(link.token, pin: '1234');
      expect(consumed, isNotNull);
      expect(consumed!.existsSync(), isTrue);

      // Subsequent access on single-use link should now fail
      final secondTry = service.validateAndConsume(link.token, pin: '1234');
      expect(secondTry, isNull);
    });

    test('supports manual link revocation', () {
      final dummyFile = File('${tempDir.path}/doc.pdf')..writeAsStringSync('DATA');
      final service = ExpiringBeamLinkService.instance;
      final link = service.createExpiringLink(dummyFile.path);

      expect(link.isValid, isTrue);
      service.revokeLink(link.token);
      expect(link.isValid, isFalse);
      expect(link.isRevoked, isTrue);
    });
  });
}
