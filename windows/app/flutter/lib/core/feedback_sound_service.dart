import 'package:flutter/services.dart';
import 'app_settings_service.dart';

enum FeedbackEventType {
  transferComplete,
  transferFailed,
  peerConnected,
  itemSelected,
}

/// Service managing tactile audio chimes and haptic feedback.
/// Uses Flutter's native SystemSound and HapticFeedback engines without bulky external audio assets.
class FeedbackSoundService {
  static final FeedbackSoundService _instance = FeedbackSoundService._internal();
  static FeedbackSoundService get instance => _instance;

  FeedbackSoundService._internal();

  bool Function()? overrideEnabled;

  bool get isEnabled => overrideEnabled?.call() ?? AppSettingsService.instance.soundNotifications;

  Future<void> playTransferComplete() async {
    if (!isEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<void> playTransferFailed() async {
    if (!isEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> playPeerConnected() async {
    if (!isEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> playSelectionClick() async {
    if (!isEnabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
