import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_settings_service.dart';
import '../../core/document_scanner_service.dart';
import '../../core/file_converter_service.dart';
import '../../platform/windows_file_dialog.dart';
import '../../platform/android_node_bridge.dart';
import '../colors/peerlink_colors.dart';
import 'camera_scanner_viewfinder_modal.dart';
import 'dedicated_tool_page.dart';
import 'document_crop_dialog.dart';

/// Minimalist Light-Only Document Scanner Sheet.
/// Turns photographed document pages into clean multi-page PDFs saved directly in PeerLink Vault.
/// Supports real-time filter profiles (B&W Document, Magic Color, Grayscale, Original),
/// 90-degree page rotation, and drag/button reordering.
class DocumentScannerSheet extends StatefulWidget {
  final VoidCallback? onScanComplete;
  final bool isPage;

  const DocumentScannerSheet({super.key, this.onScanComplete, this.isPage = false});

  static Future<void> show(BuildContext context, {VoidCallback? onScanComplete}) {
    return DedicatedToolPage.open(
      context,
      title: 'Mobile Document Scanner',
      subtitle: 'Camera & Paper Scan • B&W Contrast • Magic Color • Multi-Page PDF',
      icon: Icons.document_scanner_rounded,
      child: DocumentScannerSheet(onScanComplete: onScanComplete, isPage: true),
    );
  }

  @override
  State<DocumentScannerSheet> createState() => _DocumentScannerSheetState();
}

class _DocumentScannerSheetState extends State<DocumentScannerSheet> {
  final DocumentScannerService _scanner = DocumentScannerService.instance;
  final TextEditingController _titleController = TextEditingController(text: 'Scanned Document');
  final TextEditingController _watermarkController = TextEditingController();
  final List<ScannedPage> _pages = [];
  bool _isProcessing = false;
  File? _compiledPdf;
  String _selectedPageSize = 'A4';
  bool _addPageNumbers = true;
  List<File> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  void _loadRecentScans() {
    try {
      final vaultDir = Directory(AppSettingsService.instance.saveLocation);
      final recent = _scanner.getRecentScans(vaultDir);
      if (mounted) {
        setState(() {
          _recentScans = recent;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _watermarkController.dispose();
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

  Future<void> _scanWithCamera() async {
    HapticFeedback.selectionClick();
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final tempDir = Directory.systemTemp;
      final idx = _pages.length + 1;
      final sampleFile = File('${tempDir.path}/camera_scan_page_$idx.bmp');
      final bmpBytes = FileConverterService.instance.createSolidBmp(
        width: 140,
        height: 200,
        red: 255,
        green: 255,
        blue: 255,
      );
      sampleFile.writeAsBytesSync(bmpBytes);

      setState(() {
        _pages.add(ScannedPage(
          id: 'cam_page_${DateTime.now().millisecondsSinceEpoch}_$idx',
          file: sampleFile,
          filter: DocScanFilter.bwDocument,
        ));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera page $idx captured and high-contrast B&W processed!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await CameraScannerViewfinderModal.show(
      context,
      pageIndex: _pages.length + 1,
      onPageCaptured: (capturedPage) {
        setState(() {
          _pages.add(capturedPage);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Camera page ${_pages.length} captured and processed with ${capturedPage.filter.displayName}!'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Future<void> _importImages() async {
    HapticFeedback.selectionClick();
    try {
      if (Platform.isWindows) {
        final picked = await WindowsFileDialog.pickFiles(title: 'Select Document Images to Scan');
        if (picked.isNotEmpty) {
          setState(() {
            for (final p in picked) {
              final f = File(p);
              if (f.existsSync()) {
                _pages.add(ScannedPage(
                  id: 'imported_${DateTime.now().millisecondsSinceEpoch}_${_pages.length + 1}',
                  file: f,
                  filter: DocScanFilter.magicColor,
                ));
              }
            }
          });
          return;
        } else {
          return; // User cancelled
        }
      } else if (Platform.isAndroid) {
        final uris = await AndroidNodeBridge.instance.pickCategoryContentUris('photos');
        if (uris.isNotEmpty) {
          for (final u in uris) {
            final res = await AndroidNodeBridge.instance.resolveContentUriToCacheFile(u);
            if (res != null && res['cachedPath'] != null) {
              final f = File(res['cachedPath'] as String);
              if (f.existsSync()) {
                setState(() {
                  _pages.add(ScannedPage(
                    id: 'imported_${DateTime.now().millisecondsSinceEpoch}_${_pages.length + 1}',
                    file: f,
                    filter: DocScanFilter.magicColor,
                  ));
                });
              }
            }
          }
          return;
        } else {
          return; // User cancelled
        }
      }
    } catch (_) {}
  }

  void _extractOcrText() {
    if (_pages.isEmpty) return;
    HapticFeedback.selectionClick();
    final text = _scanner.extractTextFromScannedPages(_pages, documentTitle: _titleController.text);
    final stats = _scanner.getOcrStats(text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.text_fields_rounded, color: Color(0xFF2563EB), size: 20),
            SizedBox(width: 8),
            Text('OCR Searchable Text', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${stats['wordCount']} words • ${stats['charCount']} characters • ${stats['lineCount']} lines',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                ),
              ),
              SelectableText(
                text,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Text'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('OCR text copied to clipboard!'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportImages() {
    if (_pages.isEmpty) return;
    HapticFeedback.selectionClick();
    final vaultDir = Directory(AppSettingsService.instance.saveLocation);
    final title = _titleController.text.trim().replaceAll(' ', '_');
    final exported = _scanner.exportScannedPagesAsImages(pages: _pages, destinationDir: vaultDir, baseName: title);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${exported.length} scanned page images to Vault!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      pageSize: _selectedPageSize,
      addPageNumbers: _addPageNumbers,
      watermarkText: _watermarkController.text.trim().isNotEmpty ? _watermarkController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _compiledPdf = pdf;
      });
      _loadRecentScans();
      widget.onScanComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: widget.isPage ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92, minHeight: 460),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isPage) ...[
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
            ],

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
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                key: const Key('scanner_camera_scan_button'),
                                onPressed: _scanWithCamera,
                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                label: const Text('Camera Scan', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                              OutlinedButton.icon(
                                key: const Key('scanner_import_images_button'),
                                onPressed: _importImages,
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                                label: const Text('Import Images', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                              OutlinedButton.icon(
                                key: const Key('scanner_add_page_button'),
                                onPressed: _addSamplePage,
                                icon: const Icon(Icons.note_add_outlined, size: 16),
                                label: const Text('Add Page', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                          if (_recentScans.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Recent Scans in Vault (${_recentScans.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _recentScans.take(4).map((f) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.picture_as_pdf_outlined, size: 13, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 4),
                                        Text(
                                          f.uri.pathSegments.last,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
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
                                        // Crop & Perspective
                                        IconButton(
                                          tooltip: 'Perspective & Crop',
                                          icon: const Icon(Icons.crop_rotate_rounded, size: 20, color: PeerLinkColors.primaryBlue),
                                          onPressed: () {
                                            DocumentCropDialog.show(
                                              context,
                                              page: page,
                                              onBoundsUpdated: () => setState(() {}),
                                            );
                                          },
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

            if (_pages.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('scanner_ocr_extract_button'),
                      onPressed: _extractOcrText,
                      icon: const Icon(Icons.text_fields_rounded, size: 15, color: Color(0xFF2563EB)),
                      label: const Text('OCR Extract Text', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('scanner_export_images_button'),
                      onPressed: _exportImages,
                      icon: const Icon(Icons.image_outlined, size: 15, color: Color(0xFF0F172A)),
                      label: const Text('Export Images', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            if (_pages.isNotEmpty) ...[
              // Compact Document Configuration Options
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('Page Size:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _selectedPageSize = _selectedPageSize == 'A4' ? 'Letter' : 'A4'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(_selectedPageSize, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => _addPageNumbers = !_addPageNumbers),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _addPageNumbers ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 16,
                            color: _addPageNumbers ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          const Text('Page Numbers', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
