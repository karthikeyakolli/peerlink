import 'package:flutter/material.dart';
import '../../core/inbox_routing_service.dart';

/// Minimalist Light-Only Deterministic "Auto-Sort Inbox" Rules Sheet.
/// Shows explicit rule toggles, live dry-run preview of files to organize, and 1-tap Run.
class AutoSortRulesSheet extends StatefulWidget {
  final VoidCallback? onSorted;

  const AutoSortRulesSheet({super.key, this.onSorted});

  static Future<void> show(BuildContext context, {VoidCallback? onSorted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutoSortRulesSheet(onSorted: onSorted),
    );
  }

  @override
  State<AutoSortRulesSheet> createState() => _AutoSortRulesSheetState();
}

class _AutoSortRulesSheetState extends State<AutoSortRulesSheet> {
  final InboxRoutingService _routing = InboxRoutingService.instance;
  bool _running = false;

  Future<void> _runAutoSort() async {
    setState(() => _running = true);
    final count = await _routing.applyAutoSort();
    if (!mounted) return;
    setState(() => _running = false);
    widget.onSorted?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Auto-sorted $count file(s) into organized folders'
              : 'Inbox is already organized — 0 files needed moving',
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = _routing.rules;
    final preview = _routing.previewAutoSort();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                  child: const Icon(Icons.rule_folder_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Sort Inbox Rules',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Deterministic local filing — zero cloud, zero AI guessing',
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
            const Divider(height: 22, color: Color(0xFFE5E7EB)),

            // Active Rules List
            ...rules.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Destination: PeerLink/${r.targetSubfolder}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: r.enabled,
                        onChanged: (v) {
                          setState(() => _routing.toggleRule(r.id, v));
                        },
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 10),
            Text(
              'Dry-Run Preview (${preview.length} matching file${preview.length == 1 ? "" : "s"})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            if (preview.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Text(
                  'No root Vault files currently match the enabled rules.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
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
                    final a = preview[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            a.matchedRuleName,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('apply_auto_sort_button'),
              onPressed: (_running || preview.isEmpty) ? null : _runAutoSort,
              icon: const Icon(Icons.auto_awesome_motion_rounded, size: 18),
              label: Text(_running ? 'Organizing...' : 'Run Auto-Sort Now (${preview.length})'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
