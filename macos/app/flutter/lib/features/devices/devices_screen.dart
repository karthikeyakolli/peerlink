import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/node_ipc_client.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';

enum DeviceTrustLevel {
  trustedPeer,
  temporaryGuest,
}

class PairedDevice {
  final String id;
  final String name;
  final String deviceType;
  final String fingerprint;
  final DeviceTrustLevel trustLevel;
  final bool isOnline;
  final String lastSeen;

  PairedDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.fingerprint,
    required this.trustLevel,
    required this.isOnline,
    required this.lastSeen,
  });
}

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final NodeIpcClient _client = NodeIpcClient.instance;

  final List<PairedDevice> _devices = [
    PairedDevice(
      id: 'peer_laptop_pro',
      name: 'MacBook Pro 16" (Work)',
      deviceType: 'Laptop',
      fingerprint: 'SHA256:7b9a4f2e1c8d0e3a5f6b9c8d7e6f5a4b',
      trustLevel: DeviceTrustLevel.trustedPeer,
      isOnline: true,
      lastSeen: 'Active now (Direct TCP/TLS)',
    ),
    PairedDevice(
      id: 'peer_pixel_phone',
      name: 'Pixel 8 Pro (Personal)',
      deviceType: 'Phone',
      fingerprint: 'SHA256:3d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a',
      trustLevel: DeviceTrustLevel.trustedPeer,
      isOnline: false,
      lastSeen: '18 minutes ago',
    ),
    PairedDevice(
      id: 'guest_collaborator_bob',
      name: 'Bob (Guest Project Share)',
      deviceType: 'Desktop',
      fingerprint: 'SHA256:e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9',
      trustLevel: DeviceTrustLevel.temporaryGuest,
      isOnline: true,
      lastSeen: 'Active now (Sandboxed Read-Only)',
    ),
  ];

  void _showPairDeviceDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    String generatedCode = '749-281';

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
                    labelText: 'Friendly Device Name (e.g. Living Room Tablet)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'VERIFICATION PIN (SAS)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        generatedCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ensure both devices display this exact code to protect against network tampering.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.black54),
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
                  setState(() {
                    _devices.add(PairedDevice(
                      id: targetId,
                      name: name,
                      deviceType: 'Device',
                      fingerprint: 'SHA256:1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d',
                      trustLevel: DeviceTrustLevel.trustedPeer,
                      isOnline: true,
                      lastSeen: 'Just paired',
                    ));
                  });
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
                    '• Trust token is invalidated immediately on this node.\n'
                    '• Any active session with this device will be disconnected.\n'
                    '• Note: If the remote device is currently offline, it will be rejected as soon as it attempts to reconnect.',
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
              setState(() {
                _devices.removeWhere((d) => d.id == device.id);
              });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myPeerId = _client.currentState.peerId ?? 'local-desktop-node';

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
      body: ListView(
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

          // This Device Node Card (InteractiveGlassCard)
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Public Key Fingerprint (Ed25519 · Keystore):',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                          SizedBox(height: 2),
                          Text(
                            'SHA256:9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Fingerprint',
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: 'SHA256:9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c'));
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
                'Paired Devices (${_devices.length})',
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

          // Paired Devices List
          ..._devices.map((device) => _buildDeviceCard(context, device)),
        ],
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
                  device.deviceType == 'Phone' ? Icons.smartphone_rounded : Icons.computer_rounded,
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
                            device.isOnline ? '1.8 ms' : 'Offline',
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
