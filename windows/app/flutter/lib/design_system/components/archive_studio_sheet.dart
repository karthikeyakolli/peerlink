import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/archive_extractor_service.dart';
import '../../core/archive_studio_service.dart';

/// Minimalist Light-only in-place ZIP & Archive Studio modal.
/// Enables selective single-file extraction without extracting entire archives to disk.
class ArchiveStudioSheet extends StatefulWidget {
  final String archivePath;
  final VoidCallback? onExtracted;

  const ArchiveStudioSheet({
    super.key,
    required this.archivePath,
    this.onExtracted,
  });

  static Future<void> show(BuildContext context, {required String archivePath, VoidCallback? onExtracted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArchiveStudioSheet(
        archivePath: archivePath,
        onExtracted: onExtracted,
      ),
    );
  }

  @override
  State<ArchiveStudioSheet> createState() => _ArchiveStudioSheetState();
}

class _ArchiveStudioSheetState extends State<ArchiveStudioSheet> {
  ArchiveDetails? _details;
  bool _isLoading = true;
  String _filterQuery = '';
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadArchiveDetails();
  }

  Future<void> _loadArchiveDetails() async {
    setState(() => _isLoading = true);
    final details = await ArchiveStudioService.instance.inspectArchive(widget.archivePath);
    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
      });
    }
  }

  Future<void> _extractSingle(ArchiveEntry entry) async {
    setState(() => _statusMessage = 'Extracting ${entry.name}...');
    final zipFile = File(widget.archivePath);
    final targetDir = '${zipFile.parent.path}/Extracted_${zipFile.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '')}';

    final extracted = await ArchiveStudioService.instance.extractSingleEntry(
      widget.archivePath,
      entry.path,
      targetDir,
    );

    if (mounted) {
      setState(() {
        if (extracted != null && extracted.existsSync()) {
          _statusMessage = 'Extracted: ${entry.name}';
        } else {
          _statusMessage = 'Extraction complete to $targetDir';
        }
      });
      widget.onExtracted?.call();
    }
  }

  Future<void> _extractAll() async {
    setState(() => _statusMessage = 'Extracting entire archive...');
    try {
      final out = await ArchiveExtractorService.instance.extractArchive(widget.archivePath);
      if (mounted) {
        setState(() => _statusMessage = 'All files unpacked to $out');
        widget.onExtracted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Extraction failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.archivePath.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
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
                  child: const Icon(Icons.folder_zip_outlined, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _details != null
                            ? '${_details!.fileCount} files • ${_details!.formattedTotalSize}'
                            : 'Reading archive contents...',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (_details != null && _details!.compressionRatio < 0.99)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      '${((1.0 - _details!.compressionRatio) * 100).toStringAsFixed(0)}% smaller',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Status message banner
          if (_statusMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Search inside archive
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search files inside archive...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (val) => setState(() => _filterQuery = val.trim().toLowerCase()),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Entry List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _buildEntriesList(),
          ),

          // Bottom Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('archive_extract_all_button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.unarchive_outlined, size: 18),
                    label: const Text('Extract All', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: _extractAll,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('archive_done_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    final allEntries = _details?.entries ?? [];
    final filtered = _filterQuery.isEmpty
        ? allEntries
        : allEntries.where((e) => e.name.toLowerCase().contains(_filterQuery) || e.path.toLowerCase().contains(_filterQuery)).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _filterQuery.isEmpty ? 'Archive is empty' : 'No matching files found',
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return ListTile(
          dense: true,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: entry.isDirectory ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              entry.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_outlined,
              color: entry.isDirectory ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              size: 18,
            ),
          ),
          title: Text(
            entry.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            entry.path,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.formattedSize,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              if (!entry.isDirectory) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: Key('extract_single_button_$index'),
                  icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF2563EB)),
                  tooltip: 'Extract this file',
                  onPressed: () => _extractSingle(entry),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
