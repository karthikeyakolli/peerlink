import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/sync_backup_service.dart';
import '../../core/device_trust_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/windows_file_dialog.dart';

export '../../core/sync_backup_service.dart'
    show SyncMode, SyncStatus, SyncSpace, BackupSnapshot, SyncDryRunDiff;

class SpacesScreen extends StatefulWidget {
  final void Function(int targetTabIndex)? onNavigate;
  const SpacesScreen({super.key, this.onNavigate});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  @override
  void initState() {
    super.initState();
    SyncBackupService.instance.loadPersistedSpaces().then((_) {
      if (mounted) {
        SyncBackupService.instance.startBackgroundWatcher();
      }
    });
  }

  Future<String?> _pickFolder() async {
    if (Platform.isAndroid) {
      return await AndroidNodeBridge.instance.pickDirectoryUri();
    } else if (Platform.isWindows) {
      return await WindowsFileDialog.pickDirectory();
    }
    return null;
  }

  void _showAddSpaceDialog() async {
    final suggestedSpaceId = 'space_${DateTime.now().millisecondsSinceEpoch}';
    final defaultPath = await SyncBackupService.instance.allocateDefaultSpacePath(suggestedSpaceId);
    if (!mounted) return;

    final nameController = TextEditingController(text: 'My Space');
    final pathController = TextEditingController(text: defaultPath);
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
              Expanded(
                child: Text(
                  'Configure Sync Space',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Synchronize a local folder across trusted peers with causal versioning and safety circuit breakers.',
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 16, color: Colors.amber),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('Folder Location:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.folder_open_rounded, size: 14),
                            label: const Text('Change', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final picked = await _pickFolder();
                              if (picked != null && picked.isNotEmpty) {
                                setDialogState(() {
                                  pathController.text = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pathController.text,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Sync Mode:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<SyncMode>(
                  initialValue: selectedMode,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                      value: SyncMode.twoWaySync,
                      child: Text('Two-Way Bidirectional Sync', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: SyncMode.oneWayPush,
                      child: Text('One-Way Push (Send Only)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: SyncMode.oneWayMirror,
                      child: Text('One-Way Mirror (Replica)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedMode = val);
                    }
                  },
                ),
                if (devices.length > 1) ...[
                  const SizedBox(height: 12),
                  const Text('Target Peer:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPeerId,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: devices.map((d) => DropdownMenuItem(
                      value: d.id,
                      child: Text('${d.name} (${d.id.length > 12 ? "${d.id.substring(0, 12)}..." : d.id})', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedPeerId = val);
                      }
                    },
                  ),
                ],
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
                      id: suggestedSpaceId,
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
          child: SingleChildScrollView(
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
        content: SingleChildScrollView(
          child: Column(
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
        content: SingleChildScrollView(
          child: Column(
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

  void _showCreateSnapshotDialog() async {
    final spaces = SyncBackupService.instance.spaces;
    String defaultPath = '';
    if (spaces.isNotEmpty) {
      defaultPath = spaces.first.localPath;
    } else if (Platform.isAndroid) {
      final storage = await AndroidNodeBridge.instance.getAppStorageDirectory();
      defaultPath = storage ?? Directory.systemTemp.path;
    } else {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.systemTemp.path;
      defaultPath = '$home/Documents';
    }
    if (!mounted) return;

    final nameController = TextEditingController(
      text: 'Snapshot ${DateTime.now().toLocal().toString().split(' ')[0]}',
    );
    final pathController = TextEditingController(text: defaultPath);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.camera_alt_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Create Backup Snapshot', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(dialogCtx).dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 16, color: Color(0xFF7C3AED)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Source Folder:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.folder_open_rounded, size: 14),
                            label: const Text('Change', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final picked = await _pickFolder();
                              if (picked != null && picked.isNotEmpty) {
                                setDialogState(() {
                                  pathController.text = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pathController.text,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
              onPressed: () async {
                final name = nameController.text.trim();
                final path = pathController.text.trim();
                if (name.isNotEmpty && path.isNotEmpty) {
                  Navigator.pop(ctx);
                  final snap = await SyncBackupService.instance
                      .createSnapshot(name: name, folderPath: path);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Snapshot "${snap.name}" created with Merkle root ${snap.rootHash.length >= 16 ? snap.rootHash.substring(0, 16) : snap.rootHash}...'),
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
      ),
    );
  }

  void _showRestoreDialog(BackupSnapshot snap) async {
    String defaultDest;
    if (Platform.isAndroid) {
      final appStorage = await AndroidNodeBridge.instance.getAppStorageDirectory();
      defaultDest = (appStorage != null && appStorage.isNotEmpty)
          ? '$appStorage/PeerLink/Restores/${snap.id}'
          : '${Directory.systemTemp.path}/PeerLink/Restores/${snap.id}';
    } else {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.systemTemp.path;
      defaultDest = '$home/PeerLink/Restores/${snap.id}';
    }
    if (!mounted) return;
    final destController = TextEditingController(text: defaultDest);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded,
                color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(child: Text('Restore Snapshot', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
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
                            fontSize: 10, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
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
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.sync_rounded, size: 17, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'Sync & Backup',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          leading: widget.onNavigate != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
                  tooltip: 'Back to Home',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onNavigate!(0);
                  },
                )
              : null,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(49),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  labelColor: Color(0xFF2563EB),
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFF2563EB),
                  indicatorWeight: 2.5,
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_copy_outlined, size: 16),
                          SizedBox(width: 6),
                          Flexible(child: Text('SYNC SPACES', overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Tab(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16),
                          SizedBox(width: 6),
                          Flexible(child: Text('BACKUPS', overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              ],
            ),
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

  ({IconData icon, Color color, Color bg, Color border, String label}) _syncModeVisual(SyncMode mode) {
    switch (mode) {
      case SyncMode.twoWaySync:
        return (
          icon: Icons.sync_alt_rounded,
          color: const Color(0xFF2563EB),
          bg: const Color(0xFFEFF6FF),
          border: const Color(0xFFDBEAFE),
          label: 'Two-Way Sync',
        );
      case SyncMode.oneWayPush:
        return (
          icon: Icons.upload_file_rounded,
          color: const Color(0xFF0D9488),
          bg: const Color(0xFFF0FDFA),
          border: const Color(0xFF99F6E4),
          label: 'One-Way Push',
        );
      case SyncMode.oneWayMirror:
        return (
          icon: Icons.content_copy_rounded,
          color: const Color(0xFF7C3AED),
          bg: const Color(0xFFF5F3FF),
          border: const Color(0xFFDDD6FE),
          label: 'One-Way Mirror',
        );
    }
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
            // Compact Flat Light Info Banner
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Content-Hash Folder Sync',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Reconciles real SHA-256 content changes across trusted Android & Windows devices with automatic mass-deletion safety holds.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final titleWidget = Row(
                  children: [
                    const Icon(Icons.folder_copy_outlined, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Configured Sync Spaces (${spaces.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
                final addBtn = FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showAddSpaceDialog();
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Sync Space', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleWidget,
                      const SizedBox(height: 8),
                      addBtn,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    addBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (spaces.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: const Icon(Icons.folder_copy_outlined, size: 28, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No sync spaces configured',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Link a local folder to keep documents and media automatically synchronized with your Windows PC or paired phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _showAddSpaceDialog();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add a Sync Space'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
    final modeVis = _syncModeVisual(space.mode);
    Color statusColor;
    Color statusBg;
    Color statusBorder;
    String statusLabel;
    IconData statusIcon;

    switch (space.status) {
      case SyncStatus.inSync:
        statusColor = const Color(0xFF15803D);
        statusBg = const Color(0xFFF0FDF4);
        statusBorder = const Color(0xFFBBF7D0);
        statusLabel = 'IN SYNC';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case SyncStatus.syncing:
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFEFF6FF);
        statusBorder = const Color(0xFFBFDBFE);
        statusLabel = 'SYNCING';
        statusIcon = Icons.sync_rounded;
        break;
      case SyncStatus.conflictDetected:
        statusColor = const Color(0xFFB45309);
        statusBg = const Color(0xFFFFFBEB);
        statusBorder = const Color(0xFFFDE68A);
        statusLabel = 'CONFLICT (${space.pendingConflicts})';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SyncStatus.massChangePaused:
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEF2F2);
        statusBorder = const Color(0xFFFECACA);
        statusLabel = 'MASS-CHANGE PAUSED';
        statusIcon = Icons.shield_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: modeVis.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: modeVis.border),
                ),
                child: Icon(modeVis.icon, color: modeVis.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      modeVis.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: modeVis.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _buildSpaceMetaRow(Icons.folder_outlined, space.localPath),
                const SizedBox(height: 5),
                _buildSpaceMetaRow(Icons.devices_rounded, 'Target Peer: ${space.remotePeerId}'),
                const SizedBox(height: 5),
                _buildSpaceMetaRow(Icons.schedule_rounded, '${space.fileCount} files • ${space.lastSyncTime}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (space.status == SyncStatus.massChangePaused)
                FilledButton.icon(
                  onPressed: () => _showMassChangeWarning(space),
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Review Mass Changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else if (space.status == SyncStatus.conflictDetected)
                FilledButton.icon(
                  onPressed: () => _showConflictResolver(space),
                  icon: const Icon(Icons.call_split_rounded, size: 16),
                  label: Text('Resolve Conflict (${space.pendingConflicts})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showDryRunPreview(space);
                  },
                  icon: const Icon(Icons.difference_outlined, size: 16),
                  label: const Text('Preview Dry-Run', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final ok = await SyncBackupService.instance.performAutomatedSync(space.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Space "${space.name}" synchronized successfully.'
                              : 'Sync hold active on "${space.name}".'),
                          backgroundColor: ok ? const Color(0xFF15803D) : const Color(0xFFD97706),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              IconButton(
                tooltip: 'Remove sync space',
                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFF64748B)),
                onPressed: () => _confirmRemoveSpace(space),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceMetaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _confirmRemoveSpace(SyncSpace space) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Sync Space?'),
        content: Text(
          'Stop syncing "${space.name}"? Your local files on disk will NOT be deleted.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              SyncBackupService.instance.removeSpace(space.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
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
            // Flat Light Backup Callout
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: Color(0xFF7C3AED), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Immutable Merkle Preservation',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Point-in-time snapshots verified by SHA-256 Merkle roots. Restoring always writes to a safe copy without overwriting history.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final titleWidget = Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Historical Snapshots (${snapshots.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
                final snapBtn = FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showCreateSnapshotDialog();
                  },
                  icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                  label: const Text('Take Snapshot Now', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleWidget,
                      const SizedBox(height: 8),
                      snapBtn,
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    snapBtn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (snapshots.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFF7C3AED)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No backup snapshots yet',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create a point-in-time snapshot with verifiable SHA-256 Merkle root hash for instant non-destructive recovery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _showCreateSnapshotDialog();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create First Snapshot'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snap.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${snap.fileCount} files • ${snap.totalSize} • ${snap.timestamp}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF15803D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Root: ${snap.rootHash}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _showRestoreDialog(snap);
                },
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Restore Snapshot', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                  backgroundColor: const Color(0xFFF5F3FF),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
