import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/file_integrity_diff_service.dart';

/// Minimalist Light-Only File Integrity Verifier (SHA-256 / MD5) & Text Diff Viewer.
class FileHashDiffSheet extends StatefulWidget {
  final String primaryFilePath;
  final String primaryFileName;
  final String? compareFilePath;
  final String? compareFileName;

  const FileHashDiffSheet({
    super.key,
    required this.primaryFilePath,
    required this.primaryFileName,
    this.compareFilePath,
    this.compareFileName,
  });

  static Future<void> showChecksumVerifier(
    BuildContext context, {
    required String filePath,
    required String fileName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FileHashDiffSheet(
        primaryFilePath: filePath,
        primaryFileName: fileName,
      ),
    );
  }

  static Future<void> showTextDiff(
    BuildContext context, {
    required String leftPath,
    required String leftName,
    required String rightPath,
    required String rightName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FileHashDiffSheet(
        primaryFilePath: leftPath,
        primaryFileName: leftName,
        compareFilePath: rightPath,
        compareFileName: rightName,
      ),
    );
  }

  @override
  State<FileHashDiffSheet> createState() => _FileHashDiffSheetState();
}

class _FileHashDiffSheetState extends State<FileHashDiffSheet> {
  final TextEditingController _expectedHashCtrl = TextEditingController();
  late FileChecksumReport _checksum;
  TextDiffReport? _diffReport;

  bool get _isDiffMode => widget.compareFilePath != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant FileHashDiffSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryFilePath != widget.primaryFilePath ||
        oldWidget.compareFilePath != widget.compareFilePath) {
      _loadData();
    }
  }

  void _loadData() {
    _checksum = FileIntegrityDiffService.instance.computeChecksumsSync(widget.primaryFilePath);
    if (_isDiffMode) {
      try {
        final left = File(widget.primaryFilePath).readAsStringSync();
        final right = File(widget.compareFilePath!).readAsStringSync();
        _diffReport = FileIntegrityDiffService.instance.diffText(left, right);
      } catch (_) {
        _diffReport = null;
      }
    } else {
      _diffReport = null;
    }
  }

  @override
  void dispose() {
    _expectedHashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pasted = _expectedHashCtrl.text.trim();
    final hasPaste = pasted.isNotEmpty;
    final matches = hasPaste && _checksum.matchesExpected(pasted);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Icon(
                      _isDiffMode ? Icons.compare_arrows_rounded : Icons.verified_outlined,
                      color: const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDiffMode ? 'Text Diff Comparison' : 'File Hash & Integrity Verifier',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          _isDiffMode
                              ? '${widget.primaryFileName} vs ${widget.compareFileName}'
                              : widget.primaryFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 22, color: Color(0xFFE5E7EB)),

              if (_isDiffMode && _diffReport != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _diffBadge('+${_diffReport!.addedCount} added', const Color(0xFF15803D), const Color(0xFFECFDF5)),
                    _diffBadge('-${_diffReport!.removedCount} removed', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                    _diffBadge('${_diffReport!.unchangedCount} unchanged', const Color(0xFF475569), const Color(0xFFF1F5F9)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  key: const Key('text_diff_container'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _diffReport!.lines.map((line) {
                      final bg = switch (line.kind) {
                        DiffLineKind.added => const Color(0xFFECFDF5),
                        DiffLineKind.removed => const Color(0xFFFEF2F2),
                        DiffLineKind.unchanged => Colors.transparent,
                      };
                      final fg = switch (line.kind) {
                        DiffLineKind.added => const Color(0xFF166534),
                        DiffLineKind.removed => const Color(0xFF991B1B),
                        DiffLineKind.unchanged => const Color(0xFF334155),
                      };
                      final prefix = switch (line.kind) {
                        DiffLineKind.added => '+ ',
                        DiffLineKind.removed => '- ',
                        DiffLineKind.unchanged => '  ',
                      };
                      return Container(
                        color: bg,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '$prefix${line.text}',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: fg),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                _buildHashRow('SHA-256', _checksum.sha256Hex),
                const SizedBox(height: 10),
                _buildHashRow('MD5', _checksum.md5Hex),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('expected_checksum_field'),
                  controller: _expectedHashCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Paste expected SHA-256 or MD5 to verify',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (hasPaste) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('checksum_match_banner'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: matches ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: matches ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          matches ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                          color: matches ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            matches
                                ? 'Checksum Verified — File is 100% intact'
                                : 'Checksum Mismatch — File differs from expected hash',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: matches ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _diffBadge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildHashRow(String label, String hash) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: hash));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: const Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            hash,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
