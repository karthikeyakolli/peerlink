import 'package:flutter/material.dart';
import 'local_node_card.dart';
import '../../design_system/components/send_receive_hero.dart';
import '../../design_system/components/media_category_bar.dart';
import '../../design_system/components/radar_sonar_view.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../design_system/components/quick_text_share_modal.dart';
import '../../design_system/components/desktop_dropzone.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/instant_beam_deck.dart';
import '../../design_system/components/web_beam_modal.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int targetTabIndex)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

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
                'â€¢ Direct P2P: Transfers travel directly between your laptop, desktop, and phone over local Wi-Fi or end-to-end encrypted relay without unencrypted storage on central servers.\n\n'
                'â€¢ Cryptographic Trust: Devices verify each other using Ed25519 public key fingerprints instead of central passwords.\n\n'
                'â€¢ Staged Safety: Files are verified with end-to-end SHA-256 checks in quarantine before touching your disk.\n\n'
                'â€¢ Mass-Change Protection: Automated sync pauses if unexpected bulk deletions occur, ensuring your data is never lost accidentally.',
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
                'Your device is visible to nearby senders on local Wi-Fi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RadarSonarView(
                  localDeviceName: 'Desktop PC',
                  discoveredPeers: const [
                    RadarPeerInfo(
                      id: 'peer-work-pc',
                      name: 'Work PC',
                      deviceType: 'desktop',
                      isTrusted: true,
                    ),
                    RadarPeerInfo(
                      id: 'peer-mac-air',
                      name: "Sarah's Mac",
                      deviceType: 'laptop',
                      isTrusted: false,
                    ),
                  ],
                  onPeerSelected: (peer) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Connected with ${peer.name}'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  },
                  onQrScanPressed: () {
                    QrPairingSheet.show(
                      context,
                      deviceName: 'Desktop PC',
                      peerId: 'peer_desktop_primary',
                      fingerprint: 'ed25519:7fa8...91b2',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                peerId: 'peer_desktop_primary',
                fingerprint: 'ed25519:7fa8...91b2',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dropped ${paths.length} file(s). Ready to send!'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
          onNavigate?.call(2); // Jump to Files tab
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Primary Bilateral Hero: SEND / RECEIVE
              SendReceiveHero(
                onSendPressed: () => onNavigate?.call(2), // Jump to Files / Sender tab
                onReceivePressed: () => _showReceiveModal(context),
                discoveredPeersCount: 3,
                isNodeOnline: true,
              ),
              const SizedBox(height: 18),

              // 1-Tap Frictionless Instant Beam Deck (Minimalist Glassmorphic)
              InstantBeamDeck(
                nearbyPeers: const [
                  BeamPeerItem(
                    peerId: 'peer-alice-laptop',
                    name: 'MacBook Pro',
                    deviceType: 'laptop',
                    fingerprint: 'ed25519:7fa8...91b2',
                    isPaired: true,
                    transportInfo: '5GHz Wi-Fi',
                  ),
                  BeamPeerItem(
                    peerId: 'peer-bob-phone',
                    name: 'Pixel 9',
                    deviceType: 'phone',
                    fingerprint: 'ed25519:3bc1...44a7',
                    isPaired: true,
                    transportInfo: 'Direct QUIC',
                  ),
                  BeamPeerItem(
                    peerId: 'peer-charlie-pc',
                    name: 'Ubuntu Studio',
                    deviceType: 'desktop',
                    fingerprint: 'ed25519:88e9...11f0',
                    isPaired: false,
                    transportInfo: 'Hotspot P2P',
                  ),
                ],
                activePayloadSummary: '2 files staged (5.2 MB) â€¢ Ready to beam',
                onSelectPayload: () => onNavigate?.call(2), // Jump to Files tab
                onPeerTap: (peer) => _handleInstantBeam(context, peer),
              ),
              const SizedBox(height: 18),

              // Quick Actions Shelf: Text Share, Web Beam, Wi-Fi Hotspot Direct, Radar Sonar
              Row(
                children: [
                  Expanded(
                    child: _buildQuickToolCard(
                      context,
                      title: 'Quick Text',
                      subtitle: 'Clipboard / Link',
                      icon: Icons.content_paste_go_rounded,
                      color: const Color(0xFF2563EB),
                      onTap: () {
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickToolCard(
                      context,
                      title: 'Web Beam',
                      subtitle: '0-Install Share',
                      icon: Icons.language_rounded,
                      color: const Color(0xFF0284C7),
                      onTap: () {
                        WebBeamModal.show(
                          context,
                          fileName: 'Shared Document.pdf',
                          fileSize: '4.2 MB',
                          portalUrl: 'http://192.168.1.120:52002/?token=7f9a2b1c4e6d',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickToolCard(
                      context,
                      title: 'Hotspot P2P',
                      subtitle: '0-Router Offline',
                      icon: Icons.wifi_tethering_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        QrPairingSheet.show(
                          context,
                          deviceName: 'Desktop PC',
                          peerId: 'peer_desktop_primary',
                          fingerprint: 'ed25519:7fa8...91b2',
                          initialTab: 2, // Direct Hotspot tab
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickToolCard(
                      context,
                      title: 'Radar Sonar',
                      subtitle: 'Active Scan',
                      icon: Icons.radar_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _showReceiveModal(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Media Categories Quick Select Shelf (SHAREit inspired)
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
                  // Navigate directly to Files tab with that filter
                  onNavigate?.call(2);
                },
              ),
              const SizedBox(height: 20),

              // Live Background Node Status
              const SizedBox(height: 12),
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
                    onTap: () => onNavigate?.call(2), // Files tab
                  ),
                  const SizedBox(width: 14),
                  _buildIntentCard(
                    context,
                    title: 'ACCESS',
                    description: 'On-demand browsing',
                    icon: Icons.folder_shared_rounded,
                    color: Colors.teal,
                    onTap: () => onNavigate?.call(1), // Devices tab
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
                    onTap: () => onNavigate?.call(4), // Spaces tab
                  ),
                  const SizedBox(width: 14),
                  _buildIntentCard(
                    context,
                    title: 'BACKUP',
                    description: 'Versioned preservation',
                    icon: Icons.history_rounded,
                    color: Colors.deepPurpleAccent,
                    onTap: () => onNavigate?.call(4), // Spaces tab
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInstantBeam(BuildContext context, BeamPeerItem peer) {
    if (peer.isPaired) {
      // 1-Tap Instant Transfer for paired devices!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Beaming 2 files directly to ${peer.name}... (SHA-256 E2EE verified)'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Security Verification for New / Unknown Peer
      _showTrustDeviceModal(context, peer);
    }
  }

  void _showTrustDeviceModal(BuildContext context, BeamPeerItem peer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.amber.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Verify New Peer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${peer.name} is requesting direct P2P connection.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cryptographic Key Fingerprint:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 2),
                  SelectableText(
                    peer.fingerprint,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Security Level: End-to-End Staged Quarantine', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once trusted, future transfers between your devices proceed with 1-tap simplicity.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Reject'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device paired! Beaming files to ${peer.name}...'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            icon: const Icon(Icons.verified_user_rounded, size: 16),
            label: const Text('Trust & Beam (1-Tap)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToolCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      glowColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
