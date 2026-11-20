import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ai_gateway_service.dart';
import '../../core/app_settings_service.dart';
import '../../core/device_trust_service.dart';
import '../../core/drop_zone_service.dart';
import '../../core/node_ipc_client.dart';
import '../../core/quarantine_service.dart';
import '../../core/feedback_sound_service.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../features/activity/quarantine_vault_sheet.dart';
import '../../platform/platform_capabilities.dart';
import '../../platform/android_node_bridge.dart';
import '../onboarding/first_run_permissions_screen.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(int targetTabIndex)? onNavigate;
  const SettingsScreen({super.key, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedLimitBps = 0; // 0 = unlimited
  bool _isRestarting = false;
  NodeLifecycleStateEnum _androidLifecycle = NodeLifecycleStateEnum.ready;
  StreamSubscription<NodeLifecycleStateEnum>? _androidLifecycleSub;
  StreamSubscription<void>? _settingsSub;
  StreamSubscription<List<QuarantinedItem>>? _quarantineSub;

  final AppSettingsService _settings = AppSettingsService.instance;

  bool get _isAndroid => PlatformCapabilities.isAndroid;
  bool get _isWindows => PlatformCapabilities.isWindows;

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

    _settingsSub = _settings.changeStream.listen((_) {
      if (mounted) setState(() {});
    });

    _quarantineSub = QuarantineService.instance.quarantinedStream.listen((_) {
      if (mounted) setState(() {});
    });
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
    _settingsSub?.cancel();
    _quarantineSub?.cancel();
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

  void _showChangeFolderDialog() {
    final controller = TextEditingController(text: _settings.saveLocation);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_open_rounded, size: 20),
            SizedBox(width: 8),
            Text('Change Save Folder', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter destination folder for received files:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: r'C:\Downloads\PeerLink',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newPath = controller.text.trim();
              if (newPath.isNotEmpty) {
                _settings.saveLocation = newPath;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Save location updated to: $newPath'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDeviceNameDialog() {
    final controller = TextEditingController(text: _settings.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, size: 20),
            SizedBox(width: 8),
            Text('Edit Device Name', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other devices will see this name during discovery and transfers:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'e.g. My Work Laptop',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _settings.deviceName = newName;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device name updated to: $newName'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPairingQrCode() async {
    final devName = _settings.deviceName;
    String effectivePeerId = NodeIpcClient.instance.currentState.peerId ?? 'peer_local_primary';
    if (PlatformCapabilities.isAndroid) {
      final pid = await AndroidNodeBridge.instance.getLocalPeerId();
      if (pid != null && pid.isNotEmpty) {
        effectivePeerId = pid;
      }
    }
    final fingerprint =
        DeviceTrustService.instance.getLocalFingerprint(effectivePeerId);
    if (!mounted) return;
    QrPairingSheet.show(
      context,
      deviceName: devName,
      peerId: effectivePeerId,
      fingerprint: fingerprint,
    );
  }

  void _clearTempFiles() {
    final clearedCount = _settings.clearTemporaryCache();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(clearedCount > 0
            ? 'Temporary cache cleared ($clearedCount items removed).'
            : 'Temporary cache is already clean.'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Zero-Trust Safety', overflow: TextOverflow.ellipsis),
        leading: widget.onNavigate != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Home',
                onPressed: () => widget.onNavigate!(0),
              )
            : null,
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

          final quarantinedCount = QuarantineService.instance.count;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // 1. Zero-Trust Invariant Enforcement Header
              GlassContainer(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded,
                              color: Color(0xFF2563EB), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Zero-Trust Invariant Enforcement',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All cryptographic keys and transfer payloads remain strictly on your device. Autonomous self-healing and zero-touch background sync active.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Trust & Devices Summary
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Live Daemon / Runtime Status
              GlassContainer(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 360;
                        final headerContent = Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isConnected
                                        ? const Color(0xFF10B981)
                                        : Colors.amber)
                                    .withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isConnected
                                    ? Icons.verified_user_rounded
                                    : Icons.sensors_off_rounded,
                                color: isConnected
                                    ? const Color(0xFF10B981)
                                    : Colors.amber,
                                size: 20,
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
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    statusSubtitle,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isConnected
                                          ? const Color(0xFF10B981)
                                          : Colors.amber,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final restartBtn = FilledButton.tonalIcon(
                          onPressed: _isRestarting ? null : _restartDaemon,
                          icon: _isRestarting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('Restart Node'),
                          style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              headerContent,
                              const SizedBox(height: 10),
                              restartBtn,
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: headerContent),
                            const SizedBox(width: 8),
                            restartBtn,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 360) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricColumn('PORT', portText, theme)),
                                    Expanded(child: _buildMetricColumn('VERSION', versionText, theme)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricColumn('HEARTBEATS', heartbeatsText, theme)),
                                    Expanded(child: _buildMetricColumn('TRUST STORE', '${DeviceTrustService.instance.devices.length} Peers', theme)),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricColumn('PORT', portText, theme),
                              _buildMetricColumn('VERSION', versionText, theme),
                              _buildMetricColumn('HEARTBEATS', heartbeatsText, theme),
                              _buildMetricColumn('TRUST STORE', '${DeviceTrustService.instance.devices.length} Peers', theme),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Section: Transfers & Speed
              _buildSectionHeader('Transfers & Speed', Icons.swap_horiz_rounded, theme),
              const SizedBox(height: 8),
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Transfer Bandwidth Limit',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isAndroid
                          ? 'Bandwidth limit is enforced on Desktop daemon sockets. Android utilizes dynamic Wi-Fi line speed.'
                          : 'Set a maximum transfer speed ceiling to keep Wi-Fi free for gaming or browsing.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _applyBandwidthLimit,
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Apply Bandwidth Limit'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    _buildToggleRow(
                      title: 'Auto-accept from trusted devices',
                      subtitle: 'Automatically receive files from verified paired devices without asking.',
                      value: _settings.autoAcceptFromTrusted,
                      onChanged: (val) => setState(() => _settings.autoAcceptFromTrusted = val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleRow(
                      title: 'Sound & Alerts',
                      subtitle: 'Play sound alerts when a transfer finishes or a pairing invitation arrives.',
                      value: _settings.soundNotifications,
                      onChanged: (val) => setState(() => _settings.soundNotifications = val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleRow(
                      title: 'Automated Background Sync',
                      subtitle: 'Silently sync paired folder spaces in the background when changes are detected.',
                      value: _settings.autoSyncEnabled,
                      onChanged: (val) => setState(() => _settings.autoSyncEnabled = val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleRow(
                      title: 'Drop-Zone Quick-Beam Watcher',
                      subtitle: 'Monitor a designated folder; files dropped inside are automatically staged or beamed.',
                      value: _settings.dropZoneEnabled,
                      onChanged: (val) {
                        setState(() => _settings.dropZoneEnabled = val);
                        if (val) {
                          DropZoneService.instance.configureDropZone(
                            SmartDropZoneConfig(
                              id: 'default_drop_zone',
                              folderPath: _settings.dropZonePath,
                              targetPeerId: _settings.dropZoneTargetPeerId,
                              autoDispatch: _settings.dropZoneAutoDispatch,
                              enabled: true,
                            ),
                          );
                          DropZoneService.instance.startWatcher();
                        } else {
                          DropZoneService.instance.stopWatcher();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Section: Safety & Antimalware (Blocked & Corrupted Files)
              _buildSectionHeader('Safety & Antimalware', Icons.shield_outlined, theme),
              const SizedBox(height: 8),
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          quarantinedCount > 0 ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                          color: quarantinedCount > 0 ? Colors.amber.shade700 : const Color(0xFF10B981),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quarantinedCount > 0
                                ? '$quarantinedCount blocked file${quarantinedCount == 1 ? '' : 's'} in quarantine'
                                : 'No blocked or corrupted files',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: quarantinedCount > 0 ? Colors.amber.shade800 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quarantinedCount > 0
                          ? 'Files with checksum errors, interrupted transfers, or unrecognized signatures are safely held in isolation.'
                          : 'PeerLink automatically holds corrupted or unverified files in isolation so your computer remains completely safe.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => QuarantineVaultSheet.show(context),
                          icon: const Icon(Icons.security_rounded, size: 16),
                          label: const Text('View Quarantine Vault'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        if (quarantinedCount > 0)
                          OutlinedButton.icon(
                            onPressed: () async {
                              await QuarantineService.instance.purgeAll();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All quarantined files permanently purged.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                            label: const Text('Purge All', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 6. Section: Where Files Are Saved (Downloads)
              _buildSectionHeader('Where Files Are Saved', Icons.folder_rounded, theme),
              const SizedBox(height: 8),
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Location',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _settings.saveLocation,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showChangeFolderDialog,
                          icon: const Icon(Icons.drive_file_move_rounded, size: 16),
                          label: const Text('Change Folder'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        if (_isWindows)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final opened = await _settings.openSaveLocation();
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open folder in Explorer.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Open in Explorer'),
                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        TextButton.icon(
                          onPressed: _clearTempFiles,
                          icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                          label: const Text('Clear Temp Files'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 7. Section: Device Identity (How others see you)
              _buildSectionHeader('Device Identity', Icons.badge_rounded, theme),
              const SizedBox(height: 8),
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Name',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _settings.deviceName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showEditDeviceNameDialog,
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _showPairingQrCode,
                          icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                          label: const Text('Show Pairing QR Code'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 8. Section: Platform-specific Startup & Background Controls
              if (_isWindows) ...[
                _buildSectionHeader('Windows Startup & Background', Icons.window_rounded, theme),
                const SizedBox(height: 8),
                InteractiveGlassCard(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildToggleRow(
                        title: 'Open on Windows Startup',
                        subtitle: 'Start PeerLink automatically when your computer turns on.',
                        value: _settings.startOnBoot,
                        onChanged: (val) => setState(() => _settings.startOnBoot = val),
                      ),
                      const SizedBox(height: 12),
                      _buildToggleRow(
                        title: 'Keep Running in Background',
                        subtitle: 'Closing the window minimizes PeerLink to the taskbar clock tray.',
                        value: _settings.minimizeToTray,
                        onChanged: (val) => setState(() => _settings.minimizeToTray = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isAndroid) ...[
                _buildSectionHeader('System Permissions & Readiness', Icons.security_update_good_rounded, theme),
                const SizedBox(height: 8),
                InteractiveGlassCard(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Android System Permissions',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review Android OS permission state, Scoped Storage access, Quick Settings tile, and Direct Share targets.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('Permissions & Readiness')),
                                  body: FirstRunPermissionsScreen(onComplete: () => Navigator.pop(context)),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('View Readiness'),
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Feedback & Chimes
              _buildSectionHeader('Feedback & Chimes', Icons.volume_up_rounded, theme),
              const SizedBox(height: 8),
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildToggleRow(
                      title: 'Tactile Chimes & Haptic Feedback',
                      subtitle: 'Plays subtle audio pings and vibrations when peers connect or transfers complete.',
                      value: _settings.soundNotifications,
                      onChanged: (val) {
                        setState(() => _settings.soundNotifications = val);
                        if (val) {
                          FeedbackSoundService.instance.playSelectionClick();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 9. Section: Non-Authoritative AI Gateway (Phase 15, Rule 11)
              _buildSectionHeader('AI Assistant & Gateway (Non-Authoritative)', Icons.auto_awesome_rounded, theme),
              const SizedBox(height: 8),
              InteractiveGlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggleRow(
                      title: 'Enable AI Smart Assistant',
                      subtitle: 'Formulates natural-language search suggestions, batch bundles, and explanations.',
                      value: _settings.aiAssistantEnabled,
                      onChanged: (val) => setState(() => _settings.aiAssistantEnabled = val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleRow(
                      title: '100% Offline Rule-Based Mode',
                      subtitle: 'Forces all assistance to run locally via deterministic logic without external cloud calls.',
                      value: _settings.aiOfflineOnly,
                      onChanged: (val) => setState(() => _settings.aiOfflineOnly = val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleRow(
                      title: 'Sensitive Metadata Disclosure',
                      subtitle: 'Disabled by default. When off, filenames, peer IDs, and paths are redacted before any model sees them.',
                      value: _settings.aiSensitiveDisclosureAuthorized,
                      onChanged: (val) => setState(() => _settings.aiSensitiveDisclosureAuthorized = val),
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_rounded, size: 20, color: Color(0xFF2563EB)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Rule 11 Enforced: AI has zero authority over identity, trust, encryption, sync truth, deletion, or execution. Every transfer proposal requires your explicit confirmation tap.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Audited Operations: ${AiGatewayService.instance.auditTrail.length} records',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('AI Audit Trail contains ${AiGatewayService.instance.auditTrail.length} verified operations.'),
                              ),
                            );
                          },
                          child: const Text('View Audit Log', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAutomatedFeatureBadge(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF15803D)),
        const SizedBox(width: 6),
        Text(
          '$title: ',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
        ),
        Expanded(
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
