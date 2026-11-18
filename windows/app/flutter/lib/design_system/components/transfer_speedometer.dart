import 'package:flutter/material.dart';

/// Real-time throughput monitor and dual-progress card inspired by SHAREit and Quick Share.
/// Displays live MB/s, ETA, and staged SHA-256 security verification.
class TransferSpeedometer extends StatelessWidget {
  final String fileName;
  final int currentItemIndex;
  final int totalItems;
  final double currentFileProgress; // 0.0 to 1.0
  final double totalBatchProgress; // 0.0 to 1.0
  final double speedMbps; // MB/s
  final int etaSeconds;
  final String peerName;
  final bool isSender;
  final VoidCallback? onCancel;
  final String? networkRouteInfo;
  final String? performanceAdvice;

  const TransferSpeedometer({
    super.key,
    required this.fileName,
    this.currentItemIndex = 1,
    this.totalItems = 1,
    required this.currentFileProgress,
    required this.totalBatchProgress,
    this.speedMbps = 0.0,
    this.etaSeconds = 0,
    required this.peerName,
    this.isSender = true,
    this.onCancel,
    this.networkRouteInfo,
    this.performanceAdvice,
  });

  String _formatEta(int seconds) {
    if (seconds <= 0) return 'Finishing...';
    if (seconds < 60) return '${seconds}s remaining';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s remaining';
  }

  bool get _isFastBand =>
      (networkRouteInfo ?? '').contains('5 GHz') ||
      (networkRouteInfo ?? '').contains('Wi-Fi Direct') ||
      (networkRouteInfo ?? '').contains('Hotspot') ||
      speedMbps >= 15.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryAccent =
        isSender ? const Color(0xFF2563EB) : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Direction, Peer, and Cancel Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSender
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: primaryAccent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSender ? 'Sending to $peerName' : 'Receiving from $peerName',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancel Transfer',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Speed & ETA Hero Numbers
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                speedMbps > 0 ? speedMbps.toStringAsFixed(1) : '—',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: -1.0,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'MB/s',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryAccent,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatEta(etaSeconds),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Wi-Fi Band & Route Diagnostic Bar
          if (networkRouteInfo != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  key: const Key('wifi_band_diagnostic_pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_isFastBand
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B)).withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_isFastBand
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B)).withValues(alpha: isDark ? 0.40 : 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_rounded,
                        size: 13,
                        color: _isFastBand
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        networkRouteInfo!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isFastBand
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                              : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (performanceAdvice != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('performance_advice_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      performanceAdvice!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Current File Label & Index
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currentItemIndex of $totalItems',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Primary Linear Progress Bar (Batch)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalBatchProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(primaryAccent),
            ),
          ),
          const SizedBox(height: 14),

          // Staged Safety Footer Badge (Zero-Trust)
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'End-to-end encrypted • Staged SHA-256 verification',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              Text(
                '${(totalBatchProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
