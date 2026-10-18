import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_constants.dart';
import '../../core/node_ipc_client.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../platform/android_node_bridge.dart';

class LocalNodeCard extends StatefulWidget {
  final NodeIpcClient? client;
  final bool? forceAndroidMode;

  const LocalNodeCard({
    super.key,
    this.client,
    this.forceAndroidMode,
  });

  @override
  State<LocalNodeCard> createState() => _LocalNodeCardState();
}

class _LocalNodeCardState extends State<LocalNodeCard> {
  // Desktop IPC State
  late final NodeIpcClient _ipcClient;
  bool _ownsClient = false;
  final TextEditingController _tokenController =
      TextEditingController(text: 'dev-token-default');
  final TextEditingController _portController =
      TextEditingController(text: '50051');

  // Android Native Zero-Config State
  NodeLifecycleStateEnum _lifecycleState = NodeLifecycleStateEnum.starting;
  NodeCapabilities? _capabilities;
  String? _localPeerId;
  String? _fingerprint;
  String? _securityLevel;
  bool _showDiagnostics = false;
  bool _isActionInProgress = false;
  StreamSubscription<NodeLifecycleStateEnum>? _lifecycleSub;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;

  bool get _isAndroidMode =>
      widget.forceAndroidMode ?? PlatformCapabilities.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_isAndroidMode) {
      _initAndroidNode();
    } else {
      _initDesktopIpc();
    }
  }

  void _initDesktopIpc() {
    if (widget.client != null) {
      _ipcClient = widget.client!;
    } else {
      _ipcClient = NodeIpcClient();
      _ownsClient = true;
    }
  }

  Future<void> _initAndroidNode() async {
    setState(() => _isActionInProgress = true);
    try {
      // 1. Authoritative zero-config auto-startup
      _lifecycleState = await AndroidNodeBridge.instance.getLifecycleState();
      if (_lifecycleState == NodeLifecycleStateEnum.stopped ||
          _lifecycleState == NodeLifecycleStateEnum.unknown) {
        _lifecycleState = await AndroidNodeBridge.instance.startNode();
      }

      // 2. Fetch device identity and runtime capabilities
      final caps = await AndroidNodeBridge.instance.getNodeCapabilities();
      final peerId = await AndroidNodeBridge.instance.getLocalPeerId();
      final fp = await AndroidNodeBridge.instance.getFingerprint();
      final sec = await AndroidNodeBridge.instance.getSecurityLevel();

      if (mounted) {
        setState(() {
          _capabilities = caps;
          _localPeerId = peerId;
          _fingerprint = fp;
          _securityLevel = sec;
          _isActionInProgress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }

    // 3. Listen to reactive lifecycle updates
    _lifecycleSub = AndroidNodeBridge.instance.lifecycleStream.listen((state) {
      if (mounted) {
        setState(() => _lifecycleState = state);
        _refreshCapabilities();
      }
    });

    // 4. Listen to environmental / discovery events
    _eventSub = AndroidNodeBridge.instance.events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'nodeStateChanged' || type == 'permissionsChanged') {
        _refreshCapabilities();
      }
    });
  }

  Future<void> _refreshCapabilities() async {
    try {
      final caps = await AndroidNodeBridge.instance.getNodeCapabilities();
      final peerId = await AndroidNodeBridge.instance.getLocalPeerId();
      if (mounted) {
        setState(() {
          if (caps != null) _capabilities = caps;
          if (peerId != null) _localPeerId = peerId;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleAndroidRestart() async {
    setState(() => _isActionInProgress = true);
    try {
      await AndroidNodeBridge.instance.stopNode();
      await AndroidNodeBridge.instance.startNode();
      await _refreshCapabilities();
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _handleRequestPermissions() async {
    if (_capabilities == null || _capabilities!.missingPermissions.isEmpty) return;
    final missing = _capabilities!.missingPermissions;
    final keys = <String>[];
    for (final p in missing) {
      if (p.contains('Notification')) keys.add('notifications');
      if (p.contains('Nearby')) keys.add('nearby');
      if (p.contains('Camera')) keys.add('camera');
      if (p.contains('Network')) keys.add('localNetwork');
    }
    if (keys.isNotEmpty) {
      await AndroidNodeBridge.instance.requestPermissions(keys);
      await _refreshCapabilities();
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _portController.dispose();
    _lifecycleSub?.cancel();
    _eventSub?.cancel();
    if (_ownsClient) {
      _ipcClient.dispose();
    }
    super.dispose();
  }

  // --- Android UI Helpers ---

  Color _getAndroidStatusColor(NodeLifecycleStateEnum state) {
    switch (state) {
      case NodeLifecycleStateEnum.ready:
      case NodeLifecycleStateEnum.connected:
        return const Color(0xFF10B981); // Emerald Green
      case NodeLifecycleStateEnum.transferring:
        return const Color(0xFF3B82F6); // Blue
      case NodeLifecycleStateEnum.discovering:
      case NodeLifecycleStateEnum.recovering:
      case NodeLifecycleStateEnum.checkingCapabilities:
      case NodeLifecycleStateEnum.starting:
        return const Color(0xFFF59E0B); // Amber
      case NodeLifecycleStateEnum.degraded:
        return const Color(0xFFF97316); // Orange
      case NodeLifecycleStateEnum.unavailable:
        return const Color(0xFFEF4444); // Red
      case NodeLifecycleStateEnum.stopped:
      case NodeLifecycleStateEnum.stopping:
      case NodeLifecycleStateEnum.unknown:
        return const Color(0xFF6B7280); // Gray
    }
  }

  String _getAndroidStatusLabel(NodeLifecycleStateEnum state) {
    switch (state) {
      case NodeLifecycleStateEnum.ready:
        return 'READY (ONLINE)';
      case NodeLifecycleStateEnum.connected:
        return 'CONNECTED';
      case NodeLifecycleStateEnum.transferring:
        return 'TRANSFERRING';
      case NodeLifecycleStateEnum.discovering:
        return 'DISCOVERING PEERS';
      case NodeLifecycleStateEnum.recovering:
        return 'RECOVERING JOURNAL';
      case NodeLifecycleStateEnum.checkingCapabilities:
        return 'CHECKING CAPABILITIES';
      case NodeLifecycleStateEnum.starting:
        return 'STARTING NODE...';
      case NodeLifecycleStateEnum.degraded:
        return 'DEGRADED';
      case NodeLifecycleStateEnum.unavailable:
        return 'UNAVAILABLE';
      case NodeLifecycleStateEnum.stopping:
        return 'STOPPING...';
      case NodeLifecycleStateEnum.stopped:
        return 'STOPPED';
      case NodeLifecycleStateEnum.unknown:
        return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAndroidMode) {
      return _buildAndroidNativeCard(context);
    }
    return _buildDesktopIpcCard(context);
  }

  // --- Android Native Zero-Config Card ---
  Widget _buildAndroidNativeCard(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getAndroidStatusColor(_lifecycleState);
    final missingPerms = _capabilities?.missingPermissions ?? [];
    final activeListeners = _capabilities?.activeListeners ?? [];
    final usableTransports = _capabilities?.usableTransports ?? ['TCP_TLS', 'QUIC', 'WIFI_DIRECT'];
    final limitations = _capabilities?.backgroundTransferLimitations ?? 'Optimal Execution';
    final securityTier = _securityLevel ?? 'Ed25519 (Protected by Android Keystore)';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: statusColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.phonelink_ring_rounded,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Android Native Node',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Zero-Config Direct P2P',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getAndroidStatusLabel(_lifecycleState),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Missing Permissions Banner (Context-aware alert)
            if (missingPerms.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permissions Needed for Full Capability',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Missing: ${missingPerms.join(", ")}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _handleRequestPermissions,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Grant'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Peer Identity & Hardware Keystore Tier
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    label: 'Local Peer ID',
                    value: _localPeerId != null && _localPeerId!.isNotEmpty
                        ? _localPeerId!
                        : 'Authenticating...',
                    icon: Icons.fingerprint_rounded,
                    onTapValue: _localPeerId != null
                        ? () {
                            Clipboard.setData(ClipboardData(text: _localPeerId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied Peer ID to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    label: 'Keystore Security Tier',
                    value: securityTier,
                    icon: Icons.shield_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Active Listeners & OS Background Limits
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    label: 'Active Listeners',
                    value: activeListeners.isNotEmpty
                        ? activeListeners.join('\n')
                        : (_lifecycleState.isOperational
                            ? 'TCP://0.0.0.0:8765 (TLS/Ed25519)'
                            : 'None active'),
                    icon: Icons.radar_rounded,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    label: 'OS Background Mode',
                    value: limitations,
                    icon: Icons.battery_charging_full_rounded,
                  ),
                ),
              ],
            ),

            // Collapsible Technical Diagnostics
            if (_showDiagnostics) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              Text(
                'Technical Route Diagnostics',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Usable Transports: ${usableTransports.join(", ")}\n'
                '• Network Interfaces: ${(_capabilities?.availableNetworkInterfaces ?? []).join(", ").ifEmpty("wlan0 (active)")}\n'
                '• Fingerprint: ${_fingerprint ?? "Ed25519 (Authoritative)"}\n'
                '• Transfer Readiness: ${_capabilities?.canTransfer == true ? "Direct Stream Ready" : "Initializing"}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),

            // Actions Row (Zero configuration: only retry, refresh, or diagnostics toggle)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isActionInProgress ? null : _refreshCapabilities,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh Status'),
                ),
                OutlinedButton.icon(
                  onPressed: _isActionInProgress ? null : _handleAndroidRestart,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Restart Node'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showDiagnostics = !_showDiagnostics);
                  },
                  icon: Icon(
                    _showDiagnostics
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                  label: Text(_showDiagnostics ? 'Hide Details' : 'Show Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Desktop IPC Card (Preserved for Desktop backward compatibility) ---
  Widget _buildDesktopIpcCard(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<IpcConnectionState>(
      stream: _ipcClient.stateStream,
      initialData: _ipcClient.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _ipcClient.currentState;
        final statusColor = _getDesktopStatusColor(state.status);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.developer_board_rounded,
                            color: theme.colorScheme.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Desktop Local Node IPC',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getDesktopStatusLabel(state.status),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        label: 'Local Peer ID',
                        value: state.peerId ?? 'Not connected',
                        icon: Icons.fingerprint_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        label: 'Node / API Version',
                        value: state.nodeVersion != null
                            ? '${state.nodeVersion} (API v1)'
                            : 'Unknown',
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        label: 'Streaming Heartbeats',
                        value:
                            '${state.activeHeartbeatCount} received (seq: ${state.lastHeartbeat?.sequenceNumber ?? 0})',
                        icon: Icons.monitor_heart_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        context,
                        label: 'Node Memory / Uptime',
                        value: state.lastHeartbeat != null
                            ? '${(state.lastHeartbeat!.memoryUsedBytes.toInt() / (1024 * 1024)).toStringAsFixed(1)} MB / ${state.lastHeartbeat!.uptimeSeconds}s'
                            : 'N/A',
                        icon: Icons.memory_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Connection Parameters',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'IPC Auth Token',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: theme.textTheme.bodySmall,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: state.status == IpcConnectionStatus.connected
                          ? null
                          : () => _handleDesktopConnect(),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Connect'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.status == IpcConnectionStatus.disconnected
                          ? null
                          : () => _ipcClient.disconnect(),
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Disconnect'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.status == IpcConnectionStatus.connected
                          ? () => _ipcClient.getStatus()
                          : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Query Status'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.status == IpcConnectionStatus.connected
                          ? () => _ipcClient.restartNode()
                          : null,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Restart Node'),
                    ),
                    TextButton.icon(
                      onPressed: () => _handleDesktopConnect(
                          versionOverride: '2.0.0-incompatible'),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text('Test Incompatible Version'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleDesktopConnect({String? versionOverride}) {
    final port =
        int.tryParse(_portController.text) ?? AppConstants.defaultIpcPort;
    final token = _tokenController.text.trim();
    _ipcClient.connectAndAuthenticate(
      host: AppConstants.defaultIpcHost,
      port: port,
      localAuthToken: token,
      clientVersion: versionOverride ?? AppConstants.appVersion,
    );
  }

  Color _getDesktopStatusColor(IpcConnectionStatus status) {
    switch (status) {
      case IpcConnectionStatus.connected:
        return Colors.green;
      case IpcConnectionStatus.connecting:
      case IpcConnectionStatus.authenticating:
      case IpcConnectionStatus.reconnecting:
        return Colors.amber.shade700;
      case IpcConnectionStatus.incompatibleVersion:
        return Colors.orange.shade800;
      case IpcConnectionStatus.disconnected:
      case IpcConnectionStatus.error:
        return Colors.red.shade600;
    }
  }

  String _getDesktopStatusLabel(IpcConnectionStatus status) {
    switch (status) {
      case IpcConnectionStatus.connected:
        return 'CONNECTED (AUTHENTICATED)';
      case IpcConnectionStatus.connecting:
        return 'CONNECTING...';
      case IpcConnectionStatus.authenticating:
        return 'AUTHENTICATING...';
      case IpcConnectionStatus.reconnecting:
        return 'RECONNECTING...';
      case IpcConnectionStatus.incompatibleVersion:
        return 'INCOMPATIBLE VERSION';
      case IpcConnectionStatus.disconnected:
        return 'DISCONNECTED';
      case IpcConnectionStatus.error:
        return 'ERROR / UNREACHABLE';
    }
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTapValue,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              InkWell(
                onTap: onTapValue,
                child: Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
