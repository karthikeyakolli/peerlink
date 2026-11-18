import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/media_trimmer_service.dart';
import 'package:peerlink/core/video_engine_controller.dart';

void main() {
  group('VideoEngineController PiP & Background Audio Tests', () {
    late VideoEngineController controller;

    setUp(() {
      controller = VideoEngineController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial PiP and Background Audio states are sane', () {
      expect(controller.isPipActive, isFalse);
      expect(controller.backgroundAudioEnabled, isTrue);
    });

    test('togglePip switches PiP state and triggers HUD update', () {
      controller.togglePip();
      expect(controller.isPipActive, isTrue);
      expect(controller.gestureHudMessage, contains('Picture-in-Picture'));

      controller.togglePip();
      expect(controller.isPipActive, isFalse);
    });

    test('toggleBackgroundAudio toggles audio state and updates HUD', () {
      controller.toggleBackgroundAudio();
      expect(controller.backgroundAudioEnabled, isFalse);
      expect(controller.gestureHudMessage, contains('Background Audio: OFF'));

      controller.toggleBackgroundAudio();
      expect(controller.backgroundAudioEnabled, isTrue);
      expect(controller.gestureHudMessage, contains('Background Audio: ON'));
    });
  });

  group('MediaTrimmerService Tests', () {
    late Directory tempDir;
    late File dummyVideo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('peerlink_trim_test_');
      dummyVideo = File('${tempDir.path}/sample_clip.mp4');
      // Create a dummy video payload of 4KB
      dummyVideo.writeAsBytesSync(List.generate(4096, (i) => i % 256));
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('trimVideoSegment trims clip file cleanly without throwing', () async {
      final trimmedPath = await MediaTrimmerService.instance.trimVideoSegment(
        videoPath: dummyVideo.path,
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 25),
      );

      final trimmedFile = File(trimmedPath);
      expect(trimmedFile.existsSync(), isTrue);
      expect(trimmedFile.lengthSync(), greaterThan(0));
      expect(trimmedPath, contains('clip_5s-25s.mp4'));
    });

    test('extractAudioTrack extracts companion audio file cleanly', () async {
      final audioPath = await MediaTrimmerService.instance.extractAudioTrack(
        videoPath: dummyVideo.path,
      );

      final audioFile = File(audioPath);
      expect(audioFile.existsSync(), isTrue);
      expect(audioFile.lengthSync(), greaterThan(0));
      expect(audioPath, endsWith('.m4a'));
    });
  });
}
