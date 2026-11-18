import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/device_trust_service.dart';
import '../../core/file_staging_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';
import '../colors/peerlink_colors.dart';
import 'glass_container.dart';

/// Represents a peer entry in the Quick-Drop Proximity Carousel.
class QuickDropPeerItem {
  final String id;
  final String name;
  final String deviceType;
  final bool isTrusted;
  final bool isOnline;
  final String? ip;
  final String? technology;

  const QuickDropPeerItem({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.isTrusted,
    this.isOnline = true,
    this.ip,
    this.technology,
  });
}

/// Ambient Nearby Peers Quick-Drop Carousel.
/// Surfaces nearby online and trusted devices in a horizontal deck with 1-tap beam actions.
class QuickDropPeerCarousel extends StatelessWidget {
  final List<QuickDropPeerItem>? overridePeers;
  final void Function(QuickDropPeerItem peer)? onPeerTapped;
  final void Function(QuickDropPeerItem peer)? onQuickDrop;
  final VoidCallback? onPairQrPressed;
  final VoidCallback? onManageDevicesPressed;

  const QuickDropPeerCarousel({
    super.key,
    this.overridePeers,
    this.onPeerTapped,
    this.onQuickDrop,
    this.onPairQrPressed,
    this.onManageDevicesPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<StagedFileItem>>(
      stream: FileStagingService.instance.stagedFilesStream,
      initialData: FileStagingService.instance.stagedFiles,
      builder: (context, stagingSnapshot) {
        final staged = stagingSnapshot.data ?? [];
        final stagedCount = staged.where((f) => f.selected).length;

        if (overridePeers != null) {
          return _buildDeck(context, theme, overridePeers!, stagedCount);
        }

        return StreamBuilder<List<PairedDevice>>(
          stream: DeviceTrustService.instance.devicesStream,
          initialData: DeviceTrustService.instance.devices,
          builder: (context, devicesSnapshot) {
            final paired = devicesSnapshot.data ?? [];

            if (PlatformCapabilities.isAndroid) {
              return StreamBuilder<List<DiscoveredPeer>>(
                stream: AndroidNodeBridge.instance.discoveredPeersStream,
                initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                builder: (context, discoveredSnapshot) {
                  final discovered = discoveredSnapshot.data ?? [];
                  final peers = _mergePeers(paired, discovered);
                  return _buildDeck(context, theme, peers, stagedCount);
                },
              );
            }

            final peers = paired.map((d) => QuickDropPeerItem(
              id: d.id,
              name: d.name,
              deviceType: d.deviceType,
              isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
              isOnline: d.isOnline,
            )).toList();

            return _buildDeck(context, theme, peers, stagedCount);
          },
        );
      },
    );
  }

  List<QuickDropPeerItem> _mergePeers(List<PairedDevice> paired, List<DiscoveredPeer> discovered) {
    final Map<String, QuickDropPeerItem> map = {};

    for (final d in paired) {
      map[d.id] = QuickDropPeerItem(
        id: d.id,
        name: d.name,
        deviceType: d.deviceType,
        isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
        isOnline: d.isOnline,
      );
    }

    for (final p in discovered) {
      final isTrusted = map.containsKey(p.peerId) && map[p.peerId]!.isTrusted;
      map[p.peerId] = QuickDropPeerItem(
        id: p.peerId,
        name: p.name.isNotEmpty ? p.name : p.peerId,
        deviceType: p.technology.contains('WIFI_DIRECT') ? 'phone' : 'desktop',
        isTrusted: isTrusted,
        isOnline: true,
        ip: p.host,
        technology: p.technology,
      );
    }

    return map.values.toList();
  }

  Widget _buildDeck(BuildContext context, ThemeData theme, List<QuickDropPeerItem> peers, int stagedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nearby Quick-Drop',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (peers.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${peers.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ],
              if (onManageDevicesPressed != null) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onManageDevicesPressed,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('All Devices', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Carousel / Deck
        if (peers.isEmpty)
          _buildEmptyScanner(context, theme)
        else
          SizedBox(
            height: 126,
            child: ListView.separated(
              key: const Key('quick_drop_peer_list'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: peers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, index) {
                final peer = peers[index];
                return _buildPeerCard(ctx, theme, peer, stagedCount);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPeerCard(BuildContext context, ThemeData theme, QuickDropPeerItem peer, int stagedCount) {
    final hasStaged = stagedCount > 0;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (hasStaged) {
          DeviceTrustService.instance.setSelectedSendTarget(peer.id);
          onQuickDrop?.call(peer);
        } else {
          onPeerTapped?.call(peer);
        }
      },
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasStaged
                ? theme.colorScheme.primary
                : const Color(0xFFE5E7EB),
            width: hasStaged ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar Stack with online indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasStaged
                        ? const Color(0xFF2563EB)
                        : (peer.isTrusted
                            ? const Color(0xFF15803D)
                            : const Color(0xFF2563EB)),
                  ),
                  child: Icon(
                    _getDeviceIcon(peer.deviceType),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (peer.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF15803D),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Peer Name
            Text(
              peer.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Action Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasStaged
                    ? theme.colorScheme.primary
                    : (peer.isTrusted
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasStaged ? 'Drop ($stagedCount)' : (peer.isTrusted ? 'Trusted' : 'Beam'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: hasStaged
                      ? Colors.white
                      : (peer.isTrusted
                          ? const Color(0xFF15803D)
                          : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanner(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scanning nearby Wi-Fi...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Ensure devices are on same Wi-Fi.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onPairQrPressed != null) ...[
            const SizedBox(width: 6),
            IconButton(
              key: const Key('quick_drop_pair_qr_button'),
              tooltip: 'Pair QR',
              icon: Icon(Icons.qr_code_rounded, size: 20, color: theme.colorScheme.primary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onPairQrPressed,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    final lower = deviceType.toLowerCase();
    if (lower.contains('phone') || lower.contains('android') || lower.contains('mobile')) {
      return Icons.phone_android_rounded;
    }
    if (lower.contains('laptop')) {
      return Icons.laptop_rounded;
    }
    if (lower.contains('tablet') || lower.contains('ipad')) {
      return Icons.tablet_mac_rounded;
    }
    return Icons.desktop_windows_rounded;
  }
}
