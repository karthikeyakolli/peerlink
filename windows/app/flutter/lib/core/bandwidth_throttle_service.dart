import 'dart:async';
import 'dart:math';

enum BandwidthLimitPreset {
  unlimited,
  fast50Mb,
  medium10Mb,
  low2Mb,
}

extension BandwidthLimitPresetExtension on BandwidthLimitPreset {
  int get bytesPerSecond {
    switch (this) {
      case BandwidthLimitPreset.unlimited:
        return 0; // 0 means unthrottled
      case BandwidthLimitPreset.fast50Mb:
        return 50 * 1024 * 1024;
      case BandwidthLimitPreset.medium10Mb:
        return 10 * 1024 * 1024;
      case BandwidthLimitPreset.low2Mb:
        return 2 * 1024 * 1024;
    }
  }

  String get displayName {
    switch (this) {
      case BandwidthLimitPreset.unlimited:
        return 'Unlimited (Line Speed)';
      case BandwidthLimitPreset.fast50Mb:
        return '50 MB/s (High Speed)';
      case BandwidthLimitPreset.medium10Mb:
        return '10 MB/s (Balanced)';
      case BandwidthLimitPreset.low2Mb:
        return '2 MB/s (Low Congestion)';
    }
  }
}

/// Token-Bucket Bandwidth Throttle & Traffic Shaper.
/// Prevents local Wi-Fi / LAN saturation by throttling peer transfer pipelines.
class BandwidthThrottleService {
  static final BandwidthThrottleService _instance = BandwidthThrottleService._internal();
  static BandwidthThrottleService get instance => _instance;

  BandwidthThrottleService._internal();

  BandwidthLimitPreset _currentPreset = BandwidthLimitPreset.unlimited;
  int _customLimitBytesPerSec = 0;

  final StreamController<BandwidthLimitPreset> _presetController =
      StreamController<BandwidthLimitPreset>.broadcast();

  Stream<BandwidthLimitPreset> get presetStream => _presetController.stream;
  BandwidthLimitPreset get currentPreset => _currentPreset;

  int get effectiveBytesPerSecond =>
      _customLimitBytesPerSec > 0 ? _customLimitBytesPerSec : _currentPreset.bytesPerSecond;

  bool get isThrottled => effectiveBytesPerSecond > 0;

  void setPreset(BandwidthLimitPreset preset) {
    _currentPreset = preset;
    _customLimitBytesPerSec = 0;
    _presetController.add(_currentPreset);
  }

  void setCustomLimitBytesPerSec(int bytesPerSec) {
    _customLimitBytesPerSec = max(0, bytesPerSec);
    _presetController.add(_currentPreset);
  }

  /// Calculates and applies rate-limiting delay for a chunk of bytes.
  Future<int> calculateDelayMs(int byteCount) async {
    final limit = effectiveBytesPerSecond;
    if (limit <= 0 || byteCount <= 0) return 0;

    final seconds = byteCount / limit;
    final ms = (seconds * 1000).round();
    return ms;
  }

  /// Throttles async execution if a rate limit is active.
  Future<void> throttle(int byteCount) async {
    final delayMs = await calculateDelayMs(byteCount);
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: min(delayMs, 5000)));
    }
  }

  void resetForTesting() {
    _currentPreset = BandwidthLimitPreset.unlimited;
    _customLimitBytesPerSec = 0;
  }
}
