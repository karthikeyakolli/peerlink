import 'package:flutter/material.dart';
import '../../core/sync_backup_service.dart';
import '../../core/device_trust_service.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

export '../../core/sync_backup_service.dart'
    show SyncMode, SyncStatus, SyncSpace, BackupSnapshot, SyncDryRunDiff;

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  void _showAddSpaceDialog() {
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    SyncMode selectedMode = SyncMode.twoWaySync;
    final devices = DeviceTrustService.instance.devices;
    String selectedPeerId = devices.isNotEmpty ? devices.first.id : 'peer_local_network';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_shared_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Configure New Sync Space'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Synchronize a local folder across trusted peers with causal versioning and mass-change protection.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Space Name',
                    hintText: 'e.g. Work Documents',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pathController,
                  decoration: const InputDecoration(
                    labelText: 'Local Folder Path',
                    hintText: 'e.g. C:\\PeerLinkSync\\Folder',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Sync Reconciler Mode:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<SyncMode>(
                  value: selectedMode,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                      value: SyncMode.twoWaySync,
                      child: Text('Two-Way Bidirectional Sync'),
                    ),
                    DropdownMenuItem(
                      value: SyncMode.oneWayPush,
                      child: Text('One-Way Push (Send Only)'),
                    ),
                    DropdownMenuItem(
                      value: SyncMode.oneWayMirror,
                      child: Text('One-Way Mirror (Replica)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedMode = val);
                    }
                  },
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
                final name = nameController.text.trim();
                final path = pathController.text.trim();
                if (name.isNotEmpty && path.isNotEmpty) {
                  SyncBackupService.instance.addSpace(
                    SyncSpace(
                      id: 'space_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      localPath: path,
                      remotePeerId: selectedPeerId,
                      mode: selectedMode,
                      status: SyncStatus.inSync,
                      fileCount: 0,
                      lastSyncTime: 'Just configured',
                    ),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sync Space "$name" created successfully.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Create Space'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDryRunPreview(SyncSpace space) {
    final diffs = SyncBackupService.instance.computeDryRun(space);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.preview_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('Sync Preview: ${space.name}')),
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
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dry-run simulation only. Manifest exchange verified. No destructive changes applied.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Manifest Comparison:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              if (diffs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Local directory is clean or awaiting peer changes. No pending file diffs.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                ...diffs.map((d) => _buildChangeItem(
                      Icons.check_circle_outline,
                      Colors.blue,
                      d.type,
                      '${d.relativePath} (${d.detail})',
                    )),
              const Divider(height: 24),
              Text(
                'Peer: ${space.remotePeerId} • Mode: ${space.mode.name}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Preview'),
          ),
        ],
      ),
    );
  }

  void _showConflictResolver(SyncSpace space) {
    final conflictFileName = space.conflictFile ?? 'spec.json';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Resolve Sync Conflict')),
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
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$conflictFileName\nLocal version preserved • Causal versioning fork',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose Resolution Policy:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.copy_all_rounded, color: Colors.blue),
              title: const Text('Keep Both (Recommended)'),
              subtitle: Text(
                  'Preserves local file and saves remote version as $conflictFileName.conflict'),
              onTap: () {
                SyncBackupService.instance
                    .resolveConflict(space.id, 'KEEP_BOTH');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Conflict resolved: Both versions preserved non-destructively.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.computer_rounded, color: Colors.green),
              title: const Text('Keep Local Version'),
              subtitle: const Text(
                  'Preserves this device\'s content and overrides remote change'),
              onTap: () {
                SyncBackupService.instance
                    .resolveConflict(space.id, 'KEEP_LOCAL');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conflict resolved: Local version kept.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_download_rounded,
                  color: Colors.orange),
              title: const Text('Accept Remote Version'),
              subtitle:
                  const Text('Replaces local copy with remote peer\'s version'),
              onTap: () {
                SyncBackupService.instance
                    .resolveConflict(space.id, 'ACCEPT_REMOTE');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conflict resolved: Remote version accepted.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
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
            Expanded(child: Text('Mass-Change Circuit Breaker')),
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
            Text(
              'Remote peer "${space.remotePeerId}" initiated bulk deletion/modification exceeding safety threshold (>50% of dataset).',
              style: const TextStyle(fontSize: 13),
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
          OutlinedButton(
            onPressed: () {
              SyncBackupService.instance.releaseMassChangeHold(space.id, false);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mass deletions rejected. Local files preserved.',
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject Deletions'),
          ),
          FilledButton(
            onPressed: () {
              SyncBackupService.instance.releaseMassChangeHold(space.id, true);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mass changes authorized and executed.',
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Authorize'),
          ),
        ],
      ),
    );
  }

  void _showCreateSnapshotDialog() {
    final nameController = TextEditingController();
    final pathController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Expanded(child: Text('Create Backup Snapshot')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate an immutable point-in-time snapshot with SHA-256 Merkle root verification.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Snapshot Name',
                hintText: 'e.g. Monthly Cold Backup',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Source Directory',
                hintText: 'e.g. C:\\Projects',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final path = pathController.text.trim();
              if (name.isNotEmpty && path.isNotEmpty) {
                Navigator.pop(ctx);
                final snap = await SyncBackupService.instance
                    .createSnapshot(name: name, folderPath: path);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Snapshot "${snap.name}" created with Merkle root ${snap.rootHash.substring(0, 16)}...'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              }
            },
            child: const Text('Create Snapshot'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BackupSnapshot snap) {
    final destController = TextEditingController(
        text: 'C:\\Users\\User\\Restored_Backups\\${snap.id}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded,
                color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(child: Text('Restore Snapshot')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Restore "${snap.name}" (${snap.totalSize}, ${snap.fileCount} files)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                const Icon(Icons.verified_outlined,
                    size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Merkle Root: ${snap.rootHash}',
                      style: const TextStyle(
                          fontSize: 10, fontFamily: 'monospace')),
                ),
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
              final target = destController.text.trim();
              final safePath =
                  SyncBackupService.instance.determineSafeRestorePath(target, snap.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Restoring snapshot to "$safePath" with Merkle verification. No silent overwrite.'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Verify & Restore'),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem(
      IconData icon, Color color, String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
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
              Tab(
                  icon: Icon(Icons.history_rounded),
                  text: 'BACKUPS & SNAPSHOTS'),
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
    return StreamBuilder<List<SyncSpace>>(
      stream: SyncBackupService.instance.spacesStream,
      initialData: SyncBackupService.instance.spaces,
      builder: (context, snapshot) {
        final spaces = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Educational Sync Distinction Glass Container
            GlassContainer(
              glowColor: const Color(0xFFF59E0B),
              padding: const EdgeInsets.all(16.0),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sync_rounded,
                            color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Continuous Sync Replicas',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync continuously reconciles file changes between paired devices. When a file is updated or deleted on one peer, the change is mirrored when devices connect. Destructive actions have built-in mass-change circuit breakers.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configured Sync Spaces (${spaces.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showAddSpaceDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Sync Space'),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (spaces.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.folder_shared_outlined, size: 40, color: theme.disabledColor),
                    const SizedBox(height: 12),
                    const Text(
                      'No sync spaces configured',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a directory to keep folders automatically in sync across your paired devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showAddSpaceDialog,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Add a Sync Space'),
                    ),
                  ],
                ),
              )
            else
              ...spaces.map((s) => _buildSyncSpaceCard(theme, s)),
          ],
        );
      },
    );
  }

  Widget _buildSyncSpaceCard(ThemeData theme, SyncSpace space) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (space.status) {
      case SyncStatus.inSync:
        statusColor = const Color(0xFF10B981);
        statusLabel = 'IN SYNC';
        statusIcon = Icons.check_circle_rounded;
        break;
      case SyncStatus.syncing:
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'SYNCING';
        statusIcon = Icons.sync_rounded;
        break;
      case SyncStatus.conflictDetected:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'CONFLICT (${space.pendingConflicts})';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SyncStatus.massChangePaused:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'MASS-CHANGE PAUSED';
        statusIcon = Icons.shield_rounded;
        break;
    }

    return InteractiveGlassCard(
      glowColor: statusColor,
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  space.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
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
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Local Path: ${space.localPath}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
              'Target Peer: ${space.remotePeerId} • Mode: ${space.mode.name}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
              'Files: ${space.fileCount} • Last Reconciled: ${space.lastSyncTime}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (space.status == SyncStatus.massChangePaused)
                FilledButton.icon(
                  onPressed: () => _showMassChangeWarning(space),
                  icon: const Icon(Icons.shield_rounded, size: 16),
                  label: const Text('Review Mass Changes'),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
                )
              else if (space.status == SyncStatus.conflictDetected)
                FilledButton.icon(
                  onPressed: () => _showConflictResolver(space),
                  icon: const Icon(Icons.call_split_rounded, size: 16),
                  label: Text('Resolve Conflict (${space.pendingConflicts})'),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B)),
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
    );
  }

  Widget _buildBackupTab(ThemeData theme) {
    return StreamBuilder<List<BackupSnapshot>>(
      stream: SyncBackupService.instance.snapshotsStream,
      initialData: SyncBackupService.instance.snapshots,
      builder: (context, snapshot) {
        final snapshots = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Backup Distinction Callout
            GlassContainer(
              glowColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.all(16.0),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_edu_rounded,
                            color: Color(0xFF7C3AED), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Immutable Merkle Preservation',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Sync propagates live updates and deletions between active devices.\n'
                    '• Backup creates immutable, point-in-time preservation snapshots with SHA-256 deduplication.\n'
                    '• Restoring creates a new historical copy without overwriting past backups.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Historical Snapshots (${snapshots.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showCreateSnapshotDialog,
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Take Snapshot Now'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        const Color(0xFF7C3AED).withValues(alpha: 0.18),
                    foregroundColor: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshots.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_outlined, size: 40, color: theme.disabledColor),
                    const SizedBox(height: 12),
                    const Text(
                      'No backup snapshots yet',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a point-in-time snapshot with verifiable Merkle root hash for disaster recovery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showCreateSnapshotDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create First Snapshot'),
                    ),
                  ],
                ),
              )
            else
              ...snapshots.map((snap) => _buildSnapshotCard(theme, snap)),
          ],
        );
      },
    );
  }

  Widget _buildSnapshotCard(ThemeData theme, BackupSnapshot snap) {
    return InteractiveGlassCard(
      glowColor: const Color(0xFF7C3AED),
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                snap.name,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(snap.timestamp,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Files: ${snap.fileCount} • Total Size: ${snap.totalSize}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Root Hash: ${snap.rootHash}',
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _showRestoreDialog(snap),
                icon: const Icon(Icons.settings_backup_restore_rounded,
                    size: 16),
                label: const Text('Restore Snapshot'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
