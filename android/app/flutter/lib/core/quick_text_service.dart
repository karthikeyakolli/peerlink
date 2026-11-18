import 'dart:async';
import 'package:flutter/services.dart';
import 'device_trust_service.dart';

/// Represents a transmitted or received text snippet or link.
class TextSnippetItem {
  final String id;
  final String text;
  final String peerId;
  final String peerName;
  final bool isOutgoing;
  final DateTime timestamp;

  const TextSnippetItem({
    required this.id,
    required this.text,
    required this.peerId,
    required this.peerName,
    required this.isOutgoing,
    required this.timestamp,
  });

  bool get isUrl {
    final t = text.trim();
    return t.startsWith('http://') || t.startsWith('https://');
  }
}

/// Authoritative service managing peer-to-peer quick text and clipboard sharing.
class QuickTextService {
  static final QuickTextService _instance = QuickTextService._internal();
  static QuickTextService get instance => _instance;

  QuickTextService._internal();

  final List<TextSnippetItem> _history = [];
  final StreamController<TextSnippetItem> _incomingTextController =
      StreamController<TextSnippetItem>.broadcast(sync: true);
  final StreamController<List<TextSnippetItem>> _historyController =
      StreamController<List<TextSnippetItem>>.broadcast(sync: true);

  Stream<TextSnippetItem> get incomingTextStream => _incomingTextController.stream;
  Stream<List<TextSnippetItem>> get historyStream => _historyController.stream;
  List<TextSnippetItem> get history => List.unmodifiable(_history);

  /// Prepares and sends a text snippet to a target peer.
  Future<bool> sendText({
    required String text,
    required String targetPeerId,
    String? targetPeerName,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || targetPeerId.isEmpty) return false;

    final peer = DeviceTrustService.instance.getDevice(targetPeerId);
    final effectiveName = targetPeerName ?? peer?.name ?? targetPeerId;

    final item = TextSnippetItem(
      id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
      text: cleanText,
      peerId: targetPeerId,
      peerName: effectiveName,
      isOutgoing: true,
      timestamp: DateTime.now(),
    );

    _history.insert(0, item);
    _historyController.add(List.unmodifiable(_history));
    return true;
  }

  /// Ingests an incoming text snippet from a peer and alerts active UI listeners.
  void receiveText({
    required String text,
    required String senderPeerId,
    String? senderPeerName,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final peer = DeviceTrustService.instance.getDevice(senderPeerId);
    final effectiveName = senderPeerName ?? peer?.name ?? senderPeerId;

    final item = TextSnippetItem(
      id: 'txt_in_${DateTime.now().millisecondsSinceEpoch}',
      text: cleanText,
      peerId: senderPeerId,
      peerName: effectiveName,
      isOutgoing: false,
      timestamp: DateTime.now(),
    );

    _history.insert(0, item);
    _historyController.add(List.unmodifiable(_history));
    _incomingTextController.add(item);
  }

  /// Convenience helper to add text snippets (e.g. from system share intent or clipboard).
  void addSnippet(String text, {String senderPeerId = 'System Share'}) {
    receiveText(text: text, senderPeerId: senderPeerId);
  }

  /// Copies text directly into the system clipboard.
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Reads current system clipboard text.
  Future<String?> readFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  void clearHistory() {
    _history.clear();
    _historyController.add(List.unmodifiable(_history));
  }

  void resetForTesting() {
    _history.clear();
    _historyController.add(List.unmodifiable(_history));
  }
}
