import 'package:flutter/material.dart';
import 'local_node_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerLink'),
        elevation: 0,
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
              'Connect your trusted devices directly. No central file storage.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
                ),
                const SizedBox(width: 16),
                _buildIntentCard(
                  context,
                  title: 'ACCESS',
                  description: 'On-demand remote browsing',
                  icon: Icons.folder_shared_rounded,
                  color: Colors.teal,
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
                ),
                const SizedBox(width: 16),
                _buildIntentCard(
                  context,
                  title: 'BACKUP',
                  description: 'Versioned preservation',
                  icon: Icons.history_rounded,
                  color: Colors.deepPurpleAccent,
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
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      ),
    );
  }
}
