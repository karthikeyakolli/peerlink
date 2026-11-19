import 'package:flutter/material.dart';
import '../../core/media_trimmer_service.dart';
import '../../core/received_files_service.dart';
import 'dedicated_tool_page.dart';

class VideoTrimmerSheet extends StatefulWidget {
  final ReceivedFileItem fileItem;
  final Duration videoDuration;
  final VoidCallback onExported;
  final bool isPage;

  const VideoTrimmerSheet({
    super.key,
    required this.fileItem,
    required this.videoDuration,
    required this.onExported,
    this.isPage = false,
  });

  static Future<void> show(
    BuildContext context, {
    required ReceivedFileItem fileItem,
    required Duration videoDuration,
    required VoidCallback onExported,
  }) {
    return DedicatedToolPage.open(
      context,
      title: 'Video Trimmer & Audio Extractor',
      subtitle: 'Lossless Keyframe Segment Trimming & Soundtrack Rip',
      icon: Icons.content_cut_rounded,
      child: VideoTrimmerSheet(
        fileItem: fileItem,
        videoDuration: videoDuration,
        onExported: onExported,
        isPage: true,
      ),
    );
  }

  @override
  State<VideoTrimmerSheet> createState() => _VideoTrimmerSheetState();
}

class _VideoTrimmerSheetState extends State<VideoTrimmerSheet> {
  final MediaTrimmerService _service = MediaTrimmerService.instance;
  late double _startSec;
  late double _endSec;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final total = widget.videoDuration.inSeconds > 0 ? widget.videoDuration.inSeconds.toDouble() : 60.0;
    _startSec = 0.0;
    _endSec = total;
  }

  Future<void> _exportClip() async {
    setState(() => _isProcessing = true);
    try {
      final outPath = await _service.trimVideoSegment(
        videoPath: widget.fileItem.path,
        start: Duration(seconds: _startSec.round()),
        end: Duration(seconds: _endSec.round()),
      );
      if (!mounted) return;
      widget.onExported();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported trimmed clip to: ${outPath.split(r'[\/]').last}'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trim: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _extractAudio() async {
    setState(() => _isProcessing = true);
    try {
      final outPath = await _service.extractAudioTrack(videoPath: widget.fileItem.path);
      if (!mounted) return;
      widget.onExported();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Extracted audio track to: ${outPath.split(r'[\/]').last}'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to extract audio: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSec = widget.videoDuration.inSeconds > 0 ? widget.videoDuration.inSeconds.toDouble() : 60.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isPage) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.content_cut_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video Trimmer & Audio Extractor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        widget.fileItem.name,
                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Window Range
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start: ${_formatSec(_startSec.round())}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                ),
                Text(
                  'End: ${_formatSec(_endSec.round())}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            RangeSlider(
              key: const Key('video_trim_range_slider'),
              values: RangeValues(_startSec, _endSec),
              min: 0.0,
              max: maxSec,
              activeColor: const Color(0xFF2563EB),
              inactiveColor: const Color(0xFFE2E8F0),
              onChanged: (vals) {
                setState(() {
                  _startSec = vals.start;
                  _endSec = vals.end;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('extract_audio_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.music_note_rounded, size: 18),
                    label: const Text('Extract Audio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _isProcessing ? null : _extractAudio,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('export_trim_clip_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_isProcessing ? Icons.hourglass_top_rounded : Icons.content_cut_rounded, size: 18),
                    label: Text(
                      _isProcessing ? 'Processing...' : 'Export Clip',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _isProcessing ? null : _exportClip,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatSec(int sec) {
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
