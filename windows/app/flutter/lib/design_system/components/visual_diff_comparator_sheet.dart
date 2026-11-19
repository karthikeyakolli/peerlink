import 'package:flutter/material.dart';

class DiffLine {
  final int? oldLine;
  final int? newLine;
  final String text;
  final DiffType type;

  const DiffLine({
    this.oldLine,
    this.newLine,
    required this.text,
    required this.type,
  });
}

enum DiffType { same, added, removed }

/// Modal sheet providing side-by-side / unified visual diff comparison for text and code files.
class VisualDiffComparatorSheet extends StatefulWidget {
  final String fileAName;
  final String fileBName;

  const VisualDiffComparatorSheet({
    super.key,
    this.fileAName = 'config.v1.json',
    this.fileBName = 'config.v2.json',
  });

  static Future<void> show(BuildContext context, {String fileAName = 'config.v1.json', String fileBName = 'config.v2.json'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VisualDiffComparatorSheet(fileAName: fileAName, fileBName: fileBName),
    );
  }

  @override
  State<VisualDiffComparatorSheet> createState() => _VisualDiffComparatorSheetState();
}

class _VisualDiffComparatorSheetState extends State<VisualDiffComparatorSheet> {
  final List<DiffLine> _diffs = [
    const DiffLine(oldLine: 1, newLine: 1, text: '{', type: DiffType.same),
    const DiffLine(oldLine: 2, newLine: 2, text: '  "version": "1.0.0",', type: DiffType.removed),
    const DiffLine(oldLine: null, newLine: 2, text: '  "version": "2.0.0-rc1",', type: DiffType.added),
    const DiffLine(oldLine: 3, newLine: 3, text: '  "port": 50052,', type: DiffType.same),
    const DiffLine(oldLine: 4, newLine: 4, text: '  "max_bandwidth_mbps": 100,', type: DiffType.removed),
    const DiffLine(oldLine: null, newLine: 4, text: '  "max_bandwidth_mbps": 250,', type: DiffType.added),
    const DiffLine(oldLine: null, newLine: 5, text: '  "resumable_chunks": true,', type: DiffType.added),
    const DiffLine(oldLine: 5, newLine: 6, text: '  "zero_trust": true', type: DiffType.same),
    const DiffLine(oldLine: 6, newLine: 7, text: '}', type: DiffType.same),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.difference_outlined, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visual Diff Comparator',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${widget.fileAName} ↔ ${widget.fileBName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          // Header Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text('3 additions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                SizedBox(width: 12),
                Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                SizedBox(width: 4),
                Text('2 deletions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C))),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: ListView.builder(
              itemCount: _diffs.length,
              itemBuilder: (context, idx) {
                final line = _diffs[idx];
                Color bgColor = Colors.transparent;
                Color textColor = const Color(0xFF0F172A);
                String prefix = ' ';

                if (line.type == DiffType.added) {
                  bgColor = const Color(0xFFDCFCE7);
                  textColor = const Color(0xFF15803D);
                  prefix = '+';
                } else if (line.type == DiffType.removed) {
                  bgColor = const Color(0xFFFEE2E2);
                  textColor = const Color(0xFFB91C1C);
                  prefix = '-';
                }

                return Container(
                  color: bgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          line.oldLine?.toString() ?? '',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text(
                          line.newLine?.toString() ?? '',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        prefix,
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: textColor),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          line.text,
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: textColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
