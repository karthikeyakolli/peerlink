import 'dart:async';
import 'dart:io';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter/material.dart';
import '../../core/node_ipc_client.dart';
import '../../core/operation_journal_service.dart';
import '../../core/protocol/peerlink/v1/transfer.pb.dart';
import '../../design_system/components/radar_sonar_view.dart';
import '../../design_system/components/transfer_speedometer.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';
import '../../design_system/components/ephemeral_policy_modal.dart';
import '../../design_system/components/burn_viewer_modal.dart';
import '../../design_system/components/desktop_dropzone.dart';
import '../../platform/windows_file_dialog.dart';
import '../../platform/android_node_bridge.dart';

class SelectedFileInfo {
  final String path;
  final String name;
  final int sizeBytes;
  final bool isDirectory;
  bool selected;

  SelectedFileInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.isDirectory,
    this.selected = true,
  });
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final NodeIpcClient _client = NodeIpcClient.instance;

  final TextEditingController _targetPeerController =
      TextEditingController(text: 'peer-desktop-b');
  final TextEditingController _sourcePathsController = TextEditingController();
  final TextEditingController _destinationDirController =
      TextEditingController();
  DuplicateDestinationPolicy _duplicatePolicy =
      DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS;

  bool _isSending = false;
  String? _statusBanner;
  String? _refreshError;
  StreamSubscription<TransferProgress>? _progressSub;
  final Map<String, TransferProgress> _transfers = {};
  EphemeralPolicy _currentPolicy = EphemeralPolicy.permanent;

  String _activeCategory = 'All';
  final List<SelectedFileInfo> _selectedFiles = [];

  void _addPaths(List<String> paths) {
    for (final p in paths) {
      if (p.trim().isEmpty) continue;
      final cleanPath = p.trim();
      final f = File(cleanPath);
      final d = Directory(cleanPath);
      String name = cleanPath.split(RegExp(r'[\\/]')).last;
      name = Uri.decodeComponent(name);
      if (name.contains(':')) {
        name = name.split(':').last;
      }

      int size = 0;
      bool isDir = false;
      try {
        if (f.existsSync()) {
          size = f.lengthSync();
          isDir = false;
        } else if (d.existsSync()) {
          isDir = true;
        }
      } catch (_) {}

      if (size == 0 && cleanPath.startsWith('content://')) {
        size = 1024 * 1024;
      }

      if (!_selectedFiles.any((item) => item.path == cleanPath)) {
        _selectedFiles.add(SelectedFileInfo(
          path: cleanPath,
          name: name.isEmpty ? cleanPath : name,
          sizeBytes: size,
          isDirectory: isDir,
        ));
      }
    }
    _syncController();
  }

  void _syncController() {
    _sourcePathsController.text = _selectedFiles
        .where((f) => f.selected)
        .map((f) => f.path)
        .join('\n');
  }

  Future<void> _pickFiles() async {
    final paths = await WindowsFileDialog.pickFiles();
    if (paths.isNotEmpty && mounted) {
      setState(() {
        _addPaths(paths);
      });
    }
  }

  Future<void> _pickFolder() async {
    final folder = await WindowsFileDialog.pickDirectory();
    if (folder != null && mounted) {
      setState(() {
        _addPaths([folder]);
      });
    }
  }

  Future<void> _pickSafFile() async {
    try {
      final uris = await AndroidNodeBridge.instance.pickContentUris();
      if (uris.isNotEmpty && mounted) {
        setState(() {
          _addPaths(uris);
        });
      }
    } catch (_) {}
  }

  void _clearSelectedFiles() {
    setState(() {
      _selectedFiles.clear();
      _sourcePathsController.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshTransfers();
    _progressSub = _client.transferProgressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _transfers[progress.transferId] = progress;
        });
        // Invariant: Unknown or uncertain transfer events trigger reconciliation
        if (progress.state == TransferState.TRANSFER_STATE_UNSPECIFIED ||
            progress.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN) {
          OperationJournalService.instance.runDiagnosticsAndReconcile(progress.transferId);
        }
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
    setState(() => _refreshError = null);
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshError = 'Error refreshing transfer list: $e';
        });
      }
    }
  }

  Future<void> _initiateSend() async {
    final rawPaths = _sourcePathsController.text.trim();
    if (rawPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter at least one file or folder path to send.')),
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

    if (paths.any((p) => p.startsWith('content://'))) {
      try {
        final transferId = await AndroidNodeBridge.instance.initiateSend(
          targetPeerId: targetPeer,
          contentUris: paths,
        );
        if (mounted) {
          if (transferId.isNotEmpty) {
            setState(() {
              _statusBanner = 'Transfer initiated: $transferId';
              _sourcePathsController.clear();
              _selectedFiles.clear();
            });
            _refreshTransfers();
          } else {
            setState(() {
              _statusBanner = 'Initiation rejected by target peer: $targetPeer';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusBanner = 'Android Send rejected / error: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
      return;
    }

    if (!_client.isAuthenticated) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _statusBanner =
              'Local Node daemon is disconnected. Please start the node to transfer files.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Local Node daemon is disconnected. Transfer cannot be initiated.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

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
            _selectedFiles.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Transfer initiated successfully! ID: ${res.transferId}'),
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
          _statusBanner = 'Transfer Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating transfer: $e'),
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
            SnackBar(
                content: Text('Failed to reveal file: ${res.errorMessage}')),
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
    final b = bytes is int
        ? bytes
        : (bytes is num ? bytes.toInt() : (bytes?.toInt() ?? 0));
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
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
        body: Column(
          children: [
            if (_refreshError != null)
              Container(
                color: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _refreshError!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _refreshTransfers,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSendTab(theme),
                  _buildHistoryTab(theme, sortedTransfers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRadarPicker() {
    final selectedFiles =
        _selectedFiles.where((f) => f.selected).toList();
    if (selectedFiles.isEmpty && _sourcePathsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one file to send.')),
      );
      return;
    }

    if (selectedFiles.isNotEmpty) {
      _sourcePathsController.text =
          selectedFiles.map((f) => f.path).join('\n');
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select Destination Device',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Tap a nearby peer to send the selected batch directly',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RadarSonarView(
                  localDeviceName: 'This PC (Windows)',
                  discoveredPeers: const [
                    RadarPeerInfo(
                      id: 'peer-work-pc',
                      name: 'Work PC',
                      deviceType: 'desktop',
                      isTrusted: true,
                    ),
                    RadarPeerInfo(
                      id: 'peer-desktop-b',
                      name: 'Peer B (Receiver)',
                      deviceType: 'desktop',
                      isTrusted: true,
                    ),
                  ],
                  onPeerSelected: (peer) {
                    Navigator.pop(ctx);
                    setState(() {
                      _targetPeerController.text = peer.id;
                    });
                    _initiateSend();
                  },
                  onQrScanPressed: () {
                    Navigator.pop(ctx);
                    QrPairingSheet.show(
                      context,
                      deviceName: 'This PC (Windows)',
                      peerId: _client.currentState.peerId ?? 'peer_windows_local',
                      fingerprint: 'ed25519:windows...node',
                      onQrScanned: (payload) {
                        setState(() {
                          _targetPeerController.text = 'peer-scanned-01';
                        });
                        _initiateSend();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    final selectedCount =
        _selectedFiles.where((f) => f.selected).length;
    final selectedBytes = _selectedFiles
        .where((f) => f.selected)
        .fold<int>(0, (sum, f) => sum + f.sizeBytes);

    return DesktopDropzone(
      onFilesDropped: (dropped) {
        setState(() {
          _addPaths(dropped);
        });
      },
      child: Column(
        children: [
          // Status Banner (Initiation results, rejection, disconnection)
          if (_statusBanner != null)
            Container(
              width: double.infinity,
              color: _statusBanner!.contains('initiated')
                  ? const Color(0xFF10B981)
                  : (_statusBanner!.contains('rejected') ||
                          _statusBanner!.contains('disconnected') ||
                          _statusBanner!.contains('Error')
                      ? Colors.red.shade800
                      : Colors.blue.shade800),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _statusBanner!.contains('initiated')
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusBanner!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16),
                    onPressed: () => setState(() => _statusBanner = null),
                  ),
                ],
              ),
            ),

          // Real File Action Bar (Windows Desktop & Android File Pickers)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.file_open_rounded, size: 18),
                    label: const Text('Add Files...'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _pickFolder,
                    icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                    label: const Text('Add Folder...'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _pickSafFile,
                    icon: const Icon(Icons.sd_storage_rounded, size: 18),
                    label: const Text('Pick SAF File'),
                  ),
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _clearSelectedFiles,
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Scrollable Media Selection List & Advanced Options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                if (_selectedFiles.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                          : const Color(0xFFF1F5F9),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.drive_folder_upload_rounded,
                          size: 48,
                          color: const Color(0xFF2563EB).withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No files selected yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Drag & drop files from Windows File Explorer here, or click "Add Files..." above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._selectedFiles.map((file) {
                    final isSelected = file.selected;
                    final fileColor = file.isDirectory ? Colors.amber : const Color(0xFF2563EB);
                    return InteractiveGlassCard(
                      glowColor: fileColor,
                      isSelected: isSelected,
                      borderRadius: BorderRadius.circular(18),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onTap: () {
                        setState(() {
                          file.selected = !isSelected;
                          _syncController();
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: fileColor.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              file.isDirectory
                                  ? Icons.folder_rounded
                                  : Icons.insert_drive_file_rounded,
                              color: fileColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  file.isDirectory ? 'Folder' : _formatBytes(file.sizeBytes),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (val) {
                              setState(() {
                                file.selected = val ?? false;
                                _syncController();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 12),

                // Collapsible Advanced Manual Form (Preserves developer / script controls)
                ExpansionTile(
                  title: const Text(
                    'Advanced Manual Paths & Policy',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  leading: const Icon(Icons.tune_rounded, size: 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _targetPeerController,
                            decoration: const InputDecoration(
                              labelText: 'Target Peer ID',
                              hintText: 'e.g. peer_alice or node-uuid',
                              prefixIcon: Icon(Icons.person_pin_circle_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _sourcePathsController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Source Paths (File or Folder)',
                              hintText: 'Enter absolute file or folder paths',
                              prefixIcon: Icon(Icons.source_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _destinationDirController,
                            decoration: const InputDecoration(
                              labelText: 'Destination Directory (Optional)',
                              hintText: 'Leave empty for node default',
                              prefixIcon: Icon(Icons.folder_open_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<DuplicateDestinationPolicy>(
                            initialValue: _duplicatePolicy,
                            decoration: const InputDecoration(
                              labelText: 'Duplicate Policy',
                              prefixIcon: Icon(Icons.file_copy_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: DuplicateDestinationPolicy
                                    .DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                                child: Text('FAIL_IF_EXISTS (Error if file exists)'),
                              ),
                              DropdownMenuItem(
                                value: DuplicateDestinationPolicy
                                    .DUPLICATE_DESTINATION_POLICY_OVERWRITE,
                                child: Text('OVERWRITE (Replace existing file)'),
                              ),
                              DropdownMenuItem(
                                value: DuplicateDestinationPolicy
                                    .DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX,
                                child: Text('RENAME_WITH_SUFFIX (Save as (1))'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _duplicatePolicy = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _isSending ? null : _initiateSend,
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('SEND TO EXACT PEER ID'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Sticky Bottom Batch Action Pill (AirDrop / Quick Share inspired)
        AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          offset: selectedCount > 0 ? Offset.zero : const Offset(0, 0.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selectedCount > 0 ? 1.0 : 0.6,
            child: GlassContainer(
              glowColor: const Color(0xFF2563EB),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$selectedCount item(s) selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatBytes(selectedBytes),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final policy = await EphemeralPolicyModal.show(
                        context,
                        initialPolicy: _currentPolicy,
                      );
                      if (policy != null) {
                        setState(() => _currentPolicy = policy);
                      }
                    },
                    icon: Icon(
                      Icons.local_fire_department_rounded,
                      color: _currentPolicy.isEphemeral
                          ? const Color(0xFFEF4444)
                          : Colors.white54,
                    ),
                    tooltip: _currentPolicy.isEphemeral
                        ? 'Ephemeral Mode Active (${_currentPolicy.burnAfterRead ? "1-View" : "${_currentPolicy.ttlSeconds}s TTL"})'
                        : 'Configure Burn-After-Read Ephemeral Policy',
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: selectedCount > 0 ? _openRadarPicker : null,
                    icon: Icon(
                      _currentPolicy.isEphemeral
                          ? Icons.local_fire_department_rounded
                          : Icons.radar_rounded,
                      size: 18,
                    ),
                    label: Text(_currentPolicy.isEphemeral
                        ? 'Burn Beam (1-Tap)'
                        : 'Send via Radar (1-Tap)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _currentPolicy.isEphemeral
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF2563EB),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildHistoryTab(ThemeData theme, List<TransferProgress> transfers) {
    final journalOps = OperationJournalService.instance.operations;

    final activeJournalOps = journalOps.where((op) => !op.isTerminal).toList();
    final historyJournalOps = journalOps.where((op) => op.isTerminal).toList();

    final activeTransfers = transfers.where((t) =>
        t.state == TransferState.TRANSFER_STATE_TRANSFERRING ||
        t.state == TransferState.TRANSFER_STATE_COMMITTING ||
        t.state == TransferState.TRANSFER_STATE_VERIFYING ||
        t.state == TransferState.TRANSFER_STATE_PREPARING ||
        t.state == TransferState.TRANSFER_STATE_CONNECTING).toList();

    final historyTransfers = transfers.where((t) =>
        t.state == TransferState.TRANSFER_STATE_COMPLETED ||
        t.state == TransferState.TRANSFER_STATE_FAILED ||
        t.state == TransferState.TRANSFER_STATE_CANCELLED ||
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN).toList();

    final hasActive = activeTransfers.isNotEmpty || activeJournalOps.isNotEmpty;
    final hasHistory = historyTransfers.isNotEmpty || historyJournalOps.isNotEmpty;

    if (!hasActive && !hasHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horizontal_circle_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No Transfers Recorded Yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            const Text(
                'Transfers initiated or received by the Local Node will appear here.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (hasActive) ...[
          Text(
            'ACTIVE IN-FLIGHT TRANSFERS (${activeTransfers.length + activeJournalOps.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 10),
          ...activeTransfers.map((t) => _buildTransferCard(theme, t)),
          ...activeJournalOps.map((op) => _buildJournalOperationCard(theme, op)),
          const SizedBox(height: 16),
        ],
        if (hasHistory) ...[
          Text(
            'TRANSFER JOURNAL & HISTORY (${historyTransfers.length + historyJournalOps.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          ...historyTransfers.map((t) => _buildTransferCard(theme, t)),
          ...historyJournalOps.map((op) => _buildJournalOperationCard(theme, op)),
        ],
      ],
    );
  }

  Widget _buildJournalOperationCard(ThemeData theme, JournalOperation op) {
    Color stateColor;
    String stateLabel;
    switch (op.state) {
      case JournalOperationState.committed:
        stateColor = const Color(0xFF10B981);
        stateLabel = 'COMMITTED';
        break;
      case JournalOperationState.executing:
        stateColor = const Color(0xFF2563EB);
        stateLabel = 'EXECUTING';
        break;
      case JournalOperationState.waiting:
        stateColor = Colors.orange;
        stateLabel = 'WAITING';
        break;
      case JournalOperationState.verifying:
        stateColor = const Color(0xFF8B5CF6);
        stateLabel = 'VERIFYING';
        break;
      case JournalOperationState.failed:
        stateColor = const Color(0xFFEF4444);
        stateLabel = 'FAILED';
        break;
      case JournalOperationState.cancelled:
        stateColor = Colors.grey;
        stateLabel = 'CANCELLED';
        break;
      case JournalOperationState.outcomeUnknown:
        stateColor = Colors.deepPurple;
        stateLabel = 'UNCERTAIN';
        break;
      default:
        stateColor = Colors.blue;
        stateLabel = op.state.name.toUpperCase();
    }

    final fraction = op.totalBytes > 0
        ? (op.bytesTransferred / op.totalBytes).clamp(0.0, 1.0)
        : 0.0;

    return InteractiveGlassCard(
      glowColor: stateColor,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  op.summary,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: stateColor),
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Peer: ${op.peerId} • ID: ${op.operationId} • Stage: ${op.stage.name.toUpperCase()}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: op.isTerminal ? (op.state == JournalOperationState.committed ? 1.0 : fraction) : fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(stateColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatBytes(op.bytesTransferred)} / ${_formatBytes(op.totalBytes)} (${(fraction * 100).toStringAsFixed(1)}%)',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(ThemeData theme, TransferProgress t) {
    final totalBytes = t.totalBytes.toInt();
    final transferredBytes = t.transferredBytes.toInt();
    final fraction =
        totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
    final stateColor = _getStateColor(t.state);

    final isTerminated = t.state == TransferState.TRANSFER_STATE_COMPLETED ||
        t.state == TransferState.TRANSFER_STATE_FAILED ||
        t.state == TransferState.TRANSFER_STATE_CANCELLED ||
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN;

    final isCompleted = t.state == TransferState.TRANSFER_STATE_COMPLETED;
    final isPaused = t.state == TransferState.TRANSFER_STATE_PAUSED;
    final isOutcomeUnknown =
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN;

    return InteractiveGlassCard(
      glowColor: stateColor,
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: BorderRadius.circular(20),
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
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label:
                      'Transfer state is ${t.state.name.replaceFirst("TRANSFER_STATE_", "")}',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              _buildDetailRow(Icons.layers_rounded, 'Items:',
                  '${t.currentItemIndex + 1} / ${t.totalItems}'),
            if (t.currentFile.isNotEmpty)
              _buildDetailRow(
                  Icons.description_rounded, 'Current File:', t.currentFile),
            if (t.destinationPath.isNotEmpty)
              _buildDetailRow(Icons.folder_special_rounded, 'Destination:',
                  t.destinationPath),
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
                          ? 'Verified SHA-256 âœ“'
                          : (isOutcomeUnknown
                              ? 'Outcome Unconfirmed'
                              : 'Terminated'))
                      : (isPaused
                          ? 'Paused'
                          : _formatSpeed(t.speedBps.toDouble())),
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
                    Icon(Icons.help_outline_rounded,
                        color: Colors.deepPurple.shade700, size: 20),
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
                            style: TextStyle(
                                color: Colors.deepPurple.shade900,
                                fontSize: 12),
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
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: Colors.red.shade800),
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
                        style:
                            TextStyle(color: Colors.red.shade800, fontSize: 12),
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
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade900),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isTerminated && !isPaused)
                  OutlinedButton.icon(
                    onPressed: () => _cancelTransfer(t.transferId),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                if (isOutcomeUnknown) ...[
                  FilledButton.tonalIcon(
                    onPressed: _refreshTransfers,
                    icon: const Icon(Icons.sync_problem_rounded, size: 18),
                    label: const Text('Reconcile Status'),
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      BurnViewerModal.show(
                        context,
                        fileName: t.currentFile.isNotEmpty
                            ? t.currentFile.split(RegExp(r'[\\/]')).last
                            : 'Document.pdf',
                        fileSize: _formatBytes(t.transferredBytes),
                        previewContent:
                            'CONFIDENTIAL ENCRYPTED RECORD\nSHA-256 Verified Payload: 8f4a...e12b\nZero-Trust Ephemeral Beam Content\nAuto-shredded upon viewer closure.',
                        policy: EphemeralPolicy.singleView,
                        onShred: () {
                          setState(() {
                            _transfers.remove(t.transferId);
                          });
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    label: const Text('Burn Viewer'),
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
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
