import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/node_ipc_client.dart';
import '../../core/protocol/peerlink/v1/transfer.pb.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final NodeIpcClient _client = NodeIpcClient.instance;

  final TextEditingController _targetPeerController = TextEditingController(text: 'peer-desktop-b');
  final TextEditingController _sourcePathsController = TextEditingController();
  final TextEditingController _destinationDirController = TextEditingController();
  DuplicateDestinationPolicy _duplicatePolicy =
      DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS;

  bool _isSending = false;
  String? _statusBanner;
  StreamSubscription<TransferProgress>? _progressSub;
  final Map<String, TransferProgress> _transfers = {};

  @override
  void initState() {
    super.initState();
    _refreshTransfers();
    _progressSub = _client.transferProgressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _transfers[progress.transferId] = progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _targetPeerController.dispose();
    _sourcePathsController.dispose();
    _destinationDirController.dispose();
    super.dispose();
  }

  Future<void> _refreshTransfers() async {
    if (!_client.isAuthenticated) return;
    try {
      final res = await _client.listTransfers();
      if (mounted) {
        setState(() {
          for (final t in res.transfers) {
            _transfers[t.transferId] = t;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _initiateSend() async {
    final rawPaths = _sourcePathsController.text.trim();
    if (rawPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one file or folder path to send.')),
      );
      return;
    }

    final targetPeer = _targetPeerController.text.trim();
    if (targetPeer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a target peer ID.')),
      );
      return;
    }

    final paths = rawPaths
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    setState(() {
      _isSending = true;
      _statusBanner = null;
    });

    try {
      final res = await _client.initiateSend(
        targetPeerId: targetPeer,
        sourcePaths: paths,
        destinationDirectory: _destinationDirController.text.trim(),
        duplicatePolicy: _duplicatePolicy,
      );

      if (mounted) {
        if (res.accepted) {
          setState(() {
            _statusBanner = 'Transfer initiated: ${res.transferId}';
            _sourcePathsController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transfer initiated successfully! ID: ${res.transferId}'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          _refreshTransfers();
        } else {
          setState(() {
            _statusBanner = 'Initiation rejected: ${res.errorMessage}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Send failed: ${res.errorMessage}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusBanner = 'IPC Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error communicating with Local Node: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _cancelTransfer(String transferId) async {
    try {
      final res = await _client.cancelTransfer(transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Transfer cancellation requested: ${res.message}'
                : 'Failed to cancel: ${res.message}'),
          ),
        );
        _refreshTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling transfer: $e')),
        );
      }
    }
  }

  Future<void> _pauseTransfer(String transferId) async {
    try {
      final res = await _client.pauseTransfer(transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Transfer paused: ${res.message}'
                : 'Failed to pause: ${res.message}'),
          ),
        );
        _refreshTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pausing transfer: $e')),
        );
      }
    }
  }

  Future<void> _resumeTransfer(String transferId) async {
    try {
      final res = await _client.resumeTransfer(transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Transfer resumed: ${res.message}'
                : 'Failed to resume: ${res.message}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _refreshTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming transfer: $e')),
        );
      }
    }
  }

  Future<void> _revealInFolder(String path) async {
    try {
      final res = await _client.revealInFolder(path);
      if (mounted) {
        if (!res.opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reveal file: ${res.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error revealing in folder: $e')),
        );
      }
    }
  }

  String _formatBytes(dynamic bytes) {
    final b = bytes is int ? bytes : (bytes is num ? bytes.toInt() : (bytes?.toInt() ?? 0));
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Color _getStateColor(TransferState state) {
    switch (state) {
      case TransferState.TRANSFER_STATE_COMPLETED:
        return Colors.green;
      case TransferState.TRANSFER_STATE_TRANSFERRING:
      case TransferState.TRANSFER_STATE_COMMITTING:
      case TransferState.TRANSFER_STATE_VERIFYING:
        return Colors.blue;
      case TransferState.TRANSFER_STATE_PAUSED:
        return Colors.amber.shade800;
      case TransferState.TRANSFER_STATE_PREPARING:
      case TransferState.TRANSFER_STATE_CONNECTING:
      case TransferState.TRANSFER_STATE_RECEIVED:
        return Colors.orange;
      case TransferState.TRANSFER_STATE_CANCELLED:
        return Colors.grey;
      case TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN:
        return Colors.deepPurple;
      case TransferState.TRANSFER_STATE_FAILED:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedTransfers = _transfers.values.toList().reversed.toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Direct File Send & Transfers'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Transfers',
              onPressed: _refreshTransfers,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.send_rounded), text: 'SEND'),
              Tab(icon: Icon(Icons.history_rounded), text: 'ACTIVE & HISTORY'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSendTab(theme),
            _buildHistoryTab(theme, sortedTransfers),
          ],
        ),
      ),
    );
  }

  Widget _buildSendTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            'PeerLink Staged Transfer Architecture',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Content is transferred chunk-by-chunk into temporary staging, verified via end-to-end SHA-256 integrity checks, and atomically committed to the exact destination upon verification. Unverified bytes never touch the final destination.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Initiate Secure Send',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _targetPeerController,
                decoration: const InputDecoration(
                  labelText: 'Target Peer ID',
                  hintText: 'e.g. peer_alice or node-uuid',
                  prefixIcon: Icon(Icons.person_pin_circle_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sourcePathsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Source Paths (File or Folder)',
                  hintText: 'Enter absolute file or folder paths (one per line)\ne.g. C:\\Data\\report.pdf\nC:\\Data\\Projects\\',
                  prefixIcon: Icon(Icons.source_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _destinationDirController,
                decoration: const InputDecoration(
                  labelText: 'Exact Destination Directory (Optional)',
                  hintText: 'Leave empty for node default (PeerLink_Received)',
                  prefixIcon: Icon(Icons.folder_open_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DuplicateDestinationPolicy>(
                initialValue: _duplicatePolicy,
                decoration: const InputDecoration(
                  labelText: 'Duplicate Destination Policy',
                  prefixIcon: Icon(Icons.file_copy_rounded),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                    child: Text('FAIL_IF_EXISTS (Error if file exists)'),
                  ),
                  DropdownMenuItem(
                    value: DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_OVERWRITE,
                    child: Text('OVERWRITE (Replace existing file)'),
                  ),
                  DropdownMenuItem(
                    value: DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX,
                    child: Text('RENAME_WITH_SUFFIX (Save as filename (1))'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _duplicatePolicy = val);
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSending ? null : _initiateSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSending ? 'Initiating Transfer...' : 'SEND TO PEER'),
                ),
              ),
              if (_statusBanner != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusBanner!,
                    style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme, List<TransferProgress> transfers) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horizontal_circle_outlined, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No Transfers Recorded Yet',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            const Text('Transfers initiated or received by the Local Node will appear here.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final t = transfers[index];
        return _buildTransferCard(theme, t);
      },
    );
  }

  Widget _buildTransferCard(ThemeData theme, TransferProgress t) {
    final totalBytes = t.totalBytes.toInt();
    final transferredBytes = t.transferredBytes.toInt();
    final fraction = totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
    final stateColor = _getStateColor(t.state);

    final isTerminated = t.state == TransferState.TRANSFER_STATE_COMPLETED ||
        t.state == TransferState.TRANSFER_STATE_FAILED ||
        t.state == TransferState.TRANSFER_STATE_CANCELLED ||
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN;

    final isCompleted = t.state == TransferState.TRANSFER_STATE_COMPLETED;
    final isPaused = t.state == TransferState.TRANSFER_STATE_PAUSED;
    final isOutcomeUnknown = t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: stateColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.transferId,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label: 'Transfer state is ${t.state.name.replaceFirst("TRANSFER_STATE_", "")}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stateColor),
                    ),
                    child: Text(
                      t.state.name.replaceFirst('TRANSFER_STATE_', ''),
                      style: TextStyle(
                        color: stateColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (t.totalItems > 0)
              _buildDetailRow(Icons.layers_rounded, 'Items:', '${t.currentItemIndex + 1} / ${t.totalItems}'),
            if (t.currentFile.isNotEmpty)
              _buildDetailRow(Icons.description_rounded, 'Current File:', t.currentFile),
            if (t.destinationPath.isNotEmpty)
              _buildDetailRow(Icons.folder_special_rounded, 'Destination:', t.destinationPath),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isTerminated ? (isCompleted ? 1.0 : fraction) : fraction,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatBytes(transferredBytes)} / ${_formatBytes(totalBytes)} (${(fraction * 100).toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  isTerminated
                      ? (isCompleted
                          ? 'Verified SHA-256 ✓'
                          : (isOutcomeUnknown ? 'Outcome Unconfirmed' : 'Terminated'))
                      : (isPaused ? 'Paused' : _formatSpeed(t.speedBps.toDouble())),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? Colors.green
                        : (isPaused ? Colors.amber.shade900 : null),
                  ),
                ),
              ],
            ),
            if (isOutcomeUnknown) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.help_outline_rounded, color: Colors.deepPurple.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outcome Unconfirmed (Network Interruption)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Data was staged remotely, but the final confirmation was interrupted. Do NOT re-send blindly to avoid duplicate copies. Verify remote destination or click "Reconcile Status" below.',
                            style: TextStyle(color: Colors.deepPurple.shade900, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (t.hasError()) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.error.humanSummary.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: Colors.red.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.error.humanSummary,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (t.error.humanExplanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Why: ${t.error.humanExplanation}',
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ],
                    if (t.error.suggestedRecoveryAction.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Action: ${t.error.suggestedRecoveryAction}',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPaused) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _resumeTransfer(t.transferId),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Resume'),
                  ),
                  const SizedBox(width: 8),
                ] else if (!isTerminated) ...[
                  OutlinedButton.icon(
                    onPressed: () => _pauseTransfer(t.transferId),
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pause'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.amber.shade900),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isTerminated && !isPaused)
                  OutlinedButton.icon(
                    onPressed: () => _cancelTransfer(t.transferId),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                if (isOutcomeUnknown) ...[
                  FilledButton.tonalIcon(
                    onPressed: _refreshTransfers,
                    icon: const Icon(Icons.sync_problem_rounded, size: 18),
                    label: const Text('Reconcile Status'),
                  ),
                ],
                if (isCompleted && t.destinationPath.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _revealInFolder(t.destinationPath),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Reveal in Folder'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
