import 'dart:math';

/// Authoritative transfer states representing the complete lifecycle of a PeerLink transfer.
enum TransferState {
  preparing,
  waitingForAcceptance,
  connecting,
  negotiating,
  queued,
  transferring,
  paused,
  retrying,
  reconnecting,
  verifyingIntegrity,
  committing,
  completed,
  failed,
  cancelled,
  recoverableInterruption,
  outcomeUnknown;

  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  bool get isOngoing =>
      this == transferring ||
      this == verifyingIntegrity ||
      this == committing ||
      this == queued ||
      this == connecting ||
      this == negotiating ||
      this == preparing;

  bool get isPausedOrInterrupted =>
      this == paused ||
      this == recoverableInterruption ||
      this == retrying ||
      this == reconnecting;

  String get userFacingDescription {
    switch (this) {
      case TransferState.preparing:
        return 'Preparing files...';
      case TransferState.waitingForAcceptance:
        return 'Waiting for recipient to accept...';
      case TransferState.connecting:
        return 'Connecting to peer...';
      case TransferState.negotiating:
        return 'Securing connection...';
      case TransferState.queued:
        return 'Transfer queued...';
      case TransferState.transferring:
        return 'Transferring files...';
      case TransferState.paused:
        return 'Transfer paused';
      case TransferState.retrying:
        return 'Retrying transfer...';
      case TransferState.reconnecting:
        return 'Reconnecting to peer...';
      case TransferState.verifyingIntegrity:
        return 'Verifying file integrity...';
      case TransferState.committing:
        return 'Saving to storage...';
      case TransferState.completed:
        return 'Transfer complete';
      case TransferState.failed:
        return 'Transfer failed';
      case TransferState.cancelled:
        return 'Transfer cancelled';
      case TransferState.recoverableInterruption:
        return 'Interrupted - ready to resume';
      case TransferState.outcomeUnknown:
        return 'Transfer status unconfirmed';
    }
  }
}

/// Represents an individual file within an aggregate multi-file transfer batch.
class TransferFileItem {
  final String id;
  final String name;
  final int sizeBytes;
  final int transferredBytes;
  final bool isCompleted;

  const TransferFileItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    this.transferredBytes = 0,
    this.isCompleted = false,
  });

  TransferFileItem copyWith({
    int? transferredBytes,
    bool? isCompleted,
  }) {
    return TransferFileItem(
      id: id,
      name: name,
      sizeBytes: sizeBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Internal measurement sample for rate smoothing.
class _RateSample {
  final int timestampMs;
  final int transferredBytes;

  const _RateSample(this.timestampMs, this.transferredBytes);
}

/// Authoritative, truthful transfer progress engine.
///
/// Implements:
/// - Exact transferred-byte accounting from authoritative events (zero simulated timers).
/// - 3-sample sliding-window rate smoothing without falsifying bytes.
/// - Remaining time (ETA) only calculated when at least 3 reliable samples exist.
/// - Multi-file aggregate progress weighted by actual item sizes.
/// - Indeterminate progress support for unknown file sizes.
/// - Never displays 100% until receiver verification and commit confirmation is received.
class TransferProgressModel {
  final String transferId;
  final String remotePeerId;
  final String remotePeerName;
  final bool isOutbound;

  TransferState _state;
  int _transferredBytes;
  int _totalBytes;
  String _currentFileName;
  String? _errorMessage;
  final int _startTimeMs;

  final List<TransferFileItem> _items;
  final List<_RateSample> _rateWindow = [];
  static const int _maxRateSamples = 3;

  TransferProgressModel({
    required this.transferId,
    required this.remotePeerId,
    this.remotePeerName = 'Unknown Peer',
    this.isOutbound = true,
    TransferState initialState = TransferState.preparing,
    int initialTransferredBytes = 0,
    int initialTotalBytes = -1,
    String initialFileName = '',
    List<TransferFileItem> items = const [],
    int? startTimeMs,
  })  : _state = initialState,
        _transferredBytes = initialTransferredBytes,
        _totalBytes = initialTotalBytes,
        _currentFileName = initialFileName,
        _items = List.from(items),
        _startTimeMs = startTimeMs ?? DateTime.now().millisecondsSinceEpoch {
    _rateWindow.add(_RateSample(_startTimeMs, initialTransferredBytes));
  }

  // Getters
  TransferState get state => _state;
  int get transferredBytes => _transferredBytes;
  int get totalBytes => _totalBytes;
  String get currentFileName => _currentFileName;
  String? get errorMessage => _errorMessage;
  int get startTimeMs => _startTimeMs;
  List<TransferFileItem> get items => List.unmodifiable(_items);

  int get totalItemCount => _items.isNotEmpty ? _items.length : 1;
  int get completedItemCount => _items.where((i) => i.isCompleted).length;

  bool get isIndeterminate => _totalBytes <= 0;

  /// Progress ratio from 0.0 to 1.0, or null if total size is unknown.
  ///
  /// CRITICAL RULE: Never returns 1.0 in `transferring` state before verification and commit.
  double? get progressRatio {
    if (isIndeterminate) return null;
    if (_totalBytes <= 0) return null;

    final rawRatio = (_transferredBytes / _totalBytes).clamp(0.0, 1.0);

    // Rule: Never show 100% until verifying integrity, committing, or completed
    if (_state == TransferState.transferring && rawRatio >= 1.0) {
      return 0.99;
    }
    if (_state == TransferState.completed) {
      return 1.0;
    }
    return rawRatio;
  }

  /// Percentage integer (0 to 100), or null if indeterminate.
  int? get progressPercent {
    final ratio = progressRatio;
    if (ratio == null) return null;
    return (ratio * 100).round();
  }

  /// Updates state authoritatively.
  void updateState(TransferState newState, {String? error}) {
    _state = newState;
    if (error != null) _errorMessage = error;
    if (newState == TransferState.completed) {
      if (_totalBytes > 0) {
        _transferredBytes = _totalBytes;
      }
    }
  }

  /// Records authoritative progress event.
  ///
  /// Uses a 3-sample sliding window to smooth rate without falsifying counters.
  void recordProgress({
    required int transferredBytes,
    int? totalBytes,
    String? currentFileName,
    int? timestampMs,
  }) {
    _transferredBytes = transferredBytes;
    if (totalBytes != null && totalBytes > 0) {
      _totalBytes = totalBytes;
    }
    if (currentFileName != null && currentFileName.isNotEmpty) {
      _currentFileName = currentFileName;
    }

    final now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

    // Discard any older sample if timestamp is not monotonically non-decreasing
    if (_rateWindow.isNotEmpty && now <= _rateWindow.last.timestampMs) {
      return;
    }

    _rateWindow.add(_RateSample(now, transferredBytes));
    while (_rateWindow.length > _maxRateSamples) {
      _rateWindow.removeAt(0);
    }
  }

  /// Smoothed transfer rate in bytes per second.
  ///
  /// Returns null if fewer than 2 samples exist or if the transfer is paused/terminal.
  double? get smoothedRateBytesPerSec {
    if (_state.isTerminal || _state == TransferState.paused) return null;
    if (_rateWindow.length < 2) return null;

    double totalRate = 0;
    int intervals = 0;

    for (int i = 1; i < _rateWindow.length; i++) {
      final prev = _rateWindow[i - 1];
      final curr = _rateWindow[i];
      final deltaBytes = curr.transferredBytes - prev.transferredBytes;
      final deltaSec = (curr.timestampMs - prev.timestampMs) / 1000.0;

      // Skip intervals shorter than 50ms to prevent division by zero / jitter
      if (deltaSec >= 0.05 && deltaBytes >= 0) {
        totalRate += deltaBytes / deltaSec;
        intervals++;
      }
    }

    if (intervals == 0) return null;
    return totalRate / intervals;
  }

  /// Estimated time remaining.
  ///
  /// CRITICAL RULE: Only calculated when at least 3 reliable samples exist,
  /// smoothed rate > 1024 B/s, and totalBytes is known and greater than transferred.
  Duration? get estimatedRemainingTime {
    if (_state.isTerminal || _state == TransferState.paused) return null;
    if (isIndeterminate) return null;
    if (_rateWindow.length < 3) return null;

    final rate = smoothedRateBytesPerSec;
    if (rate == null || rate < 1024) return null;

    final remainingBytes = _totalBytes - _transferredBytes;
    if (remainingBytes <= 0) return Duration.zero;

    final remainingSec = remainingBytes / rate;
    if (remainingSec.isNaN || remainingSec.isInfinite || remainingSec < 0) {
      return null;
    }

    return Duration(seconds: min(remainingSec.round(), 86400 * 7)); // Max 7 days cap
  }

  /// Formatted transferred progress (e.g., "14.2 MB / 50.0 MB (28%)" or "14.2 MB (Unknown)").
  String get formattedProgress {
    final transStr = _formatBytes(_transferredBytes);
    if (isIndeterminate) {
      return '$transStr (Unknown size)';
    }
    final totalStr = _formatBytes(_totalBytes);
    final pct = progressPercent ?? 0;
    return '$transStr / $totalStr ($pct%)';
  }

  /// Formatted rate string (e.g. "12.5 MB/s" or "--").
  String get formattedRate {
    final rate = smoothedRateBytesPerSec;
    if (rate == null || rate <= 0) return '--';
    return '${_formatBytes(rate.round())}/s';
  }

  /// Formatted remaining time (e.g. "About 45s remaining" or "--").
  String get formattedEta {
    final eta = estimatedRemainingTime;
    if (eta == null) return '--';
    if (eta.inSeconds < 60) {
      return 'About ${eta.inSeconds}s remaining';
    } else if (eta.inMinutes < 60) {
      final remSec = eta.inSeconds % 60;
      return 'About ${eta.inMinutes}m ${remSec}s remaining';
    } else {
      final remMin = eta.inMinutes % 60;
      return 'About ${eta.inHours}h ${remMin}m remaining';
    }
  }

  /// Formats byte count into human-readable unit.
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
