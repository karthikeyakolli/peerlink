import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/document_scanner_service.dart';
import 'package:peerlink/core/file_converter_service.dart';
import 'package:peerlink/core/pdf_power_suite_service.dart';
import 'package:peerlink/design_system/components/document_scanner_sheet.dart';
import 'package:peerlink/design_system/components/ilovepdf_suite_sheet.dart';
import 'package:peerlink/features/converter/file_converter_flow_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_ilovepdf_test_');
    AppSettingsService.instance.saveLocation = tempDir.path;
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('PdfPowerSuiteService Complete Capabilities Tests', () {
    final pdfService = PdfPowerSuiteService.instance;

    test('mergePdfs merges multiple documents into a valid PDF', () async {
      final doc1 = File('${tempDir.path}/merge1.txt')..writeAsStringSync('Hello Page 1');
      final doc2 = File('${tempDir.path}/merge2.txt')..writeAsStringSync('Hello Page 2');
      final out = '${tempDir.path}/merged_test.pdf';

      final result = await pdfService.mergePdfs([doc1.path, doc2.path], out);

      expect(result.pageCount, equals(2));
      expect(File(out).existsSync(), isTrue);
      final bytes = File(out).readAsBytesSync();
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(8)), contains('%PDF-1.4'));
    });

    test('splitPdf extracts specified page ranges', () async {
      final doc = File('${tempDir.path}/multi.txt')..writeAsStringSync('Line 1\nLine 2\nLine 3\nLine 4');
      final out = '${tempDir.path}/split_test.pdf';

      final result = await pdfService.splitPdf(doc.path, '1-2', out);
      expect(result.pageCount, equals(2));
      expect(File(out).existsSync(), isTrue);
    });

    test('compressPdf achieves ratio according to compression tier', () async {
      final doc = File('${tempDir.path}/comp_source.txt')..writeAsStringSync('Lots of sample document content for compression');
      final out = '${tempDir.path}/compressed_test.pdf';

      final result = await pdfService.compressPdf(doc.path, out, tier: PdfCompressionTier.extreme);
      expect(result.compressionRatioPercent, equals(65));
      expect(File(out).existsSync(), isTrue);
    });

    test('protectPdf and unlockPdf handle encryption passwords', () async {
      final doc = File('${tempDir.path}/secret.txt')..writeAsStringSync('Confidential financial data');
      final protectedOut = '${tempDir.path}/protected_test.pdf';
      final unlockedOut = '${tempDir.path}/unlocked_test.pdf';

      final protectRes = await pdfService.protectPdf(doc.path, 'MyPass123', protectedOut);
      expect(protectRes.isProtected, isTrue);
      expect(File(protectedOut).existsSync(), isTrue);
      final protectedText = File(protectedOut).readAsStringSync();
      expect(protectedText, contains('/Encrypt'));

      final unlockRes = await pdfService.unlockPdf(protectedOut, 'MyPass123', unlockedOut);
      expect(unlockRes.isProtected, isFalse);
      expect(File(unlockedOut).existsSync(), isTrue);
    });

    test('rotatePdf adds /Rotate clause to pages', () async {
      final doc = File('${tempDir.path}/orient.txt')..writeAsStringSync('Sideways document text');
      final out = '${tempDir.path}/rotated_test.pdf';

      await pdfService.rotatePdf(doc.path, 90, out);
      expect(File(out).existsSync(), isTrue);
      final pdfContent = File(out).readAsStringSync();
      expect(pdfContent, contains('/Rotate 90'));
    });

    test('imagesToPdf converts image list into multi-page document album', () async {
      final img1 = File('${tempDir.path}/img1.jpg')..writeAsStringSync('fake_jpeg_1');
      final img2 = File('${tempDir.path}/img2.jpg')..writeAsStringSync('fake_jpeg_2');
      final out = '${tempDir.path}/album_test.pdf';

      final result = await pdfService.imagesToPdf([img1.path, img2.path], out, title: 'Vacation Receipts');
      expect(result.pageCount, equals(2));
      expect(File(out).existsSync(), isTrue);
    });

    test('addPageNumbers embeds page pagination in footer', () async {
      final doc = File('${tempDir.path}/unnumbered.txt')..writeAsStringSync('Page content without numbering');
      final out = '${tempDir.path}/numbered_test.pdf';

      await pdfService.addPageNumbers(doc.path, out);
      expect(File(out).existsSync(), isTrue);
      final pdfContent = File(out).readAsStringSync();
      expect(pdfContent, contains('Page 1 of 1'));
    });

    test('pdfToText extracts text to target plain file', () async {
      final doc = File('${tempDir.path}/read_text.pdf')..writeAsStringSync('Exported plain content from PDF document');
      final out = '${tempDir.path}/extracted_test.txt';

      final result = await pdfService.pdfToText(doc.path, out);
      expect(result.existsSync(), isTrue);
      expect(result.readAsStringSync(), contains('Exported plain content'));
    });
  });

  group('DocumentScannerService Tests', () {
    final scanner = DocumentScannerService.instance;
    final converter = FileConverterService.instance;

    test('applyScanFilter processes BMP image with B&W, Grayscale, Magic Color', () {
      final bmp = converter.createSolidBmp(width: 8, height: 8, red: 180, green: 120, blue: 60);

      final gray = scanner.applyScanFilter(bmp, DocScanFilter.grayscale);
      expect(gray.length, equals(bmp.length));

      final bw = scanner.applyScanFilter(bmp, DocScanFilter.bwDocument);
      expect(bw.length, equals(bmp.length));

      final magic = scanner.applyScanFilter(bmp, DocScanFilter.magicColor);
      expect(magic.length, equals(bmp.length));
    });

    test('compileScannedPagesToPdf compiles ScannedPage items with rotations and filters', () async {
      final p1 = File('${tempDir.path}/scan_p1.bmp')
        ..writeAsBytesSync(converter.createSolidBmp(width: 8, height: 8, red: 255, green: 255, blue: 255));
      final p2 = File('${tempDir.path}/scan_p2.bmp')
        ..writeAsBytesSync(converter.createSolidBmp(width: 8, height: 8, red: 200, green: 200, blue: 200));

      final pages = [
        ScannedPage(id: '1', file: p1, rotationDegrees: 90, filter: DocScanFilter.bwDocument),
        ScannedPage(id: '2', file: p2, rotationDegrees: 0, filter: DocScanFilter.magicColor),
      ];

      final pdf = await scanner.compileScannedPagesToPdf(
        pages: pages,
        documentTitle: 'Contract Scan 2026',
        destinationDir: tempDir,
      );

      expect(pdf.existsSync(), isTrue);
      final pdfContent = pdf.readAsStringSync();
      expect(pdfContent, contains('%PDF-1.4'));
      expect(pdfContent, contains('/Rotate 90'));
      expect(pdfContent, contains('[B&W Document]'));
      expect(pdfContent, contains('[Magic Color]'));
    });
  });

  group('iLovePDF Suite & Document Scanner Widget Tests', () {
    testWidgets('ILovePdfSuiteSheet renders tabs and triggers operations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ILovePdfSuiteSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('iLovePDF Studio'), findsOneWidget);
      expect(find.text('Organize'), findsOneWidget);
      expect(find.text('Optimize'), findsOneWidget);
      expect(find.text('Convert'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);

      // Tap Merge Documents button
      expect(find.byKey(const Key('ilovepdf_merge_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ilovepdf_merge_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Merged 2 documents successfully!'), findsOneWidget);

      // Switch to Security Tab
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ilovepdf_protect_button')), findsOneWidget);
      expect(find.byKey(const Key('ilovepdf_unlock_button')), findsOneWidget);

      await tester.drag(find.byKey(const Key('ilovepdf_protect_button')), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ilovepdf_watermark_button')), findsOneWidget);
    });

    testWidgets('DocumentScannerSheet adds pages and compiles to PDF', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DocumentScannerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Document Scanner'), findsOneWidget);
      expect(find.byKey(const Key('scanner_add_page_button')), findsOneWidget);

      // Add a page
      await tester.tap(find.byKey(const Key('scanner_add_page_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 page captured'), findsOneWidget);
      expect(find.text('B&W Document'), findsWidgets);

      // Compile to PDF
      expect(find.byKey(const Key('scanner_compile_pdf_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scanner_compile_pdf_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('PDF Saved:'), findsOneWidget);
    });

    testWidgets('FileConverterFlowView displays both iLovePDF Studio and Document Scanner cards along with all previous tools', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileConverterFlowView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify iLovePDF Suite Card
      expect(find.text('iLovePDF Studio (20+ PDF Tools)'), findsOneWidget);
      expect(find.byKey(const Key('open_ilovepdf_studio_button')), findsOneWidget);

      // Verify Document Scanner Card
      expect(find.text('Document Scanner (Camera & Paper Scan)'), findsOneWidget);
      expect(find.byKey(const Key('open_doc_scanner_button')), findsOneWidget);

      // Verify all 6 original required cards
      expect(find.text('Offline Format Converter'), findsOneWidget);
      expect(find.text('Disk Space Treemap & Heatmap'), findsOneWidget);
      expect(find.text('Security, Privacy & Split-APKs'), findsOneWidget);
      expect(find.text('In-App Video Trimmer & Audio Extractor'), findsOneWidget);
      expect(find.text('Checksum & Integrity Verifier'), findsOneWidget);
      expect(find.text('Storage Junk Scrubber'), findsOneWidget);
    });
  });
}
