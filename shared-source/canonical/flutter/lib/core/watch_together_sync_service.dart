import 'package:flutter/foundation.dart';

enum WatchPlaybackAction {
  play,
  pause,
  seek,
}

typedef BroadcastActionCallback = void Function(Map<String, dynamic> action);
typedef DriftCorrectionCallback = void Function(int targetPositionMs);

class WatchTogetherSyncService extends ChangeNotifier {
  WatchTogetherSyncService._();
  static final WatchTogetherSyncService instance = WatchTogetherSyncService._();

  String? _sessionId;
  bool _isHost = false;
  bool get isInSession => _sessionId != null;
  bool get isHost => _isHost;

  BroadcastActionCallback? onBroadcastAction;
  DriftCorrectionCallback? onDriftCorrectionRequired;

  void startSession({required String sessionId, required bool isHost}) {
    _sessionId = sessionId;
    _isHost = isHost;
    notifyListeners();
  }

  void stopSession() {
    _sessionId = null;
    _isHost = false;
    notifyListeners();
  }

  void broadcastPlaybackState({
    required WatchPlaybackAction action,
    required int positionMs,
    required double speed,
  }) {
    if (!isInSession) return;

    final actionStr = action == WatchPlaybackAction.play
        ? 'PLAY'
        : (action == WatchPlaybackAction.pause ? 'PAUSE' : 'SEEK');

    final payload = {
      'type': 'WATCH_TOGETHER_SYNC',
      'sessionId': _sessionId,
      'action': actionStr,
      'positionMs': positionMs,
      'speed': speed,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    onBroadcastAction?.call(payload);
  }

  void handleIncomingAction(
    Map<String, dynamic> packet, {
    required int currentLocalPositionMs,
  }) {
    final remotePositionMs = (packet['positionMs'] as num?)?.toInt() ?? 0;
    final drift = (remotePositionMs - currentLocalPositionMs).abs();

    // If playback position drifts more than 500ms, smoothly correct
    if (drift > 500) {
      onDriftCorrectionRequired?.call(remotePositionMs);
    }

    notifyListeners();
  }
}
