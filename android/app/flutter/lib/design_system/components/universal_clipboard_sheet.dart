import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/universal_clipboard_service.dart';

/// Minimalist Light-Only Opt-In Universal Clipboard Sync Sheet.
class UniversalClipboardSheet extends StatefulWidget {
  const UniversalClipboardSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const UniversalClipboardSheet(),
    );
  }

  @override
  State<UniversalClipboardSheet> createState() => _UniversalClipboardSheetState();
}

class _UniversalClipboardSheetState extends State<UniversalClipboardSheet> {
  final UniversalClipboardService _clip = UniversalClipboardService.instance;
  final TextEditingController _manualClipCtrl = TextEditingController();
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _clip.changeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _manualClipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _clip.activeEntries;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Icon(Icons.content_paste_go_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Universal Clipboard Sync',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Opt-in paired device clipboard with 60s OTP auto-clear',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFE5E7EB)),

              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Clipboard with Paired Devices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Paused until enabled • Never uploaded to cloud', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('universal_clipboard_sync_toggle'),
                    value: _clip.syncEnabled,
                    onChanged: (v) => setState(() => _clip.setSyncEnabled(v)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text('Auto-clear OTPs & tokens after 60s', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: _clip.autoExpireSensitive,
                    onChanged: (v) => setState(() => _clip.setAutoExpireSensitive(v)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('universal_clipboard_input_field'),
                      controller: _manualClipCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type or paste link/text to sync...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('universal_clipboard_push_button'),
                    onPressed: () {
                      final txt = _manualClipCtrl.text.trim();
                      if (txt.isEmpty) return;
                      _clip.recordSyncedClip(txt, sourceDevice: 'This Device');
                      _manualClipCtrl.clear();
                    },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                    child: const Text('Sync'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final entry = await _clip.pushLocalClipboard();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(entry != null ? 'Synced current clipboard' : 'Clipboard is empty'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.paste_rounded, size: 16),
                label: const Text('Push System Clipboard Now', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Synced Clips (${entries.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  if (entries.isNotEmpty)
                    TextButton(
                      onPressed: _clip.clearHistory,
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                    ),
                ],
              ),
              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'No synced clips yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final e = entries[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.sourceDevice}${e.autoExpire ? " • Auto-expires in 60s" : ""}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy',
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                            onPressed: () {
                              _clip.copyEntryToLocalClipboard(e);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard'), behavior: SnackBarBehavior.floating),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
