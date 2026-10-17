import 'package:flutter/material.dart';
import 'glass_container.dart';

class BeamPeerItem {
  final String peerId;
  final String name;
  final String deviceType; // 'phone', 'laptop', 'desktop', 'tablet'
  final String fingerprint;
  final bool isPaired;
  final String transportInfo; // 'Local Wi-Fi', 'Hotspot P2P', 'Direct QUIC'

  const BeamPeerItem({
    required this.peerId,
    required this.name,
    required this.deviceType,
    required this.fingerprint,
    required this.isPaired,
    this.transportInfo = 'Local Wi-Fi',
  });
}

/// Instant Beam Deck: 1-Tap Frictionless P2P Sharing Deck.
/// Solves multi-step friction by allowing users to tap a nearby peer avatar
/// to beam staged files or text immediately with transparent Ed25519 authentication
/// and staged quarantine SHA-256 validation.
class InstantBeamDeck extends StatefulWidget {
  final List<BeamPeerItem> nearbyPeers;
  final String? activePayloadSummary; // e.g., '2 files (5.2 MB) ready' or 'Clipboard link ready'
  final void Function(BeamPeerItem peer) onPeerTap;
  final VoidCallback? onSelectPayload;
  final bool isScanning;

  const InstantBeamDeck({
    super.key,
    required this.nearbyPeers,
    this.activePayloadSummary,
    required this.onPeerTap,
    this.onSelectPayload,
    this.isScanning = true,
  });

  @override
  State<InstantBeamDeck> createState() => _InstantBeamDeckState();
}

class _InstantBeamDeckState extends State<InstantBeamDeck>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _selectedPeerId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'phone':
        return Icons.phone_android_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'desktop':
        return Icons.desktop_windows_rounded;
      case 'tablet':
        return Icons.tablet_mac_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      glowColor: const Color(0xFF2563EB), // Subtle blue aura
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Live Status Radar Dot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10B981),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Instant Beam',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '1-TAP SHARE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              // Security Assurance Capsule
              Tooltip(
                message: 'All transfers use Ed25519 mutual authentication and quarantine SHA-256 verification',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'E2EE Verified',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active Payload Preview Bar (Tap to change)
          InkWell(
            onTap: widget.onSelectPayload,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                    : const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.activePayloadSummary ?? '2 files selected (5.2 MB) • Ready to beam',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nearby Peers 1-Tap Avatar Strip
          Text(
            'TAP A DEVICE TO SEND DIRECTLY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),

          if (widget.nearbyPeers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    size: 36,
                    color: (isDark ? Colors.white30 : Colors.black26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scanning for nearby devices...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: widget.nearbyPeers.map((peer) {
                  final isSelected = _selectedPeerId == peer.peerId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedPeerId = peer.peerId);
                        widget.onPeerTap(peer);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 96,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB).withValues(alpha: 0.16)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Device Icon Circle with cryptographic badge
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: peer.isPaired
                                          ? [
                                              const Color(0xFF2563EB),
                                              const Color(0xFF3B82F6),
                                            ]
                                          : [
                                              const Color(0xFF64748B),
                                              const Color(0xFF475569),
                                            ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (peer.isPaired ? const Color(0xFF2563EB) : Colors.black)
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getDeviceIcon(peer.deviceType),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                // Paired / Verified Badge
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      color: peer.isPaired ? const Color(0xFF10B981) : Colors.amber.shade700,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      peer.isPaired ? Icons.check_rounded : Icons.lock_outline_rounded,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Peer Name
                            Text(
                              peer.name,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            // Transport Hint
                            Text(
                              peer.transportInfo,
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
