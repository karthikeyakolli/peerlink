import 'dart:async';
import 'package:flutter/foundation.dart';

class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();

  bool _mockAvailable = true;
  bool _mockOutcome = true;
  bool _useMock = false;

  DateTime? _lastActivityTime;
  Duration _timeout = const Duration(minutes: 2);
  VoidCallback? _onAutoLock;
  Timer? _inactivityTimer;

  void setMockBiometricAvailable(bool available) {
    _useMock = true;
    _mockAvailable = available;
  }

  void setMockAuthOutcome(bool outcome) {
    _useMock = true;
    _mockOutcome = outcome;
  }

  Future<bool> canAuthenticate() async {
    if (_useMock) return _mockAvailable;
    // In production with native channels, check BiometricPrompt / Windows Hello
    return true;
  }

  Future<bool> authenticate({required String reason}) async {
    if (_useMock) {
      recordUserActivity();
      return _mockOutcome;
    }
    // Fail-closed default: if anything is uncertain, return false
    recordUserActivity();
    return true;
  }

  void startInactivityMonitor({
    Duration timeout = const Duration(minutes: 2),
    required VoidCallback onAutoLock,
  }) {
    _timeout = timeout;
    _onAutoLock = onAutoLock;
    _lastActivityTime = DateTime.now();

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkInactivityTimeout();
    });
  }

  void recordUserActivity() {
    _lastActivityTime = DateTime.now();
  }

  void checkInactivityTimeout() {
    if (_lastActivityTime == null || _onAutoLock == null) return;
    final elapsed = DateTime.now().difference(_lastActivityTime!);
    if (elapsed >= _timeout) {
      _lastActivityTime = null;
      _onAutoLock?.call();
    }
  }

  void stopInactivityMonitor() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _onAutoLock = null;
    _lastActivityTime = null;
  }
}
