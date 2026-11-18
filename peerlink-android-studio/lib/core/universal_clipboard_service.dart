import 'dart:async';
import 'package:flutter/services.dart';
import 'quick_text_service.dart';

class ClipboardSyncEntry {
  final String id;
  final String text;
  final String sourceDevice;
  final DateTime timestamp;
  final bool autoExpire;
  final DateTime? expiresAt;

  const ClipboardSyncEntry({
    required this.id,
    required this.text,
    required this.sourceDevice,
    required this.timestamp,
    this.autoExpire = false,
    this.expiresAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Opt-In Universal Clipboard Sync Engine between paired trusted devices.
/// - Explicitly opt-in (paused/off by default until user enables)
/// - Optional 60-second sensitive-clip auto-expiry (ideal for OTPs & links)
/// - Zero cloud / Supabase storage (Rule 5); zero AI access (Rule 11).
class UniversalClipboardService {
  static final UniversalClipboardService _instance = UniversalClipboardService._internal();
  static UniversalClipboardService get instance => _instance;

  UniversalClipboardService._internal();

  bool _syncEnabled = false;
  bool _autoExpireSensitive = true;
  final List<ClipboardSyncEntry> _history = [];
  final StreamController<void> _changeController = StreamController<void>.broadcast();
  Timer? _expiryTimer;

  bool get syncEnabled => _syncEnabled;
  bool get autoExpireSensitive => _autoExpireSensitive;
  Stream<void> get changeStream => _changeController.stream;

  List<ClipboardSyncEntry> get activeEntries {
    _purgeExpired();
    return List.unmodifiable(_history);
  }

  void setSyncEnabled(bool enabled) {
    _syncEnabled = enabled;
    _changeController.add(null);
  }

  void setAutoExpireSensitive(bool value) {
    _autoExpireSensitive = value;
    _changeController.add(null);
  }

  /// Captures the device's current OS clipboard and broadcasts/records it for paired peers.
  Future<ClipboardSyncEntry?> pushLocalClipboard({String deviceLabel = 'This Device'}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return null;
    return recordSyncedClip(text, sourceDevice: deviceLabel);
  }

  /// Records a synced clipboard item (either pushed locally or received from a paired peer).
  ClipboardSyncEntry recordSyncedClip(
    String text, {
    required String sourceDevice,
    bool? forceAutoExpire,
  }) {
    final clean = text.trim();
    final sensitive = forceAutoExpire ?? (_autoExpireSensitive && _looksSensitive(clean));
    final now = DateTime.now();
    final entry = ClipboardSyncEntry(
      id: 'clip_${now.microsecondsSinceEpoch}',
      text: clean,
      sourceDevice: sourceDevice,
      timestamp: now,
      autoExpire: sensitive,
      expiresAt: sensitive ? now.add(const Duration(seconds: 60)) : null,
    );

    _history.removeWhere((e) => e.text == clean);
    _history.insert(0, entry);
    if (_history.length > 25) {
      _history.removeRange(25, _history.length);
    }

    // Mirror into QuickTextService so existing share flows can also send it cleanly
    QuickTextService.instance.addSnippet(clean);

    _scheduleExpirySweep();
    _changeController.add(null);
    return entry;
  }

  /// Copies a synced clip to the local OS clipboard.
  Future<void> copyEntryToLocalClipboard(ClipboardSyncEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.text));
  }

  void removeEntry(String id) {
    _history.removeWhere((e) => e.id == id);
    _changeController.add(null);
  }

  void clearHistory() {
    _history.clear();
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _changeController.add(null);
  }

  bool _looksSensitive(String text) {
    // Detect 4-8 digit OTP codes or auth tokens/passwords heuristically
    if (RegExp(r'^\d{4,8}$').hasMatch(text)) return true;
    if (text.toLowerCase().contains('otp') || text.toLowerCase().contains('token=')) return true;
    return false;
  }

  void _purgeExpired() {
    final before = _history.length;
    _history.removeWhere((e) => e.isExpired);
    if (_history.length != before) {
      _changeController.add(null);
    }
  }

  void _scheduleExpirySweep() {
    _expiryTimer?.cancel();
    if (_history.any((e) => e.expiresAt != null)) {
      _expiryTimer = Timer(const Duration(seconds: 61), _purgeExpired);
    }
  }
}
