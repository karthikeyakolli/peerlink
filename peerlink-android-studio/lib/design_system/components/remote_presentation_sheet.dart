import 'package:flutter/material.dart';
import '../../core/remote_presentation_controller_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only Remote Presentation & Media Controller Sheet.
/// Turns the phone into a slide clicker and media controller for the Windows PC over authenticated LAN.
class RemotePresentationSheet extends StatefulWidget {
  const RemotePresentationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RemotePresentationSheet(),
    );
  }

  @override
  State<RemotePresentationSheet> createState() => _RemotePresentationSheetState();
}

class _RemotePresentationSheetState extends State<RemotePresentationSheet> {
  final RemotePresentationControllerService _remote = RemotePresentationControllerService.instance;
  String _lastAction = 'Ready';

  void _send(PresentationCommand cmd, String label) {
    _remote.sendPresentationCommand(cmd);
    setState(() => _lastAction = label);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.cast_for_education_rounded, size: 22, color: PeerLinkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remote Presentation & Media',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        'Status: $_lastAction',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Slide Presentation Controller Deck
            const Text(
              'SLIDE CONTROLS (PowerPoint / PDF / Keynote)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 80,
                    child: OutlinedButton.icon(
                      key: const Key('remote_prev_slide_button'),
                      onPressed: () => _send(PresentationCommand.prevSlide, 'Previous Slide'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      label: const Text('Previous', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 80,
                    child: ElevatedButton.icon(
                      key: const Key('remote_next_slide_button'),
                      onPressed: () => _send(PresentationCommand.nextSlide, 'Next Slide'),
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 22),
                      label: const Text('Next Slide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PeerLinkColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _send(PresentationCommand.blackScreen, 'Toggle Black Screen'),
              icon: const Icon(Icons.visibility_off_outlined, size: 16),
              label: const Text('Toggle Black Screen (B)'),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 20),

            // Media & Volume Controller
            const Text(
              'MEDIA & VOLUME CONTROLS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_down_rounded, size: 24, color: Color(0xFF334155)),
                    tooltip: 'Volume Down',
                    onPressed: () => _send(PresentationCommand.volumeDown, 'Volume Down'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 36, color: PeerLinkColors.primaryBlue),
                    tooltip: 'Play / Pause',
                    onPressed: () => _send(PresentationCommand.mediaPlayPause, 'Play/Pause'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, size: 24, color: Color(0xFF334155)),
                    tooltip: 'Volume Up',
                    onPressed: () => _send(PresentationCommand.volumeUp, 'Volume Up'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_off_rounded, size: 24, color: Color(0xFFEF4444)),
                    tooltip: 'Mute',
                    onPressed: () => _send(PresentationCommand.mute, 'Mute'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
