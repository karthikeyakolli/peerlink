import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/design_system/components/media_preview_modal.dart';

void main() {
  group('MediaPreviewModal Widget Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('preview_modal_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders text preview for text documents', (tester) async {
      final sampleFile = File('${tempDir.path}/notes.txt')..writeAsStringSync('Hello PeerLink Vault!');

      final item = ReceivedFileItem(
        path: sampleFile.path,
        name: 'notes.txt',
        sizeBytes: 21,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.documents,
        extension: 'txt',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Hello PeerLink Vault!'), findsOneWidget);
      expect(find.text('Reveal Folder'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('enforces Rule 10 security banner for application/executable files', (tester) async {
      final apkFile = File('${tempDir.path}/app.apk')..writeAsBytesSync([1, 2, 3]);

      final item = ReceivedFileItem(
        path: apkFile.path,
        name: 'app.apk',
        sizeBytes: 3,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.apps,
        extension: 'apk',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaPreviewModal(fileItem: item),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('app.apk'), findsOneWidget);
      expect(find.text('Rule 10: Auto-Execution Guard'), findsOneWidget);
      expect(find.textContaining('quarantined from automatic execution'), findsOneWidget);
    });

    testWidgets('renders image viewer with rotation controls, lightbox, and stage button', (tester) async {
      final imgFile = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

      final item = ReceivedFileItem(
        path: imgFile.path,
        name: 'photo.jpg',
        sizeBytes: 4,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.photos,
        extension: 'jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 900,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinch / Scroll to Zoom'), findsOneWidget);
      expect(find.byKey(const Key('rotate_image_button')), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_image_button')), findsOneWidget);
      expect(find.byKey(const Key('stage_image_button')), findsOneWidget);

      // Tap rotate button
      await tester.tap(find.byKey(const Key('rotate_image_button')));
      await tester.pumpAndSettle();

      // Tap fullscreen lightbox button
      await tester.tap(find.byKey(const Key('fullscreen_image_button')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Close Lightbox'), findsOneWidget);
      await tester.tap(find.byTooltip('Close Lightbox'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders video player hub with hardware-acceleration badge and play controls', (tester) async {
      final videoFile = File('${tempDir.path}/clip.mp4')..writeAsBytesSync([1, 2, 3, 4]);

      final item = ReceivedFileItem(
        path: videoFile.path,
        name: 'clip.mp4',
        sizeBytes: 1024 * 1024 * 15,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.videos,
        extension: 'mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 900,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MP4 • HW 4K/HDR'), findsOneWidget);
      expect(find.text('Hardware-Accelerated Zero-Loss Playback'), findsOneWidget);
      expect(find.byKey(const Key('play_video_button')), findsOneWidget);
      expect(find.byKey(const Key('open_video_player_button')), findsOneWidget);
      expect(find.byKey(const Key('stage_video_button')), findsOneWidget);
      expect(find.byKey(const Key('video_gesture_surface')), findsOneWidget);
      expect(find.byKey(const Key('video_screen_lock_button')), findsOneWidget);
      expect(find.byKey(const Key('video_toolbar_play_pause_button')), findsOneWidget);

      // Tap screen lock button
      await tester.tap(find.byKey(const Key('video_screen_lock_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('video_screen_unlock_button')), findsOneWidget);
      expect(find.textContaining('Screen Controls Locked'), findsOneWidget);
      expect(find.byKey(const Key('video_gesture_surface')), findsNothing);

      // Tap unlock button
      await tester.tap(find.byKey(const Key('video_screen_unlock_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('video_screen_lock_button')), findsOneWidget);
      expect(find.byKey(const Key('video_gesture_surface')), findsOneWidget);
    });

    testWidgets('renders audio player hub with turntable and play audio track controls', (tester) async {
      final audioFile = File('${tempDir.path}/track.flac')..writeAsBytesSync([1, 2, 3, 4]);

      final item = ReceivedFileItem(
        path: audioFile.path,
        name: 'track.flac',
        sizeBytes: 1024 * 1024 * 5,
        lastModified: DateTime.now(),
        category: ReceivedFileCategory.audio,
        extension: 'flac',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 900,
              child: MediaPreviewModal(fileItem: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FLAC AUDIO'), findsOneWidget);
      expect(find.textContaining('Lossless Audio Track'), findsOneWidget);
      expect(find.byKey(const Key('play_audio_button')), findsOneWidget);
      expect(find.byKey(const Key('stage_audio_button')), findsOneWidget);
    });
  });
}
