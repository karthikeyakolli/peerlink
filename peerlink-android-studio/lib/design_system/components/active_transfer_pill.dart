import 'dart:async';
import 'package:flutter/material.dart';
import '../../platform/android_node_bridge.dart';

class LiveTransferStatus {
  final String transferId;
  final String fileName;
  final int percent;
  final int transferredBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final bool isCompleted;
  final bool isSuccess;
  final String? errorMessage;

  const LiveTransferStatus({
    required this.transferId,
    required this.fileName,
    required this.percent,
    required this.transferredBytes,
    required this.totalBytes,
    this.bytesPerSecond = 0,
    this.isCompleted = false,
    this.isSuccess = true,
    this.errorMessage,
  });

  String get formattedSpeed {
    if (bytesPerSecond <= 0) return '';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}

/// Minimalist flat light-mode live transfer progress bar docked cleanly over the
/// navigation bar so users can monitor real-time P2P transfers without leaving
/// the File Manager. Zero gradients, zero shadows, reduced-motion safe.
class ActiveTransferPill extends StatefulWidget {
  final VoidCallback? onOpenActivity;

  const ActiveTransferPill({super.key, this.onOpenActivity});

  @override
  State<ActiveTransferPill> createState() => _ActiveTransferPillState();
}

class _ActiveTransferPillState extends State<ActiveTransferPill> {
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  LiveTransferStatus? _active;
  DateTime? _startedAt;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _sub = AndroidNodeBridge.instance.events.listen(_onNodeEvent);
  }

  void _onNodeEvent(Map<dynamic, dynamic> event) {
    final type = event['type'] as String?;
    if (!mounted) return;

    if (type == 'transferStarted') {
      _dismissTimer?.cancel();
      _startedAt = DateTime.now();
      setState(() {
        _active = LiveTransferStatus(
          transferId: event['transferId']?.toString() ?? '',
          fileName: event['fileName']?.toString() ?? 'Transferring file…',
          percent: 0,
          transferredBytes: 0,
          totalBytes: (event['totalBytes'] as num?)?.toInt() ?? 0,
        );
      });
    } else if (type == 'transferProgress') {
      _dismissTimer?.cancel();
      final id = event['transferId']?.toString() ?? '';
      final pct = ((event['percent'] as num?)?.toInt() ?? 0).clamp(0, 100);
      final transferred = (event['transferredBytes'] as num?)?.toInt() ?? 0;
      final total = (event['totalBytes'] as num?)?.toInt() ?? 0;
      final started = _startedAt ?? DateTime.now();
      final elapsedSec = DateTime.now().difference(started).inMilliseconds / 1000.0;
      final speed = elapsedSec > 0.05 ? transferred / elapsedSec : 0.0;

      setState(() {
        _active = LiveTransferStatus(
          transferId: id,
          fileName: _active?.fileName ?? 'Transferring file…',
          percent: pct,
          transferredBytes: transferred,
          totalBytes: total,
          bytesPerSecond: speed,
        );
      });
    } else if (type == 'transferCompleted') {
      final id = event['transferId']?.toString() ?? '';
      final success = event['success'] == true;
      final err = event['errorMessage']?.toString();
      setState(() {
        _active = LiveTransferStatus(
          transferId: id,
          fileName: _active?.fileName ?? 'Transfer',
          percent: success ? 100 : (_active?.percent ?? 0),
          transferredBytes: _active?.transferredBytes ?? 0,
          totalBytes: _active?.totalBytes ?? 0,
          isCompleted: true,
          isSuccess: success,
          errorMessage: (err != null && err.isNotEmpty) ? err : null,
        );
      });
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _active = null);
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final active = _active;

    return AnimatedSize(
      duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: active == null
          ? const SizedBox.shrink()
          : Container(
              key: const Key('active_transfer_pill'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
                ),
              ),
              child: InkWell(
                onTap: widget.onOpenActivity,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: active.isCompleted
                                ? (active.isSuccess
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFEF2F2))
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: active.isCompleted
                                  ? (active.isSuccess
                                      ? const Color(0xFFBBF7D0)
                                      : const Color(0xFFFECACA))
                                  : const Color(0xFFDBEAFE),
                            ),
                          ),
                          child: Icon(
                            active.isCompleted
                                ? (active.isSuccess
                                    ? Icons.check_rounded
                                    : Icons.error_outline_rounded)
                                : Icons.swap_vert_rounded,
                            size: 16,
                            color: active.isCompleted
                                ? (active.isSuccess
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFDC2626))
                                : const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                active.isCompleted
                                    ? (active.isSuccess
                                        ? 'Transfer complete'
                                        : (active.errorMessage ?? 'Transfer failed'))
                                    : '${active.percent}%'
                                        '${active.formattedSpeed.isNotEmpty ? ' • ${active.formattedSpeed}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: active.isCompleted && !active.isSuccess
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Dismiss',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                          onPressed: () {
                            _dismissTimer?.cancel();
                            setState(() => _active = null);
                          },
                        ),
                      ],
                    ),
                    if (!active.isCompleted) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: active.percent > 0 ? active.percent / 100.0 : null,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
