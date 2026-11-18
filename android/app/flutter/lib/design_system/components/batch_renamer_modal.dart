import 'package:flutter/material.dart';
import '../../core/batch_renamer_service.dart';

class BatchRenamerModal extends StatefulWidget {
  final List<String> filePaths;
  final VoidCallback onRenamed;

  const BatchRenamerModal({
    super.key,
    required this.filePaths,
    required this.onRenamed,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> filePaths,
    required VoidCallback onRenamed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchRenamerModal(
        filePaths: filePaths,
        onRenamed: onRenamed,
      ),
    );
  }

  @override
  State<BatchRenamerModal> createState() => _BatchRenamerModalState();
}

class _BatchRenamerModalState extends State<BatchRenamerModal> {
  final BatchRenamerService _service = BatchRenamerService.instance;
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  bool _useSequence = false;
  RenameCaseMode _caseMode = RenameCaseMode.none;
  late BatchRenamePlan _plan;
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    _updatePlan();
  }

  void _updatePlan() {
    _plan = _service.previewPlan(
      paths: widget.filePaths,
      prefix: _prefixController.text.trim(),
      suffix: _suffixController.text.trim(),
      search: _searchController.text.trim(),
      replace: _replaceController.text,
      useSequence: _useSequence,
      caseMode: _caseMode,
    );
  }

  Future<void> _apply() async {
    if (_plan.modifiedCount == 0 || _plan.hasAnyCollision || _isRenaming) return;
    setState(() => _isRenaming = true);
    final count = await _service.executePlan(_plan);
    if (!mounted) return;
    widget.onRenamed();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully renamed $count file(s)'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _suffixController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.drive_file_rename_outline_rounded, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Rename (${widget.filePaths.length} items)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Add prefix/suffix, search-replace or sequential numbers',
                          style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Prefix & Suffix
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('batch_rename_prefix_input'),
                      controller: _prefixController,
                      decoration: InputDecoration(
                        labelText: 'Prefix',
                        hintText: 'e.g. Vacation_',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(_updatePlan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('batch_rename_suffix_input'),
                      controller: _suffixController,
                      decoration: InputDecoration(
                        labelText: 'Suffix',
                        hintText: 'e.g. _FINAL',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(_updatePlan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Search & Replace
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('batch_rename_search_input'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Find',
                        hintText: 'e.g. _',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(_updatePlan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('batch_rename_replace_input'),
                      controller: _replaceController,
                      decoration: InputDecoration(
                        labelText: 'Replace with',
                        hintText: 'e.g. [space]',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(_updatePlan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Sequence toggle
              Row(
                children: [
                  Checkbox(
                    key: const Key('batch_rename_sequence_checkbox'),
                    value: _useSequence,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (v) => setState(() {
                      _useSequence = v ?? false;
                      _updatePlan();
                    }),
                  ),
                  const Text('Append counter (_01, _02...)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              // Preview Box
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _plan.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 8, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, idx) {
                    final e = _plan.entries[idx];
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.oldName,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            e.newName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: e.hasCollision
                                  ? const Color(0xFFDC2626)
                                  : (e.isModified ? const Color(0xFF2563EB) : const Color(0xFF0F172A)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (e.hasCollision)
                          const Text(' (Collision)', style: TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('apply_batch_rename_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isRenaming ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  _isRenaming ? 'Renaming...' : 'Apply (${_plan.modifiedCount} files)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: (_plan.modifiedCount == 0 || _plan.hasAnyCollision || _isRenaming)
                    ? null
                    : _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
