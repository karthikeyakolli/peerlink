import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ephemeral_burner_share_service.dart';
import '../../core/hotspot_tether_qr_service.dart';
import '../../core/network_diagnostic_service.dart';
import '../../core/received_files_service.dart';
import '../../core/web_beam_server_service.dart';
import '../../design_system/components/burner_viewer_modal.dart';
import '../../design_system/components/contextual_share_sheet.dart';
import '../../design_system/components/hotspot_tether_qr_sheet.dart';
import '../../design_system/components/network_diagnostic_card.dart';
import '../../design_system/components/web_beam_modal.dart';

/// Dedicated P2P Share & Transfer Flow.
/// Unifies local Wi-Fi Hotspot Auto-Tether QR, Bi-Directional Web Beam 2.0,
/// Wi-Fi 6 Link Diagnostics, Ephemeral Burner Shares, and bandwidth governors.
class ShareHubFlowView extends StatefulWidget {
  const ShareHubFlowView({super.key});

  @override
  State<ShareHubFlowView> createState() => _ShareHubFlowViewState();
}

class _ShareHubFlowViewState extends State<ShareHubFlowView> {
  final WebBeamServerService _webBeamService = WebBeamServerService.instance;
  WebBeamSessionState _webBeamState = WebBeamSessionState.stopped;
  StreamSubscription<WebBeamSessionState>? _webBeamSub;

  String _bandwidthLimit = 'Unlimited';
  bool _batteryGuardEnabled = true;

  @override
  void initState() {
    super.initState();
    _webBeamState = _webBeamService.currentState;
    _webBeamSub = _webBeamService.stateStream.listen((st) {
      if (mounted) setState(() => _webBeamState = st);
    });
  }

  @override
  void dispose() {
    _webBeamSub?.cancel();
    super.dispose();
  }

  void _showHotspotSheet() {
    HotspotTetherQrSheet.show(context);
  }

  Future<void> _createBurnerShare() async {
    final files = await ReceivedFilesService.instance.getReceivedFiles();
    final nonDirs = files.where((f) => !f.isDirectory).toList();
    if (nonDirs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files in vault to create a Burner Share. Receive or copy a file first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final selectedFile = await showDialog<ReceivedFileItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pick File for Burner Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          height: 260,
          child: ListView.builder(
            itemCount: nonDirs.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.description_outlined, color: Color(0xFFDC2626)),
              title: Text(nonDirs[i].name, style: const TextStyle(fontSize: 13), maxLines: 1),
              subtitle: Text(nonDirs[i].formattedSize, style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, nonDirs[i]),
            ),
          ),
        ),
      ),
    );

    if (selectedFile == null || !mounted) return;

    final pinController = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.local_fire_department_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Set Burner Protection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Protecting "${selectedFile.name}". Self-destructs after single view.', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Optional 4-digit PIN',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create Burner Share'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final pin = pinController.text.trim();
      final token = EphemeralBurnerShareService.instance.createBurnerShare(
        filePath: selectedFile.path,
        pin: pin.isNotEmpty ? pin : null,
      );
      pinController.dispose();
      await BurnerViewerModal.show(context, token: token);
    } else {
      pinController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Send & Receive P2P Radar Card
        _buildP2PRadarCard(),
        const SizedBox(height: 14),

        // 2. Zero-Touch Hotspot Auto-Tether Card
        _buildHotspotTetherCard(),
        const SizedBox(height: 14),

        // 3. Bi-Directional Web Portal 2.0 (Web Beam)
        _buildWebBeamCard(),
        const SizedBox(height: 14),

        // 4. One-Time Ephemeral Burner Vault Share
        _buildBurnerShareCard(),
        const SizedBox(height: 14),

        // 5. Wi-Fi 6 / 5GHz Link Diagnostic & Congestion Advisor
        const NetworkDiagnosticCard(),
        const SizedBox(height: 14),

        // 6. Network Governors (Speed Throttling & Battery Guard)
        _buildGovernorsCard(),
      ],
    );
  }

  Widget _buildP2PRadarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.radar_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Direct P2P Beam & Discovery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Zero-config discovery over local Wi-Fi & Hotspot', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('share_hub_send_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send Files', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ContextualShareSheet.show(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('share_hub_receive_button'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('Receive Radar', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ContextualShareSheet.show(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotTetherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hotspot Auto-Tether QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Instant WPA2/3 connection QR for zero-network environments', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('share_hub_open_hotspot_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF15803D),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Show Hotspot Tether QR', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _showHotspotSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildWebBeamCard() {
    final isRunning = _webBeamState.isRunning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bi-Directional Web Portal 2.0', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      isRunning ? 'Live at ${_webBeamState.hostIp}:${_webBeamState.port}' : 'Browser dropzone for PCs and non-PeerLink phones',
                      style: TextStyle(fontSize: 11, color: isRunning ? const Color(0xFF16A34A) : const Color(0xFF64748B), fontWeight: isRunning ? FontWeight.w600 : FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                key: const Key('share_hub_web_beam_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: isRunning ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                  foregroundColor: isRunning ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(isRunning ? Icons.stop_circle_outlined : Icons.public_rounded, size: 18),
                label: Text(isRunning ? 'Stop Portal' : 'Launch Web Portal', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (isRunning) {
                    _webBeamService.stop();
                  } else {
                    WebBeamModal.showLive(context, initialPaths: const []);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBurnerShareCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFDC2626), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('One-Time Ephemeral Burner Vault Share', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('PIN-protected single-view share that wipes permanently on close', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('share_hub_create_burner_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              foregroundColor: const Color(0xFFB91C1C),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Create Burner Share', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _createBurnerShare,
          ),
        ],
      ),
    );
  }

  Widget _buildGovernorsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transfer Engine Governors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bandwidth Limit:', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
              DropdownButton<String>(
                value: _bandwidthLimit,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'Unlimited', child: Text('Unlimited (Max PHY)')),
                  DropdownMenuItem(value: '25 MB/s', child: Text('25 MB/s (Home Cap)')),
                  DropdownMenuItem(value: '10 MB/s', child: Text('10 MB/s (Balanced)')),
                  DropdownMenuItem(value: '5 MB/s', child: Text('5 MB/s (Low Bandwidth)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _bandwidthLimit = val);
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Battery-Aware Transfer Guard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    Text('Auto-pause bulk sync if battery drops below 15%', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Switch(
                value: _batteryGuardEnabled,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) => setState(() => _batteryGuardEnabled = val),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
