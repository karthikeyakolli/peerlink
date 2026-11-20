import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/document_scanner_service.dart';
import 'package:peerlink/core/file_converter_service.dart';
import 'package:peerlink/design_system/components/camera_scanner_viewfinder_modal.dart';
import 'package:peerlink/design_system/components/document_crop_dialog.dart';
import 'package:peerlink/design_system/components/document_scanner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_real_doc_scanner_test_');
    AppSettingsService.instance.saveLocation = tempDir.path;
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DocumentScannerService Advanced Capabilities Tests', () {
    final scanner = DocumentScannerService.instance;

    test('getOcrStats calculates word, character, and line metrics correctly', () {
      const sampleText = 'Title: Invoice Receipt\nTotal Amount: \$45.50\nVendor: PeerLink Store';
      final stats = scanner.getOcrStats(sampleText);

      expect(stats['wordCount'], equals(9));
      expect(stats['charCount'], equals( sampleText.length));
      expect(stats['lineCount'], equals(3));
    });

    test('getOcrStats handles empty text gracefully', () {
      final stats = scanner.getOcrStats('');
      expect(stats['wordCount'], equals(0));
      expect(stats['charCount'], equals(0));
      expect(stats['lineCount'], equals(0));
    });

    test('compileScannedPagesToPdf supports A4, Letter, page numbers and watermark', () async {
      final bmpBytes = FileConverterService.instance.createSolidBmp(
        width: 100,
        height: 100,
        red: 240,
        green: 240,
        blue: 240,
      );
      final p1File = File('${tempDir.path}/page_1.bmp')..writeAsBytesSync(bmpBytes);
      final p2File = File('${tempDir.path}/page_2.bmp')..writeAsBytesSync(bmpBytes);

      final pages = [
        ScannedPage(id: 'p1', file: p1File, filter: DocScanFilter.bwDocument),
        ScannedPage(id: 'p2', file: p2File, filter: DocScanFilter.magicColor),
      ];

      final pdf = await scanner.compileScannedPagesToPdf(
        pages: pages,
        documentTitle: 'Contract_Agreement',
        destinationDir: tempDir,
        pageSize: 'Letter',
        addPageNumbers: true,
        watermarkText: 'CONFIDENTIAL',
      );

      expect(pdf.existsSync(), isTrue);
      final content = pdf.readAsStringSync();
      expect(content, contains('%PDF-1.4'));
      expect(content, contains('CONFIDENTIAL'));
      expect(content, contains('Page 1 of 2'));
      expect(content, contains('Page 2 of 2'));
      expect(content, contains('/MediaBox [0 0 612 792]'));
    });

    test('getRecentScans lists compiled PDFs from Vault sorted by newest first', () {
      final recent = scanner.getRecentScans(tempDir);
      expect(recent.isNotEmpty, isTrue);
      expect(recent.first.path.endsWith('.pdf'), isTrue);
    });
  });

  group('CameraScannerViewfinderModal Widget Tests', () {
    testWidgets('renders camera viewfinder, alignment guides, presets, and flash controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      ScannedPage? capturedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraScannerViewfinderModal(
              pageIndex: 1,
              onPageCaptured: (page) {
                capturedPage = page;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Guidance & Mode labels
      expect(find.text('Align Document (A4) within frame'), findsOneWidget);
      expect(find.text('Single'), findsOneWidget);

      // Flash & Grid controls
      expect(find.byIcon(Icons.flash_auto_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);

      // Presets
      expect(find.text('Document (A4)'), findsOneWidget);
      expect(find.text('ID Card / Badge'), findsOneWidget);
      expect(find.text('Receipt / Bill'), findsOneWidget);
      expect(find.text('Book / Note'), findsOneWidget);

      // Tap ID Card preset
      await tester.tap(find.text('ID Card / Badge'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap flash toggle to switch to Flash On
      await tester.tap(find.byIcon(Icons.flash_auto_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);

      // Tap shutter button
      final shutterFinder = find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration && (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(shutterFinder, findsWidgets);

      await tester.tap(shutterFinder.last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(capturedPage, isNotNull);
      expect(capturedPage!.filter, equals(DocScanFilter.magicColor));
    });
  });

  group('DocumentCropDialog Widget Tests', () {
    testWidgets('renders 4-corner crop dialog, rotation, and auto-detect triggers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bmpBytes = FileConverterService.instance.createSolidBmp(
        width: 100,
        height: 100,
        red: 250,
        green: 250,
        blue: 250,
      );
      final testFile = File('${tempDir.path}/crop_test_page.bmp')..writeAsBytesSync(bmpBytes);
      final testPage = ScannedPage(id: 'crop_p1', file: testFile);

      bool updated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCropDialog(
              page: testPage,
              onBoundsUpdated: () {
                updated = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Perspective & Crop Adjustment'), findsOneWidget);
      expect(find.text('Auto Detect'), findsOneWidget);
      expect(find.text('Full Page'), findsOneWidget);

      // Tap 90 rotation button
      expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.rotate_right_rounded));
      await tester.pumpAndSettle();
      expect(testPage.rotationDegrees, equals(90));

      // Tap Full Page
      await tester.tap(find.text('Full Page'));
      await tester.pumpAndSettle();

      // Tap Apply Crop
      expect(find.text('Apply Crop'), findsOneWidget);
      await tester.tap(find.text('Apply Crop'));
      await tester.pumpAndSettle();

      expect(updated, isTrue);
    });
  });
}
