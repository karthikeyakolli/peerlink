import 'package:flutter/material.dart';
import 'local_node_card.dart';

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
                '• Direct P2P: Transfers travel directly between your laptop, desktop, and phone over local Wi-Fi or encrypted relay. No third party ever sees your files.\n\n'
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerLink'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Learn About PeerLink',
            onPressed: () => _showOnboardingOverview(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy-First Distributed Personal Data',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your trusted devices directly. No cloud storage, no account tracking.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Onboarding Callout Card
            Card(
              elevation: 0,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blue.shade800, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'First time using PeerLink?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pair your other devices to begin direct transfers, sync folders, or create immutable backups.',
                            style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showOnboardingOverview(context),
                      child: const Text('Learn More'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const LocalNodeCard(),
            const SizedBox(height: 24),
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
                const SizedBox(width: 16),
                _buildIntentCard(
                  context,
                  title: 'ACCESS',
                  description: 'On-demand remote browsing',
                  icon: Icons.folder_shared_rounded,
                  color: Colors.teal,
                  onTap: () => onNavigate?.call(1), // Devices tab
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                const SizedBox(width: 16),
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
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: color),
                  ],
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
        ),
      ),
    );
  }
}
