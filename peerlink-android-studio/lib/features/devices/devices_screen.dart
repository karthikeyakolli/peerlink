import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/node_ipc_client.dart';
import '../../core/device_trust_service.dart';
import '../../core/pairing_invitation.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';
import '../files/remote_scoped_browser_sheet.dart';
import '../../design_system/components/contextual_share_sheet.dart';
import '../../design_system/components/local_hotspot_modal.dart';
import '../../design_system/components/remote_stream_browser_sheet.dart';
import '../../design_system/components/universal_clipboard_sheet.dart';
import '../../design_system/components/webdav_status_sheet.dart';
import '../../design_system/components/peer_room_sheet.dart';
import '../../design_system/components/remote_presentation_sheet.dart';
import '../../design_system/components/lan_benchmark_sheet.dart';
import '../../core/usb_turbo_mode_service.dart';

export '../../core/device_trust_service.dart' show PairedDevice, DeviceTrustLevel;

class DevicesScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const DevicesScreen({super.key, this.onNavigate});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final NodeIpcClient _client = NodeIpcClient.instance;
  String? _androidPeerId;
  String? _androidFingerprint;

  @override
  void initState() {
    super.initState();
    if (PlatformCapabilities.isAndroid) {
      _loadAndroidIdentity();
    }
  }

  Future<void> _loadAndroidIdentity() async {
    try {
      final pid = await AndroidNodeBridge.instance.getLocalPeerId();
      final fp = await AndroidNodeBridge.instance.getFingerprint();
      if (mounted) {
        setState(() {
          _androidPeerId = pid;
          _androidFingerprint = fp;
        });
      }
    } catch (_) {}
  }

  void _showPairDeviceDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    DeviceTrustLevel selectedTrustLevel = DeviceTrustLevel.trustedPeer;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Pair New Device', overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded, color: Colors.blue),
                tooltip: 'Scan Device QR Code',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  QrPairingSheet.show(
                    context,
                    deviceName: PlatformCapabilities.isAndroid ? 'Android Peer' : 'Desktop PC',
                    peerId: _androidPeerId ?? _client.currentState.peerId ?? 'peer_node_local',
                    fingerprint: _androidFingerprint ?? 'ed25519:peerlink...node',
                    onQrScanned: (payload) {
                      String scannedId = payload;
                      try {
                        final invitation = PairingInvitation.parse(payload);
                        scannedId = invitation.peerId;
                        if (invitation.name.isNotEmpty) {
                          nameController.text = invitation.name;
                        }
                      } catch (_) {}
                      setDialogState(() {
                        idController.text = scannedId;
                      });
                    },
                  );
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PeerLink establishes direct, encrypted connections. Pair only with devices you physically own or directly control.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Remote Device ID or IP Address',
                    hintText: 'e.g. peer_charlie or 192.168.1.105',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Friendly Device Name',
                    hintText: 'e.g. Living Room Tablet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Trust Authorization Level:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                RadioGroup<DeviceTrustLevel>(
                  groupValue: selectedTrustLevel,
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedTrustLevel = val);
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<DeviceTrustLevel>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: DeviceTrustLevel.trustedPeer,
                        title: Text('Trusted Peer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Full bidirectional synchronization & transfer rights', style: TextStyle(fontSize: 11)),
                      ),
                      RadioListTile<DeviceTrustLevel>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: DeviceTrustLevel.temporaryGuest,
                        title: Text('Guest (Scoped)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('Restricted read-only access with consent prompt', style: TextStyle(fontSize: 11)),
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
            FilledButton.icon(
              onPressed: () {
                final targetId = idController.text.trim();
                final name = nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : (targetId.isNotEmpty ? targetId : 'New Paired Device');

                if (targetId.isNotEmpty) {
                  final fingerprint = DeviceTrustService.instance.getLocalFingerprint(targetId);
                  final isGuest = selectedTrustLevel == DeviceTrustLevel.temporaryGuest;

                  final isDiscovered = AndroidNodeBridge.instance.activeDiscoveredPeers
                      .any((p) => p.peerId == targetId || p.host == targetId);

                  DeviceTrustService.instance.pairDevice(
                    PairedDevice(
                      id: targetId,
                      name: name,
                      deviceType: 'Device',
                      fingerprint: fingerprint,
                      trustLevel: selectedTrustLevel,
                      isOnline: isDiscovered,
                      lastSeen: isDiscovered ? 'Discovered on local network' : 'Paired (Offline)',
                      scopedCapabilities: isGuest ? const ['READ'] : const ['READ', 'WRITE', 'SYNC'],
                    ),
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Device "$name" paired and trusted!'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Verify & Trust'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRevokeDialog(PairedDevice device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Revoke Device Trust?', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to revoke trust for "${device.name}" (${device.id})?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revocation Behavior:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Trust token is invalidated immediately in TrustStore.\n'
                    '• Any active session with this device will be disconnected.\n'
                    '• The device will be rejected if it attempts future transfers.',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
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
            child: const Text('Keep Device'),
          ),
          FilledButton(
            onPressed: () {
              DeviceTrustService.instance.revokeDevice(device.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device "${device.name}" trust revoked successfully.'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke Trust'),
          ),
        ],
      ),
    );
  }

  void _showRemoteAccessDialog(PairedDevice device) {
    if (!device.isOnline) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.grey),
              SizedBox(width: 8),
              Text('Device Offline'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${device.name} (${device.id}) is currently offline.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Device is currently offline or unreachable. Remote browsing is unavailable until this device comes online on the local network or established relay.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Device is online: show scoped remote access explorer (ACCESS Mode)
    RemoteScopedBrowserSheet.show(context, device);
  }

  void _showDirectIpConnectDialog() {
    final hostController = TextEditingController();
    final portController = TextEditingController(text: '8765');
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.lan_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(child: Text('Direct IP Connect', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bypass restricted Wi-Fi / blocked mDNS multicast by connecting straight to a peer\'s LAN IP address and port.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('direct_ip_host_field'),
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: 'Peer IP Address',
                  hintText: 'e.g. 192.168.1.50',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('direct_ip_port_field'),
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('direct_ip_name_field'),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Label (optional)',
                  hintText: 'e.g. Office Desktop',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            key: const Key('direct_ip_connect_submit_button'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              final host = hostController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 8765;
              if (host.isEmpty) return;
              final peerId = '$host:$port';
              final label = nameController.text.trim().isEmpty ? 'LAN Peer ($host)' : nameController.text.trim();
              DeviceTrustService.instance.pairDevice(
                PairedDevice(
                  id: peerId,
                  name: label,
                  deviceType: 'Desktop',
                  fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                  trustLevel: DeviceTrustLevel.trustedPeer,
                  isOnline: true,
                  lastSeen: 'Direct IP ($host:$port)',
                ),
                host: host,
                port: port,
              );
              DeviceTrustService.instance.togglePinDevice(peerId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pinned direct peer $label ($host:$port)'),
                  backgroundColor: const Color(0xFF15803D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Connect & Pin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = PlatformCapabilities.isAndroid;
    final myPeerId = isAndroid
        ? (_androidPeerId ?? 'android-node-initializing')
        : (_client.currentState.peerId ?? 'local-desktop-node');
    final localFingerprint = isAndroid && _androidFingerprint != null && _androidFingerprint!.isNotEmpty
        ? _androidFingerprint!
        : DeviceTrustService.instance.getLocalFingerprint(myPeerId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Trust', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering_rounded),
            tooltip: 'Direct Hotspot (AP Bypass)',
            onPressed: () => LocalHotspotModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Pair New Device',
            onPressed: _showPairDeviceDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<PairedDevice>>(
        stream: DeviceTrustService.instance.devicesStream,
        initialData: DeviceTrustService.instance.devices,
        builder: (context, snapshot) {
          final devices = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // Quick Connectivity & Productivity Strip (Compact 2-Row Grid)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_direct_ip_button',
                            label: 'Direct IP',
                            icon: Icons.lan_outlined,
                            color: const Color(0xFF2563EB),
                            onTap: _showDirectIpConnectDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_universal_clipboard_button',
                            label: 'Clipboard Sync',
                            icon: Icons.content_paste_go_rounded,
                            color: const Color(0xFF7C3AED),
                            onTap: () => UniversalClipboardSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_stream_folder_button',
                            label: 'Stream Folder',
                            icon: Icons.cast_connected_rounded,
                            color: const Color(0xFF059669),
                            onTap: () => RemoteStreamBrowserSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_webdav_mount_button',
                            label: 'WebDAV Drive',
                            icon: Icons.storage_rounded,
                            color: const Color(0xFF2563EB),
                            onTap: () => WebDavStatusSheet.show(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_peerroom_button',
                            label: 'PeerRoom Drop',
                            icon: Icons.groups_rounded,
                            color: const Color(0xFFD97706),
                            onTap: () => PeerRoomSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_remote_controller_button',
                            label: 'Remote Deck',
                            icon: Icons.cast_for_education_rounded,
                            color: const Color(0xFF4F46E5),
                            onTap: () => RemotePresentationSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            keyName: 'devices_lan_benchmark_button',
                            label: 'Speed Test',
                            icon: Icons.speed_rounded,
                            color: const Color(0xFF0284C7),
                            onTap: () => LanBenchmarkSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Paired Devices Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Paired Devices (${devices.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _showPairDeviceDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Pair Device'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Paired Devices List or Empty State
              if (devices.isEmpty)
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
                      Icon(Icons.devices_other_rounded, size: 40, color: theme.disabledColor),
                      const SizedBox(height: 12),
                      const Text(
                        'No paired devices yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pair your laptop, tablet, or phone to enable instant direct P2P transfers and remote access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showPairDeviceDialog,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('Pair a Device Now'),
                      ),
                    ],
                  ),
                )
              else
                ...DeviceTrustService.instance.sortedDevices.map((device) => _buildDeviceCard(context, device)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, PairedDevice device) {
    final theme = Theme.of(context);
    final isGuest = device.trustLevel == DeviceTrustLevel.temporaryGuest;
    final glow = isGuest ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final isPinned = DeviceTrustService.instance.isPinned(device.id);

    return InteractiveGlassCard(
      glowColor: null, // Minimal, clean, non-glowing
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: glow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  device.deviceType.toLowerCase() == 'phone'
                      ? Icons.smartphone_rounded
                      : (device.deviceType.toLowerCase() == 'tablet'
                          ? Icons.tablet_mac_rounded
                          : Icons.computer_rounded),
                  color: glow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.push_pin_rounded, size: 14, color: Colors.amber),
                        ],
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: glow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            device.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: glow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'ID: ${device.id} • ${device.lastSeen}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPinned ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isPinned ? Colors.amber : Colors.grey,
                  size: 20,
                ),
                tooltip: isPinned ? 'Unpin favorite' : 'Pin to top',
                onPressed: () {
                  setState(() {
                    DeviceTrustService.instance.togglePinDevice(device.id);
                  });
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: glow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: glow),
                ),
                child: Text(
                  isGuest ? 'GUEST SHARE' : 'TRUSTED PEER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: glow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    device.fingerprint,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  DeviceTrustService.instance.setSelectedSendTarget(device.id);
                  ContextualShareSheet.show(context);
                },
                icon: const Icon(Icons.send_rounded, size: 15),
                label: const Text('Send Files'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showRemoteAccessDialog(device),
                icon: const Icon(Icons.folder_shared_rounded, size: 15),
                label: const Text('Access / Browse'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showRevokeDialog(device),
                icon: const Icon(Icons.link_off_rounded, size: 15),
                label: const Text('Revoke Trust'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String keyName,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }
}
