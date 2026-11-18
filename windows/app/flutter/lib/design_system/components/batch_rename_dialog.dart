import 'package:flutter/material.dart';
import '../../core/batch_rename_service.dart';

/// Minimalist Light-Only Batch File Renamer with Live Before -> After Preview.
class BatchRenameDialog extends StatefulWidget {
  final List<String> paths;
  final VoidCallback? onRenamed;

  const BatchRenameDialog({
    super.key,
    required this.paths,
    this.onRenamed,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> paths,
    VoidCallback? onRenamed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchRenameDialog(paths: paths, onRenamed: onRenamed),
    );
  }

  @override
  State<BatchRenameDialog> createState() => _BatchRenameDialogState();
}

class _BatchRenameDialogState extends State<BatchRenameDialog> {
  final TextEditingController _prefixCtrl = TextEditingController();
  final TextEditingController _suffixCtrl = TextEditingController();
  final TextEditingController _findCtrl = TextEditingController();
  final TextEditingController _replaceCtrl = TextEditingController();
  final TextEditingController _seqBaseCtrl = TextEditingController(text: 'Item_');

  bool _useSequence = false;
  int _startNumber = 1;
  bool _applying = false;

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _suffixCtrl.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    _seqBaseCtrl.dispose();
    super.dispose();
  }

  BatchRenameRule get _rule => BatchRenameRule(
        prefix: _prefixCtrl.text,
        suffix: _suffixCtrl.text,
        findText: _findCtrl.text,
        replaceText: _replaceCtrl.text,
        useSequentialNumbering: _useSequence,
        sequenceBaseName: _seqBaseCtrl.text,
        startNumber: _startNumber,
      );

  Future<void> _apply(List<BatchRenamePreviewEntry> preview) async {
    setState(() => _applying = true);
    final res = await BatchRenameService.instance.applyRename(preview);
    if (!mounted) return;
    setState(() => _applying = false);
    widget.onRenamed?.call();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.errors.isEmpty
              ? 'Renamed ${res.renamedCount} file(s) successfully'
              : 'Renamed ${res.renamedCount}, ${res.errors.length} error(s)',
        ),
        backgroundColor: res.errors.isEmpty ? const Color(0xFF15803D) : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = BatchRenameService.instance.buildPreview(widget.paths, _rule);
    final hasCollisions = preview.any((e) => e.hasCollision);
    final actionableCount = preview.where((e) => !e.isUnchanged && !e.hasCollision).length;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.drive_file_rename_outline_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Rename (${widget.paths.length} files)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        const Text(
                          'Live preview before touching disk',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
              const SizedBox(height: 12),

              // Mode Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('batch_mode_pattern'),
                      label: const Text('Prefix / Replace', style: TextStyle(fontSize: 12)),
                      selected: !_useSequence,
                      onSelected: (_) => setState(() => _useSequence = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      key: const Key('batch_mode_sequence'),
                      label: const Text('Number Sequence', style: TextStyle(fontSize: 12)),
                      selected: _useSequence,
                      onSelected: (_) => setState(() => _useSequence = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_useSequence) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        key: const Key('batch_seq_base_field'),
                        controller: _seqBaseCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Base Name (e.g. Trip_)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Start #',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        controller: TextEditingController(text: '$_startNumber'),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n >= 0) {
                            setState(() => _startNumber = n);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('batch_prefix_field'),
                        controller: _prefixCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Prefix',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('batch_suffix_field'),
                        controller: _suffixCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Suffix',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('batch_find_field'),
                        controller: _findCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Find text',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('batch_replace_field'),
                        controller: _replaceCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Replace with',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),
              const Text(
                'Live Preview',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: preview.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (_, idx) {
                    final e = preview[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.originalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF94A3B8)),
                          ),
                          Expanded(
                            child: Text(
                              e.newName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: e.hasCollision
                                    ? const Color(0xFFDC2626)
                                    : (e.isUnchanged ? const Color(0xFF64748B) : const Color(0xFF15803D)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (hasCollisions) ...[
                const SizedBox(height: 8),
                const Text(
                  'Warning: One or more target filenames collide and will be skipped.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('apply_batch_rename_button'),
                onPressed: (_applying || actionableCount == 0) ? null : () => _apply(preview),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_applying ? 'Renaming...' : 'Rename $actionableCount File(s)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
