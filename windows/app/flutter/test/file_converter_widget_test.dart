import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/design_system/components/file_converter_sheet.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';

void main() {
  group('FileConverterSheet Widget Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('converter_widget_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders converter sheet with source info and converts CSV to JSON', (tester) async {
      final csvFile = File('${tempDir.path}/test.csv')..writeAsStringSync('name,role\nAlice,Lead\nBob,Dev\n');

      final item = ReceivedFileItem(
        path: csvFile.path,
        name: 'test.csv',
        sizeBytes: csvFile.lengthSync(),
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
        extension: 'csv',
      );

      bool conversionFinished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 800,
              child: FileConverterSheet(
                fileItem: item,
                onConversionComplete: () => conversionFinished = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Convert File Format'), findsOneWidget);
      expect(find.text('test.csv'), findsOneWidget);
      expect(find.text('.JSON'), findsOneWidget);
      expect(find.text('.TSV'), findsOneWidget);

      // Tap convert button
      await tester.tap(find.text('Convert to .JSON & Save to Vault'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Conversion Successful!'), findsOneWidget);
      expect(conversionFinished, isTrue);
    });

    testWidgets('media preview modal displays convert format button and video controls', (tester) async {
      final videoFile = File('${tempDir.path}/sample.mp4')..writeAsBytesSync([1, 2, 3, 4]);

      final item = ReceivedFileItem(
        path: videoFile.path,
        name: 'sample.mp4',
        sizeBytes: 1024 * 1024 * 2,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.videos,
        extension: 'mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 1000,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('modal_convert_format_button')), findsOneWidget);
      expect(find.byKey(const Key('video_skip_back_button')), findsOneWidget);
      expect(find.byKey(const Key('video_skip_forward_button')), findsOneWidget);
      expect(find.byKey(const Key('video_speed_button')), findsOneWidget);
      expect(find.byKey(const Key('video_aspect_ratio_button')), findsOneWidget);
      expect(find.byKey(const Key('video_loop_button')), findsOneWidget);

      // Scroll and tap aspect ratio button to cycle
      final aspectFinder = find.byKey(const Key('video_aspect_ratio_button'));
      await tester.ensureVisible(aspectFinder);
      await tester.tap(aspectFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('FILL'), findsOneWidget);

      // Tap loop toggle
      final loopFinder = find.byKey(const Key('video_loop_button'));
      await tester.ensureVisible(loopFinder);
      await tester.tap(loopFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Loop: ON'), findsOneWidget);
    });
  });
}
