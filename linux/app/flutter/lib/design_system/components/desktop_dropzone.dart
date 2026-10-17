import 'package:flutter/material.dart';

/// Desktop Drag-and-Drop Zone widget for Windows, macOS, and Linux.
/// Provides an illuminated drop target allowing users to drag files from
/// File Explorer directly onto the app to start sending.
class DesktopDropzone extends StatefulWidget {
  final void Function(List<String> droppedFilePaths) onFilesDropped;
  final Widget child;

  const DesktopDropzone({
    super.key,
    required this.onFilesDropped,
    required this.child,
  });

  @override
  State<DesktopDropzone> createState() => _DesktopDropzoneState();
}

class _DesktopDropzoneState extends State<DesktopDropzone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragging = true);
        return true;
      },
      onLeave: (_) {
        setState(() => _isDragging = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isDragging = false);
        widget.onFilesDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            widget.child,

            // Illuminated Drag Overlay
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: (isDark ? const Color(0xFF0F172A) : Colors.white)
                      .withValues(alpha: 0.92),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF2563EB),
                          width: 2.5,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_rounded,
                              size: 48,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Drop files here to send to nearby peers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Files will be chunked, SHA-256 verified, and sent directly over encrypted P2P',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
