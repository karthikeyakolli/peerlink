import 'dart:async';

/// Security trip state for ransomware defense.
class CanaryTripEvent {
  final DateTime timestamp;
  final int operationCount;
  final Duration window;
  final List<String> suspiciousExtensions;
  final String triggerPath;

  const CanaryTripEvent({
    required this.timestamp,
    required this.operationCount,
    required this.window,
    required this.suspiciousExtensions,
    required this.triggerPath,
  });
}

/// Ransomware & Mass-Renaming Canary Guard protecting the vault from external malware.
class RansomwareCanaryGuard {
  RansomwareCanaryGuard._();
  static final RansomwareCanaryGuard instance = RansomwareCanaryGuard._();

  static const List<String> suspiciousExtensions = [
    '.locked',
    '.crypto',
    '.enc',
    '.wnry',
    '.ransom',
    '.crypted',
    '.darkness',
    '.payload',
  ];

  static const int velocityThreshold = 20; // operations
  static const Duration windowDuration = Duration(seconds: 3);

  final List<DateTime> _recentModifications = [];
  bool _isVaultLocked = false;
  CanaryTripEvent? _lastTrip;

  final StreamController<CanaryTripEvent> _tripController = StreamController<CanaryTripEvent>.broadcast();
  Stream<CanaryTripEvent> get onTrip => _tripController.stream;

  bool get isVaultLocked => _isVaultLocked;
  CanaryTripEvent? get lastTrip => _lastTrip;

  /// Call before any external or incoming batch file modification.
  /// Returns `true` if operation is allowed, or `false` if vault is locked.
  bool recordOperation(String fileName) {
    if (_isVaultLocked) return false;

    final now = DateTime.now();
    _recentModifications.add(now);

    // Prune entries older than window
    _recentModifications.removeWhere((t) => now.difference(t) > windowDuration);

    final lower = fileName.toLowerCase();
    final hasSuspiciousExt = suspiciousExtensions.any((ext) => lower.endsWith(ext));

    if ((_recentModifications.length >= velocityThreshold && hasSuspiciousExt) ||
        _recentModifications.length > velocityThreshold * 2) {
      _tripVault(fileName, now);
      return false;
    }

    return true;
  }

  void _tripVault(String triggerPath, DateTime now) {
    _isVaultLocked = true;
    _lastTrip = CanaryTripEvent(
      timestamp: now,
      operationCount: _recentModifications.length,
      window: windowDuration,
      suspiciousExtensions: suspiciousExtensions,
      triggerPath: triggerPath,
    );
    _tripController.add(_lastTrip!);
  }

  /// Manually unlock vault after user reviews safety.
  void unlockVault() {
    _isVaultLocked = false;
    _recentModifications.clear();
    _lastTrip = null;
  }
}
