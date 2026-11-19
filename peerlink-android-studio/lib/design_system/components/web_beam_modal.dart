import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/web_beam_server_service.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/windows_file_dialog.dart';
import 'glass_container.dart';
import 'interactive_glass_card.dart';
import 'dedicated_tool_page.dart';

/// Modal bottom sheet for the real On-Device Zero-Install Browser Web Beam Portal.
/// Runs a live embedded HTTP server directly on the phone or desktop over Wi-Fi / Hotspot,
/// displaying a scannable QR code and 128-bit token-authenticated browser URL.
class WebBeamModal extends StatefulWidget {
  final String? fileName;
  final String? fileSize;
  final String? portalUrl;
  final List<String>? initialPaths;
  final VoidCallback? onStopPortal;

  const WebBeamModal({
    super.key,
    this.fileName,
    this.fileSize,
    this.portalUrl,
    this.initialPaths,
    this.onStopPortal,
  });

  /// Launches a live on-device Web Beam HTTP server for [initialPaths] (or lets the user
  /// pick files inside the modal if empty) and presents the live QR & URL portal.
  static Future<void> showLive(
    BuildContext context, {
    List<String> initialPaths = const [],
    VoidCallback? onStopPortal,
  }) {
    return DedicatedToolPage.open(
      context,
      title: 'Bi-Directional Web Portal 2.0',
      subtitle: 'On-Device Zero-Install Browser Beam & QR Portal',
      icon: Icons.language_rounded,
      child: WebBeamModal(
        initialPaths: initialPaths,
        onStopPortal: onStopPortal,
      ),
    );
  }

  /// Backward-compatible constructor when a portal URL is already supplied.
  static Future<void> show(
    BuildContext context, {
    required String fileName,
    required String fileSize,
    required String portalUrl,
    VoidCallback? onStopPortal,
  }) {
    return DedicatedToolPage.open(
      context,
      title: 'Bi-Directional Web Portal 2.0',
      subtitle: 'On-Device Zero-Install Browser Beam & QR Portal',
      icon: Icons.language_rounded,
      child: WebBeamModal(
        fileName: fileName,
        fileSize: fileSize,
        portalUrl: portalUrl,
        onStopPortal: onStopPortal,
      ),
    );
  }

  @override
  State<WebBeamModal> createState() => _WebBeamModalState();
}

class _WebBeamModalState extends State<WebBeamModal> {
  final WebBeamServerService _server = WebBeamServerService.instance;
  StreamSubscription<WebBeamSessionState>? _sub;
  WebBeamSessionState _session = WebBeamServerService.instance.currentState;
  bool _isStarting = false;
  bool _copied = false;
  bool _burnAfterDownload = false;
  String? _errorText;

  bool get _isStaticPreview =>
      widget.portalUrl != null && widget.portalUrl!.isNotEmpty && widget.initialPaths == null;

  @override
  void initState() {
    super.initState();
    _sub = _server.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _session = state;
          if (state.error != null) _errorText = state.error;
        });
      }
    });

    if (!_isStaticPreview) {
      final paths = widget.initialPaths ?? const [];
      if (paths.isNotEmpty) {
        _startServerWithPaths(paths);
      } else if (!_session.isRunning) {
        // Leave ready for user to pick files right inside the sheet
        _errorText = null;
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _startServerWithPaths(List<String> paths) async {
    setState(() {
      _isStarting = true;
      _errorText = null;
    });
    final state = await _server.start(
      paths: paths,
      burnAfterDownload: _burnAfterDownload,
    );
    if (mounted) {
      setState(() {
        _session = state;
        _isStarting = false;
        _errorText = state.error;
      });
    }
  }

  Future<void> _pickAndHostFiles() async {
    List<String> picked = [];
    if (Platform.isAndroid) {
      picked = await AndroidNodeBridge.instance.pickContentUris();
    } else if (Platform.isWindows) {
      picked = await WindowsFileDialog.pickFiles();
    }

    if (picked.isEmpty || !mounted) return;

    setState(() {
      _isStarting = true;
      _errorText = null;
    });

    final state = _session.isRunning
        ? await _server.addFiles(picked)
        : await _server.start(paths: picked, burnAfterDownload: _burnAfterDownload);

    if (mounted) {
      setState(() {
        _session = state;
        _isStarting = false;
        _errorText = state.error;
      });
    }
  }

  void _copyToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeUrl = _isStaticPreview ? widget.portalUrl! : _session.portalUrl;
    final activeFileName = _isStaticPreview
        ? (widget.fileName ?? 'Shared Files')
        : _session.summaryFileName;
    final activeFileSize = _isStaticPreview
        ? (widget.fileSize ?? '')
        : '${_session.summaryFileSize} • ${_session.files.length} file(s)';
    final isHosted = _isStaticPreview || _session.isRunning;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zero-Install Web Beam',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hosted directly on this device over Wi-Fi / Hotspot',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_isStarting) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 12),
                    Text(
                      'Starting local Wi-Fi portal on this device...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ] else if (!isHosted) ...[
              // No files selected yet — let user pick directly
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file_rounded, size: 36, color: Color(0xFF2563EB)),
                    const SizedBox(height: 10),
                    const Text(
                      'Select files to host from this device',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _errorText ??
                          'Anyone on the same Wi-Fi or Hotspot can scan the QR code or open the link in their browser to download.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _errorText != null
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Burn after first download',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Closes portal after first download • Live Gallery + ZIP included',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('web_beam_burn_toggle'),
                          value: _burnAfterDownload,
                          onChanged: (v) => setState(() => _burnAfterDownload = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('web_beam_pick_files_button'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Pick Files to Share'),
                      onPressed: _pickAndHostFiles,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Active Shared File Banner
              GlassContainer(
                borderRadius: BorderRadius.circular(14),
                customBgColor: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF2563EB), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeFileName,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _isStaticPreview
                                ? activeFileSize
                                : '$activeFileSize • ${_session.downloadCount} download(s)',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 12),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Scannable QR Code for Phone-to-Any-Browser Instant Open
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        key: const Key('web_beam_qr_code'),
                        data: activeUrl,
                        version: QrVersions.auto,
                        size: 164,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Scan with any phone camera to download',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Portal URL Link Card
              InteractiveGlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'RECEIVER BROWSER URL',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Expires in 15m',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              activeUrl,
                              key: const Key('web_beam_portal_url_text'),
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _copyToClipboard(activeUrl),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _copied ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _copied ? 'Copied' : 'Copy',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Security Badges
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildSecurityBadge(Icons.lock_rounded, '128-Bit Token Auth'),
                  _buildSecurityBadge(Icons.swap_horiz_rounded, '2-Way Send & Receive'),
                  _buildSecurityBadge(Icons.timer_outlined, '15m Auto-Expire'),
                ],
              ),

              if (!_isStaticPreview && (_session.downloadCount > 0 || _session.uploadCount > 0)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    'Transferred live: ${_session.downloadCount} downloaded • ${_session.uploadCount} uploaded to Vault'
                    '${_session.lastUploadedFileName != null ? ' (latest: ${_session.lastUploadedFileName})' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Add More Files + Stop Portal Actions
              Row(
                children: [
                  if (!_isStaticPreview) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Files'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _pickAndHostFiles,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('web_beam_stop_button'),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Stop Portal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (!_isStaticPreview) {
                          await _server.stop();
                        }
                        widget.onStopPortal?.call();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
