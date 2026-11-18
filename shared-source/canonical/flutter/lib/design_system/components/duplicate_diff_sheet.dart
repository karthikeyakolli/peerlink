import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/duplicate_diff_service.dart';

/// Minimalist Light-only side-by-side or line-by-line visual text/document diff viewer.
class DuplicateDiffSheet extends StatefulWidget {
  final File leftFile;
  final File rightFile;
  final VoidCallback? onResolved;

  const DuplicateDiffSheet({
    super.key,
    required this.leftFile,
    required this.rightFile,
    this.onResolved,
  });

  static Future<void> show(
    BuildContext context, {
    required File leftFile,
    required File rightFile,
    VoidCallback? onResolved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DuplicateDiffSheet(
        leftFile: leftFile,
        rightFile: rightFile,
        onResolved: onResolved,
      ),
    );
  }

  @override
  State<DuplicateDiffSheet> createState() => _DuplicateDiffSheetState();
}

class _DuplicateDiffSheetState extends State<DuplicateDiffSheet> {
  List<DiffLine> _diffs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _computeDiff();
  }

  void _computeDiff() {
    try {
      final leftText = widget.leftFile.existsSync() ? widget.leftFile.readAsStringSync() : '';
      final rightText = widget.rightFile.existsSync() ? widget.rightFile.readAsStringSync() : '';
      _diffs = DuplicateDiffService.instance.computeLineDiff(leftText, rightText);
    } catch (_) {
      _diffs = [];
    }
    setState(() => _isLoading = false);
  }

  void _deleteRightFile() {
    try {
      if (widget.rightFile.existsSync()) {
        widget.rightFile.deleteSync();
      }
      widget.onResolved?.call();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftName = widget.leftFile.uri.pathSegments.last;
    final rightName = widget.rightFile.uri.pathSegments.last;

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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.difference_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visual File Diff',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$leftName vs $rightName',
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

          // Diff Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _diffs.isEmpty
                    ? const Center(
                        child: Text('Files are identical byte-for-byte', style: TextStyle(color: Color(0xFF64748B))),
                      )
                    : ListView.builder(
                        itemCount: _diffs.length,
                        itemBuilder: (context, index) {
                          final diff = _diffs[index];
                          Color bg = Colors.white;
                          Color textCol = const Color(0xFF334155);
                          String prefix = ' ';

                          if (diff.type == DiffLineType.added) {
                            bg = const Color(0xFFF0FDF4);
                            textCol = const Color(0xFF15803D);
                            prefix = '+';
                          } else if (diff.type == DiffLineType.deleted) {
                            bg = const Color(0xFFFEF2F2);
                            textCol = const Color(0xFFDC2626);
                            prefix = '-';
                          }

                          return Container(
                            color: bg,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    diff.leftLineNumber?.toString() ?? '',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    diff.rightLineNumber?.toString() ?? '',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  prefix,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textCol, fontFamily: 'monospace'),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    diff.text,
                                    style: TextStyle(fontSize: 11, color: textCol, fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Action
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Keep Both', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('diff_delete_right_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete Duplicate', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: _deleteRightFile,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
