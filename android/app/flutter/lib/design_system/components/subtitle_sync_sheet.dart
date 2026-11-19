import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal sheet for auto-detecting subtitles and adjusting real-time sync offset (+/- 2500ms).
class SubtitleSyncSheet extends StatefulWidget {
  final String videoStem;
  final int initialOffsetMs;
  final ValueChanged<int>? onOffsetChanged;

  const SubtitleSyncSheet({
    super.key,
    required this.videoStem,
    this.initialOffsetMs = 0,
    this.onOffsetChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String videoStem,
    int initialOffsetMs = 0,
    ValueChanged<int>? onOffsetChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubtitleSyncSheet(
        videoStem: videoStem,
        initialOffsetMs: initialOffsetMs,
        onOffsetChanged: onOffsetChanged,
      ),
    );
  }

  @override
  State<SubtitleSyncSheet> createState() => _SubtitleSyncSheetState();
}

class _SubtitleSyncSheetState extends State<SubtitleSyncSheet> {
  late int _offsetMs;
  bool _subtitlesEnabled = true;
  String _selectedSubtitle = 'Auto-matched (.srt)';

  @override
  void initState() {
    super.initState();
    _offsetMs = widget.initialOffsetMs;
  }

  void _updateOffset(int newOffset) {
    HapticFeedback.selectionClick();
    setState(() {
      _offsetMs = newOffset.clamp(-2500, 2500);
    });
    widget.onOffsetChanged?.call(_offsetMs);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.subtitles_outlined, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subtitles & Real-Time Sync',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Match local .srt/.vtt files and calibrate timing offset',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Subtitles master toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Render Subtitle Track',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
                Switch(
                  value: _subtitlesEnabled,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _subtitlesEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Detected Subtitle Track
          const Text(
            'Matched Local Subtitle',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.videoStem}.en.srt',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                  ),
                ),
                const Text('UTF-8', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Timing Offset Calibration Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sync Timing Offset',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${_offsetMs >= 0 ? "+" : ""}${_offsetMs} ms',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          Slider(
            value: _offsetMs.toDouble(),
            min: -2500,
            max: 2500,
            divisions: 100,
            activeColor: const Color(0xFF2563EB),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (val) => _updateOffset(val.round()),
          ),
          // Nudge buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _updateOffset(_offsetMs - 100),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('-100 ms', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _updateOffset(0),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Reset (0 ms)', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _updateOffset(_offsetMs + 100),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('+100 ms', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
