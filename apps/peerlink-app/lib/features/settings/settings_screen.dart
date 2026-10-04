import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showTrustDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Trust & Device Security'),
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
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
            Icon(Icons.shield_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Safety & Antimalware Policy'),
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
              Text('• VERIFIED CLEAN: Inspected by active host antivirus and no threats detected.', style: TextStyle(fontSize: 12, color: Colors.green)),
              SizedBox(height: 4),
              Text('• SCANNER UNAVAILABLE: Host antivirus is offline or not installed. SHA-256 integrity was verified, but malware inspection was skipped. Never assumed to be clean.', style: TextStyle(fontSize: 12, color: Colors.orange)),
              SizedBox(height: 4),
              Text('• MALICIOUS: Known virus signature, disguised executable, or decompression bomb detected. The file is deleted from quarantine immediately.', style: TextStyle(fontSize: 12, color: Colors.red)),
              SizedBox(height: 12),
              Text(
                'Executable Restrictions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Files with executable extensions (.exe, .bat, .cmd, .sh, .ps1) are held in staging quarantine and will not be launched or committed without explicit confirmation.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
            Icon(Icons.folder_shared_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('Sharing & Permissions'),
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
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
            Icon(Icons.wifi_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Network & Transports'),
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
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
            Icon(Icons.storage_rounded, color: Colors.purple),
            SizedBox(width: 8),
            Text('Storage & Maintenance'),
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
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Safety Policies'),
      ),
      body: ListView(
        children: [
          _buildSettingsTile(
            context,
            icon: Icons.security_rounded,
            title: 'Trust & Devices',
            subtitle: 'Device identity, pairing fingerprints, revocation guarantees',
            onTap: () => _showTrustDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.shield_rounded,
            title: 'Safety & Antimalware',
            subtitle: 'Malware inspection, scanner-unavailable alerts, executable policies',
            onTap: () => _showPrivacyDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.folder_shared_rounded,
            title: 'Guest Sharing & Remote Access',
            subtitle: 'Sandboxed guest links, expiration timers, permission boundaries',
            onTap: () => _showSharingDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.wifi_rounded,
            title: 'Network & Transports',
            subtitle: 'Direct LAN, Netty QUIC/TCP-TLS, end-to-end encrypted relay',
            onTap: () => _showNetworkDialog(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.storage_rounded,
            title: 'Storage & Retention',
            subtitle: 'Local SQLite WAL database, staging cleanup, operation limits',
            onTap: () => _showStorageDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
