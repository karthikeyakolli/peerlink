import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/remote_presentation_controller_service.dart';
import 'package:peerlink/core/document_scanner_service.dart';
import 'package:peerlink/core/file_converter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peerlink_task5_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('RemotePresentationControllerService Tests', () {
    test('constructs and parses slide and media command packets', () {
      final remote = RemotePresentationControllerService.instance;

      Map<String, dynamic>? dispatched;
      remote.onSendCommand = (cmd) => dispatched = cmd;

      // 1. Next slide command
      remote.sendPresentationCommand(PresentationCommand.nextSlide);
      expect(dispatched, isNotNull);
      expect(dispatched!['type'], 'REMOTE_COMMAND');
      expect(dispatched!['command'], 'NEXT_SLIDE');

      // 2. Volume up command
      remote.sendPresentationCommand(PresentationCommand.volumeUp);
      expect(dispatched!['command'], 'VOLUME_UP');

      // 3. Media Play/Pause
      remote.sendPresentationCommand(PresentationCommand.mediaPlayPause);
      expect(dispatched!['command'], 'MEDIA_PLAY_PAUSE');

      // 4. Mouse Move
      remote.sendMouseMove(dx: 15.5, dy: -8.0);
      expect(dispatched!['command'], 'MOUSE_MOVE');
      expect(dispatched!['dx'], 15.5);
      expect(dispatched!['dy'], -8.0);

      // 5. Parse command on host
      final parsed = remote.parseCommand(dispatched!);
      expect(parsed, isNotNull);
      expect(parsed!.command, PresentationCommand.mouseMove);
      expect(parsed.dx, 15.5);
    });
  });

  group('DocumentScannerService Tests', () {
    test('processes captured pages and compiles multi-page PDF in Vault', () async {
      final scanner = DocumentScannerService.instance;
      final converter = FileConverterService.instance;

      // Create 2 test page image bitmaps
      final page1File = File('${tempDir.path}/scan_page_1.bmp')
        ..writeAsBytesSync(converter.createSolidBmp(width: 8, height: 8, red: 255, green: 255, blue: 255));
      final page2File = File('${tempDir.path}/scan_page_2.bmp')
        ..writeAsBytesSync(converter.createSolidBmp(width: 8, height: 8, red: 240, green: 240, blue: 240));

      final resultPdf = await scanner.compileScannedPagesToPdf(
        pageFiles: [page1File, page2File],
        documentTitle: 'Scanned Meeting Notes',
        destinationDir: tempDir,
      );

      expect(resultPdf.existsSync(), isTrue);
      expect(resultPdf.path.endsWith('.pdf'), isTrue);
      expect(resultPdf.lengthSync(), greaterThan(100));

      final content = resultPdf.readAsStringSync();
      expect(content, contains('%PDF-1.4'));
      expect(content, contains('/Type /Pages'));
      expect(content, contains('/Type /Catalog'));
    });
  });
}
