import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/apk_inspector_service.dart';

/// Minimalist Light-only APK Inspector sheet for static package auditing and metadata inspection.
/// Complies with AGENTS.md Rule 10 & 11: Inspects metadata statically without auto-executing code.
class ApkInspectorSheet extends StatefulWidget {
  final String apkPath;
  final VoidCallback? onSendRequested;

  const ApkInspectorSheet({
    super.key,
    required this.apkPath,
    this.onSendRequested,
  });

  static Future<void> show(BuildContext context, {required String apkPath, VoidCallback? onSendRequested}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApkInspectorSheet(
        apkPath: apkPath,
        onSendRequested: onSendRequested,
      ),
    );
  }

  @override
  State<ApkInspectorSheet> createState() => _ApkInspectorSheetState();
}

class _ApkInspectorSheetState extends State<ApkInspectorSheet> {
  ApkDetails? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  Future<void> _inspect() async {
    setState(() => _isLoading = true);
    final details = await ApkInspectorService.instance.inspectApk(widget.apkPath);
    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag pill
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.android_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _details?.fileName ?? 'Inspecting APK...',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _details != null
                            ? '${_details!.packageName} • ${_details!.formattedSize}'
                            : 'Reading manifest & signatures...',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _buildContent(),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('apk_done_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                if (widget.onSendRequested != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('apk_send_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send to Peer', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSendRequested?.call();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final details = _details!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Version & Target SDK Info Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Version Name / Code', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(
                    '${details.versionName} (${details.versionCode})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SDK Compatibility', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(
                    'Min API ${details.minSdk} • Target API ${details.targetSdk}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Signature State', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: details.isSigned ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: details.isSigned ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      details.isSigned ? 'Signed APK' : 'Unsigned',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: details.isSigned ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Signer SHA-256 Fingerprint
        if (details.signerSha256.isNotEmpty) ...[
          const Text(
            'Signer Certificate Fingerprint (SHA-256)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    details.signerSha256,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF475569)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                  tooltip: 'Copy Fingerprint',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: details.signerSha256));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signer fingerprint copied'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // High Risk Permissions Notice
        if (details.highRiskPermissions.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${details.highRiskPermissions.length} sensitive permissions declared (${details.highRiskPermissions.map((p) => p.split('.').last).join(', ')})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Declared Permissions List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Declared Permissions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            Text(
              '${details.permissions.length} total',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (details.permissions.isEmpty)
          const Text('No permissions declared', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
        else
          ...details.permissions.map((perm) {
            final isSensitive = details.highRiskPermissions.contains(perm);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSensitive ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSensitive ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    isSensitive ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: isSensitive ? const Color(0xFFD97706) : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perm,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSensitive ? const Color(0xFF92400E) : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
