import 'package:flutter/material.dart';

enum SyncMode {
  twoWaySync,
  oneWayPush,
  oneWayMirror,
}

enum SyncStatus {
  inSync,
  syncing,
  conflictDetected,
  massChangePaused,
}

class SyncSpace {
  final String id;
  final String name;
  final String localPath;
  final String remotePeerId;
  final SyncMode mode;
  final SyncStatus status;
  final int fileCount;
  final String lastSyncTime;
  final int pendingConflicts;

  SyncSpace({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remotePeerId,
    required this.mode,
    required this.status,
    required this.fileCount,
    required this.lastSyncTime,
    this.pendingConflicts = 0,
  });
}

class BackupSnapshot {
  final String id;
  final String name;
  final String timestamp;
  final int fileCount;
  final String totalSize;
  final String rootHash;

  BackupSnapshot({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.fileCount,
    required this.totalSize,
    required this.rootHash,
  });
}

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  final List<SyncSpace> _spaces = [
    SyncSpace(
      id: 'space_work_docs',
      name: 'Work Documents',
      localPath: 'C:\\Users\\User\\Documents\\Work',
      remotePeerId: 'peer_laptop_pro',
      mode: SyncMode.twoWaySync,
      status: SyncStatus.inSync,
      fileCount: 342,
      lastSyncTime: '3 minutes ago',
    ),
    SyncSpace(
      id: 'space_code_projects',
      name: 'Code Projects & Repos',
      localPath: 'C:\\Users\\User\\Projects',
      remotePeerId: 'peer_laptop_pro',
      mode: SyncMode.twoWaySync,
      status: SyncStatus.conflictDetected,
      fileCount: 1250,
      lastSyncTime: '12 minutes ago',
      pendingConflicts: 1,
    ),
    SyncSpace(
      id: 'space_photo_vault',
      name: 'Media Vault (Mirror)',
      localPath: 'D:\\Photos\\2026',
      remotePeerId: 'peer_pixel_phone',
      mode: SyncMode.oneWayMirror,
      status: SyncStatus.massChangePaused,
      fileCount: 4890,
      lastSyncTime: '1 hour ago',
    ),
  ];

  final List<BackupSnapshot> _snapshots = [
    BackupSnapshot(
      id: 'snap_20261004_1200',
      name: 'Work Documents (Snapshot #14)',
      timestamp: 'Today at 12:00 PM',
      fileCount: 342,
      totalSize: '128.4 MB',
      rootHash: 'SHA256:4a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d',
    ),
    BackupSnapshot(
      id: 'snap_20261003_1800',
      name: 'Work Documents (Snapshot #13)',
      timestamp: 'Yesterday at 06:00 PM',
      fileCount: 338,
      totalSize: '124.1 MB',
      rootHash: 'SHA256:1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c',
    ),
    BackupSnapshot(
      id: 'snap_20261001_0900',
      name: 'Monthly Full Cold Backup',
      timestamp: 'Oct 01, 2026 at 09:00 AM',
      fileCount: 1592,
      totalSize: '1.82 GB',
      rootHash: 'SHA256:8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d',
    ),
  ];

  void _showDryRunPreview(SyncSpace space) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.preview_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Sync Preview (Dry-Run): ${space.name}'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dry-run simulation only. No files on disk have been modified or deleted.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Planned Changes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildChangeItem(Icons.add_circle_outline, Colors.green, 'Added remotely:', 'reports/q3_summary.pdf (+2.4 MB)'),
              _buildChangeItem(Icons.edit_outlined, Colors.amber.shade800, 'Modified remotely:', 'specs/architecture.md'),
              _buildChangeItem(Icons.delete_outline, Colors.red, 'Deleted remotely:', 'drafts/notes_old.txt'),
              const Divider(height: 24),
              const Text(
                'Direction: peer_laptop_pro ➔ Local Node (Two-Way Sync)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync executed cleanly! All changes applied.')),
              );
            },
            child: const Text('Apply Changes to Disk'),
          ),
        ],
      ),
    );
  }

  void _showConflictResolver(SyncSpace space) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Resolve Sync Conflict'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conflicting edits detected on both devices while offline for:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.description_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'specs/roadmap.json\nLocal: Modified 12m ago • Remote: Modified 14m ago',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose Resolution Policy:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.copy_all_rounded, color: Colors.blue),
              title: const Text('Keep Both (Recommended)'),
              subtitle: const Text('Preserves local file and saves remote version as roadmap.conflict.json'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conflict resolved: Both versions preserved.')),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.computer_rounded, color: Colors.green),
              title: const Text('Keep Local Version'),
              subtitle: const Text('Overwrites remote replica with this device\'s content'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conflict resolved: Local version kept.')),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_download_rounded, color: Colors.orange),
              title: const Text('Accept Remote Version'),
              subtitle: const Text('Replaces local copy with remote peer\'s content'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conflict resolved: Remote version accepted.')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showMassChangeWarning(SyncSpace space) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Mass-Change Circuit Breaker'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mass-change protection was triggered to prevent accidental data loss!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 10),
            const Text(
              'Remote peer "peer_pixel_phone" initiated deletion or modification of 148 files (exceeding safety threshold of 50 files / 20% of dataset).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Sync is currently PAUSED on this folder. Local files remain intact. You must explicitly review and authorize before deletions are applied.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Paused'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mass deletions rejected. Local files preserved.')),
              );
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject Remote Deletions'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mass changes authorized and executed.')),
              );
            },
            child: const Text('Authorize & Apply'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BackupSnapshot snap) {
    final destController = TextEditingController(text: 'C:\\Users\\User\\Restored_Backups\\${snap.id}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Restore Snapshot'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restore "${snap.name}" (${snap.totalSize}, ${snap.fileCount} files)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Important: Restoring creates a new historical copy in your chosen folder. It NEVER overwrites or deletes past backup snapshots.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: destController,
              decoration: const InputDecoration(
                labelText: 'Destination Folder',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text('Manifest SHA-256: ${snap.rootHash.substring(0, 20)}...', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Restoring snapshot to "${destController.text}" with SHA-256 verification...'),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            },
            child: const Text('Verify & Restore'),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem(IconData icon, Color color, String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sync & Backup Spaces'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.sync_rounded), text: 'SYNC SPACES'),
              Tab(icon: Icon(Icons.history_rounded), text: 'BACKUPS & SNAPSHOTS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSyncTab(theme),
            _buildBackupTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Educational Sync Distinction Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'How PeerLink Sync Works',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sync continuously reconciles file changes between paired devices. When a file is updated or deleted on one peer, the change is mirrored when devices connect. Destructive actions have built-in mass-change circuit breakers.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._spaces.map((s) => _buildSyncSpaceCard(theme, s)),
      ],
    );
  }

  Widget _buildSyncSpaceCard(ThemeData theme, SyncSpace space) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (space.status) {
      case SyncStatus.inSync:
        statusColor = Colors.green;
        statusLabel = 'IN SYNC';
        statusIcon = Icons.check_circle_rounded;
        break;
      case SyncStatus.syncing:
        statusColor = Colors.blue;
        statusLabel = 'SYNCING';
        statusIcon = Icons.sync_rounded;
        break;
      case SyncStatus.conflictDetected:
        statusColor = Colors.amber.shade900;
        statusLabel = 'CONFLICT (${space.pendingConflicts})';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SyncStatus.massChangePaused:
        statusColor = Colors.red;
        statusLabel = 'MASS-CHANGE PAUSED';
        statusIcon = Icons.shield_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    space.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Local Path: ${space.localPath}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Target Peer: ${space.remotePeerId} • Mode: ${space.mode.name}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Files: ${space.fileCount} • Last Reconciled: ${space.lastSyncTime}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (space.status == SyncStatus.massChangePaused)
                  FilledButton.icon(
                    onPressed: () => _showMassChangeWarning(space),
                    icon: const Icon(Icons.shield_rounded, size: 16),
                    label: const Text('Review Mass Deletions'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  )
                else if (space.status == SyncStatus.conflictDetected)
                  FilledButton.icon(
                    onPressed: () => _showConflictResolver(space),
                    icon: const Icon(Icons.call_split_rounded, size: 16),
                    label: const Text('Resolve Conflict'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade900),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _showDryRunPreview(space),
                    icon: const Icon(Icons.preview_rounded, size: 16),
                    label: const Text('Preview Dry-Run'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Backup Distinction Callout
        Card(
          elevation: 0,
          color: Colors.deepPurple.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepPurple.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu_rounded, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'Backup vs Sync: Key Distinction',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Sync propagates live updates and deletions between active devices.\n'
                  '• Backup creates immutable, point-in-time preservation snapshots with SHA-256 deduplication.\n'
                  '• Restoring creates a new historical copy without overwriting past backups.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.deepPurple.shade900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Historical Snapshots (${_snapshots.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Full incremental backup initiated! Indexing files...')),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Take Snapshot Now'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._snapshots.map((snap) => _buildSnapshotCard(theme, snap)),
      ],
    );
  }

  Widget _buildSnapshotCard(ThemeData theme, BackupSnapshot snap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  snap.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(snap.timestamp, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Files: ${snap.fileCount} • Total Size: ${snap.totalSize}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Root Hash: ${snap.rootHash}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showRestoreDialog(snap),
                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                  label: const Text('Restore Snapshot'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
