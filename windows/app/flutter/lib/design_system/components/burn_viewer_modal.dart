import 'dart:async';
import 'package:flutter/material.dart';
import 'ephemeral_policy_modal.dart';
import 'glass_container.dart';

/// Sandboxed viewer for confidential Burn-After-Read ephemeral transfers.
/// Features a live countdown timer, watermark overlay, and automated physical shredding on exit.
class BurnViewerModal extends StatefulWidget {
  final String fileName;
  final String fileSize;
  final String previewContent;
  final EphemeralPolicy policy;
  final VoidCallback onShred;

  const BurnViewerModal({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.previewContent,
    required this.policy,
    required this.onShred,
  });

  static Future<void> show(
    BuildContext context, {
    required String fileName,
    required String fileSize,
    required String previewContent,
    required EphemeralPolicy policy,
    required VoidCallback onShred,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BurnViewerModal(
        fileName: fileName,
        fileSize: fileSize,
        previewContent: previewContent,
        policy: policy,
        onShred: onShred,
      ),
    );
  }

  @override
  State<BurnViewerModal> createState() => _BurnViewerModalState();
}

class _BurnViewerModalState extends State<BurnViewerModal> with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isShredding = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.policy.ttlSeconds > 0 ? widget.policy.ttlSeconds : 60; // 60s default for 1-view reading
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.policy.ttlSeconds > 0 || widget.policy.burnAfterRead) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _triggerShred();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _triggerShred() {
    if (_isShredding) return;
    setState(() => _isShredding = true);
    _timer?.cancel();

    // Call shred callback
    widget.onShred();

    // Show shredding animation then close
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🔥 "${widget.fileName}" was permanently shredded and unlinked from disk.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final watermarkText = widget.policy.watermark.isNotEmpty
        ? widget.policy.watermark
        : 'CONFIDENTIAL • 1-VIEW BURN';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        customBorder: Border.all(
          color: _isShredding ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB),
          width: 1.0,
        ),
        customBgColor: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Watermark background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.04,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Text(
                      '$watermarkText\n$watermarkText\n$watermarkText\n$watermarkText',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar
                Row(
                  children: [
                    FadeTransition(
                      opacity: _pulseCtrl,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.fileName,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: const Text(
                                  'EPHEMERAL',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.fileSize,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    // Countdown timer badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, color: Color(0xFFDC2626), size: 14),
                          const SizedBox(width: 5),
                          Text(
                            _formatTimer(_remainingSeconds),
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Preview Box
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.previewContent,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Security notice
                Row(
                  children: [
                    const Icon(Icons.lock_clock, color: Color(0xFFB45309), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.policy.burnAfterRead
                            ? '1-View Mode: Closing this viewer or timer expiry will trigger immediate zero-trust multi-pass shredding.'
                            : 'TTL Mode: File will be wiped when the timer reaches 00:00.',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isShredding ? null : _triggerShred,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Close & Burn Now'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isShredding ? null : _triggerShred,
                        icon: const Icon(Icons.local_fire_department, size: 18),
                        label: Text(_isShredding ? 'Shredding...' : 'Shred Immediately'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
