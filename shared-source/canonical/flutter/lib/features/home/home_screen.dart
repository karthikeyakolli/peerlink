import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/file_staging_service.dart';
import '../../core/node_ipc_client.dart';
import '../../core/device_trust_service.dart';
import '../../core/operation_journal_service.dart';
import '../../core/quick_text_service.dart';
import '../../core/bluetooth_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';
import '../../design_system/components/send_receive_hero.dart';
import '../../design_system/components/transfer_speedometer.dart';
import '../../design_system/components/radar_sonar_view.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../design_system/components/quick_text_share_modal.dart';
import '../../design_system/components/bluetooth_share_modal.dart';
import '../../design_system/components/desktop_dropzone.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/local_hotspot_modal.dart';
import '../../design_system/components/quick_drop_peer_carousel.dart';
import '../../design_system/components/smart_clipboard_banner.dart';
import '../../core/smart_content_sniffer.dart';
import '../files/remote_scoped_browser_sheet.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int targetTabIndex)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<TextSnippetItem>? _incomingTextSub;
  StreamSubscription<BluetoothPayloadRecord>? _incomingBluetoothSub;
  String? _localAndroidPeerId;
  String? _localAndroidFingerprint;
  SmartContentResult? _activeClipboardContent;
  String? _lastDismissedClipboardText;

  @override
  void initState() {
    super.initState();
    _resolveAndroidIdentity();
    _checkAmbientClipboard();
    _incomingTextSub =
        QuickTextService.instance.incomingTextStream.listen((snippet) {
      if (mounted) {
        QuickTextShareModal.showIncomingText(
          context,
          senderName: snippet.peerName,
          text: snippet.text,
        );
      }
    });
    _incomingBluetoothSub =
        BluetoothService.instance.incomingPayloadStream.listen((payload) {
      if (mounted) {
        BluetoothShareModal.showIncomingPayload(
          context,
          payload: payload,
        );
      }
    });
  }

  @override
  void dispose() {
    _incomingTextSub?.cancel();
    _incomingBluetoothSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveAndroidIdentity() async {
    if (PlatformCapabilities.isAndroid) {
      final pid = await AndroidNodeBridge.instance.getLocalPeerId();
      final fp = await AndroidNodeBridge.instance.getFingerprint();
      if (mounted) {
        setState(() {
          if (pid != null && pid.isNotEmpty) _localAndroidPeerId = pid;
          if (fp != null && fp.isNotEmpty) _localAndroidFingerprint = fp;
        });
      }
    }
  }

  Future<void> _checkAmbientClipboard() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clip?.text?.trim();
      if (text != null && text.isNotEmpty && text != _lastDismissedClipboardText) {
        final sniffed = SmartContentSniffer.instance.sniff(text);
        if (mounted) {
          setState(() {
            _activeClipboardContent = sniffed;
          });
        }
      }
    } catch (_) {}
  }

  String get _effectivePeerId =>
      _localAndroidPeerId ??
      NodeIpcClient.instance.currentState.peerId ??
      (PlatformCapabilities.isAndroid ? 'peer_android_node' : 'peer_desktop_primary');

  Future<void> _handlePasteToSend(BuildContext context) async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipData?.text?.trim();
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }

    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim().replaceAll('"', '')).where((l) => l.isNotEmpty).toList();
    final existingPaths = lines.where((l) => File(l).existsSync() || Directory(l).existsSync()).toList();

    if (existingPaths.isNotEmpty) {
      FileStagingService.instance.addPaths(existingPaths);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${existingPaths.length} item(s) pasted from clipboard and staged!'),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'View Files',
              textColor: Colors.white,
              onPressed: () => widget.onNavigate?.call(2),
            ),
          ),
        );
      }
    } else {
      if (context.mounted) {
        QuickTextShareModal.show(context, initialText: text);
      }
    }
  }

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
                '• Direct P2P: Transfers travel directly between your laptop, desktop, and phone over local Wi-Fi or end-to-end encrypted relay without unencrypted storage on central servers.\n\n'
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

  void _showPeerActionSheet(RadarPeerInfo peer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: peer.isTrusted
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF2563EB).withValues(alpha: 0.15),
                  child: Icon(
                    peer.deviceType == 'phone'
                        ? Icons.phone_android_rounded
                        : Icons.laptop_rounded,
                    color: peer.isTrusted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'IP: ${peer.ip} • ${peer.technology} • ${peer.isTrusted ? "Trusted" : "Discovered"}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                DeviceTrustService.instance.setSelectedSendTarget(peer.id);
                widget.onNavigate?.call(2);
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                'Send Files to ${peer.name}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                QuickTextShareModal.show(context, initialPeerId: peer.id);
              },
              icon: const Icon(Icons.content_paste_go_rounded, size: 18),
              label: Text(
                'Send Text or Link to ${peer.name}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final paired = DeviceTrustService.instance.getDevice(peer.id) ??
                    PairedDevice(
                      id: peer.id,
                      name: peer.name,
                      deviceType: peer.deviceType,
                      fingerprint: DeviceTrustService.instance
                          .getLocalFingerprint(peer.id),
                      trustLevel: peer.isTrusted
                          ? DeviceTrustLevel.trustedPeer
                          : DeviceTrustLevel.temporaryGuest,
                      isOnline: true,
                    );
                RemoteScopedBrowserSheet.show(context, paired);
              },
              icon: const Icon(Icons.folder_shared_rounded, size: 18),
              label: Text(
                'Browse Shared Files on ${peer.name}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 8),
            if (!peer.isTrusted)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  DeviceTrustService.instance.pairDevice(
                    PairedDevice(
                      id: peer.id,
                      name: peer.name,
                      deviceType: peer.deviceType,
                      fingerprint: DeviceTrustService.instance
                          .getLocalFingerprint(peer.id),
                      trustLevel: DeviceTrustLevel.trustedPeer,
                      isOnline: true,
                      lastSeen: 'Direct Route (${peer.ip})',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Device "${peer.name}" is now paired and trusted!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user_rounded, size: 18),
                label: const Text('Trust & Pair Device'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReceiveModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final devices = DeviceTrustService.instance.devices;
    final localFingerprint = DeviceTrustService.instance.getLocalFingerprint(
      NodeIpcClient.instance.currentState.peerId,
    );

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
              Text(
                'Waiting to Receive',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Your device is visible to paired peers on local network',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<DiscoveredPeer>>(
                  stream: AndroidNodeBridge.instance.discoveredPeersStream,
                  initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                  builder: (context, snapshot) {
                    final livePeers = snapshot.data ?? [];
                    final List<RadarPeerInfo> peerInfos;
                    if (Platform.isAndroid) {
                      peerInfos = livePeers.map((p) {
                        final isTrusted = DeviceTrustService.instance.devices
                            .any((d) => d.id == p.peerId);
                        return RadarPeerInfo(
                          id: p.peerId,
                          name: p.name.isNotEmpty ? p.name : p.peerId,
                          deviceType: p.technology.contains('WIFI_DIRECT') ? 'phone' : 'desktop',
                          isTrusted: isTrusted,
                          ip: p.host,
                          technology: p.technology,
                          routeCount: p.routes.isNotEmpty ? p.routes.length : 1,
                        );
                      }).toList();
                    } else {
                      peerInfos = devices.map((d) => RadarPeerInfo(
                        id: d.id,
                        name: d.name,
                        deviceType: d.deviceType,
                        isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
                        ip: '127.0.0.1',
                        technology: 'Configured',
                        routeCount: 1,
                      )).toList();
                    }

                    return RadarSonarView(
                      localDeviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                      discoveredPeers: peerInfos,
                      onAddManualEndpoint: (ip, port, name) async {
                        final peerId = 'manual_${ip.replaceAll('.', '_')}';
                        final effectiveName = name.isNotEmpty ? name : 'Manual Endpoint ($ip)';
                        DeviceTrustService.instance.pairDevice(
                          PairedDevice(
                            id: peerId,
                            name: effectiveName,
                            deviceType: 'Manual',
                            fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                            trustLevel: DeviceTrustLevel.trustedPeer,
                            isOnline: true,
                            lastSeen: 'Direct IP Route ($ip:$port)',
                          ),
                        );
                        await AndroidNodeBridge.instance.addManualPeer(
                          peerId: peerId,
                          name: effectiveName,
                          host: ip,
                          port: port,
                        );
                        await AndroidNodeBridge.instance.addTrustedPeer(
                          peerId: peerId,
                          fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                          name: effectiveName,
                          host: ip,
                          port: port,
                        );
                      },
                      onPeerSelected: (peer) {
                        _showPeerActionSheet(peer);
                      },
                      onQrScanPressed: () {
                        QrPairingSheet.show(
                          context,
                          deviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                          peerId: _effectivePeerId,
                          fingerprint: _localAndroidFingerprint ?? localFingerprint,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localFingerprint = DeviceTrustService.instance.getLocalFingerprint(
      NodeIpcClient.instance.currentState.peerId,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('PeerLink'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search & Query',
            onPressed: () => widget.onNavigate?.call(5),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Security',
            onPressed: () => widget.onNavigate?.call(6),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Show Pairing QR',
            onPressed: () {
              QrPairingSheet.show(
                context,
                deviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                peerId: _effectivePeerId,
                fingerprint: _localAndroidFingerprint ?? localFingerprint,
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More Options',
            onSelected: (val) {
              if (val == 'hotspot') {
                LocalHotspotModal.show(context);
              } else if (val == 'text') {
                QuickTextShareModal.show(context);
              } else if (val == 'settings') {
                widget.onNavigate?.call(6);
              } else if (val == 'about') {
                _showOnboardingOverview(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'hotspot',
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Direct Hotspot (AP Bypass)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'text',
                child: Row(
                  children: [
                    Icon(Icons.content_paste_go_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Quick Text & Link Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Settings & Appearance'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('About PeerLink Guide'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () => _handlePasteToSend(context),
        },
        child: Focus(
          autofocus: true,
          child: DesktopDropzone(
            onFilesDropped: (paths) {
              FileStagingService.instance.addPaths(paths);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${paths.length} file(s) staged. Ready to send!'),
                  backgroundColor: const Color(0xFF10B981),
                  action: SnackBarAction(
                    label: 'View Files',
                    textColor: Colors.white,
                    onPressed: () => widget.onNavigate?.call(2),
                  ),
                ),
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Primary Bilateral Hero: SEND / RECEIVE
                  if (PlatformCapabilities.isAndroid)
                    StreamBuilder<NodeLifecycleStateEnum>(
                      stream: AndroidNodeBridge.instance.lifecycleStream,
                      initialData: NodeLifecycleStateEnum.ready,
                      builder: (context, snapshot) {
                        final state = snapshot.data ?? NodeLifecycleStateEnum.ready;
                        final isOnline = state.isOperational;
                        final deviceCount = DeviceTrustService.instance.devices.length;
                        return SendReceiveHero(
                          onSendPressed: () => widget.onNavigate?.call(2), // Files tab
                          onReceivePressed: () => _showReceiveModal(context),
                          discoveredPeersCount: deviceCount,
                          isNodeOnline: isOnline,
                        );
                      },
                    )
                  else
                    StreamBuilder<IpcConnectionState>(
                      stream: NodeIpcClient.instance.stateStream,
                      initialData: NodeIpcClient.instance.currentState,
                      builder: (context, snapshot) {
                        final isOnline = snapshot.data?.status == IpcConnectionStatus.connected;
                        final deviceCount = DeviceTrustService.instance.devices.length;
                        return SendReceiveHero(
                          onSendPressed: () => widget.onNavigate?.call(2), // Files tab
                          onReceivePressed: () => _showReceiveModal(context),
                          discoveredPeersCount: deviceCount,
                          isNodeOnline: isOnline,
                        );
                      },
                    ),
                  const SizedBox(height: 12),

                  // 1.2 Live Active Transfer Speedometer & Wi-Fi Diagnostic Bar
                  StreamBuilder<List<JournalOperation>>(
                    stream: OperationJournalService.instance.operationsStream,
                    initialData: OperationJournalService.instance.operations,
                    builder: (context, snapshot) {
                      final ops = snapshot.data ?? [];
                      final active = ops.where((op) => !op.isTerminal && op.state != JournalOperationState.outcomeUnknown).toList();
                      if (active.isEmpty) return const SizedBox.shrink();

                      final currentOp = active.first;
                      final elapsedSec = (DateTime.now().difference(currentOp.timestamp).inMilliseconds / 1000.0).clamp(0.1, 86400.0);
                      final dynamicSpeedMb = (currentOp.bytesTransferred / (1024 * 1024)) / elapsedSec;
                      final progress = currentOp.totalBytes > 0
                          ? (currentOp.bytesTransferred / currentOp.totalBytes).clamp(0.0, 1.0)
                          : 0.0;
                      final remainingBytes = currentOp.totalBytes - currentOp.bytesTransferred;
                      final etaSeconds = (dynamicSpeedMb > 0 && remainingBytes > 0)
                          ? (remainingBytes / (1024 * 1024) / dynamicSpeedMb).round()
                          : 0;
                      final is5G = dynamicSpeedMb >= 15.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TransferSpeedometer(
                          key: const Key('home_active_transfer_speedometer'),
                          fileName: currentOp.summary,
                          currentItemIndex: 1,
                          totalItems: active.length,
                          currentFileProgress: progress,
                          totalBatchProgress: progress,
                          speedMbps: dynamicSpeedMb,
                          etaSeconds: etaSeconds,
                          peerName: currentOp.peerId,
                          isSender: currentOp.type == OperationType.send,
                          networkRouteInfo: is5G ? 'Wi-Fi Direct (5 GHz)' : 'Direct Link (2.4 GHz)',
                          performanceAdvice: is5G
                              ? null
                              : 'Using 2.4 GHz band. Switch to 5 GHz or Direct Hotspot for maximum speed.',
                          onCancel: () {
                            OperationJournalService.instance.updateState(
                              currentOp.operationId,
                              JournalOperationState.cancelled,
                              note: 'Cancelled by user from Home live transfer card',
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // Quick Actions Bar (Send Text / Link, Paste to Send, Pair Device, Hotspot)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.content_paste_go_rounded, size: 16, color: theme.colorScheme.primary),
                        label: const Text('Send Text / Link', style: TextStyle(fontSize: 12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.0),
                        backgroundColor: theme.colorScheme.surface,
                        onPressed: () => QuickTextShareModal.show(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.paste_rounded, size: 16, color: theme.colorScheme.primary),
                        label: const Text('Paste to Send', style: TextStyle(fontSize: 12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.0),
                        backgroundColor: theme.colorScheme.surface,
                        onPressed: () => _handlePasteToSend(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.qr_code_scanner_rounded, size: 16, color: theme.colorScheme.primary),
                        label: const Text('Pair Device', style: TextStyle(fontSize: 12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.0),
                        backgroundColor: theme.colorScheme.surface,
                        onPressed: () => QrPairingSheet.show(
                          context,
                          deviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                          peerId: _effectivePeerId,
                          fingerprint: _localAndroidFingerprint ?? localFingerprint,
                        ),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.bluetooth_searching_rounded, size: 16, color: theme.colorScheme.primary),
                        label: const Text('Bluetooth Beam', style: TextStyle(fontSize: 12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.0),
                        backgroundColor: theme.colorScheme.surface,
                        onPressed: () => BluetoothShareModal.show(context),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.wifi_tethering_rounded, size: 16, color: theme.colorScheme.primary),
                        label: const Text('Direct Hotspot', style: TextStyle(fontSize: 12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.0),
                        backgroundColor: theme.colorScheme.surface,
                        onPressed: () => LocalHotspotModal.show(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Nearby Quick-Drop Carousel (Ambient Proximity Deck when files are staged)
                  StreamBuilder<List<StagedFileItem>>(
                    stream: FileStagingService.instance.stagedFilesStream,
                    initialData: FileStagingService.instance.stagedFiles,
                    builder: (context, stagingSnapshot) {
                      final hasStaged = (stagingSnapshot.data ?? []).any((f) => f.selected);
                      if (!hasStaged) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          QuickDropPeerCarousel(
                            onPeerTapped: (peer) {
                              _showPeerActionSheet(RadarPeerInfo(
                                id: peer.id,
                                name: peer.name,
                                deviceType: peer.deviceType,
                                isTrusted: peer.isTrusted,
                                ip: peer.ip ?? '127.0.0.1',
                                technology: peer.technology ?? 'Direct Route',
                                routeCount: 1,
                              ));
                            },
                            onQuickDrop: (peer) {
                              DeviceTrustService.instance.setSelectedSendTarget(peer.id);
                              widget.onNavigate?.call(2);
                            },
                            onPairQrPressed: () => QrPairingSheet.show(
                              context,
                              deviceName: Platform.isAndroid ? 'Android Peer' : 'Desktop PC',
                              peerId: _effectivePeerId,
                              fingerprint: _localAndroidFingerprint ?? localFingerprint,
                            ),
                            onManageDevicesPressed: () => widget.onNavigate?.call(1),
                          ),
                          const SizedBox(height: 18),
                        ],
                      );
                    },
                  ),

                  // Smart Clipboard Auto-Beam Banner
                  if (_activeClipboardContent != null) ...[
                    SmartClipboardBanner(
                      content: _activeClipboardContent!,
                      targetPeerName: DeviceTrustService.instance.devices.isNotEmpty
                          ? DeviceTrustService.instance.devices.first.name
                          : null,
                      onBeam: () {
                        final text = _activeClipboardContent!.rawText;
                        final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim().replaceAll('"', '')).where((l) => l.isNotEmpty).toList();
                        final existingPaths = lines.where((l) => File(l).existsSync() || Directory(l).existsSync()).toList();
                        if (existingPaths.isNotEmpty) {
                          FileStagingService.instance.addPaths(existingPaths);
                          widget.onNavigate?.call(2);
                        } else {
                          QuickTextShareModal.show(context, initialText: text);
                        }
                        setState(() {
                          _lastDismissedClipboardText = text;
                          _activeClipboardContent = null;
                        });
                      },
                      onDismiss: () {
                        setState(() {
                          _lastDismissedClipboardText = _activeClipboardContent?.rawText;
                          _activeClipboardContent = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 2. Nearby & Paired Devices (Simple & Truthful)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Nearby & Paired Devices',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.onNavigate?.call(1), // Devices tab
                    icon: const Icon(Icons.phonelink_ring_rounded, size: 16),
                    label: const Text('Manage'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<PairedDevice>>(
                stream: DeviceTrustService.instance.devicesStream,
                initialData: DeviceTrustService.instance.devices,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? [];
                  if (devices.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.devices_other_rounded, size: 36, color: theme.disabledColor),
                          const SizedBox(height: 8),
                          const Text(
                            'No paired devices yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pair with your phone or computer to transfer files securely.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => widget.onNavigate?.call(1), // Devices tab
                            icon: const Icon(Icons.add_link_rounded, size: 16),
                            label: const Text('Pair a Device'),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: devices.take(3).map((device) {
                      final isTrusted = device.trustLevel == DeviceTrustLevel.trustedPeer;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: (device.isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                            child: Icon(
                              device.deviceType == 'phone' ? Icons.smartphone_rounded : Icons.laptop_rounded,
                              color: device.isOnline ? Colors.green : Colors.grey,
                              size: 18,
                            ),
                          ),
                          title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                          subtitle: Text(
                            device.isOnline
                                ? 'Online • ${isTrusted ? "Trusted Peer" : "Guest"}'
                                : 'Offline • Last seen: ${device.lastSeen}',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: () => widget.onNavigate?.call(2), // Files tab
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Send Files', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 3. Recent Transfers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent Transfers',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.onNavigate?.call(3), // Activity tab
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<JournalOperation>>(
                stream: OperationJournalService.instance.operationsStream,
                initialData: OperationJournalService.instance.operations,
                builder: (context, snapshot) {
                  final ops = snapshot.data ?? [];
                  if (ops.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 32, color: theme.disabledColor),
                          const SizedBox(height: 6),
                          const Text(
                            'No recent transfers',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transferred files and sync events will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: ops.take(3).map((op) {
                      Color statusColor;
                      IconData statusIcon;
                      if (op.state == JournalOperationState.committed) {
                        statusColor = const Color(0xFF10B981);
                        statusIcon = Icons.check_circle_outline_rounded;
                      } else if (op.state == JournalOperationState.failed) {
                        statusColor = const Color(0xFFEF4444);
                        statusIcon = Icons.error_outline_rounded;
                      } else {
                        statusColor = const Color(0xFF3B82F6);
                        statusIcon = Icons.sync_rounded;
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: statusColor.withValues(alpha: 0.15),
                            child: Icon(statusIcon, color: statusColor, size: 18),
                          ),
                          title: Text(op.summary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                          subtitle: Text(
                            '${op.type.name.toUpperCase()} • ${op.state.name}',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          trailing: Text(
                            '${(op.bytesTransferred / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 4. Distributed Storage Modes
              Text(
                'Distributed Storage Modes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildIntentCard(
                    context,
                    title: 'SEND',
                    description: 'One-time direct copy',
                    icon: Icons.send_rounded,
                    color: Colors.blueAccent,
                    onTap: () => widget.onNavigate?.call(2), // Files tab
                  ),
                  const SizedBox(width: 10),
                  _buildIntentCard(
                    context,
                    title: 'ACCESS',
                    description: 'On-demand browsing',
                    icon: Icons.folder_shared_rounded,
                    color: Colors.teal,
                    onTap: () => widget.onNavigate?.call(1), // Devices tab
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildIntentCard(
                    context,
                    title: 'SYNC',
                    description: 'Convergent replicas',
                    icon: Icons.sync_rounded,
                    color: Colors.amber.shade800,
                    onTap: () => widget.onNavigate?.call(4), // Spaces tab
                  ),
                  const SizedBox(width: 10),
                  _buildIntentCard(
                    context,
                    title: 'BACKUP',
                    description: 'Versioned preservation',
                    icon: Icons.history_rounded,
                    color: Colors.deepPurpleAccent,
                    onTap: () => widget.onNavigate?.call(4), // Spaces tab
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      child: GlassContainer(
        glowColor: null, // Minimal, clean, non-glowing
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
