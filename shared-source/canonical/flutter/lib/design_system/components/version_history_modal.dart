import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/file_version_snapshot_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only Version History Modal (Local Time-Machine Rollback).
class VersionHistoryModal extends StatefulWidget {
  final File targetFile;
  final VoidCallback? onRestored;

  const VersionHistoryModal({
    super.key,
    required this.targetFile,
    this.onRestored,
  });

  static Future<void> show(
    BuildContext context,
    File targetFile, {
    VoidCallback? onRestored,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VersionHistoryModal(
        targetFile: targetFile,
        onRestored: onRestored,
      ),
    );
  }

  @override
  State<VersionHistoryModal> createState() => _VersionHistoryModalState();
}

class _VersionHistoryModalState extends State<VersionHistoryModal> {
  final FileVersionSnapshotService _versionService = FileVersionSnapshotService.instance;
  late List<FileVersionSnapshot> _snapshots;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  void _loadSnapshots() {
    setState(() {
      _snapshots = _versionService.getSnapshots(widget.targetFile);
    });
  }

  void _handleRestore(FileVersionSnapshot snap) {
    final ok = _versionService.restoreSnapshot(widget.targetFile, snap);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored revision from ${_formatDate(snap.timestamp)}!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRestored?.call();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.targetFile.uri.pathSegments.last;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.history_rounded, size: 22, color: PeerLinkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version History: $fileName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        '${_snapshots.length} local ${_snapshots.length == 1 ? "snapshot" : "snapshots"} saved',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Snapshot List
            Expanded(
              child: _snapshots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          const Text(
                            'No previous revisions found.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Revisions are automatically captured before in-app edits and sync overwrites.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _snapshots.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (ctx, idx) {
                        final snap = _snapshots[idx];
                        final isLatest = idx == 0;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isLatest ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                            child: Icon(
                              isLatest ? Icons.star_rounded : Icons.restore_rounded,
                              size: 16,
                              color: isLatest ? PeerLinkColors.primaryBlue : const Color(0xFF4B5563),
                            ),
                          ),
                          title: Text(
                            '${snap.reason} • ${_formatBytes(snap.byteSize)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            _formatDate(snap.timestamp),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                          trailing: FilledButton.tonal(
                            key: Key('restore_snapshot_${snap.id}'),
                            onPressed: () => _handleRestore(snap),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('Restore', style: TextStyle(fontSize: 11)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
