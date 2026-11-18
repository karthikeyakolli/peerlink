import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../platform/android_node_bridge.dart';
import 'glass_container.dart';

/// Modal dialog / sheet for activating and displaying the Direct Wi-Fi Hotspot.
/// Bypasses AP/Client Isolation on enterprise and hotel networks (Product Feature Inventory §4).
class LocalHotspotModal extends StatefulWidget {
  const LocalHotspotModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LocalHotspotModal(),
    );
  }

  @override
  State<LocalHotspotModal> createState() => _LocalHotspotModalState();
}

class _LocalHotspotModalState extends State<LocalHotspotModal> {
  final AndroidNodeBridge _bridge = AndroidNodeBridge.instance;
  bool _isLoading = false;
  Map<String, dynamic>? _hotspotInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    setState(() => _isLoading = true);
    final active = await _bridge.isHotspotActive();
    if (active) {
      final info = await _bridge.startLocalHotspot();
      if (mounted) {
        setState(() {
          _hotspotInfo = info;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHotspot() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_hotspotInfo != null) {
        await _bridge.stopLocalHotspot();
        if (mounted) {
          setState(() {
            _hotspotInfo = null;
            _isLoading = false;
          });
        }
      } else {
        final info = await _bridge.startLocalHotspot();
        if (mounted) {
          setState(() {
            _hotspotInfo = info;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = _hotspotInfo != null;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isActive ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: isActive ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Direct Wi-Fi Hotspot',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      isActive ? 'Broadcasting ad-hoc network' : 'AP Isolation Bypass',
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? const Color(0xFF10B981) : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Explanatory Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              'Bypasses client isolation on hotel, campus, or public Wi-Fi routers. Devices connect directly to this phone over an encrypted local WPA2 network without requiring an external internet connection.',
              style: TextStyle(fontSize: 12, height: 1.4, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (isActive && _hotspotInfo != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: QrImageView(
                  data: _hotspotInfo!['wifiQr']?.toString() ?? '',
                  version: QrVersions.auto,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Scan with peer phone or laptop camera to join network',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),

            // Credentials Detail Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildCredentialRow('Network (SSID)', _hotspotInfo!['ssid']?.toString() ?? '', theme),
                  const Divider(height: 12),
                  _buildCredentialRow('Password', _hotspotInfo!['passphrase']?.toString() ?? '', theme),
                  const Divider(height: 12),
                  _buildCredentialRow('Gateway IP', '${_hotspotInfo!["gatewayIp"]}:${_hotspotInfo!["listenPort"]}', theme),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          FilledButton.icon(
            onPressed: _isLoading ? null : _toggleHotspot,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(isActive ? Icons.power_settings_new_rounded : Icons.wifi_tethering_rounded),
            label: Text(isActive ? 'Stop Hotspot & Release Radio' : 'Activate Offline Hotspot'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: isActive ? Colors.red.shade700 : const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}
