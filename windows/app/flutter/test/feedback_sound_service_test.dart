import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/feedback_sound_service.dart';

void main() {
  group('FeedbackSoundService Tests', () {
    final service = FeedbackSoundService.instance;

    setUp(() {
      service.overrideEnabled = null;
      AppSettingsService.instance.soundNotifications = true;
    });

    test('follows AppSettingsService.instance.soundNotifications by default', () {
      AppSettingsService.instance.soundNotifications = true;
      expect(service.isEnabled, isTrue);

      AppSettingsService.instance.soundNotifications = false;
      expect(service.isEnabled, isFalse);
    });

    test('overrideEnabled overrides settings state', () {
      AppSettingsService.instance.soundNotifications = false;
      service.overrideEnabled = () => true;
      expect(service.isEnabled, isTrue);

      service.overrideEnabled = () => false;
      expect(service.isEnabled, isFalse);
    });

    test('invokes audio and haptic methods without throwing exceptions', () async {
      service.overrideEnabled = () => true;

      await expectLater(service.playTransferComplete(), completes);
      await expectLater(service.playTransferFailed(), completes);
      await expectLater(service.playPeerConnected(), completes);
      await expectLater(service.playSelectionClick(), completes);
    });

    test('no-ops when disabled without throwing exceptions', () async {
      service.overrideEnabled = () => false;

      await expectLater(service.playTransferComplete(), completes);
      await expectLater(service.playTransferFailed(), completes);
      await expectLater(service.playPeerConnected(), completes);
      await expectLater(service.playSelectionClick(), completes);
    });
  });
}
