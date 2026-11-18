import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/video_engine_controller.dart';
import 'package:peerlink/core/file_converter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peerlink_converter_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('VideoEngineController Tests', () {
    test('initializes with default values and allows playback speed changes', () {
      final controller = VideoEngineController(
        duration: const Duration(seconds: 120),
      );

      expect(controller.playbackSpeed, 1.0);
      expect(controller.isLooping, isFalse);
      expect(controller.aspectRatioMode, VideoAspectRatioMode.fit);
      expect(controller.currentPosition, Duration.zero);

      controller.setPlaybackSpeed(1.5);
      expect(controller.playbackSpeed, 1.5);

      controller.setPlaybackSpeed(0.5);
      expect(controller.playbackSpeed, 0.5);

      controller.setPlaybackSpeed(2.0);
      expect(controller.playbackSpeed, 2.0);
    });

    test('seeks relatively with forward and backward boundaries clamped', () {
      final controller = VideoEngineController(
        duration: const Duration(seconds: 100),
      );

      // Seek forward 10s
      controller.seekRelative(const Duration(seconds: 10));
      expect(controller.currentPosition, const Duration(seconds: 10));

      // Seek forward 30s
      controller.seekRelative(const Duration(seconds: 30));
      expect(controller.currentPosition, const Duration(seconds: 40));

      // Seek backward 10s
      controller.seekRelative(const Duration(seconds: -10));
      expect(controller.currentPosition, const Duration(seconds: 30));

      // Seek backward 50s -> should clamp to 0
      controller.seekRelative(const Duration(seconds: -50));
      expect(controller.currentPosition, Duration.zero);

      // Seek forward 150s -> should clamp to duration (100s)
      controller.seekRelative(const Duration(seconds: 150));
      expect(controller.currentPosition, const Duration(seconds: 100));
    });

    test('toggles aspect ratio modes cyclically', () {
      final controller = VideoEngineController(duration: const Duration(seconds: 60));
      expect(controller.aspectRatioMode, VideoAspectRatioMode.fit);

      controller.toggleAspectRatio();
      expect(controller.aspectRatioMode, VideoAspectRatioMode.fill);

      controller.toggleAspectRatio();
      expect(controller.aspectRatioMode, VideoAspectRatioMode.sixteenNine);

      controller.toggleAspectRatio();
      expect(controller.aspectRatioMode, VideoAspectRatioMode.fourThree);

      controller.toggleAspectRatio();
      expect(controller.aspectRatioMode, VideoAspectRatioMode.original);

      controller.toggleAspectRatio();
      expect(controller.aspectRatioMode, VideoAspectRatioMode.fit);
    });

    test('parses SRT subtitle cues and returns active subtitle for current position', () {
      const srtContent = '''
1
00:00:05,000 --> 00:00:09,500
Hello and welcome to PeerLink!

2
00:00:10,000 --> 00:00:15,000
True local-first peer-to-peer sharing.
No cloud required.

3
00:00:20,000 --> 00:00:25,000
Enjoy the show!
''';

      final controller = VideoEngineController(duration: const Duration(seconds: 60));
      controller.loadSubtitlesFromString(srtContent);

      expect(controller.subtitles.length, 3);

      // At 2 seconds -> no subtitle
      expect(controller.getSubtitleAt(const Duration(seconds: 2)), isNull);

      // At 7 seconds -> Cue 1
      expect(controller.getSubtitleAt(const Duration(seconds: 7)), 'Hello and welcome to PeerLink!');

      // At 9.8 seconds -> between cues -> null
      expect(controller.getSubtitleAt(const Duration(milliseconds: 9800)), isNull);

      // At 12 seconds -> Cue 2
      expect(
        controller.getSubtitleAt(const Duration(seconds: 12)),
        'True local-first peer-to-peer sharing.\nNo cloud required.',
      );

      // At 22 seconds -> Cue 3
      expect(controller.getSubtitleAt(const Duration(seconds: 22)), 'Enjoy the show!');
    });

    test('auto-detects companion srt file next to video', () {
      final videoFile = File('${tempDir.path}/presentation.mp4')..writeAsStringSync('dummy video');
      final srtFile = File('${tempDir.path}/presentation.srt')..writeAsStringSync('''
1
00:00:01,000 --> 00:00:04,000
Opening Title
''');

      final detected = VideoEngineController.findCompanionSubtitlePath(videoFile.path);
      expect(detected != null, isTrue);
      expect(File(detected!).existsSync(), isTrue);
      expect(detected!.toLowerCase().endsWith('presentation.srt'), isTrue);

      final controller = VideoEngineController(duration: const Duration(seconds: 30));
      final loaded = controller.loadSubtitleFromFileSync(detected!);
      expect(loaded, isTrue);
      expect(controller.getSubtitleAt(const Duration(seconds: 2)), 'Opening Title');
    });
  });

  group('FileConverterService Tests', () {
    final service = FileConverterService.instance;

    test('converts CSV to JSON and JSON to CSV', () async {
      final csvFile = File('${tempDir.path}/sample.csv');
      csvFile.writeAsStringSync('name,role,level\nAlice,Engineer,5\nBob,Designer,4\n');

      final jsonResult = await service.convertCsvToJson(
        source: csvFile,
        destinationDir: tempDir,
      );

      expect(jsonResult.success, isTrue);
      expect(jsonResult.outputFile.existsSync(), isTrue);
      expect(jsonResult.outputFile.path.endsWith('.json'), isTrue);

      final jsonText = jsonResult.outputFile.readAsStringSync();
      expect(jsonText, contains('"name": "Alice"'));
      expect(jsonText, contains('"role": "Engineer"'));

      // Convert JSON back to CSV
      final csvResult = await service.convertJsonToCsv(
        source: jsonResult.outputFile,
        destinationDir: tempDir,
      );

      expect(csvResult.success, isTrue);
      expect(csvResult.outputFile.existsSync(), isTrue);
      expect(csvResult.outputFile.path.endsWith('.csv'), isTrue);

      final csvBack = csvResult.outputFile.readAsStringSync();
      expect(csvBack, contains('name,role,level'));
      expect(csvBack, contains('Alice,Engineer,5'));
    });

    test('converts CSV to TSV and TSV to CSV', () async {
      final csvFile = File('${tempDir.path}/data.csv');
      csvFile.writeAsStringSync('id,name,score\n1,Alpha,99\n2,Beta,85\n');

      final tsvResult = await service.convertDelimited(
        source: csvFile,
        fromDelimiter: ',',
        toDelimiter: '\t',
        targetExtension: 'tsv',
        destinationDir: tempDir,
      );

      expect(tsvResult.success, isTrue);
      expect(tsvResult.outputFile.existsSync(), isTrue);
      final tsvText = tsvResult.outputFile.readAsStringSync();
      expect(tsvText, contains("id\tname\tscore"));
      expect(tsvText, contains("1\tAlpha\t99"));
    });

    test('converts Markdown to HTML and HTML to plain text', () async {
      final mdFile = File('${tempDir.path}/notes.md');
      mdFile.writeAsStringSync('''# Project PeerLink
## Features
- **Fast** local transfer
- *Secure* authentication
> Zero cloud dependency.
```dart
void main() => print("Hello");
```
''');

      final htmlResult = await service.convertMarkdownToHtml(
        source: mdFile,
        destinationDir: tempDir,
      );

      expect(htmlResult.success, isTrue);
      expect(htmlResult.outputFile.existsSync(), isTrue);
      final html = htmlResult.outputFile.readAsStringSync();
      expect(html, contains('<h1>Project PeerLink</h1>'));
      expect(html, contains('<h2>Features</h2>'));
      expect(html, contains('<strong>Fast</strong>'));
      expect(html, contains('<em>Secure</em>'));
      expect(html, contains('<blockquote>Zero cloud dependency.</blockquote>'));
      expect(html, contains('<code>void main() =&gt; print(&quot;Hello&quot;);</code>'));

      // Convert HTML to Plain Text
      final txtResult = await service.convertHtmlToPlainText(
        source: htmlResult.outputFile,
        destinationDir: tempDir,
      );

      expect(txtResult.success, isTrue);
      expect(txtResult.outputFile.existsSync(), isTrue);
      final plain = txtResult.outputFile.readAsStringSync();
      expect(plain, contains('Project PeerLink'));
      expect(plain, contains('Fast local transfer'));
      expect(plain, isNot(contains('<h1>')));
    });

    test('compiles plain text document to authentic PDF 1.4', () async {
      final txtFile = File('${tempDir.path}/document.txt');
      txtFile.writeAsStringSync('''PeerLink Architecture Report
Date: 2026-11-18
Status: Verified

This is an authentic PDF document compiled 100% offline via PeerLink.
No third-party cloud service or external printer binary was used.
''');

      final pdfResult = await service.compileTextToPdf(
        source: txtFile,
        title: 'PeerLink Architecture Report',
        destinationDir: tempDir,
      );

      expect(pdfResult.success, isTrue);
      expect(pdfResult.outputFile.existsSync(), isTrue);
      expect(pdfResult.outputFile.path.endsWith('.pdf'), isTrue);

      final bytes = pdfResult.outputFile.readAsBytesSync();
      final header = String.fromCharCodes(bytes.take(8));
      expect(header.startsWith('%PDF-1.4'), isTrue);

      final content = String.fromCharCodes(bytes);
      expect(content, contains('/Type /Catalog'));
      expect(content, contains('/Type /Pages'));
      expect(content, contains('/Type /Font'));
      expect(content, contains('xref'));
      expect(content, contains('trailer'));
      expect(content, contains('%%EOF'));
    });

    test('generates valid BMP image and converts image to PDF', () async {
      // Create a 2x2 red BMP file
      final bmpFile = File('${tempDir.path}/test_image.bmp');
      final bmpBytes = service.createSolidBmp(width: 4, height: 4, red: 255, green: 0, blue: 0);
      bmpFile.writeAsBytesSync(bmpBytes);

      expect(bmpFile.lengthSync(), greaterThan(54));

      // Compile BMP image into PDF
      final pdfResult = await service.compileImageToPdf(
        imageFile: bmpFile,
        title: 'Image Test',
        destinationDir: tempDir,
      );

      expect(pdfResult.success, isTrue);
      expect(pdfResult.outputFile.existsSync(), isTrue);
      expect(pdfResult.outputFile.path.endsWith('.pdf'), isTrue);

      final pdfBytes = pdfResult.outputFile.readAsBytesSync();
      final content = String.fromCharCodes(pdfBytes);
      expect(content, contains('%PDF-1.4'));
      expect(content, contains('/Subtype /Image'));
    });
  });
}
