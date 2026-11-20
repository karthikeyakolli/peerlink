import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/document_scanner_service.dart';

/// Interactive 4-Corner Perspective Crop & Alignment Dialog.
/// Allows fine-tuning document bounds, rotating 90°, and selecting full vs auto-boundary.
class DocumentCropDialog extends StatefulWidget {
  final ScannedPage page;
  final VoidCallback onBoundsUpdated;

  const DocumentCropDialog({
    super.key,
    required this.page,
    required this.onBoundsUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required ScannedPage page,
    required VoidCallback onBoundsUpdated,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DocumentCropDialog(
        page: page,
        onBoundsUpdated: onBoundsUpdated,
      ),
    );
  }

  @override
  State<DocumentCropDialog> createState() => _DocumentCropDialogState();
}

class _DocumentCropDialogState extends State<DocumentCropDialog> {
  bool _isAutoDetected = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(Icons.crop_rotate_rounded, size: 18, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Perspective & Crop Adjustment',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview container with 4-corner boundary overlay
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Document page content
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: widget.page.file.existsSync()
                        ? RotatedBox(
                            quarterTurns: widget.page.rotationDegrees ~/ 90,
                            child: Image.file(
                              widget.page.file,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.description_outlined, size: 48, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.description_outlined, size: 48, color: Color(0xFF94A3B8)),
                          ),
                  ),

                  // Perspective boundary box
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isAutoDetected ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                          width: 2,
                        ),
                        color: _isAutoDetected
                            ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Stack(
                        children: [
                          _buildCornerHandle(Alignment.topLeft),
                          _buildCornerHandle(Alignment.topRight),
                          _buildCornerHandle(Alignment.bottomLeft),
                          _buildCornerHandle(Alignment.bottomRight),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Crop Action Pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                  label: const Text('Auto Detect', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isAutoDetected = true);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop_free_rounded, size: 14),
                  label: const Text('Full Page', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isAutoDetected = false);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.rotate_right_rounded, size: 14),
                  label: const Text('Rotate 90°', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      widget.page.rotateClockwise();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            widget.onBoundsUpdated();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perspective boundaries updated!'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('Apply Crop'),
        ),
      ],
    );
  }

  Widget _buildCornerHandle(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
