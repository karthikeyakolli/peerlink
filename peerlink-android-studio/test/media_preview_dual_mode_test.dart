import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/archive_extractor_service.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';
import 'package:peerlink/design_system/theme/peerlink_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPreviewModal Light-Only & Zero-Glow Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('preview_light_mode_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders text preview with copy button in forced Light Mode', (tester) async {
      final textFile = File('${tempDir.path}/code_snippet.json')
        ..writeAsStringSync('{"peer": "alice", "status": "active"}');

      final item = ReceivedFileItem(
        path: textFile.path,
        name: 'code_snippet.json',
        sizeBytes: 42,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
        extension: 'json',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: SizedBox(
              width: 450,
              height: 800,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JSON Plaintext'), findsOneWidget);
      expect(find.byKey(const Key('copy_text_preview_button')), findsOneWidget);
      expect(find.text('{"peer": "alice", "status": "active"}'), findsOneWidget);

      await tester.tap(find.byKey(const Key('copy_text_preview_button')));
      await tester.pumpAndSettle();

      expect(find.text('Content copied to clipboard'), findsOneWidget);
    });

    testWidgets('renders video preview with zero glow in forced Light Mode', (tester) async {
      final videoFile = File('${tempDir.path}/demo.mp4')..writeAsBytesSync([1, 2, 3, 4]);

      final item = ReceivedFileItem(
        path: videoFile.path,
        name: 'demo.mp4',
        sizeBytes: 1024 * 1024 * 8,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.videos,
        extension: 'mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: SizedBox(
              width: 450,
              height: 850,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('play_video_button')), findsOneWidget);
      expect(find.byKey(const Key('open_video_player_button')), findsOneWidget);
      expect(find.byKey(const Key('stage_video_button')), findsOneWidget);

      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.boxShadow != null) {
          for (final shadow in decoration.boxShadow!) {
            expect(shadow.blurRadius, lessThanOrEqualTo(10.0),
                reason: 'BoxShadow blurRadius ${shadow.blurRadius} must not be a neon glow bloom');
          }
        }
      }
    });

    testWidgets('renders audio preview with zero glow in forced Light Mode', (tester) async {
      final audioFile = File('${tempDir.path}/music.mp3')..writeAsBytesSync([1, 2, 3, 4]);

      final item = ReceivedFileItem(
        path: audioFile.path,
        name: 'music.mp3',
        sizeBytes: 1024 * 1024 * 3,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.audio,
        extension: 'mp3',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: SizedBox(
              width: 450,
              height: 850,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('play_audio_button')), findsOneWidget);
      expect(find.byKey(const Key('stage_audio_button')), findsOneWidget);

      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final c in containers) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.boxShadow != null) {
          for (final shadow in decoration.boxShadow!) {
            expect(shadow.blurRadius, lessThanOrEqualTo(10.0),
                reason: 'BoxShadow blurRadius ${shadow.blurRadius} exceeds non-glow threshold');
          }
        }
      }
    });

    testWidgets('renders archive preview with contained file list in forced Light Mode', (tester) async {
      final archiveFile = File('${tempDir.path}/bundle.zip')..writeAsBytesSync([0x50, 0x4B, 0x05, 0x06]);

      final item = ReceivedFileItem(
        path: archiveFile.path,
        name: 'bundle.zip',
        sizeBytes: 2048,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.archives,
        extension: 'zip',
      );

      final dummyDetails = ArchiveDetails(
        archivePath: archiveFile.path,
        fileCount: 2,
        folderCount: 1,
        totalUncompressedSize: 512,
        totalCompressedSize: 256,
        entries: const [
          ArchiveEntry(
            path: 'docs/readme.txt',
            name: 'readme.txt',
            compressedSize: 128,
            uncompressedSize: 256,
            isDirectory: false,
          ),
          ArchiveEntry(
            path: 'assets/',
            name: 'assets',
            compressedSize: 0,
            uncompressedSize: 0,
            isDirectory: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: SizedBox(
              width: 450,
              height: 850,
              child: MediaPreviewModal(
                fileItem: item,
                initialArchiveDetails: dummyDetails,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ZIP Archive Inspector'), findsOneWidget);
      expect(find.text('Contained Files'), findsOneWidget);
      expect(find.text('docs/readme.txt'), findsOneWidget);
      expect(find.text('assets/'), findsOneWidget);
      expect(find.byKey(const Key('extract_archive_button')), findsOneWidget);
    });
  });
}
