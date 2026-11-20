import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/device_trust_service.dart';
import '../../core/exif_scrubber_service.dart';
import '../../core/file_staging_service.dart';
import '../../core/node_ipc_client.dart';
import '../../core/operation_journal_service.dart';
import '../../core/received_files_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';
import '../../platform/windows_file_dialog.dart';
import 'local_hotspot_modal.dart';
import 'qr_pairing_sheet.dart';
import 'quick_text_share_modal.dart';
import 'radar_sonar_view.dart';
import 'web_beam_modal.dart';
import 'dedicated_tool_page.dart';

/// Contextual On-Demand Sharing Sheet — surfaces sharing smoothly over the
/// File Manager ONLY when the user wants to share or receive, eliminating the
/// need for a separate dedicated Share tab/page.
/// Strictly flat Light Mode (zero dark backgrounds, zero gradients, zero shadows).
class ContextualShareSheet extends StatefulWidget {
  final List<String> initialPaths;

  const ContextualShareSheet({
    super.key,
    this.initialPaths = const [],
  });

  static Future<void> show(
    BuildContext context, {
    List<String> initialPaths = const [],
  }) {
    final effectivePaths = initialPaths.isNotEmpty
        ? initialPaths
        : FileStagingService.instance.stagedFiles
            .where((f) => f.selected)
            .map((f) => f.path)
            .toList();

    return DedicatedToolPage.open(
      context,
      title: 'Contextual Share & Transfer',
      subtitle: 'Nearby P2P Device Discovery, Radar & Direct File Beam',
      icon: Icons.share_rounded,
      child: ContextualShareSheet(initialPaths: effectivePaths),
    );
  }

  static void showReceiveRadar(BuildContext context) {
    final devices = DeviceTrustService.instance.devices;
    if (PlatformCapabilities.isAndroid) {
      AndroidNodeBridge.instance.refreshDiscovery();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Waiting to Receive Files',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Text(
                'Visible to nearby PeerLink devices on Wi-Fi',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<DiscoveredPeer>>(
                  stream: AndroidNodeBridge.instance.discoveredPeersStream,
                  initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                  builder: (context, snapshot) {
                    final livePeers = snapshot.data ?? [];
                    final peerInfos = PlatformCapabilities.isAndroid
                        ? livePeers
                            .map((p) => RadarPeerInfo(
                                  id: p.peerId,
                                  name: p.name.isNotEmpty ? p.name : p.peerId,
                                  deviceType: p.technology.contains('WIFI_DIRECT') ? 'phone' : 'desktop',
                                  isTrusted: DeviceTrustService.instance.devices.any((d) => d.id == p.peerId),
                                  ip: p.host,
                                  technology: p.technology,
                                  routeCount: p.routes.isNotEmpty ? p.routes.length : 1,
                                ))
                            .toList()
                        : devices
                            .map((d) => RadarPeerInfo(
                                  id: d.id,
                                  name: d.name,
                                  deviceType: d.deviceType,
                                  isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
                                  ip: '127.0.0.1',
                                  technology: 'Paired',
                                  routeCount: 1,
                                ))
                            .toList();

                    return RadarSonarView(
                      localDeviceName: PlatformCapabilities.isAndroid ? 'This Phone' : 'This PC',
                      discoveredPeers: peerInfos,
                      onPeerSelected: (_) {},
                      onQrScanPressed: () {
                        QrPairingSheet.show(
                          context,
                          deviceName: PlatformCapabilities.isAndroid ? 'Android Peer' : 'Desktop PC',
                          peerId: NodeIpcClient.instance.currentState.peerId ?? 'peer_local',
                          fingerprint: DeviceTrustService.instance.getLocalFingerprint('peer_local'),
                        );
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

  @override
  State<ContextualShareSheet> createState() => _ContextualShareSheetState();
}

class _ContextualShareSheetState extends State<ContextualShareSheet> {
  late List<String> _paths;
  bool _isSending = false;
  bool _stripExifMetadata = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _hasScrubbableImages =>
      _paths.any((p) => ExifScrubberService.instance.isSupportedImagePath(p));

  Future<List<String>> _prepareOutgoingPaths() async {
    if (!_stripExifMetadata || !_hasScrubbableImages) {
      return _paths;
    }
    final res = await ExifScrubberService.instance.scrubPathsForSharing(_paths);
    return res.paths;
  }

  @override
  void initState() {
    super.initState();
    _paths = List<String>.from(widget.initialPaths);
    if (PlatformCapabilities.isAndroid) {
      AndroidNodeBridge.instance.refreshDiscovery();
    }
  }

  String _basename(String path) {
    final clean = Uri.decodeComponent(path);
    final parts = clean.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return path;
    final last = parts.last;
    return last.contains(':') ? last.split(':').last : last;
  }

  ({IconData icon, Color color, Color bg}) _fileChipVisual(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'heic':
        return (icon: Icons.image_outlined, color: const Color(0xFF7C3AED), bg: const Color(0xFFF5F3FF));
      case 'mp4':
      case 'mkv':
      case 'mov':
      case 'webm':
        return (icon: Icons.movie_outlined, color: const Color(0xFFDC2626), bg: const Color(0xFFFEF2F2));
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return (icon: Icons.audiotrack_rounded, color: const Color(0xFFD97706), bg: const Color(0xFFFFFBEB));
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
      case 'xlsx':
      case 'csv':
        return (icon: Icons.description_outlined, color: const Color(0xFF2563EB), bg: const Color(0xFFEFF6FF));
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return (icon: Icons.folder_zip_outlined, color: const Color(0xFFDB2777), bg: const Color(0xFFFDF2F8));
      case 'apk':
      case 'exe':
      case 'msi':
        return (icon: Icons.android_rounded, color: const Color(0xFF059669), bg: const Color(0xFFECFDF5));
      default:
        return (icon: Icons.insert_drive_file_outlined, color: const Color(0xFF475569), bg: const Color(0xFFF1F5F9));
    }
  }

  Future<void> _pickMoreFiles() async {
    HapticFeedback.selectionClick();
    List<String> picked = [];
    if (PlatformCapabilities.isAndroid) {
      picked = await AndroidNodeBridge.instance.pickContentUris();
    } else if (PlatformCapabilities.isWindows) {
      picked = await WindowsFileDialog.pickFiles();
    }
    if (picked.isNotEmpty && mounted) {
      setState(() {
        for (final p in picked) {
          if (!_paths.contains(p)) _paths.add(p);
        }
        _statusMessage = null;
      });
      FileStagingService.instance.addPaths(picked);
    }
  }

  Future<void> _sendToPeer(String peerId, String peerName) async {
    if (_paths.isEmpty) {
      setState(() {
        _statusMessage = 'Pick at least one file above before sending.';
        _statusIsError = true;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending ${_paths.length} item(s) to $peerName...';
      _statusIsError = false;
    });

    try {
      final outgoingPaths = await _prepareOutgoingPaths();
      if (PlatformCapabilities.isAndroid) {
        final transferId = await AndroidNodeBridge.instance.initiateSend(
          targetPeerId: peerId,
          contentUris: outgoingPaths,
        );
        if (transferId.isNotEmpty) {
          OperationJournalService.instance.recordOperation(
            JournalOperation(
              operationId: transferId,
              type: OperationType.send,
              state: JournalOperationState.executing,
              stage: JournalStage.execute,
              peerId: peerName,
              summary: _paths.length == 1
                  ? _basename(_paths.first)
                  : '${_basename(_paths.first)} (+${_paths.length - 1} more)',
              bytesTransferred: 0,
              totalBytes: 0,
              timestamp: DateTime.now(),
            ),
          );
          FileStagingService.instance.clear();
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sending ${_paths.length} item(s) to $peerName'),
                backgroundColor: const Color(0xFF15803D),
              ),
            );
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isSending = false;
            _statusMessage = 'Could not reach $peerName. Check Wi-Fi or use Web Beam below.';
            _statusIsError = true;
          });
        }
      } else {
        final client = NodeIpcClient.instance;
        if (!client.isAuthenticated) {
          setState(() {
            _isSending = false;
            _statusMessage = 'Local node daemon offline. Use Web Beam below to share via browser.';
            _statusIsError = true;
          });
          return;
        }
        await client.initiateSend(
          targetPeerId: peerId,
          sourcePaths: outgoingPaths,
        );
        FileStagingService.instance.clear();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transfer started to $peerName'),
              backgroundColor: const Color(0xFF15803D),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _statusMessage = 'Send failed: $e';
          _statusIsError = true;
        });
      }
    }
  }

  void _openReceiveRadar(BuildContext parentContext) {
    Navigator.of(context).pop();
    ContextualShareSheet.showReceiveRadar(parentContext);
  }

  @override
  Widget build(BuildContext context) {
    final parentContext = context;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Container(
      key: const Key('contextual_share_sheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(
                    Icons.near_me_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share & Receive',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Wi-Fi Direct, browser, Quick Share & apps',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (PlatformCapabilities.isAndroid)
                  IconButton(
                    tooltip: 'Refresh nearby devices',
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      AndroidNodeBridge.instance.refreshDiscovery();
                    },
                  ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 1. Queued Files Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _paths.isEmpty ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              _paths.isEmpty ? Icons.attach_file_rounded : Icons.inventory_2_outlined,
                              size: 14,
                              color: _paths.isEmpty ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _paths.isEmpty
                                  ? 'No files selected yet'
                                  : '${_paths.length} item(s) ready to share',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        key: const Key('contextual_share_add_files'),
                        onPressed: _pickMoreFiles,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: _paths.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _paths.take(6).map((p) {
                                    final name = _basename(p);
                                    final visual = _fileChipVisual(name);
                                    return Container(
                                      padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: visual.bg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(visual.icon, size: 13, color: visual.color),
                                          ),
                                          const SizedBox(width: 6),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 130),
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() => _paths.remove(p));
                                              FileStagingService.instance.removePath(p);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (_paths.length > 6)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '+ ${_paths.length - 6} more file(s)',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                if (_hasScrubbableImages)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: InkWell(
                                      key: const Key('exif_scrubber_toggle'),
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => setState(() => _stripExifMetadata = !_stripExifMetadata),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: _stripExifMetadata
                                              ? const Color(0xFFECFDF5)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _stripExifMetadata
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _stripExifMetadata
                                                  ? Icons.gpp_good_rounded
                                                  : Icons.location_off_outlined,
                                              size: 16,
                                              color: _stripExifMetadata
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _stripExifMetadata
                                                    ? 'GPS & EXIF Metadata Stripped Before Sending'
                                                    : 'Strip GPS & Camera Metadata (EXIF)',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: _stripExifMetadata
                                                      ? const Color(0xFF065F46)
                                                      : const Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _stripExifMetadata
                                                  ? Icons.check_box_rounded
                                                  : Icons.check_box_outline_blank_rounded,
                                              size: 18,
                                              color: _stripExifMetadata
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Inline Status Feedback (Animated)
            AnimatedSize(
              duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _statusMessage != null
                  ? Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusIsError ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _statusIsError ? const Color(0xFFFECACA) : const Color(0xFFDBEAFE),
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusIsError ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // 2. Nearby & Paired Devices (Direct P2P Send)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.devices_rounded, size: 15, color: Color(0xFF475569)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Nearby & Paired Devices',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    QrPairingSheet.show(
                      context,
                      deviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                      peerId: NodeIpcClient.instance.currentState.peerId ?? 'peer_local',
                      fingerprint: DeviceTrustService.instance.getLocalFingerprint('peer_local'),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 15),
                  label: const Text('Pair QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<PairedDevice>>(
              stream: DeviceTrustService.instance.devicesStream,
              initialData: DeviceTrustService.instance.devices,
              builder: (context, pairedSnap) {
                return StreamBuilder<List<DiscoveredPeer>>(
                  stream: AndroidNodeBridge.instance.discoveredPeersStream,
                  initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                  builder: (context, liveSnap) {
                    final paired = pairedSnap.data ?? [];
                    final live = liveSnap.data ?? [];

                    final targets = <({String id, String name, String sub, bool isPhone})>[];
                    final seen = <String>{};

                    for (final p in live) {
                      if (seen.add(p.peerId)) {
                        targets.add((
                          id: p.peerId,
                          name: p.name.isNotEmpty ? p.name : p.peerId,
                          sub: 'Nearby • ${p.host}',
                          isPhone: p.technology.contains('WIFI_DIRECT'),
                        ));
                      }
                    }
                    for (final d in paired) {
                      if (seen.add(d.id)) {
                        targets.add((
                          id: d.id,
                          name: d.name,
                          sub: d.isOnline ? 'Trusted • Online' : 'Trusted • ${d.lastSeen}',
                          isPhone: d.deviceType == 'phone',
                        ));
                      }
                    }

                    if (targets.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.devices_other_rounded, size: 18, color: Color(0xFF64748B)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No nearby PeerLink devices yet — pair with QR or use Web Beam below.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: targets.take(4).map((t) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: const Color(0xFFDBEAFE)),
                                  ),
                                  child: Icon(
                                    t.isPhone ? Icons.smartphone_rounded : Icons.laptop_windows_rounded,
                                    color: const Color(0xFF2563EB),
                                    size: 19,
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              t.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              t.sub,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: FilledButton(
                              onPressed: _isSending ? null : () => _sendToPeer(t.id, t.name),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              ),
                              child: const Text('Send', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // 3. Instant Sharing Channels (2x2 Flat Light Semantic Grid — All Real On-Device)
            const Row(
              children: [
                Icon(Icons.hub_outlined, size: 15, color: Color(0xFF475569)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Instant Share Channels',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ShareChannelTile(
                    key: const Key('contextual_channel_web_beam'),
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
                    iconBorder: const Color(0xFFDBEAFE),
                    title: 'Web Beam',
                    subtitle: 'Windows & browser QR',
                    onTap: () {
                      final pathsCopy = List<String>.from(_paths);
                      Navigator.of(context).pop();
                      WebBeamModal.showLive(
                        parentContext,
                        initialPaths: pathsCopy,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ShareChannelTile(
                    key: const Key('contextual_channel_receive'),
                    icon: Icons.sensors_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    iconBorder: const Color(0xFFA7F3D0),
                    title: 'Receive Files',
                    subtitle: 'Open Wi-Fi radar',
                    onTap: () => _openReceiveRadar(parentContext),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ShareChannelTile(
                    key: const Key('contextual_channel_hotspot'),
                    icon: Icons.wifi_tethering_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFFFBEB),
                    iconBorder: const Color(0xFFFDE68A),
                    title: 'Direct Hotspot',
                    subtitle: 'Offline phone-to-phone',
                    onTap: () {
                      Navigator.of(context).pop();
                      LocalHotspotModal.show(parentContext);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ShareChannelTile(
                    key: const Key('contextual_channel_text'),
                    icon: Icons.link_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBg: const Color(0xFFF5F3FF),
                    iconBorder: const Color(0xFFDDD6FE),
                    title: 'Text & Links',
                    subtitle: 'Beam note or URL',
                    onTap: () {
                      Navigator.of(context).pop();
                      QuickTextShareModal.show(parentContext);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 4. Cross-App & OS Share Targets (Android Quick Share, Other Apps, Windows Share)
            const Row(
              children: [
                Icon(Icons.apps_rounded, size: 15, color: Color(0xFF475569)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Other Apps & System Share',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ShareChannelTile(
                    key: const Key('contextual_channel_quick_share'),
                    icon: Icons.near_me_rounded,
                    iconColor: const Color(0xFF0D9488),
                    iconBg: const Color(0xFFF0FDFA),
                    iconBorder: const Color(0xFF99F6E4),
                    title: PlatformCapabilities.isWindows ? 'Windows Share' : 'Quick Share',
                    subtitle: PlatformCapabilities.isWindows ? 'Open in Explorer' : 'Android / Windows PC',
                    onTap: () async {
                      if (_paths.isEmpty) {
                        setState(() {
                          _statusMessage = 'Pick at least one file above to share via Quick Share.';
                          _statusIsError = true;
                        });
                        return;
                      }
                      final pathsCopy = List<String>.from(_paths);
                      if (PlatformCapabilities.isAndroid) {
                        Navigator.of(context).pop();
                        await AndroidNodeBridge.instance.shareViaQuickShare(pathsCopy);
                      } else {
                        Navigator.of(context).pop();
                        await ReceivedFilesService.instance.revealInFolder(pathsCopy.first);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ShareChannelTile(
                    key: const Key('contextual_channel_other_apps'),
                    icon: Icons.share_rounded,
                    iconColor: const Color(0xFF334155),
                    iconBg: const Color(0xFFF1F5F9),
                    iconBorder: const Color(0xFFE2E8F0),
                    title: 'Other Apps',
                    subtitle: 'WhatsApp, Mail, Drive…',
                    onTap: () async {
                      if (_paths.isEmpty) {
                        setState(() {
                          _statusMessage = 'Pick at least one file above to share to other apps.';
                          _statusIsError = true;
                        });
                        return;
                      }
                      final pathsCopy = List<String>.from(_paths);
                      if (PlatformCapabilities.isAndroid) {
                        Navigator.of(context).pop();
                        await AndroidNodeBridge.instance.shareFiles(
                          pathsCopy,
                          title: 'Share ${pathsCopy.length} item(s) to app...',
                        );
                      } else {
                        Navigator.of(context).pop();
                        await ReceivedFilesService.instance.openFileWithDefaultApp(pathsCopy.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareChannelTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color iconBorder;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareChannelTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.iconBorder,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: iconBorder),
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
