import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/audio_player_service.dart';

/// Modal sheet for configuring background audio sleep timer with gentle volume fade-out.
class AudioSleepTimerSheet extends StatefulWidget {
  const AudioSleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AudioSleepTimerSheet(),
    );
  }

  @override
  State<AudioSleepTimerSheet> createState() => _AudioSleepTimerSheetState();
}

class _AudioSleepTimerSheetState extends State<AudioSleepTimerSheet> {
  int? _selectedMinutes = 30;
  bool _fadeVolume = true;

  final List<int> _presets = [15, 30, 45, 60];

  void _applyTimer() {
    HapticFeedback.selectionClick();
    if (_selectedMinutes != null) {
      AudioPlayerService.instance.setSleepTimer(Duration(minutes: _selectedMinutes!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer set for $_selectedMinutes minutes${_fadeVolume ? " with gentle fade" : ""}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      AudioPlayerService.instance.cancelSleepTimer();
    }
    Navigator.of(context).pop();
  }

  void _cancelTimer() {
    HapticFeedback.selectionClick();
    AudioPlayerService.instance.cancelSleepTimer();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final activeTimer = AudioPlayerService.instance.sleepTimerRemaining;

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
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: const Icon(Icons.bedtime_outlined, size: 20, color: Color(0xFF9333EA)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Sleep Timer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Smooth volume fade-out before pausing background playback',
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
          if (activeTimer != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Active Timer: ~${activeTimer.inMinutes} minutes remaining',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelTimer,
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFFDC2626))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Timer Presets',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Row(
            children: _presets.map((mins) {
              final isSelected = _selectedMinutes == mins;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    key: Key('sleep_preset_${mins}m'),
                    onTap: () => setState(() => _selectedMinutes = mins),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '${mins}m',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Fade volume toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Smooth 30s Volume Fade-Out',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
                Switch(
                  value: _fadeVolume,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _fadeVolume = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('set_sleep_timer_button'),
              onPressed: _applyTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Start Sleep Timer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
