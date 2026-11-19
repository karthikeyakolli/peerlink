import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for 5-band audio frequency equalization and vocal clarity enhancement.
class AudioEqualizerSheet extends StatefulWidget {
  final bool isPage;

  const AudioEqualizerSheet({super.key, this.isPage = false});

  static Future<void> show(BuildContext context) {
    return DedicatedToolPage.open(
      context,
      title: '5-Band Acoustic Equalizer',
      subtitle: 'Hardware Calibration & Vocal Clarity Booster',
      icon: Icons.graphic_eq_rounded,
      child: const AudioEqualizerSheet(isPage: true),
    );
  }

  @override
  State<AudioEqualizerSheet> createState() => _AudioEqualizerSheetState();
}

class _AudioEqualizerSheetState extends State<AudioEqualizerSheet> {
  String _selectedPreset = 'Vocal Clarity';
  List<double> _bandGains = [0.0, -1.0, 3.5, 4.0, 1.0]; // 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz

  final List<String> _bandLabels = ['60Hz', '230Hz', '910Hz', '3.6k', '14kHz'];

  final Map<String, List<double>> _presets = {
    'Vocal Clarity': [0.0, -1.0, 3.5, 4.0, 1.0],
    'Bass Boost': [5.0, 4.0, 1.0, 0.0, 0.0],
    'Podcast': [-2.0, 0.0, 4.0, 3.0, 0.0],
    'Acoustic': [2.0, 1.0, 2.0, 3.0, 3.0],
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
  };

  void _applyPreset(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreset = name;
      _bandGains = List.from(_presets[name]!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
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
                child: const Icon(Icons.graphic_eq_rounded, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5-Band Equalizer & Vocal Clarity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Hardware acoustic calibration and speech intelligibility booster',
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
          // Presets row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presets.keys.map((p) {
                final isSelected = _selectedPreset == p;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(p, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF334155))),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    onSelected: (_) => _applyPreset(p),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // 5 Sliders Container
          Container(
            height: 160,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (idx) {
                return Column(
                  children: [
                    Text(
                      '${_bandGains[idx] >= 0 ? "+" : ""}${_bandGains[idx].toStringAsFixed(0)}dB',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Slider(
                          value: _bandGains[idx],
                          min: -6.0,
                          max: 6.0,
                          divisions: 12,
                          activeColor: const Color(0xFF2563EB),
                          inactiveColor: const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            setState(() {
                              _selectedPreset = 'Custom';
                              _bandGains[idx] = val;
                            });
                          },
                        ),
                      ),
                    ),
                    Text(
                      _bandLabels[idx],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply Acoustics', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
