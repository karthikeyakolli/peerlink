import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef BroadcastFrameCallback = void Function(Map<String, dynamic> frame);

class P2pClipboardTransportService extends ChangeNotifier {
  P2pClipboardTransportService._();
  static final P2pClipboardTransportService instance = P2pClipboardTransportService._();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  String? _lastReceivedContent;
  String? get lastReceivedContent => _lastReceivedContent;

  BroadcastFrameCallback? onBroadcastFrame;
  Timer? _otpAutoClearTimer;

  static final RegExp _otpRegex = RegExp(r'^\b\d{4,8}\b$');

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  void handleLocalClipboardChanged(String text) {
    if (!_isEnabled) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final isOtp = _otpRegex.hasMatch(trimmed);

    final frame = <String, dynamic>{
      'type': 'CLIPBOARD_SYNC',
      'content': trimmed,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isOtp': isOtp,
    };

    onBroadcastFrame?.call(frame);
  }

  bool processIncomingFrame(Map<String, dynamic> frame) {
    if (frame['type'] != 'CLIPBOARD_SYNC') return false;
    final content = frame['content'];
    if (content is! String || content.trim().isEmpty) return false;

    _lastReceivedContent = content;
    final isOtp = frame['isOtp'] == true || _otpRegex.hasMatch(content.trim());

    // Update system clipboard
    try {
      Clipboard.setData(ClipboardData(text: content));
    } catch (_) {}

    // Enforce 60-second OTP auto-clear
    _otpAutoClearTimer?.cancel();
    if (isOtp) {
      _otpAutoClearTimer = Timer(const Duration(seconds: 60), () {
        try {
          Clipboard.setData(const ClipboardData(text: ''));
        } catch (_) {}
      });
    }

    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _otpAutoClearTimer?.cancel();
    super.dispose();
  }
}
