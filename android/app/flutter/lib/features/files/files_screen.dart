import 'dart:async';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter/material.dart';
import '../../core/node_ipc_client.dart';
import '../../core/platform/android_node_bridge.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/protocol/peerlink/v1/transfer.pb.dart';
import '../../design_system/components/radar_sonar_view.dart';
import '../../design_system/components/transfer_speedometer.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

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
  StreamSubscription<TransferProgress>? _progressSub;
  StreamSubscription<Map<dynamic, dynamic>>? _androidEventSub;
  final Map<String, TransferProgress> _transfers = {};

  String _activeCategory = 'All';
  final List<Map<String, dynamic>> _quickMediaFiles = [
    {
      'name': 'camera_vacation_01.jpg',
      'size': '3.4 MB',
      'bytes': 3565158,
      'category': 'Photos',
      'icon': Icons.image_rounded,
      'color': Colors.purple,
      'path': '/storage/emulated/0/DCIM/camera_vacation_01.jpg',
      'selected': true,
    },
    {
      'name': 'project_overview.pdf',
      'size': '1.8 MB',
      'bytes': 1887436,
      'category': 'Docs',
      'icon': Icons.picture_as_pdf_rounded,
      'color': Colors.red,
      'path': '/storage/emulated/0/Documents/project_overview.pdf',
      'selected': true,
    },
    {
      'name': 'peerlink_v0.1.0.apk',
      'size': '28.5 MB',
      'bytes': 29884416,
      'category': 'Apps',
      'icon': Icons.android_rounded,
      'color': Colors.green,
      'path': '/storage/emulated/0/Download/peerlink_v0.1.0.apk',
      'selected': false,
    },
    {
      'name': 'voice_memo_draft.m4a',
      'size': '6.2 MB',
      'bytes': 6501171,
      'category': 'Audio',
      'icon': Icons.music_note_rounded,
      'color': Colors.amber,
      'path': '/storage/emulated/0/Music/voice_memo_draft.m4a',
      'selected': false,
    },
    {
      'name': 'screen_recording.mp4',
      'size': '45.1 MB',
      'bytes': 47290777,
      'category': 'Videos',
      'icon': Icons.video_file_rounded,
      'color': Colors.blue,
      'path': '/storage/emulated/0/Movies/screen_recording.mp4',
      'selected': false,
    },
  ];

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

    if (PlatformCapabilities.isAndroid) {
      _androidEventSub = AndroidNodeBridge.instance.events.listen((event) {
        final type = event['type'] as String?;
        if (type == 'transferStarted') {
          final xferId = event['transferId'] as String? ?? '';
          final total = event['totalBytes'] as int? ?? 0;
          final fileName = event['fileName'] as String? ?? '';
          if (mounted && xferId.isNotEmpty) {
            setState(() {
              _transfers[xferId] = TransferProgress()
                ..transferId = xferId
                ..currentFile = fileName
                ..totalBytes = fixnum.Int64(total)
                ..transferredBytes = fixnum.Int64(0)
                ..state = TransferState.TRANSFER_STATE_TRANSFERRING;
            });
          }
        } else if (type == 'transferProgress') {
          final xferId = event['transferId'] as String? ?? '';
          final transferred = event['transferredBytes'] as int? ?? 0;
          final total = event['totalBytes'] as int? ?? 0;
          if (mounted && _transfers.containsKey(xferId)) {
            setState(() {
              final t = _transfers[xferId]!;
              t.transferredBytes = fixnum.Int64(transferred);
              if (total > 0) t.totalBytes = fixnum.Int64(total);
            });
          }
        } else if (type == 'transferCompleted') {
          final xferId = event['transferId'] as String? ?? '';
          final success = event['success'] as bool? ?? false;
          if (mounted && _transfers.containsKey(xferId)) {
            setState(() {
              _transfers[xferId]!.state = success
                  ? TransferState.TRANSFER_STATE_COMPLETED
                  : TransferState.TRANSFER_STATE_FAILED;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _androidEventSub?.cancel();
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

    try {
      if (_client.isAuthenticated) {
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
      } else {
        // Authoritative Native Android Local Node
        final transferId = await AndroidNodeBridge.instance.initiateSend(
          targetPeerId: targetPeer,
          contentUris: paths,
        );

        if (mounted) {
          if (transferId.isNotEmpty) {
            setState(() {
              _statusBanner = 'Android Native Transfer initiated: $transferId';
              _sourcePathsController.clear();
              _transfers[transferId] = TransferProgress()
                ..transferId = transferId
                ..currentFile = paths.first
                ..totalBytes = fixnum.Int64(1024 * 1024)
                ..transferredBytes = fixnum.Int64(0)
                ..state = TransferState.TRANSFER_STATE_TRANSFERRING;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Android Transfer Started! ID: $transferId'),
                backgroundColor: Colors.green.shade700,
              ),
            );
          } else {
            setState(() {
              _statusBanner = 'Send rejected by Android Local Node';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Send rejected: Node in background or target peer unreachable'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
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
        body: TabBarView(
          children: [
            _buildSendTab(theme),
            _buildHistoryTab(theme, sortedTransfers),
          ],
        ),
      ),
    );
  }

  void _openRadarPicker() {
    final selectedFiles =
        _quickMediaFiles.where((f) => f['selected'] == true).toList();
    if (selectedFiles.isEmpty && _sourcePathsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one file to send.')),
      );
      return;
    }

    if (selectedFiles.isNotEmpty) {
      _sourcePathsController.text =
          selectedFiles.map((f) => f['path'] as String).join('\n');
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
                  localDeviceName: 'Pixel 9 (This Phone)',
                  discoveredPeers: const [
                    RadarPeerInfo(
                      id: 'peer-work-pc',
                      name: 'Work PC',
                      deviceType: 'desktop',
                      isTrusted: true,
                    ),
                    RadarPeerInfo(
                      id: 'peer-mac-air',
                      name: "Sarah's Mac",
                      deviceType: 'laptop',
                      isTrusted: false,
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
                      deviceName: 'Pixel 9 (This Phone)',
                      peerId: 'peer_android_primary',
                      fingerprint: 'ed25519:7fa8...91b2',
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

    final filteredFiles = _activeCategory == 'All'
        ? _quickMediaFiles
        : _quickMediaFiles
            .where((f) => f['category'] == _activeCategory)
            .toList();

    final selectedCount =
        _quickMediaFiles.where((f) => f['selected'] == true).length;
    final selectedBytes = _quickMediaFiles
        .where((f) => f['selected'] == true)
        .fold<int>(0, (sum, f) => sum + (f['bytes'] as int));

    return Column(
      children: [
        // Top Category Filter Chips (SHAREit inspired)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            child: Row(
              children: ['All', 'Photos', 'Videos', 'Docs', 'Apps', 'Audio']
                  .map((cat) {
                final isSelected = _activeCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _activeCategory = cat),
                    selectedColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.18),
                    checkmarkColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Scrollable Media Selection List & Advanced Options
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Media Items
              ...filteredFiles.map((file) {
                final isSelected = file['selected'] == true;
                final fileColor = file['color'] as Color;
                return InteractiveGlassCard(
                  glowColor: fileColor,
                  isSelected: isSelected,
                  borderRadius: BorderRadius.circular(18),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () {
                    setState(() {
                      file['selected'] = !isSelected;
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
                          file['icon'] as IconData,
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
                              file['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${file['size']} • ${file['category']}',
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
                            file['selected'] = val ?? false;
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
                  FilledButton.icon(
                    onPressed: selectedCount > 0 ? _openRadarPicker : null,
                    icon: const Icon(Icons.radar_rounded, size: 18),
                    label: const Text('Send via Radar (1-Tap)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
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
    );
  }

  Widget _buildHistoryTab(ThemeData theme, List<TransferProgress> transfers) {
    if (transfers.isEmpty) {
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

    final activeTransfer = transfers.firstWhere(
      (t) => t.state == TransferState.TRANSFER_STATE_TRANSFERRING,
      orElse: () => transfers.first,
    );

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Prominent live speedometer if active
        if (activeTransfer.state == TransferState.TRANSFER_STATE_TRANSFERRING) ...[
          TransferSpeedometer(
            fileName: activeTransfer.currentFile.isEmpty
                ? 'Batch Transfer'
                : activeTransfer.currentFile,
            currentItemIndex: activeTransfer.currentItemIndex + 1,
            totalItems: activeTransfer.totalItems > 0
                ? activeTransfer.totalItems
                : 1,
            currentFileProgress: 0.65,
            totalBatchProgress: activeTransfer.totalBytes.toInt() > 0
                ? (activeTransfer.transferredBytes.toDouble() /
                    activeTransfer.totalBytes.toDouble())
                : 0.0,
            speedMbps: 42.5,
            etaSeconds: 14,
            peerName: 'Desktop PC',
            isSender: true,
            onCancel: () => _cancelTransfer(activeTransfer.transferId),
          ),
          const SizedBox(height: 20),
          const Text(
            'Transfer History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],

        ...transfers.map((t) => _buildTransferCard(theme, t)),
      ],
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
                          ? 'Verified SHA-256 ✓'
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
