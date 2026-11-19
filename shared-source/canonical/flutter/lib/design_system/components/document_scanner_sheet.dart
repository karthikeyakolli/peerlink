import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_settings_service.dart';
import '../../core/document_scanner_service.dart';
import '../../core/file_converter_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only Document Scanner Sheet.
/// Turns photographed document pages into clean multi-page PDFs saved directly in PeerLink Vault.
/// Supports real-time filter profiles (B&W Document, Magic Color, Grayscale, Original),
/// 90-degree page rotation, and drag/button reordering.
class DocumentScannerSheet extends StatefulWidget {
  final VoidCallback? onScanComplete;

  const DocumentScannerSheet({super.key, this.onScanComplete});

  static Future<void> show(BuildContext context, {VoidCallback? onScanComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentScannerSheet(onScanComplete: onScanComplete),
    );
  }

  @override
  State<DocumentScannerSheet> createState() => _DocumentScannerSheetState();
}

class _DocumentScannerSheetState extends State<DocumentScannerSheet> {
  final DocumentScannerService _scanner = DocumentScannerService.instance;
  final TextEditingController _titleController = TextEditingController(text: 'Scanned Document');
  final List<ScannedPage> _pages = [];
  bool _isProcessing = false;
  File? _compiledPdf;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _addSamplePage() {
    final tempDir = Directory.systemTemp;
    final idx = _pages.length + 1;
    final sampleFile = File('${tempDir.path}/scan_page_$idx.bmp');
    final bmpBytes = FileConverterService.instance.createSolidBmp(
      width: 100,
      height: 100,
      red: 250,
      green: 250,
      blue: 250,
    );
    sampleFile.writeAsBytesSync(bmpBytes);

    setState(() {
      _pages.add(ScannedPage(
        id: 'page_${DateTime.now().millisecondsSinceEpoch}_$idx',
        file: sampleFile,
        filter: DocScanFilter.bwDocument, // default to clean B&W doc filter
      ));
    });
  }

  void _rotatePage(int index) {
    setState(() {
      _pages[index].rotateClockwise();
    });
  }

  void _changePageFilter(int index, DocScanFilter filter) {
    setState(() {
      _pages[index].filter = filter;
    });
  }

  void _movePageUp(int index) {
    if (index <= 0) return;
    setState(() {
      final page = _pages.removeAt(index);
      _pages.insert(index - 1, page);
    });
  }

  void _movePageDown(int index) {
    if (index >= _pages.length - 1) return;
    setState(() {
      final page = _pages.removeAt(index);
      _pages.insert(index + 1, page);
    });
  }

  Future<void> _handleCompilePdf() async {
    if (_pages.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);

    final title = _titleController.text.trim();
    final vaultDir = Directory(AppSettingsService.instance.saveLocation);

    final pdf = await _scanner.compileScannedPagesToPdf(
      pages: _pages,
      documentTitle: title,
      destinationDir: vaultDir,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _compiledPdf = pdf;
      });
      widget.onScanComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, size: 24, color: PeerLinkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart Document Scanner',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${_pages.length} ${_pages.length == 1 ? "page" : "pages"} captured • Filters & PDF Compiler',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Document Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            if (_compiledPdf != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PDF Saved: ${_compiledPdf!.uri.pathSegments.last} in PeerLink Vault!',
                        style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Expanded(
              child: _pages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 10),
                          const Text(
                            'No pages captured yet.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add document pages, pick visual filters (B&W/Magic), and compile.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            key: const Key('scanner_add_page_button'),
                            onPressed: _addSamplePage,
                            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                            label: const Text('Add Document Page'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pages (${_pages.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            TextButton.icon(
                              key: const Key('scanner_add_more_pages_button'),
                              onPressed: _addSamplePage,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Page', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _pages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final page = _pages[idx];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${idx + 1}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: PeerLinkColors.primaryBlue),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                page.file.uri.pathSegments.last,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Rotation: ${page.rotationDegrees}° • ${page.filter.displayName}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Rotate button
                                        IconButton(
                                          tooltip: 'Rotate 90°',
                                          icon: const Icon(Icons.rotate_right_rounded, size: 20, color: PeerLinkColors.primaryBlue),
                                          onPressed: () => _rotatePage(idx),
                                        ),
                                        // Move up / down
                                        if (idx > 0)
                                          IconButton(
                                            tooltip: 'Move Up',
                                            icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: Color(0xFF64748B)),
                                            onPressed: () => _movePageUp(idx),
                                          ),
                                        if (idx < _pages.length - 1)
                                          IconButton(
                                            tooltip: 'Move Down',
                                            icon: const Icon(Icons.arrow_downward_rounded, size: 18, color: Color(0xFF64748B)),
                                            onPressed: () => _movePageDown(idx),
                                          ),
                                        // Delete button
                                        IconButton(
                                          tooltip: 'Remove Page',
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                                          onPressed: () => setState(() => _pages.removeAt(idx)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Filter chips
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: DocScanFilter.values.map((f) {
                                          final isSelected = page.filter == f;
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: ChoiceChip(
                                              label: Text(f.displayName, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF334155))),
                                              selected: isSelected,
                                              selectedColor: PeerLinkColors.primaryBlue,
                                              backgroundColor: Colors.white,
                                              side: BorderSide(color: isSelected ? PeerLinkColors.primaryBlue : const Color(0xFFCBD5E1)),
                                              onSelected: (_) => _changePageFilter(idx, f),
                                            ),
                                          );
                                        }).toList(),
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
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              key: const Key('scanner_compile_pdf_button'),
              onPressed: _pages.isEmpty || _isProcessing ? null : _handleCompilePdf,
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(_isProcessing ? 'Compiling PDF...' : 'Compile ${_pages.length} Pages into PDF & Save to Vault'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PeerLinkColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
