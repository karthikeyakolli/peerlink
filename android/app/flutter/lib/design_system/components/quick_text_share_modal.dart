import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick Text and Clipboard Sharing Modal inspired by LocalSend and AirDrop.
/// Allows sending text snippets, URLs, and clipboard clips directly between devices.
class QuickTextShareModal extends StatefulWidget {
  final void Function(String text, String? targetPeerId) onSendText;
  final String? initialPeerId;

  const QuickTextShareModal({
    super.key,
    required this.onSendText,
    this.initialPeerId,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(String text, String? targetPeerId) onSendText,
    String? initialPeerId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: QuickTextShareModal(
          onSendText: onSendText,
          initialPeerId: initialPeerId,
        ),
      ),
    );
  }

  /// Helper to display incoming text modal with one-tap copy or link navigation
  static void showIncomingText(
    BuildContext context, {
    required String senderName,
    required String text,
  }) {
    final isUrl = text.trim().startsWith('http://') ||
        text.trim().startsWith('https://');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mark_chat_read_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('Text from $senderName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            if (isUrl) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Web Link Detected',
                      style: TextStyle(fontSize: 11, color: Colors.blue)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  @override
  State<QuickTextShareModal> createState() => _QuickTextShareModalState();
}

class _QuickTextShareModalState extends State<QuickTextShareModal> {
  final TextEditingController _textController = TextEditingController();
  bool _isUrl = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_checkUrl);
  }

  @override
  void dispose() {
    _textController.removeListener(_checkUrl);
    _textController.dispose();
    super.dispose();
  }

  void _checkUrl() {
    final t = _textController.text.trim();
    final url = t.startsWith('http://') || t.startsWith('https://');
    if (url != _isUrl) {
      setState(() => _isUrl = url);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.content_paste_go_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Quick Text & Link Share',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Paste'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Text Input Box
          TextField(
            controller: _textController,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Type or paste a message, link, code snippet, or Wi-Fi password...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 10),

          // Link Detection Pill & Character Count
          Row(
            children: [
              if (_isUrl)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.link_rounded, size: 12, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        'URL Link Detected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                '${_textController.text.length} characters',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Send Action Button
          FilledButton.icon(
            onPressed: _textController.text.trim().isEmpty
                ? null
                : () {
                    final text = _textController.text.trim();
                    Navigator.pop(context);
                    widget.onSendText(text, widget.initialPeerId);
                  },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send Text to Nearby Peer'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
