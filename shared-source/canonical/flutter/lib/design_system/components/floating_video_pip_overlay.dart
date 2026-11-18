import 'package:flutter/material.dart';
import '../../core/video_engine_controller.dart';
import '../../core/received_files_service.dart';

class FloatingVideoPipOverlay extends StatefulWidget {
  final ReceivedFileItem fileItem;
  final VideoEngineController controller;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const FloatingVideoPipOverlay({
    super.key,
    required this.fileItem,
    required this.controller,
    required this.onExpand,
    required this.onClose,
  });

  @override
  State<FloatingVideoPipOverlay> createState() => _FloatingVideoPipOverlayState();
}

class _FloatingVideoPipOverlayState extends State<FloatingVideoPipOverlay> {
  Offset _position = const Offset(20, 80);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            key: const Key('floating_video_pip_card'),
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Mini Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_in_picture_alt_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.fileItem.name,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: widget.onExpand,
                        child: const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: widget.onClose,
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
                // Video Surface
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          widget.controller.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => setState(() => widget.controller.togglePlayPause()),
                      ),
                    ),
                  ),
                ),
                // Bottom Speed / Position Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        VideoEngineController.formatDuration(widget.controller.currentPosition),
                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      ),
                      Text(
                        '${widget.controller.playbackSpeed}x',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
