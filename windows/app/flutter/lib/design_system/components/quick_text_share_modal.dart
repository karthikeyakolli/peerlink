import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/device_trust_service.dart';
import '../../core/quick_text_service.dart';
import '../../core/smart_content_sniffer.dart';

/// Quick Text and Clipboard Sharing Modal inspired by LocalSend and AirDrop.
/// Enhanced with Smart Content Intelligence for 1-tap browser opening,
/// Wi-Fi credential extraction, and structured code formatting.
class QuickTextShareModal extends StatefulWidget {
  final void Function(String text, String? targetPeerId)? onSendText;
  final String? initialPeerId;
  final String? initialText;

  const QuickTextShareModal({
    super.key,
    this.onSendText,
    this.initialPeerId,
    this.initialText,
  });

  static Future<void> show(
    BuildContext context, {
    void Function(String text, String? targetPeerId)? onSendText,
    String? initialPeerId,
    String? initialText,
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
          initialText: initialText,
        ),
      ),
    );
  }

  /// Helper to display incoming text modal with 1-tap actionable intelligence.
  static void showIncomingText(
    BuildContext context, {
    required String senderName,
    required String text,
  }) {
    final intel = SmartContentSniffer.instance.sniff(text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: intel.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(intel.icon, color: intel.accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Text from $senderName',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    intel.displayTitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: intel.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  intel.formattedJson ?? text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontFamily: intel.type == SmartContentType.jsonCode ? 'monospace' : null,
                  ),
                ),
              ),
            ),
            if (intel.type == SmartContentType.url) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 4),
                  Text(
                    'Web Link Detected',
                    style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              intel.displaySubtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          if (intel.type == SmartContentType.url)
            FilledButton.icon(
              key: const Key('incoming_open_browser_button'),
              onPressed: () {
                SmartContentSniffer.instance.openUrl(text);
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text('Open in Browser'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (intel.type == SmartContentType.wifiConfig && intel.wifiConfig != null)
            FilledButton.icon(
              key: const Key('incoming_copy_wifi_button'),
              onPressed: () {
                final pass = intel.wifiConfig!.password;
                Clipboard.setData(ClipboardData(text: pass));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied Wi-Fi password for "${intel.wifiConfig!.ssid}"!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.wifi_password_rounded, size: 16),
              label: const Text('Copy Password'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                visualDensity: VisualDensity.compact,
              ),
            ),
          FilledButton.icon(
            key: const Key('incoming_copy_raw_button'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy to Clipboard'),
            style: FilledButton.styleFrom(
              backgroundColor: intel.type == SmartContentType.url ? const Color(0xFF64748B) : const Color(0xFF10B981),
              visualDensity: VisualDensity.compact,
            ),
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
  SmartContentResult? _detectedIntel;
  String? _selectedPeerId;

  @override
  void initState() {
    super.initState();
    _selectedPeerId = widget.initialPeerId ??
        DeviceTrustService.instance.selectedSendTarget ??
        (DeviceTrustService.instance.devices.isNotEmpty
            ? DeviceTrustService.instance.devices.first.id
            : null);
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      _checkContent();
    }
    _textController.addListener(_checkContent);
  }

  @override
  void dispose() {
    _textController.removeListener(_checkContent);
    _textController.dispose();
    super.dispose();
  }

  void _checkContent() {
    final t = _textController.text.trim();
    if (t.isEmpty) {
      setState(() => _detectedIntel = null);
    } else {
      final intel = SmartContentSniffer.instance.sniff(t);
      setState(() => _detectedIntel = intel);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _textController.text = data.text!;
      });
      _checkContent();
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final targetPeer = _selectedPeerId ?? 'broadcast';
    await QuickTextService.instance.sendText(
      text: text,
      targetPeerId: targetPeer,
    );

    widget.onSendText?.call(text, targetPeer);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Text sent (${text.length} chars) to ${_getPeerDisplayName(targetPeer)}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  String _getPeerDisplayName(String peerId) {
    final peer = DeviceTrustService.instance.getDevice(peerId);
    return peer?.name ?? peerId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pairedDevices = DeviceTrustService.instance.devices;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
          const SizedBox(height: 14),

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
          const SizedBox(height: 12),

          // Target Peer Selector
          if (pairedDevices.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: pairedDevices.any((d) => d.id == _selectedPeerId)
                  ? _selectedPeerId
                  : pairedDevices.first.id,
              decoration: const InputDecoration(
                labelText: 'Send to Device',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: pairedDevices.map((d) {
                return DropdownMenuItem<String>(
                  value: d.id,
                  child: Row(
                    children: [
                      Icon(
                        d.deviceType.toLowerCase().contains('phone') || d.deviceType.toLowerCase().contains('android')
                            ? Icons.phone_android_rounded
                            : Icons.laptop_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${d.name} (${d.isOnline ? "Online" : "Offline"})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedPeerId = val);
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // Text Input Box
          TextField(
            controller: _textController,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Type or paste a message, URL, code snippet, or Wi-Fi password...',
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

          // Smart Content Intelligence Pill & Character Count
          Row(
            children: [
              if (_detectedIntel != null && _detectedIntel!.type != SmartContentType.plainText)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _detectedIntel!.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _detectedIntel!.accentColor.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_detectedIntel!.icon, size: 13, color: _detectedIntel!.accentColor),
                      const SizedBox(width: 5),
                      Text(
                        _detectedIntel!.type == SmartContentType.url
                            ? 'URL Link Detected'
                            : _detectedIntel!.displayTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _detectedIntel!.accentColor,
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
          const SizedBox(height: 16),

          // Send Action Button
          FilledButton.icon(
            onPressed: _textController.text.trim().isEmpty ? null : _handleSend,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send Text or Link'),
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

