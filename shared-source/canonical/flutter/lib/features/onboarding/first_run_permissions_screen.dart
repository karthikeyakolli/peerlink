import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../platform/android_node_bridge.dart';
import '../../design_system/components/glass_container.dart';

class OnboardingPreferences {
  static Future<File> _getPrefsFile() async {
    String base;
    if (Platform.isAndroid) {
      final appStorage = await AndroidNodeBridge.instance.getAppStorageDirectory();
      base = (appStorage != null && appStorage.isNotEmpty) ? appStorage : Directory.systemTemp.path;
    } else {
      base = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.systemTemp.path;
    }
    final dir = Directory('$base/PeerLink');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/onboarding_status.json');
  }

  static Future<bool> isOnboardingCompleted() async {
    try {
      final file = await _getPrefsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        return data['onboarding_completed'] == true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    try {
      final file = await _getPrefsFile();
      final content = jsonEncode({'onboarding_completed': completed});
      final tmpFile = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await tmpFile.writeAsString(content, flush: true);
      if (!Platform.isWindows) {
        await tmpFile.rename(file.path);
      } else {
        bool renamed = false;
        for (int i = 0; i < 5; i++) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
            await tmpFile.rename(file.path);
            renamed = true;
            break;
          } catch (_) {
            await Future.delayed(const Duration(milliseconds: 30));
          }
        }
        if (!renamed) {
          await file.writeAsString(content, flush: true);
          try {
            if (await tmpFile.exists()) await tmpFile.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

class FirstRunPermissionsScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const FirstRunPermissionsScreen({super.key, required this.onComplete});

  @override
  State<FirstRunPermissionsScreen> createState() => _FirstRunPermissionsScreenState();
}

class _FirstRunPermissionsScreenState extends State<FirstRunPermissionsScreen> {
  bool _loading = true;
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    setState(() => _loading = true);
    final perms = await AndroidNodeBridge.instance.checkPermissions();
    if (mounted) {
      setState(() {
        _permissions = perms;
        _loading = false;
      });
    }
  }

  Future<void> _requestSingle(String permKey, String nativeName) async {
    final res = await AndroidNodeBridge.instance.requestPermissions([nativeName]);
    if (mounted) {
      setState(() {
        _permissions[permKey] = res[nativeName] ?? _permissions[permKey] ?? false;
      });
    }
    _checkCurrentPermissions();
  }

  Future<void> _requestAllPending() async {
    final toRequest = <String>[];
    if (_permissions['nearbyDevices'] != true) toRequest.add('nearby');
    if (_permissions['notifications'] != true) toRequest.add('notifications');
    if (_permissions['camera'] != true) toRequest.add('camera');

    if (toRequest.isNotEmpty) {
      await AndroidNodeBridge.instance.requestPermissions(toRequest);
      _checkCurrentPermissions();
    }
  }

  void _finishOnboarding() {
    OnboardingPreferences.setOnboardingCompleted(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearbyGranted = _permissions['nearbyDevices'] == true;
    final notifGranted = _permissions['notifications'] == true;
    final cameraGranted = _permissions['camera'] == true;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Header Logo & Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.shield_outlined,
                              color: theme.colorScheme.primary, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First-Run Setup',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Permission Readiness & Trust',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Educational Explanation
                    GlassContainer(
                      glowColor: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'PeerLink connects your devices directly over local Wi-Fi without cloud servers. Review and grant permissions below for seamless peer discovery and file delivery.',
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 1. Nearby Devices / Discovery
                    _buildPermissionCard(
                      theme,
                      icon: Icons.wifi_tethering_rounded,
                      title: 'Nearby Device Discovery',
                      description:
                          'Enables PeerLink to locate and connect directly to your other devices on the local Wi-Fi network.',
                      isGranted: nearbyGranted,
                      isRequired: true,
                      onGrant: () => _requestSingle('nearbyDevices', 'nearby'),
                    ),
                    const SizedBox(height: 14),

                    // 2. Notifications
                    _buildPermissionCard(
                      theme,
                      icon: Icons.notifications_active_outlined,
                      title: 'Transfer Alerts & Progress',
                      description:
                          'Alerts you when peers send files and keeps active transfers running reliably in the background.',
                      isGranted: notifGranted,
                      isRequired: false,
                      onGrant: () => _requestSingle('notifications', 'notifications'),
                    ),
                    const SizedBox(height: 14),

                    // 3. Camera
                    _buildPermissionCard(
                      theme,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'QR Code Pairing (Camera)',
                      description:
                          'Allows scanning QR codes from laptops or other phones for instant, authenticated cryptographic pairing.',
                      isGranted: cameraGranted,
                      isRequired: false,
                      onGrant: () => _requestSingle('camera', 'camera'),
                    ),
                    const SizedBox(height: 14),

                    // 4. Scoped Storage Information
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_special_outlined,
                                  color: Colors.teal, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Scoped File Access',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('Ready',
                                            style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Uses Android Storage Access Framework for user-chosen files and folders. No broad all-files access needed.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Actions
                    if (!nearbyGranted || !notifGranted || !cameraGranted) ...[
                      FilledButton.icon(
                        onPressed: _requestAllPending,
                        icon: const Icon(Icons.checklist_rounded, size: 18),
                        label: const Text('Grant All Permissions'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    OutlinedButton(
                      onPressed: _finishOnboarding,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        nearbyGranted
                            ? 'Continue to PeerLink'
                            : 'Continue with Limited Discovery',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can always grant or modify permissions later in Settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPermissionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isRequired,
    required VoidCallback onGrant,
  }) {
    final statusColor = isGranted ? const Color(0xFF10B981) : (isRequired ? Colors.amber.shade800 : Colors.grey);
    final statusText = isGranted
        ? 'Granted'
        : (isRequired ? 'Recommended' : 'Optional');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isGranted ? Icons.check_circle_rounded : Icons.pending_rounded,
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isGranted)
                  FilledButton.tonal(
                    onPressed: onGrant,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Grant', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
