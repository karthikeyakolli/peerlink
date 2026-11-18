import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/pdf_power_suite_service.dart';

/// Minimalist Light-only sheet for offline PDF power tools (watermarking, merging, and page extraction).
class PdfSuiteSheet extends StatefulWidget {
  final String sourceFilePath;
  final VoidCallback? onCompleted;

  const PdfSuiteSheet({
    super.key,
    required this.sourceFilePath,
    this.onCompleted,
  });

  static Future<void> show(BuildContext context, {required String sourceFilePath, VoidCallback? onCompleted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PdfSuiteSheet(
        sourceFilePath: sourceFilePath,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<PdfSuiteSheet> createState() => _PdfSuiteSheetState();
}

class _PdfSuiteSheetState extends State<PdfSuiteSheet> {
  final TextEditingController _watermarkController = TextEditingController(text: 'CONFIDENTIAL');
  bool _isProcessing = false;
  String? _statusMessage;

  final List<String> _presets = ['CONFIDENTIAL', 'DRAFT', 'INTERNAL ONLY', 'COPY', 'FOR REVIEW'];

  Future<void> _applyWatermark() async {
    final text = _watermarkController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessing = true);
    final src = File(widget.sourceFilePath);
    final outPath = '${src.parent.path}/${src.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '')}_watermarked.pdf';

    try {
      await PdfPowerSuiteService.instance.addWatermark(widget.sourceFilePath, text, outPath);
      if (mounted) {
        setState(() {
          _statusMessage = 'Watermarked PDF saved successfully!';
          _isProcessing = false;
        });
        widget.onCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to apply watermark: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.sourceFilePath.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag pill
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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PDF Power Suite',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Watermark Text',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          // Watermark input
          TextField(
            controller: _watermarkController,
            decoration: InputDecoration(
              hintText: 'Enter watermark stamp text...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Preset chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _presets.map((preset) {
              return ActionChip(
                label: Text(preset, style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                onPressed: () => setState(() => _watermarkController.text = preset),
              );
            }).toList(),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('pdf_suite_apply_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(_isProcessing ? 'Applying Watermark...' : 'Save Watermarked PDF', style: const TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _isProcessing ? null : _applyWatermark,
            ),
          ),
        ],
      ),
    );
  }
}
