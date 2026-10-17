import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarPeerInfo {
  final String id;
  final String name;
  final String deviceType; // 'phone', 'desktop', 'laptop', 'tablet'
  final bool isTrusted;
  final String ip;

  const RadarPeerInfo({
    required this.id,
    required this.name,
    this.deviceType = 'desktop',
    this.isTrusted = false,
    this.ip = '127.0.0.1',
  });
}

/// Pulsing Sonar / Radar Discovery View inspired by SHAREit and Apple AirDrop.
/// Renders animated concentric waves with interactive nearby device bubbles.
class RadarSonarView extends StatefulWidget {
  final List<RadarPeerInfo> discoveredPeers;
  final void Function(RadarPeerInfo peer) onPeerSelected;
  final VoidCallback? onQrScanPressed;
  final String localDeviceName;

  const RadarSonarView({
    super.key,
    required this.discoveredPeers,
    required this.onPeerSelected,
    this.onQrScanPressed,
    this.localDeviceName = 'This Device',
  });

  @override
  State<RadarSonarView> createState() => _RadarSonarViewState();
}

class _RadarSonarViewState extends State<RadarSonarView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _iconForDevice(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.phone_android_rounded;
      case 'tablet':
        return Icons.tablet_android_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.desktop_windows_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header with status & QR Scanner fallback button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.discoveredPeers.isEmpty
                        ? 'Searching nearby...'
                        : '${widget.discoveredPeers.length} device(s) found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (widget.onQrScanPressed != null)
                TextButton.icon(
                  onPressed: widget.onQrScanPressed,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scan QR'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),

        // Main radar canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final center = Offset(size.width / 2, size.height / 2);
              final maxRadius = math.min(size.width, size.height) * 0.42;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Animated radar wave circles
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: size,
                        painter: _RadarWavePainter(
                          progress: _pulseController.value,
                          maxRadius: maxRadius,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),

                  // Center Node: This Device
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.phonelink_ring_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Text(
                            widget.localDeviceName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Orbiting Discovered Peers
                  if (widget.discoveredPeers.isEmpty)
                    Positioned(
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Ensure recipient has PeerLink open on same Wi-Fi',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ),

                  ...List.generate(widget.discoveredPeers.length, (index) {
                    final peer = widget.discoveredPeers[index];
                    final count = widget.discoveredPeers.length;
                    // Distribute peers evenly on the radar orbit
                    final angle = (index * (2 * math.pi / count)) - (math.pi / 2);
                    final radius = maxRadius * 0.78;
                    final peerOffset = Offset(
                      center.dx + radius * math.cos(angle) - 34,
                      center.dy + radius * math.sin(angle) - 44,
                    );

                    return Positioned(
                      left: peerOffset.dx,
                      top: peerOffset.dy,
                      child: _PeerOrbitBubble(
                        peer: peer,
                        icon: _iconForDevice(peer.deviceType),
                        isDark: isDark,
                        onTap: () => widget.onPeerSelected(peer),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeerOrbitBubble extends StatelessWidget {
  final RadarPeerInfo peer;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _PeerOrbitBubble({
    required this.peer,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: peer.isTrusted
                        ? [const Color(0xFF059669), const Color(0xFF047857)]
                        : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (peer.isTrusted
                              ? const Color(0xFF059669)
                              : const Color(0xFF6366F1))
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (peer.isTrusted)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF059669),
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              peer.name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarWavePainter extends CustomPainter {
  final double progress;
  final double maxRadius;
  final bool isDark;

  _RadarWavePainter({
    required this.progress,
    required this.maxRadius,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final waveColor =
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

    // Draw 3 concentric pulsing rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i / 3.0)) % 1.0;
      final currentRadius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.45;

      final paint = Paint()
        ..color = waveColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      canvas.drawCircle(center, currentRadius, paint);
    }

    // Static outer boundary orbit line
    final boundaryPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius * 0.8, boundaryPaint);
  }

  @override
  bool shouldRepaint(_RadarWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
