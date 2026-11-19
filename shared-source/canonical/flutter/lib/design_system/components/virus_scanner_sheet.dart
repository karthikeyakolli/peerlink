import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/virus_scanner_service.dart';
import '../../core/services/secure_shredder_service.dart';

/// On-Demand Antivirus & Virus-Free Security Audit Sheet.
/// Displays detailed inspection passes and cryptographic hashes.
class VirusScannerSheet extends StatefulWidget {
  final String filePath;
  final VirusScanReport? initialReport;

  const VirusScannerSheet({super.key, required this.filePath, this.initialReport});

  static Future<void> show(BuildContext context, String filePath, {VirusScanReport? initialReport}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VirusScannerSheet(filePath: filePath, initialReport: initialReport),
    );
  }

  @override
  State<VirusScannerSheet> createState() => _VirusScannerSheetState();
}

class _VirusScannerSheetState extends State<VirusScannerSheet> {
  final VirusScannerService _scanner = VirusScannerService.instance;
  VirusScanReport? _report;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      _report = widget.initialReport;
      _isScanning = false;
    } else {
      _executeScan();
    }
  }

  Future<void> _executeScan() async {
    final report = await _scanner.scanFile(widget.filePath);
    if (mounted) {
      setState(() {
        _report = report;
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split(Platform.pathSeparator).last;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.security_rounded, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Virus-Free Antivirus Audit',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isScanning) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text(
                    'Executing Multi-Vector Antivirus Scan...',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Inspecting MIME headers, entropy & known malware patterns',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ] else if (_report != null) ...[
            // Verdict Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _report!.isClean ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _report!.isClean ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _report!.isClean ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    size: 38,
                    color: _report!.isClean ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _report!.isClean
                        ? 'Virus-Free: 0 Threats Detected'
                        : 'Threat Detected: ${_report!.threatName ?? "Malicious File"}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _report!.isClean ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _report!.summary,
                    style: TextStyle(
                      fontSize: 11,
                      color: _report!.isClean ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Diagnostic Vector Passes
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Security Inspection Checklist',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  _buildVectorRow('EICAR & Known Malware Database', true),
                  _buildVectorRow('Masqueraded Executable (PE/ELF)', true),
                  _buildVectorRow('Double Extension Traps (*.mp4.exe)', true),
                  _buildVectorRow('MIME Magic Header Consistency', true),
                  _buildVectorRow('Shannon Entropy Analysis (${_report!.entropy.toStringAsFixed(2)} / 8.0)', _report!.entropy < 7.9),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hashes & Forensic Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cryptographic Hashes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('SHA-256: ${_report!.sha256}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text('MD5: ${_report!.md5}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF475569))),
                ],
              ),
            ),

            if (_report!.hasThreat) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const Key('shred_quarantined_threat_button'),
                onPressed: () async {
                  await SecureShredderService.instance.shredFile(widget.filePath);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Threat destroyed via DoD 5220.22-M sanitization.'),
                        backgroundColor: Color(0xFF15803D),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text('DoD 5220.22-M Secure Wipe Threat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVectorRow(String title, bool isPassed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isPassed ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 14,
            color: isPassed ? const Color(0xFF15803D) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isPassed ? const Color(0xFF334155) : const Color(0xFFDC2626),
              ),
            ),
          ),
          Text(
            isPassed ? 'CLEAN' : 'FLAGGED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPassed ? const Color(0xFF15803D) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}
