import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/smart_content_sniffer.dart';
import '../colors/peerlink_colors.dart';
import 'glass_container.dart';

/// Ambient Floating Smart Clipboard Banner.
/// Detects copied actionable links, credentials, or text and surfaces a 1-tap beam action.
class SmartClipboardBanner extends StatelessWidget {
  final SmartContentResult content;
  final String? targetPeerName;
  final VoidCallback onBeam;
  final VoidCallback onDismiss;

  const SmartClipboardBanner({
    super.key,
    required this.content,
    this.targetPeerName,
    required this.onBeam,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final peerLabel = targetPeerName != null && targetPeerName!.isNotEmpty
        ? targetPeerName!
        : 'Nearby Peer';

    final surfaceColor = isDark ? const Color(0xFF151C28) : Colors.white;
    final borderColor = isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Content Type Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: content.accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, color: content.accentColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Content Title & Target
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        content.displayTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Clip',
                        style: TextStyle(fontSize: 8, color: textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Beam directly to $peerLabel',
                  style: TextStyle(
                    fontSize: 10,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 1-Tap Beam Button
          FilledButton.icon(
            key: const Key('smart_clipboard_beam_button'),
            style: FilledButton.styleFrom(
              backgroundColor: content.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text(
              'Beam',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: onBeam,
          ),
          const SizedBox(width: 4),

          // Dismiss Button
          IconButton(
            key: const Key('smart_clipboard_dismiss_button'),
            tooltip: 'Dismiss',
            icon: Icon(Icons.close_rounded, size: 16, color: textSecondary),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
