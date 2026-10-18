import 'dart:io';
import 'package:flutter/material.dart';
import 'local_node_card.dart';
import '../../core/node_ipc_client.dart';
import '../../core/device_trust_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../design_system/components/send_receive_hero.dart';
import '../../design_system/components/media_category_bar.dart';
import '../../design_system/components/radar_sonar_view.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../design_system/components/quick_text_share_modal.dart';
import '../../design_system/components/desktop_dropzone.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/instant_beam_deck.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int targetTabIndex)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _stagedPaths = [];

  void _showOnboardingOverview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Welcome to PeerLink'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PeerLink is a private, decentralized personal data network connecting your own devices directly.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '• Direct P2P: Transfers travel directly between your laptop, desktop, and phone over local Wi-Fi or end-to-end encrypted relay without unencrypted storage on central servers.\n\n'
                '• Cryptographic Trust: Devices verify each other using Ed25519 public key fingerprints instead of central passwords.\n\n'
                '• Staged Safety: Files are verified with end-to-end SHA-256 checks in quarantine before touching your disk.\n\n'
                '• Mass-Change Protection: Automated sync pauses if unexpected bulk deletions occur, ensuring your data is never lost accidentally.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  void _showReceiveModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final devices = DeviceTrustService.instance.devices;
    final localFingerprint = DeviceTrustService.instance.getLocalFingerprint(
      NodeIpcClient.instance.currentState.peerId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting to Receive',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Your device is visible to paired peers on local network',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<DiscoveredPeer>>(
                  stream: AndroidNodeBridge.instance.discoveredPeersStream,
                  initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                  builder: (context, snapshot) {
                    final livePeers = snapshot.data ?? [];
                    final List<RadarPeerInfo> peerInfos;
                    if (Platform.isAndroid) {
                      peerInfos = livePeers.map((p) {
                        final isTrusted = DeviceTrustService.instance.devices
                            .any((d) => d.id == p.peerId);
                        return RadarPeerInfo(
                          id: p.peerId,
                          name: p.name.isNotEmpty ? p.name : p.peerId,
                          deviceType: p.technology.contains('WIFI_DIRECT') ? 'phone' : 'desktop',
                          isTrusted: isTrusted,
                          ip: p.host,
                          technology: p.technology,
                          routeCount: p.routes.isNotEmpty ? p.routes.length : 1,
                        );
                      }).toList();
                    } else {
                      peerInfos = devices.map((d) => RadarPeerInfo(
                        id: d.id,
                        name: d.name,
                        deviceType: d.deviceType,
                        isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
                        ip: '127.0.0.1',
                        technology: 'Configured',
                        routeCount: 1,
                      )).toList();
                    }

                    return RadarSonarView(
                      localDeviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                      discoveredPeers: peerInfos,
                      onAddManualEndpoint: (ip, port, name) async {
                        final peerId = 'manual_${ip.replaceAll('.', '_')}';
                        await AndroidNodeBridge.instance.addManualPeer(
                          peerId: peerId,
                          name: name,
                          host: ip,
                          port: port,
                        );
                      },
                      onPeerSelected: (peer) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Selected peer: ${peer.name} (${peer.ip})'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      },
                      onQrScanPressed: () {
                        QrPairingSheet.show(
                          context,
                          deviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                          peerId: NodeIpcClient.instance.currentState.peerId ?? 'peer_desktop_primary',
                          fingerprint: localFingerprint,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInstantBeam(BuildContext context, BeamPeerItem peer) {
    if (_stagedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No files staged. Select files to beam to ${peer.name}.'),
          backgroundColor: const Color(0xFF2563EB),
          action: SnackBarAction(
            label: 'Select Files',
            textColor: Colors.white,
            onPressed: () => widget.onNavigate?.call(2),
          ),
        ),
      );
      return;
    }

    final client = NodeIpcClient.instance;
    if (client.currentState.status != IpcConnectionStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local Node not connected. Please connect node before sending.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    client.initiateSend(
      targetPeerId: peer.peerId,
      sourcePaths: _stagedPaths,
    ).then((resp) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer initiated (${resp.transferId}) to ${peer.name}'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        widget.onNavigate?.call(2); // Jump to Files tab to see real progress
      }
    }).catchError((err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate send: $err'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localFingerprint = DeviceTrustService.instance.getLocalFingerprint(
      NodeIpcClient.instance.currentState.peerId,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerLink'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste_go_rounded),
            tooltip: 'Quick Text & Link Share',
            onPressed: () {
              QuickTextShareModal.show(
                context,
                onSendText: (text, targetPeer) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transmitting text (${text.length} chars) to nearby peer...'),
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Show Pairing QR',
            onPressed: () {
              QrPairingSheet.show(
                context,
                deviceName: 'Desktop PC',
                peerId: NodeIpcClient.instance.currentState.peerId ?? 'peer_desktop_primary',
                fingerprint: localFingerprint,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Learn About PeerLink',
            onPressed: () => _showOnboardingOverview(context),
          ),
        ],
      ),
      body: DesktopDropzone(
        onFilesDropped: (paths) {
          setState(() {
            _stagedPaths = paths;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dropped ${paths.length} file(s). Ready to beam!'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Primary Bilateral Hero: SEND / RECEIVE
              StreamBuilder<IpcConnectionState>(
                stream: NodeIpcClient.instance.stateStream,
                initialData: NodeIpcClient.instance.currentState,
                builder: (context, snapshot) {
                  final isOnline = snapshot.data?.status == IpcConnectionStatus.connected;
                  final deviceCount = DeviceTrustService.instance.devices.length;
                  return SendReceiveHero(
                    onSendPressed: () => widget.onNavigate?.call(2), // Files / Sender tab
                    onReceivePressed: () => _showReceiveModal(context),
                    discoveredPeersCount: deviceCount,
                    isNodeOnline: isOnline,
                  );
                },
              ),
              const SizedBox(height: 18),

              // 1-Tap Frictionless Instant Beam Deck (Minimalist Glassmorphic)
              StreamBuilder<List<PairedDevice>>(
                stream: DeviceTrustService.instance.devicesStream,
                initialData: DeviceTrustService.instance.devices,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? [];
                  final beamPeers = devices.map((d) => BeamPeerItem(
                    peerId: d.id,
                    name: d.name,
                    deviceType: d.deviceType,
                    fingerprint: d.fingerprint,
                    isPaired: d.trustLevel == DeviceTrustLevel.trustedPeer,
                    transportInfo: d.isOnline ? 'Direct P2P' : 'Offline',
                  )).toList();

                  final summary = _stagedPaths.isEmpty
                      ? null
                      : '${_stagedPaths.length} file(s) staged • Ready to beam';

                  return InstantBeamDeck(
                    nearbyPeers: beamPeers,
                    activePayloadSummary: summary,
                    onSelectPayload: () => widget.onNavigate?.call(2), // Files tab
                    onPeerTap: (peer) => _handleInstantBeam(context, peer),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Media Categories Quick Select Shelf (Direct category shortcuts)
              Text(
                'Quick Share Media',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              MediaCategoryBar(
                onCategorySelected: (category) {
                  widget.onNavigate?.call(2);
                },
              ),
              const SizedBox(height: 20),

              // Live Background Node Status
              const LocalNodeCard(),
              const SizedBox(height: 24),

              // Distributed Storage Capabilities Header
              Text(
                'Distributed Storage Modes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildIntentCard(
                    context,
                    title: 'SEND',
                    description: 'One-time direct copy',
                    icon: Icons.send_rounded,
                    color: Colors.blueAccent,
                    onTap: () => widget.onNavigate?.call(2), // Files tab
                  ),
                  const SizedBox(width: 14),
                  _buildIntentCard(
                    context,
                    title: 'ACCESS',
                    description: 'On-demand browsing',
                    icon: Icons.folder_shared_rounded,
                    color: Colors.teal,
                    onTap: () => widget.onNavigate?.call(1), // Devices tab
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildIntentCard(
                    context,
                    title: 'SYNC',
                    description: 'Convergent replicas',
                    icon: Icons.sync_rounded,
                    color: Colors.amber.shade800,
                    onTap: () => widget.onNavigate?.call(4), // Spaces tab
                  ),
                  const SizedBox(width: 14),
                  _buildIntentCard(
                    context,
                    title: 'BACKUP',
                    description: 'Versioned preservation',
                    icon: Icons.history_rounded,
                    color: Colors.deepPurpleAccent,
                    onTap: () => widget.onNavigate?.call(4), // Spaces tab
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntentCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: GlassContainer(
        glowColor: color,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
