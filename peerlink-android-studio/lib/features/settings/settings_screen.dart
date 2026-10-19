import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/device_trust_service.dart';
import '../../core/node_ipc_client.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';
import '../../platform/platform_capabilities.dart';
import '../../platform/android_node_bridge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedLimitBps = 0; // 0 = unlimited
  bool _isRestarting = false;
  NodeLifecycleStateEnum _androidLifecycle = NodeLifecycleStateEnum.ready;
  StreamSubscription<NodeLifecycleStateEnum>? _androidLifecycleSub;

  bool get _isAndroid => PlatformCapabilities.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_isAndroid) {
      _loadAndroidNodeState();
      _androidLifecycleSub =
          AndroidNodeBridge.instance.lifecycleStream.listen((state) {
        if (mounted) setState(() => _androidLifecycle = state);
      });
    }
  }

  Future<void> _loadAndroidNodeState() async {
    try {
      final state = await AndroidNodeBridge.instance.getLifecycleState();
      if (mounted) {
        setState(() => _androidLifecycle = state);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _androidLifecycleSub?.cancel();
    super.dispose();
  }

  final Map<int, String> _bandwidthOptions = {
    0: 'Unlimited (Maximum Line Speed)',
    5242880: '5 MB/s (Low Background)',
    10485760: '10 MB/s (Standard)',
    26214400: '25 MB/s (High Speed)',
    52428800: '50 MB/s (Very High Speed)',
  };

  Future<void> _applyBandwidthLimit() async {
    if (_isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedLimitBps == 0
                ? 'Unlimited line speed active on Android.'
                : 'Bandwidth throttling is enforced on Desktop daemon only. Android utilizes adaptive OS transmission rate.'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
      return;
    }

    final client = NodeIpcClient.instance;
    if (!client.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot apply bandwidth limit: Local Node daemon is disconnected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final res = await client.setBandwidthLimit(_selectedLimitBps);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Bandwidth limit applied: ${_bandwidthOptions[_selectedLimitBps]!}'
                : 'Bandwidth limit rejected by Local Node daemon.'),
            backgroundColor: res.accepted ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set bandwidth limit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restartDaemon() async {
    setState(() => _isRestarting = true);

    if (_isAndroid) {
      try {
        final state = await AndroidNodeBridge.instance.startNode();
        if (mounted) {
          setState(() {
            _androidLifecycle = state;
            _isRestarting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Android native node active (${state.name.toUpperCase()}).'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRestarting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restart error: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    final client = NodeIpcClient.instance;

    if (!client.isAuthenticated) {
      setState(() => _isRestarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local Node daemon is already disconnected.'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    try {
      final success = await client.restartNode();
      if (mounted) {
        setState(() => _isRestarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Node restart command accepted by daemon.'
                : 'Restart command failed or rejected.'),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restart error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Zero-Trust Safety'),
      ),
      body: StreamBuilder<IpcConnectionState>(
        stream: NodeIpcClient.instance.stateStream,
        initialData: NodeIpcClient.instance.currentState,
        builder: (context, snapshot) {
          final ipc = snapshot.data ?? NodeIpcClient.instance.currentState;
          final isConnected = _isAndroid
              ? _androidLifecycle.isOperational
              : (ipc.status == IpcConnectionStatus.connected);
          final statusSubtitle = _isAndroid
              ? (isConnected
                  ? 'EMBEDDED RUNTIME ACTIVE (${_androidLifecycle.name.toUpperCase()})'
                  : 'EMBEDDED NODE STOPPED')
              : (isConnected ? 'AUTHORITATIVE RUNTIME ACTIVE' : 'DAEMON OFFLINE');
          final portText =
              _isAndroid ? 'IN-PROCESS' : (isConnected ? '50051 TLS' : 'N/A');
          final versionText =
              _isAndroid ? '1.0.0-android' : (ipc.nodeVersion ?? '1.0.0');
          final heartbeatsText = _isAndroid
              ? (isConnected ? 'ACTIVE' : '0')
              : '${ipc.activeHeartbeatCount}';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // Security Invariant Attestation Header
              GlassContainer(
                glowColor: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded,
                              color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Zero-Trust Invariant Enforcement',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All cryptographic keys, certificates, and transfer staging files are stored exclusively on local storage. No central server has access to private files.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Trust & Devices Summary Card
              InteractiveGlassCard(
                glowColor: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Color(0xFF8B5CF6), size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trust & Devices',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${DeviceTrustService.instance.devices.length} authoritative peer identity keys stored locally.',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Verified Live Status Indicator Card
              GlassContainer(
                glowColor: isConnected ? const Color(0xFF10B981) : Colors.amber,
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isConnected ? const Color(0xFF10B981) : Colors.amber)
                                      .withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isConnected ? Icons.verified_user_rounded : Icons.sensors_off_rounded,
                                  color: isConnected ? const Color(0xFF10B981) : Colors.amber,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAndroid
                                          ? 'Local Node Daemon Status (Embedded)'
                                          : 'Local Node Daemon Status',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      statusSubtitle,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isConnected ? const Color(0xFF10B981) : Colors.amber,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _isRestarting ? null : _restartDaemon,
                          icon: _isRestarting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Restart Node'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricColumn('PORT', portText, theme),
                          _buildMetricColumn('VERSION', versionText, theme),
                          _buildMetricColumn('HEARTBEATS', heartbeatsText, theme),
                          _buildMetricColumn('TRUST STORE', '${DeviceTrustService.instance.devices.length} Peers', theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Active Bandwidth Enforcement
              InteractiveGlassCard(
                glowColor: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Transfer Bandwidth Limit',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isAndroid
                          ? 'Transfer bandwidth throttling ceiling is enforced on Desktop daemon sockets. On Android, transfers use dynamic OS-managed Wi-Fi / Wi-Fi Direct line speed.'
                          : 'Enforce a strict throttling ceiling on outbound and inbound data transfer. Applied directly to the daemon socket engine.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedLimitBps,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _bandwidthOptions.entries.map((e) {
                        return DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLimitBps = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _applyBandwidthLimit,
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Apply Bandwidth Limit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Antimalware Safety Invariants
              InteractiveGlassCard(
                glowColor: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Safety & Antimalware',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Executable files (.exe, .bat, .cmd, .ps1, .sh) are held in quarantine and will never be automatically launched or written to primary library folders.\n'
                      '• Decompression bombs and malicious signatures trigger immediate staging purge.\n'
                      '• Scanner availability is checked per-transfer; offline scanners are never assumed to be clean.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Deferred Features Notice (Complying with Product Scope Decision)
              GlassContainer(
                glowColor: Colors.blueGrey,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Experimental tools (Web Beam browser relays, Burn-After-Read ephemeral destruction, Hotspot P2P direct fallback) are deferred pending complete cryptographic and multi-platform runtime verification.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
