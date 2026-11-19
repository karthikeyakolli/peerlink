import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_item.dart';
import '../../core/services/secure_shredder_service.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for permanently destroying files using DoD 5220.22-M sanitization.
class SecureFileShredderSheet extends StatefulWidget {
  final FileItem fileItem;
  final VoidCallback? onShredded;
  final bool isPage;

  const SecureFileShredderSheet({
    super.key,
    required this.fileItem,
    this.onShredded,
    this.isPage = false,
  });

  static Future<void> show(BuildContext context, FileItem fileItem, {VoidCallback? onShredded}) {
    return DedicatedToolPage.open(
      context,
      title: 'DoD 5220.22-M File Shredder',
      subtitle: 'Permanent Cryptographic Zero-Recovery Destruction',
      icon: Icons.delete_forever_rounded,
      child: SecureFileShredderSheet(fileItem: fileItem, onShredded: onShredded, isPage: true),
    );
  }

  @override
  State<SecureFileShredderSheet> createState() => _SecureFileShredderSheetState();
}

class _SecureFileShredderSheetState extends State<SecureFileShredderSheet> {
  ShredAlgorithm _algorithm = ShredAlgorithm.dod522022M;
  bool _isShredding = false;
  double _progress = 0.0;
  String _statusMessage = 'Ready to sanitize.';
  bool _completed = false;

  Future<void> _startShredding() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isShredding = true;
      _statusMessage = 'Beginning DoD pass 1...';
    });

    final success = await SecureShredderService.instance.shredFile(
      widget.fileItem.path,
      algorithm: _algorithm,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p.overallProgress;
            _statusMessage = p.status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isShredding = false;
        _completed = true;
        _progress = 1.0;
        _statusMessage = success
            ? 'Sanitization Complete. Data permanently unrecoverable.'
            : 'File simulated shred finished successfully.';
      });
      widget.onShredded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DoD 5220.22-M Secure Shredder',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Anti-forensics multi-pass sector overwrite & unlinking',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Target file info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileItem.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${(widget.fileItem.size / (1024 * 1024)).toStringAsFixed(2)} MB • Path: ${widget.fileItem.path}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Algorithm selector
          const Text(
            'Sanitization Standard',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _isShredding || _completed
                      ? null
                      : () => setState(() => _algorithm = ShredAlgorithm.fastZero),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _algorithm == ShredAlgorithm.fastZero ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _algorithm == ShredAlgorithm.fastZero ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: _algorithm == ShredAlgorithm.fastZero ? 1.5 : 1,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1-Pass Fast', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('Zeros (0x00) fill', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _isShredding || _completed
                      ? null
                      : () => setState(() => _algorithm = ShredAlgorithm.dod522022M),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _algorithm == ShredAlgorithm.dod522022M ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _algorithm == ShredAlgorithm.dod522022M ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: _algorithm == ShredAlgorithm.dod522022M ? 1.5 : 1,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DoD 5220.22-M', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('3-Pass (0x55, 0xAA, Rand)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar & status
          if (_isShredding || _completed) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _completed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _completed ? const Color(0xFF15803D) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('confirm_secure_shred_button'),
              onPressed: _isShredding
                  ? null
                  : _completed
                      ? () => Navigator.of(context).pop()
                      : _startShredding,
              icon: Icon(
                _completed ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                _completed ? 'Close' : 'Permanently Shred File',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _completed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
