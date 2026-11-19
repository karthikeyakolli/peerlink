import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/file_item.dart';
import '../../core/services/exif_sanitizer_service.dart';
import 'dedicated_tool_page.dart';

/// Modal sheet for stripping GPS metadata and EXIF hardware identifiers before sharing photos.
class ExifSanitizerSheet extends StatefulWidget {
  final FileItem fileItem;
  final VoidCallback? onSanitized;
  final bool isPage;

  const ExifSanitizerSheet({
    super.key,
    required this.fileItem,
    this.onSanitized,
    this.isPage = false,
  });

  static Future<void> show(BuildContext context, FileItem fileItem, {VoidCallback? onSanitized}) {
    return DedicatedToolPage.open(
      context,
      title: 'EXIF & GPS Privacy Sanitizer',
      subtitle: 'Scrub Camera, Geolocation & Hardware Tags',
      icon: Icons.location_off_rounded,
      child: ExifSanitizerSheet(fileItem: fileItem, onSanitized: onSanitized, isPage: true),
    );
  }

  @override
  State<ExifSanitizerSheet> createState() => _ExifSanitizerSheetState();
}

class _ExifSanitizerSheetState extends State<ExifSanitizerSheet> {
  bool _isSanitizing = false;
  ExifSanitizationResult? _result;

  Future<void> _runSanitize() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSanitizing = true);

    final res = await ExifSanitizerService.instance.sanitizeFile(widget.fileItem.path);

    if (mounted) {
      setState(() {
        _isSanitizing = false;
        _result = res;
      });
      widget.onSanitized?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.location_off_outlined, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EXIF & GPS Privacy Sanitizer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text(widget.fileItem.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
          // Privacy Alert Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: Color(0xFFD97706)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Standard camera photos embed exact home GPS coordinates, camera model, and capture date in the file header.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Tags to be Scrubbed:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          _buildScrubItem('GPS Latitude, Longitude & Altitude (Exact Geolocation)'),
          _buildScrubItem('Camera Serial Number & Device Identifier'),
          _buildScrubItem('Lens Specifications & Focal Settings'),
          _buildScrubItem('Hardware Capture Timestamp'),
          const SizedBox(height: 16),
          if (_result != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sanitized copy created (${_result!.bytesRemoved} bytes metadata scrubbed).',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('sanitize_exif_button'),
              onPressed: _isSanitizing
                  ? null
                  : _result != null
                      ? () => Navigator.of(context).pop()
                      : _runSanitize,
              icon: Icon(
                _result != null ? Icons.check_rounded : Icons.cleaning_services_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                _result != null ? 'Done' : 'Scrub GPS & Metadata Before Sharing',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
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

  Widget _buildScrubItem(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
        ],
      ),
    );
  }
}
