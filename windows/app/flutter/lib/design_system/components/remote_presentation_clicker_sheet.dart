import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal sheet transforming the mobile app into a local Wi-Fi presentation clicker & trackpad.
class RemotePresentationClickerSheet extends StatefulWidget {
  const RemotePresentationClickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RemotePresentationClickerSheet(),
    );
  }

  @override
  State<RemotePresentationClickerSheet> createState() => _RemotePresentationClickerSheetState();
}

class _RemotePresentationClickerSheetState extends State<RemotePresentationClickerSheet> {
  int _activeMode = 0; // 0: Clicker, 1: Trackpad
  bool _laserActive = false;

  void _sendCommand(String cmd) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dispatched slide command: $cmd'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.cast_connected_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Presentation Clicker & Remote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      Text('Control slides and PC cursor over private local Wi-Fi', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          // Mode switch chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Slide Clicker')),
                    selected: _activeMode == 0,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: _activeMode == 0 ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w600),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: _activeMode == 0 ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    onSelected: (_) => setState(() => _activeMode = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Remote Trackpad')),
                    selected: _activeMode == 1,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: _activeMode == 1 ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w600),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide(color: _activeMode == 1 ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                    onSelected: (_) => setState(() => _activeMode = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _activeMode == 0 ? _buildClickerPad() : _buildTrackpad(),
          ),
        ],
      ),
    );
  }

  Widget _buildClickerPad() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendCommand('F5 (Start Slideshow)'),
                  icon: const Icon(Icons.slideshow_rounded, size: 18),
                  label: const Text('Start (F5)'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendCommand('B (Blank Screen)'),
                  icon: const Icon(Icons.brightness_low_rounded, size: 18),
                  label: const Text('Black (B)'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Previous Slide Button
          Expanded(
            flex: 2,
            child: InkWell(
              key: const Key('clicker_prev_button'),
              onTap: () => _sendCommand('Previous Slide'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 28, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text('PREVIOUS SLIDE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Next Slide Button (Dominant)
          Expanded(
            flex: 3,
            child: InkWell(
              key: const Key('clicker_next_button'),
              onTap: () => _sendCommand('Next Slide'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('NEXT SLIDE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_downward_rounded, size: 32, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Laser pointer button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _laserActive = !_laserActive),
              icon: Icon(Icons.adjust_rounded, size: 18, color: _laserActive ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
              label: Text(_laserActive ? 'Laser Pointer ON' : 'Turn Laser Pointer ON'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _laserActive ? const Color(0xFFFECACA) : const Color(0xFFCBD5E1)),
                backgroundColor: _laserActive ? const Color(0xFFFEF2F2) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackpad() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Touch surface
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('Swipe surface to move cursor', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  Text('Tap to click • Two fingers to scroll', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Left and Right mouse buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _sendCommand('Mouse Left Click'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Left Click', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _sendCommand('Mouse Right Click'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Right Click', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
