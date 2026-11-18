import 'package:flutter/material.dart';
import '../../core/offline_full_text_search_service.dart';
import '../../core/received_files_service.dart';
import '../colors/peerlink_colors.dart';
import 'media_preview_modal.dart';

/// Minimalist Light-Only Full-Text Content Search Sheet.
/// Searches INSIDE files (.txt, .md, .csv, .json, .docx, .pdf) locally and extracts context snippets.
class ContentSearchSheet extends StatefulWidget {
  const ContentSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContentSearchSheet(),
    );
  }

  @override
  State<ContentSearchSheet> createState() => _ContentSearchSheetState();
}

class _ContentSearchSheetState extends State<ContentSearchSheet> {
  final OfflineFullTextSearchService _searcher = OfflineFullTextSearchService.instance;
  final TextEditingController _queryController = TextEditingController();
  List<SearchResultItem> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    final hits = _searcher.search(clean);
    setState(() {
      _results = hits;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(Icons.manage_search_rounded, size: 22, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full-Text Content Search',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        'Searches deep inside file text (100% Offline)',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Input
            TextField(
              key: const Key('content_search_text_field'),
              controller: _queryController,
              autofocus: true,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search text inside notes, docs, CSV, JSON...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _queryController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Search Results
            Expanded(
              child: !_hasSearched
                  ? Center(
                      child: Text(
                        'Indexed ${_searcher.indexedDocumentCount} documents locally.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching text found inside Vault documents.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          itemBuilder: (ctx, idx) {
                            final hit = _results[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Icon(Icons.description_outlined, color: PeerLinkColors.primaryBlue, size: 18),
                              ),
                              title: Text(
                                hit.fileName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              subtitle: Text(
                                hit.snippet,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9CA3AF)),
                              onTap: () {
                                final item = ReceivedFileItem(
                                  path: hit.filePath,
                                  name: hit.fileName,
                                  sizeBytes: 0,
                                  lastModified: DateTime.now(),
                                  category: ReceivedFileCategory.documents,
                                  extension: hit.fileName.split('.').lastOrNull ?? '',
                                );
                                Navigator.pop(context);
                                MediaPreviewModal.show(context, item);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
