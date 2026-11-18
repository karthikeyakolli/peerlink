import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/video_engine_controller.dart';

void main() {
  group('VideoEngineController Gestures and Controls', () {
    late VideoEngineController controller;

    setUp(() {
      controller = VideoEngineController(
        duration: const Duration(minutes: 10),
        currentPosition: const Duration(minutes: 2),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial properties are sane', () {
      expect(controller.brightness, 1.0);
      expect(controller.volume, 1.0);
      expect(controller.isLocked, isFalse);
      expect(controller.gestureHudMessage, isNull);
    });

    test('Vertical drag left adjusts brightness and clamps between 0.05 and 1.0', () {
      // Drag down (positive delta) -> reduces brightness
      controller.handleVerticalDragLeft(50.0);
      expect(controller.brightness, lessThan(1.0));
      expect(controller.gestureHudMessage, contains('Brightness'));

      // Drag down excessively
      controller.handleVerticalDragLeft(1000.0);
      expect(controller.brightness, 0.05);

      // Drag up (negative delta)
      controller.handleVerticalDragLeft(-1000.0);
      expect(controller.brightness, 1.0);
    });

    test('Vertical drag right adjusts volume and clamps between 0.0 and 1.0', () {
      // Drag down -> reduces volume
      controller.handleVerticalDragRight(50.0);
      expect(controller.volume, lessThan(1.0));
      expect(controller.gestureHudMessage, contains('Volume'));

      // Drag down excessively
      controller.handleVerticalDragRight(1000.0);
      expect(controller.volume, 0.0);

      // Drag up
      controller.handleVerticalDragRight(-1000.0);
      expect(controller.volume, 1.0);
    });

    test('Horizontal drag scrubs timestamp forward and backward', () {
      final initialPos = controller.currentPosition;
      // Drag right -> advance
      controller.handleHorizontalDrag(120.0);
      expect(controller.currentPosition.inSeconds, greaterThan(initialPos.inSeconds));
      expect(controller.gestureHudMessage, contains('+10s'));

      // Drag left -> rewind
      controller.handleHorizontalDrag(-120.0);
      expect(controller.currentPosition, initialPos);
      expect(controller.gestureHudMessage, contains('-10s'));
    });

    test('Double tap jumps +/- 10 seconds', () {
      final initialSec = controller.currentPosition.inSeconds;
      // Right side double tap -> +10s
      controller.handleDoubleTap(true);
      expect(controller.currentPosition.inSeconds, initialSec + 10);
      expect(controller.gestureHudMessage, contains('+10s'));

      // Left side double tap -> -10s
      controller.handleDoubleTap(false);
      expect(controller.currentPosition.inSeconds, initialSec);
      expect(controller.gestureHudMessage, contains('-10s'));
    });

    test('Screen lock suppresses gestures until unlocked', () {
      controller.toggleScreenLock();
      expect(controller.isLocked, isTrue);
      expect(controller.gestureHudMessage, contains('Locked'));

      final pos = controller.currentPosition;
      final bright = controller.brightness;
      final vol = controller.volume;

      // Gestures should be ignored while locked
      controller.handleVerticalDragLeft(50.0);
      controller.handleVerticalDragRight(50.0);
      controller.handleHorizontalDrag(100.0);
      controller.handleDoubleTap(true);

      expect(controller.currentPosition, pos);
      expect(controller.brightness, bright);
      expect(controller.volume, vol);

      // Unlock
      controller.toggleScreenLock();
      expect(controller.isLocked, isFalse);
      expect(controller.gestureHudMessage, contains('Unlocked'));

      // Gestures now work
      controller.handleDoubleTap(true);
      expect(controller.currentPosition.inSeconds, pos.inSeconds + 10);
    });

    test('formatDuration formats mm:ss and hh:mm:ss properly', () {
      expect(VideoEngineController.formatDuration(const Duration(seconds: 45)), '00:45');
      expect(VideoEngineController.formatDuration(const Duration(minutes: 3, seconds: 12)), '03:12');
      expect(VideoEngineController.formatDuration(const Duration(hours: 1, minutes: 23, seconds: 45)), '1:23:45');
    });
  });
}
