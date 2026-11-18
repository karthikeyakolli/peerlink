import 'package:flutter/material.dart';
import 'interactive_glass_card.dart';

/// Real-time throughput, ETA, and transport route telemetry component for in-flight transfers.
class TransferTelemetryCard extends StatelessWidget {
  final String title;
  final String peerName;
  final int bytesTransferred;
  final int totalBytes;
  final double currentSpeedMbPerSec;
  final String transportRoute;
  final int verifiedChunks;
  final int totalChunks;
  final VoidCallback? onCancel;

  const TransferTelemetryCard({
    super.key,
    required this.title,
    required this.peerName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.currentSpeedMbPerSec,
    this.transportRoute = 'DIRECT P2P (Wi-Fi Direct)',
    this.verifiedChunks = 0,
    this.totalChunks = 0,
    this.onCancel,
  });

  String get _formattedSpeed {
    if (currentSpeedMbPerSec < 0.1) return 'Negotiating...';
    return '${currentSpeedMbPerSec.toStringAsFixed(1)} MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get _etaString {
    if (currentSpeedMbPerSec <= 0 || totalBytes <= bytesTransferred) return 'Calculating...';
    final remainingBytes = totalBytes - bytesTransferred;
    final remainingMb = remainingBytes / (1024 * 1024);
    final seconds = (remainingMb / currentSpeedMbPerSec).round();
    if (seconds < 60) return '${seconds}s remaining';
    return '${seconds ~/ 60}m ${seconds % 60}s remaining';
  }

  double get _progressFraction {
    if (totalBytes <= 0) return 0.0;
    return (bytesTransferred / totalBytes).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percent = (_progressFraction * 100).toStringAsFixed(1);

    return InteractiveGlassCard(
      glowColor: null, // Minimal, clean, non-glowing
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Peer: $peerName · $_etaString',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      _formattedSpeed,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressFraction,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatBytes(bytesTransferred)} / ${_formatBytes(totalBytes)} ($percent%)',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.blueGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  transportRoute,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey,
                  ),
                ),
              ),
            ],
          ),

          if (totalChunks > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 12, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  '$verifiedChunks of $totalChunks Merkle chunks verified',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const Spacer(),
                if (onCancel != null)
                  InkWell(
                    onTap: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
