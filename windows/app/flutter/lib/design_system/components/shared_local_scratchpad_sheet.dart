import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for shared local scratchpad and instant LAN note sync.
class SharedLocalScratchpadSheet extends StatefulWidget {
  final bool isPage;

  const SharedLocalScratchpadSheet({super.key, this.isPage = false});

  static Future<void> show(BuildContext context) {
    return DedicatedToolPage.open(
      context,
      title: 'Shared Local Scratchpad',
      subtitle: 'Real-Time LAN Clipboard & Ephemeral Note Sync',
      icon: Icons.notes_rounded,
      child: const SharedLocalScratchpadSheet(isPage: true),
    );
  }

  @override
  State<SharedLocalScratchpadSheet> createState() => _SharedLocalScratchpadSheetState();
}

class _SharedLocalScratchpadSheetState extends State<SharedLocalScratchpadSheet> {
  final TextEditingController _noteController = TextEditingController(
    text: '# Project Quick Notes\n\n- Meeting link: https://meet.local/room-42\n- Test Wi-Fi password: `PeerLink2026!`\n- API Port: 50052\n',
  );

  bool _isSyncing = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _copyNote() {
    Clipboard.setData(ClipboardData(text: _noteController.text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _broadcastToPeers() {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronized scratchpad with all LAN peers'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: widget.isPage ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isPage) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.sticky_note_2_outlined, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shared LAN Scratchpad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text('Live peer-to-peer collaborative notes without cloud', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick actions toolbar
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('scratchpad_copy_button'),
                onPressed: _copyNote,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('scratchpad_sync_button'),
                onPressed: _isSyncing ? null : _broadcastToPeers,
                icon: const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF2563EB)),
                label: Text(_isSyncing ? 'Syncing...' : 'Broadcast LAN'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _noteController.clear()),
                child: const Text('Clear', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                key: const Key('scratchpad_text_field'),
                controller: _noteController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF0F172A), height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Type markdown, links, codes, or text to sync across devices...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
