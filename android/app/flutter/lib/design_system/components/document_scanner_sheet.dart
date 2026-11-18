import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_settings_service.dart';
import '../../core/document_scanner_service.dart';
import '../../core/file_converter_service.dart';
import '../colors/peerlink_colors.dart';

/// Minimalist Light-Only Document Scanner Sheet.
/// Turns photographed document pages into clean multi-page PDFs saved directly in PeerLink Vault.
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
  final List<File> _scannedPages = [];
  bool _isProcessing = false;
  File? _compiledPdf;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _addSamplePage() {
    final tempDir = Directory.systemTemp;
    final idx = _scannedPages.length + 1;
    final sampleFile = File('${tempDir.path}/scan_page_$idx.bmp');
    final bmpBytes = FileConverterService.instance.createSolidBmp(
      width: 100,
      height: 100,
      red: 250,
      green: 250,
      blue: 250,
    );
    sampleFile.writeAsBytesSync(bmpBytes);
    setState(() => _scannedPages.add(sampleFile));
  }

  Future<void> _handleCompilePdf() async {
    if (_scannedPages.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);

    final title = _titleController.text.trim();
    final vaultDir = Directory(AppSettingsService.instance.saveLocation);

    final pdf = await _scanner.compileScannedPagesToPdf(
      pageFiles: _scannedPages,
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, size: 22, color: PeerLinkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart Document Scanner',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                      ),
                      Text(
                        '${_scannedPages.length} ${_scannedPages.length == 1 ? "page" : "pages"} captured • Compiles to PDF',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Document Name',
                border: OutlineInputBorder(),
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
              child: _scannedPages.isEmpty
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
                            'Capture or add document pages, then compile into a clean PDF.',
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
                              'Pages (${_scannedPages.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            TextButton.icon(
                              onPressed: _addSamplePage,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Page', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _scannedPages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              return ListTile(
                                dense: true,
                                tileColor: const Color(0xFFF9FAFB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                leading: const Icon(Icons.description_outlined, color: PeerLinkColors.primaryBlue),
                                title: Text('Page ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text(_scannedPages[idx].uri.pathSegments.last, style: const TextStyle(fontSize: 11)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFEF4444)),
                                  onPressed: () => setState(() => _scannedPages.removeAt(idx)),
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
              onPressed: _scannedPages.isEmpty || _isProcessing ? null : _handleCompilePdf,
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(_isProcessing ? 'Compiling PDF...' : 'Compile ${_scannedPages.length} Pages into PDF & Save to Vault'),
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
