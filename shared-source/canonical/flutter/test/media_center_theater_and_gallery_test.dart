import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/media/playback_backend.dart';
import 'package:peerlink/core/media/media_source_models.dart';
import 'package:peerlink/core/media/media_library_service.dart';
import 'package:peerlink/core/video_engine_controller.dart';
import 'package:peerlink/features/media/professional_image_viewer.dart';
import 'package:peerlink/features/media/video_theater_player.dart';
import 'package:peerlink/features/media/media_hub_flow_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peerlink_media_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('MediaPlaybackBackend Engine Contract', () {
    test('SimulatedPlaybackBackend supports deterministic state transitions', () async {
      final backend = SimulatedPlaybackBackend();
      await backend.initialize();

      expect(backend.isPlaying, isFalse);
      expect(backend.volume, 1.0);
      expect(backend.rate, 1.0);

      final descriptor = MediaSourceDescriptor.fromFilePath('/fake/sample.mp4', title: 'Sample Video');
      await backend.open(descriptor, autoPlay: false);

      expect(backend.position, Duration.zero);
      expect(backend.duration, const Duration(minutes: 2));

      await backend.play();
      expect(backend.isPlaying, isTrue);

      await backend.pause();
      expect(backend.isPlaying, isFalse);

      await backend.seek(const Duration(seconds: 45));
      expect(backend.position, const Duration(seconds: 45));

      await backend.setVolume(0.75);
      expect(backend.volume, 0.75);

      await backend.setRate(1.5);
      expect(backend.rate, 1.5);

      expect(backend.audioTracks.length, greaterThanOrEqualTo(1));
      expect(backend.subtitleTracks.length, greaterThanOrEqualTo(1));

      await backend.dispose();
    });

    test('VideoEngineController binds seamlessly to MediaPlaybackBackend', () async {
      final backend = SimulatedPlaybackBackend();
      final controller = VideoEngineController(backend: backend);

      await controller.openSource(
        MediaSourceDescriptor.fromFilePath('/test/video.mkv', title: 'Test MKV'),
        autoPlay: false,
      );

      expect(controller.isPlaying, isFalse);
      controller.togglePlayPause();
      expect(controller.isPlaying, isTrue);

      controller.seekRelative(const Duration(seconds: 20));
      expect(controller.currentPosition, const Duration(seconds: 20));

      controller.setPlaybackSpeed(1.25);
      expect(controller.playbackSpeed, 1.25);
      expect(backend.rate, 1.25);

      controller.dispose();
    });
  });

  group('MediaLibraryService & Timeline Grouping', () {
    test('Correctly groups media into chronological timeline sections', () async {
      final service = MediaLibraryService.instance;

      // Populate test items
      final now = DateTime.now();
      final sampleItems = [
        MediaItem(
          id: 'photo_today',
          name: 'IMG_20261120_120000.jpg',
          path: '${tempDir.path}/IMG_20261120_120000.jpg',
          origin: MediaOrigin.deviceStorage,
          kind: MediaKind.photo,
          sizeBytes: 2048500,
          lastModified: now,
          dateTaken: now,
        ),
        MediaItem(
          id: 'video_yesterday',
          name: 'VID_20261119_153000.mp4',
          path: '${tempDir.path}/VID_20261119_153000.mp4',
          origin: MediaOrigin.deviceStorage,
          kind: MediaKind.video,
          sizeBytes: 15420000,
          lastModified: now.subtract(const Duration(days: 1)),
          dateTaken: now.subtract(const Duration(days: 1)),
          duration: const Duration(minutes: 3, seconds: 12),
        ),
      ];

      // Test formatters
      expect(sampleItems[0].formattedSize, contains('MB'));
      expect(sampleItems[1].formattedDuration, '03:12');

      // Test favorites toggle
      service.toggleFavorite('photo_today');
      expect(service.isFavorite('photo_today'), isTrue);
      service.toggleFavorite('photo_today');
      expect(service.isFavorite('photo_today'), isFalse);

      // Test multi-selection
      service.toggleSelection('photo_today');
      expect(service.isSelected('photo_today'), isTrue);
      service.clearSelection();
      expect(service.isSelected('photo_today'), isFalse);
    });
  });

  group('ProfessionalImageViewer Widget Test', () {
    testWidgets('Renders professional image viewer with chrome, rotation, and EXIF inspector', (tester) async {
      final samplePhoto = File('${tempDir.path}/test_image.jpg');
      samplePhoto.writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]); // JPEG magic header

      final mediaList = [
        MediaItem(
          id: samplePhoto.path,
          name: 'test_image.jpg',
          path: samplePhoto.path,
          origin: MediaOrigin.deviceStorage,
          kind: MediaKind.photo,
          sizeBytes: 1024,
          lastModified: DateTime.now(),
          dateTaken: DateTime.now(),
          width: 1920,
          height: 1080,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalImageViewer(playlist: mediaList),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('test_image.jpg'), findsOneWidget);
      expect(find.textContaining('1 of 1'), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Tap 90° rotation button
      await tester.tap(find.byIcon(Icons.rotate_right_rounded));
      await tester.pumpAndSettle();

      // Open Photo Details (EXIF) inspector
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Photo Details'), findsOneWidget);
      expect(find.text('Resolution'), findsOneWidget);
    });
  });

  group('VideoTheaterPlayer Widget Test', () {
    testWidgets('Renders video theater with dark canvas, scrubber, and speed controls', (tester) async {
      final sampleVideo = File('${tempDir.path}/sample.mp4');
      sampleVideo.writeAsBytesSync([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]);

      final source = MediaSourceDescriptor.fromFilePath(sampleVideo.path, title: 'Sample Cinema');
      final simulatedBackend = SimulatedPlaybackBackend();
      final controller = VideoEngineController(
        backend: simulatedBackend,
        duration: const Duration(minutes: 5),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VideoTheaterPlayer(
            source: source,
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sample Cinema'), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);

      // Verify speed pill
      expect(find.text('1.0x'), findsOneWidget);

      // Verify A-B repeat button
      expect(find.text('A-B'), findsOneWidget);

      await simulatedBackend.pause();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      controller.dispose();
    });
  });
}
