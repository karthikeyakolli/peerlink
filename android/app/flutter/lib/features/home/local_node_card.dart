import 'package:flutter/material.dart';
import '../../core/app_constants.dart';
import '../../core/node_ipc_client.dart';

class LocalNodeCard extends StatefulWidget {
  final NodeIpcClient? client;

  const LocalNodeCard({super.key, this.client});

  @override
  State<LocalNodeCard> createState() => _LocalNodeCardState();
}

class _LocalNodeCardState extends State<LocalNodeCard> {
  late final NodeIpcClient _ipcClient;
  bool _ownsClient = false;
  final TextEditingController _tokenController =
      TextEditingController(text: 'dev-token-default');
  final TextEditingController _portController =
      TextEditingController(text: '50051');

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _ipcClient = widget.client!;
    } else {
      _ipcClient = NodeIpcClient();
      _ownsClient = true;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _portController.dispose();
    if (_ownsClient) {
      _ipcClient.dispose();
    }
    super.dispose();
  }

  Color _getStatusColor(IpcConnectionStatus status) {
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

  String _getStatusLabel(IpcConnectionStatus status) {
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

  void _handleConnect({String? versionOverride}) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<IpcConnectionState>(
      stream: _ipcClient.stateStream,
      initialData: _ipcClient.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? _ipcClient.currentState;
        final statusColor = _getStatusColor(state.status);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: statusColor.withValues(alpha: 0.3), width: 1.5),
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
                      child: Row(
                        children: [
                          Icon(Icons.developer_board_rounded,
                              color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Desktop Local Node IPC',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                            _getStatusLabel(state.status),
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
                          : () => _handleConnect(),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Connect'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          state.status == IpcConnectionStatus.disconnected
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
                      onPressed: () =>
                          _handleConnect(versionOverride: '2.0.0-incompatible'),
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

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
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
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
