import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_settings_service.dart';
import '../../core/network_utils.dart';
import '../../core/webdav_server_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only WebDAV Drive Mount Sheet.
/// Exposes the Vault over local WebDAV so Windows/Mac/Linux can map it as a local drive letter.
class WebDavStatusSheet extends StatefulWidget {
  const WebDavStatusSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WebDavStatusSheet(),
    );
  }

  @override
  State<WebDavStatusSheet> createState() => _WebDavStatusSheetState();
}

class _WebDavStatusSheetState extends State<WebDavStatusSheet> {
  final WebDavServerService _webdav = WebDavServerService.instance;
  bool _isBusy = false;
  String _username = 'peerlink';
  String _password = '';
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _password = _webdav.password ?? _generateRandomPassword();
    _username = _webdav.username ?? 'peerlink';
    _loadIp();
  }

  Future<void> _loadIp() async {
    final ip = await NetworkUtils.getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rng = Random();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _toggleServer() async {
    setState(() => _isBusy = true);
    if (_webdav.isRunning) {
      await _webdav.stop();
    } else {
      final vaultDir = Directory(AppSettingsService.instance.saveLocation);
      await _webdav.start(
        rootDirectory: vaultDir,
        username: _username,
        password: _password,
      );
    }
    if (mounted) {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _webdav.isRunning;
    final ip = _localIp ?? '127.0.0.1';
    final mountCmd = _webdav.getWindowsMountCommand(ip: ip, driveLetter: 'P:');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(Icons.storage_rounded, size: 20, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mount Vault as Windows Drive (WebDAV)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        isRunning ? 'Running on Port ${_webdav.port}' : 'Mount Vault as Drive Letter P:',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRunning ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRunning ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isRunning ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Icon(
                    isRunning ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: isRunning ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRunning
                          ? 'WebDAV server active on LAN. Files can be opened directly from Explorer, Word, VS Code, etc.'
                          : 'Start server to map PeerLink Vault to your Windows PC without cables or cloud relays.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isRunning ? const Color(0xFF15803D) : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isRunning) ...[
              // Windows net use command card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Windows Command Prompt / Terminal command:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      mountCmd,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Command', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: mountCmd));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied mount command to clipboard!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Button
            ElevatedButton.icon(
              key: const Key('webdav_toggle_server_button'),
              onPressed: _isBusy ? null : _toggleServer,
              icon: _isBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
              label: Text(isRunning ? 'Stop WebDAV Server' : 'Start WebDAV Server'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRunning ? PeerLinkColors.dangerRed : PeerLinkColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
