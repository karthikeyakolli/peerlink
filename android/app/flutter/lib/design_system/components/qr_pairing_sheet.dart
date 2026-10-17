import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// QR Code Pairing Modal bottom sheet for firewall traversal / AP-isolation fallback
/// and Wi-Fi Direct Hotspot offline sharing (AirDrop / SHAREit inspired).
class QrPairingSheet extends StatefulWidget {
  final String deviceName;
  final String peerId;
  final String fingerprint;
  final String localIp;
  final int initialTab;
  final void Function(String qrPayload)? onQrScanned;

  const QrPairingSheet({
    super.key,
    required this.deviceName,
    required this.peerId,
    required this.fingerprint,
    this.localIp = '192.168.1.100',
    this.initialTab = 0,
    this.onQrScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required String deviceName,
    required String peerId,
    required String fingerprint,
    String localIp = '192.168.1.100',
    int initialTab = 0,
    void Function(String qrPayload)? onQrScanned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QrPairingSheet(
        deviceName: deviceName,
        peerId: peerId,
        fingerprint: fingerprint,
        localIp: localIp,
        initialTab: initialTab,
        onQrScanned: onQrScanned,
      ),
    );
  }

  @override
  State<QrPairingSheet> createState() => _QrPairingSheetState();
}

class _QrPairingSheetState extends State<QrPairingSheet> {
  late int _activeTab;
  bool _isHotspotActive = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // 3-Segment Switch: [Show QR] | [Scan QR] | [Hotspot Direct]
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentTab(
                    title: 'Show QR',
                    icon: Icons.qr_code_rounded,
                    isActive: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                ),
                Expanded(
                  child: _SegmentTab(
                    title: 'Scan QR',
                    icon: Icons.camera_alt_outlined,
                    isActive: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                ),
                Expanded(
                  child: _SegmentTab(
                    title: 'Hotspot P2P',
                    icon: Icons.wifi_tethering_rounded,
                    isActive: _activeTab == 2,
                    onTap: () => setState(() => _activeTab = 2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_activeTab == 0) ...[
            // SHOW QR CODE VIEW
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: CustomPaint(
                size: const Size(190, 190),
                painter: _SimulatedQrPainter(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.deviceName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'IP: ${widget.localIp} • Key: ${widget.fingerprint.substring(0, widget.fingerprint.length > 12 ? 12 : widget.fingerprint.length)}...',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Have the sender scan this code with their camera to establish an instant direct connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ] else if (_activeTab == 1) ...[
            // SCAN QR CODE VIEW
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2563EB),
                  width: 2,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 64,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Point camera at receiver QR code',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                // Simulate pairing with demo target
                widget.onQrScanned?.call('peerlink://connect?peer=peer-scanned-01');
                Navigator.pop(context);
              },
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Simulate Instant Scan'),
            ),
          ] else if (_activeTab == 2) ...[
            // WI-FI HOTSPOT DIRECT MODE (OFFLINE SHARING)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHotspotActive ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.wifi_tethering_rounded,
                            color: _isHotspotActive ? const Color(0xFF10B981) : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Direct Wi-Fi Hotspot',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_isHotspotActive ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isHotspotActive ? 'BROADCASTING' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isHotspotActive ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isHotspotActive) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CustomPaint(
                          size: const Size(130, 130),
                          painter: _SimulatedQrPainter(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildHotspotDetailRow(Icons.wifi_rounded, 'Network SSID:', 'PeerLink-Direct-94A2', context),
                  const SizedBox(height: 8),
                  _buildHotspotDetailRow(Icons.key_rounded, 'WPA2 Password:', 'peerlink-direct-key', context),
                  const SizedBox(height: 8),
                  _buildHotspotDetailRow(Icons.lan_rounded, 'Direct IP Subnet:', '192.168.49.1:52001', context),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AP Isolation Bypass: Direct P2P transfer with 0 router and 0 mobile data used.',
                            style: TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _isHotspotActive = !_isHotspotActive);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isHotspotActive
                          ? 'Hotspot broadcasting on SSID PeerLink-Direct-94A2 (Port 52001)'
                          : 'Direct Hotspot stopped.',
                    ),
                    backgroundColor: _isHotspotActive ? const Color(0xFF10B981) : Colors.grey.shade700,
                  ),
                );
              },
              icon: Icon(_isHotspotActive ? Icons.stop_circle_outlined : Icons.wifi_tethering_rounded, size: 18),
              label: Text(_isHotspotActive ? 'Stop Direct Hotspot' : 'Start Direct Hotspot (Offline Mode)'),
              style: FilledButton.styleFrom(
                backgroundColor: _isHotspotActive ? Colors.red.shade600 : const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHotspotDetailRow(IconData icon, String label, String value, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 15, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied $value'), duration: const Duration(seconds: 1)),
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(Icons.copy_rounded, size: 14, color: Colors.blueAccent),
          ),
        ),
      ],
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? const Color(0xFF2563EB)
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulatedQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Draw 3 corner finder patterns
    const finderSize = 44.0;
    _drawFinderPattern(canvas, const Offset(0, 0), finderSize, paint);
    _drawFinderPattern(canvas, Offset(size.width - finderSize, 0), finderSize, paint);
    _drawFinderPattern(canvas, Offset(0, size.height - finderSize), finderSize, paint);

    // Draw simulated interior QR data blocks
    final randomDataOffsets = [
      const Rect.fromLTWH(56, 12, 18, 18),
      const Rect.fromLTWH(86, 20, 14, 24),
      const Rect.fromLTWH(112, 10, 22, 16),
      const Rect.fromLTWH(18, 56, 24, 18),
      const Rect.fromLTWH(56, 56, 32, 32),
      const Rect.fromLTWH(100, 60, 20, 20),
      const Rect.fromLTWH(130, 56, 22, 28),
      const Rect.fromLTWH(70, 100, 26, 26),
      const Rect.fromLTWH(110, 104, 18, 30),
      const Rect.fromLTWH(56, 136, 32, 18),
      const Rect.fromLTWH(100, 140, 28, 28),
      const Rect.fromLTWH(136, 136, 24, 24),
    ];

    for (final rect in randomDataOffsets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }
  }

  void _drawFinderPattern(Canvas canvas, Offset offset, double size, Paint paint) {
    final strokePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;

    final outerRect = Rect.fromLTWH(offset.dx + 3.5, offset.dy + 3.5, size - 7, size - 7);
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(10)), strokePaint);

    final innerRect = Rect.fromLTWH(
      offset.dx + size / 2 - 7,
      offset.dy + size / 2 - 7,
      14,
      14,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(4)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
