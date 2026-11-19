import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/hotspot_tether_qr_service.dart';
import 'dedicated_tool_page.dart';

class HotspotTetherQrSheet extends StatelessWidget {
  final HotspotTetherPayload payload;
  final bool isPage;

  const HotspotTetherQrSheet({
    super.key,
    required this.payload,
    this.isPage = false,
  });

  static Future<void> show(BuildContext context, {HotspotTetherPayload? payload}) {
    final effectivePayload = payload ??
        HotspotTetherQrService.instance.createPayload(
          ssid: 'PeerLink-Direct-Hotspot',
          passphrase: 'peerlink-secure-pass',
          ipAddress: '192.168.49.1',
          port: 53317,
          nodeId: 'peerlink-local-node',
          publicKey: 'ed25519-node-key-preview',
        );
    return DedicatedToolPage.open(
      context,
      title: 'Zero-Touch Hotspot Auto-Tether',
      subtitle: 'Scan Scannable QR to Pair & Connect Wi-Fi Direct Mesh',
      icon: Icons.wifi_tethering_rounded,
      child: HotspotTetherQrSheet(payload: effectivePayload, isPage: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrUri = payload.toUriString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isPage) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zero-Touch Hotspot QR Tether',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Scan with camera to auto-connect Wi-Fi & establish TLS session',
                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Simulated High-Density QR Visual Box
            Center(
              child: Container(
                key: const Key('hotspot_qr_visual_box'),
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_tethering_rounded, size: 54, color: Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    Text(
                      payload.ssid,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${payload.ipAddress}:${payload.port}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Network SSID:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text(payload.ssid, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Password:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text(payload.passphrase, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('copy_tether_uri_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Tether Link', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrUri));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied Hotspot Tether URI to clipboard')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
