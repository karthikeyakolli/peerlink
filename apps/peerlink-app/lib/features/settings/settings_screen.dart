import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSettingsTile(
            context,
            icon: Icons.security_rounded,
            title: 'Trust & Devices',
            subtitle: 'Device identity, pairing fingerprints, revocations',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'Privacy & Permissions',
            subtitle: 'Data classifications, quarantine rules, path exclusions',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.wifi_rounded,
            title: 'Network & Transports',
            subtitle: 'Direct P2P, Netty QUIC/TCP-TLS, TURN relay fallback',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.storage_rounded,
            title: 'Storage & Cache',
            subtitle: 'Local SQLite WAL database, staging directories, retention',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.auto_awesome_rounded,
            title: 'AI Gateway (Non-Authoritative)',
            subtitle: 'Assisted search and recommendations (strictly non-authoritative)',
          ),
          _buildSettingsTile(
            context,
            icon: Icons.tune_rounded,
            title: 'Advanced & Diagnostics',
            subtitle: 'Local IPC socket, logs, crash dumps, emergency stop',
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
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {},
    );
  }
}
