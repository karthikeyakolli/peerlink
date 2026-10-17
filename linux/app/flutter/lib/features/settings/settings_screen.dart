import 'package:flutter/material.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showTrustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Text('Trust & Device Security',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cryptographic Trust Model',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 6),
              Text(
                'PeerLink pairs devices using public Ed25519 identity keys. Fingerprints must be verified during initial pairing to prevent man-in-the-middle attacks.\n\n'
                'Revocation Policy:\n'
                'When you revoke trust for a device on this node, its session is closed immediately and subsequent requests are rejected. (Note: If the remote device is offline, it will be rejected as soon as it reconnects).',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Safety & Antimalware Policy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Antimalware Verification Statuses:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                  '• VERIFIED CLEAN: Inspected by active host antivirus and no threats detected.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
              SizedBox(height: 4),
              Text(
                  '• SCANNER UNAVAILABLE: Host antivirus is offline or not installed. SHA-256 integrity was verified, but malware inspection was skipped. Never assumed to be clean.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
              SizedBox(height: 4),
              Text(
                  '• MALICIOUS: Known virus signature, disguised executable, or decompression bomb detected. The file is deleted from quarantine immediately.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
              SizedBox(height: 12),
              Text(
                'Executable Restrictions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Files with executable extensions (.exe, .bat, .cmd, .sh, .ps1) are held in staging quarantine and will not be launched or committed without explicit confirmation.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSharingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_shared_rounded, color: Color(0xFF06B6D4)),
            SizedBox(width: 8),
            Text('Sharing & Permissions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guest Sharing vs Trusted Peers:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                '• Trusted Peers: Permanent cryptographic pairing between your own devices. Full bi-directional sync, transfer, and backup capabilities.\n\n'
                '• Guest Shares: Temporary link with explicit expiration TTL (e.g. 2 hours or 1 day). Strictly read-only by default and isolated from your private libraries.\n\n'
                '• Sandboxing: Guests are strictly confined to the chosen folder path. Symlinks pointing outside the folder are forbidden.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNetworkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Network & Transports',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Direct-First Transport Hierarchy:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                '1. Direct LAN TCP/TLS & QUIC: Transfers prioritize zero-latency local Wi-Fi and Ethernet.\n\n'
                '2. WAN Direct P2P: Uses UDP hole punching when devices are on separate networks.\n\n'
                '3. Encrypted Relay Fallback: If both peers are behind symmetric NAT / corporate firewalls, connections flow through an encrypted TURN relay. The relay cannot decrypt your data.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStorageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Storage & Maintenance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local Node Storage Policies:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 8),
              Text(
                '• Local SQLite WAL Database: Manages object index and transfer sessions (Max cap: 256 MB with auto-vacuum).\n\n'
                '• Staging Directories: Incoming chunks are held in temporary staging until full SHA-256 verification. Orphaned staging files older than 24 hours are automatically purged on watchdog ticks.\n\n'
                '• Operation Journal: Maximum 100,000 entries with automatic log rotation.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Zero-Trust Safety'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Security Invariant Attestation Header
          GlassContainer(
            glowColor: const Color(0xFF2563EB),
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
                        color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded,
                          color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Zero-Trust Invariant Enforcement',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'All cryptographic keys, certificates, and transfer staging files are stored exclusively on local storage. No central server has access to private files.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPill('LOCAL-FIRST', const Color(0xFF10B981)),
                    _buildPill('SHA-256 INTEGRITY', const Color(0xFF2563EB)),
                    _buildPill('NO-CLOUD STAGING', const Color(0xFF8B5CF6)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildGlassSettingTile(
            context,
            icon: Icons.security_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Trust & Devices',
            subtitle:
                'Device identity, pairing fingerprints, revocation guarantees',
            onTap: () => _showTrustDialog(context),
          ),
          _buildGlassSettingTile(
            context,
            icon: Icons.shield_rounded,
            color: const Color(0xFF10B981),
            title: 'Safety & Antimalware',
            subtitle:
                'Malware inspection, scanner-unavailable alerts, executable policies',
            onTap: () => _showPrivacyDialog(context),
          ),
          _buildGlassSettingTile(
            context,
            icon: Icons.folder_shared_rounded,
            color: const Color(0xFF06B6D4),
            title: 'Guest Sharing & Remote Access',
            subtitle:
                'Sandboxed guest links, expiration timers, permission boundaries',
            onTap: () => _showSharingDialog(context),
          ),
          _buildGlassSettingTile(
            context,
            icon: Icons.wifi_rounded,
            color: const Color(0xFF2563EB),
            title: 'Network & Transports',
            subtitle:
                'Direct LAN, Netty QUIC/TCP-TLS, end-to-end encrypted relay',
            onTap: () => _showNetworkDialog(context),
          ),
          _buildGlassSettingTile(
            context,
            icon: Icons.storage_rounded,
            color: const Color(0xFF7C3AED),
            title: 'Storage & Retention',
            subtitle:
                'Local SQLite WAL database, staging cleanup, operation limits',
            onTap: () => _showStorageDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGlassSettingTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InteractiveGlassCard(
      glowColor: color,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: color.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}
