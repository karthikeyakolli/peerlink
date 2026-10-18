import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/node_ipc_client.dart';
import '../../core/device_trust_service.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

export '../../core/device_trust_service.dart' show PairedDevice, DeviceTrustLevel;

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final NodeIpcClient _client = NodeIpcClient.instance;

  void _showPairDeviceDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    DeviceTrustLevel selectedTrustLevel = DeviceTrustLevel.trustedPeer;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Pair New Device'),
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
                SegmentedButton<DeviceTrustLevel>(
                  segments: const [
                    ButtonSegment(
                      value: DeviceTrustLevel.trustedPeer,
                      label: Text('Trusted Peer'),
                      icon: Icon(Icons.verified_user_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: DeviceTrustLevel.temporaryGuest,
                      label: Text('Guest (Scoped)'),
                      icon: Icon(Icons.person_outline_rounded, size: 16),
                    ),
                  ],
                  selected: {selectedTrustLevel},
                  onSelectionChanged: (newSelection) {
                    setDialogState(() {
                      selectedTrustLevel = newSelection.first;
                    });
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
            FilledButton.icon(
              onPressed: () {
                final targetId = idController.text.trim();
                final name = nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : (targetId.isNotEmpty ? targetId : 'New Paired Device');

                if (targetId.isNotEmpty) {
                  final fingerprint = DeviceTrustService.instance.getLocalFingerprint(targetId);
                  final isGuest = selectedTrustLevel == DeviceTrustLevel.temporaryGuest;

                  DeviceTrustService.instance.pairDevice(
                    PairedDevice(
                      id: targetId,
                      name: name,
                      deviceType: 'Device',
                      fingerprint: fingerprint,
                      trustLevel: selectedTrustLevel,
                      isOnline: true,
                      lastSeen: 'Active now (Direct P2P)',
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
            const Text('Revoke Device Trust?'),
          ],
        ),
        content: Column(
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

    // Device is online: show scoped remote access viewer
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.folder_shared_rounded, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text('Remote Access: ${device.name}')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Authorized Scopes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                    const SizedBox(height: 4),
                    Text(
                      'Capabilities: ${device.scopedCapabilities.join(", ")}'
                      '\nTrust: ${device.trustLevel == DeviceTrustLevel.trustedPeer ? "Full Trusted Peer" : "Temporary Guest Share"}'
                      '\nSession: Active TLS Direct',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Available Remote Shares:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open_rounded, color: Colors.amber),
                title: const Text('Shared Documents', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('3 items · Scoped Read-Only'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Accessing "${device.name}" Shared Documents...'),
                      backgroundColor: Colors.teal,
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myPeerId = _client.currentState.peerId ?? 'local-desktop-node';
    final localFingerprint = DeviceTrustService.instance.getLocalFingerprint(myPeerId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Trust Management'),
        actions: [
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
              // Trust Explanation Glass Banner
              GlassContainer(
                glowColor: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Color(0xFF8B5CF6), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Direct Cryptographic Trust Model',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'PeerLink never relies on cloud authentication. Devices communicate using direct Ed25519 public keys without central servers.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // This Device Node Card
              InteractiveGlassCard(
                glowColor: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(22),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.laptop_windows_rounded,
                              color: Color(0xFF8B5CF6), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'This Device (Desktop Node)',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'ID: $myPeerId',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Text(
                            'THIS NODE',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Public Key Fingerprint (Ed25519 · Keystore):',
                                  style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                localFingerprint,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy Fingerprint',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: localFingerprint));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fingerprint copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paired Devices (${devices.length})',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
                ...devices.map((device) => _buildDeviceCard(context, device)),
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

    return InteractiveGlassCard(
      glowColor: glow,
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
                        Text(
                          device.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
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
                    ),
                  ],
                ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _showRemoteAccessDialog(device),
                icon: const Icon(Icons.folder_shared_rounded, size: 15),
                label: const Text('Access / Browse'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
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
}
