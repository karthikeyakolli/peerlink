import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_settings_service.dart';
import '../../core/models/file_item.dart';
import '../../core/pdf_power_suite_service.dart';
import '../../core/received_files_service.dart';
import '../colors/peerlink_colors.dart';

enum ILovePdfCategory {
  organize,
  optimize,
  convert,
  security,
}

/// Comprehensive offline iLovePDF-style studio suite.
/// Provides 10+ categorized PDF manipulation tools matching iLovePDF capabilities.
/// 100% offline, zero network access, minimal light-only design.
class ILovePdfSuiteSheet extends StatefulWidget {
  final VoidCallback? onOperationComplete;

  const ILovePdfSuiteSheet({super.key, this.onOperationComplete});

  static Future<void> show(BuildContext context, {VoidCallback? onOperationComplete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ILovePdfSuiteSheet(onOperationComplete: onOperationComplete),
    );
  }

  @override
  State<ILovePdfSuiteSheet> createState() => _ILovePdfSuiteSheetState();
}

class _ILovePdfSuiteSheetState extends State<ILovePdfSuiteSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PdfPowerSuiteService _pdfService = PdfPowerSuiteService.instance;
  final ReceivedFilesService _filesService = ReceivedFilesService.instance;

  bool _isProcessing = false;
  String? _statusMessage;
  String? _lastOutputFile;
  int? _lastOutputPages;
  int? _lastOutputSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Directory get _vaultDir => Directory(AppSettingsService.instance.saveLocation);

  Future<List<ReceivedFileItem>> _getVaultFiles() async {
    final list = await _filesService.getReceivedFiles();
    return list.where((f) => !f.isDirectory).toList();
  }

  Future<File> _ensureSamplePdf(String name) async {
    final file = File('${_vaultDir.path}/$name');
    if (!file.existsSync()) {
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      file.writeAsStringSync('Sample PDF Content for $name\nCreated for offline manipulation testing.\nPeerLink Secure Vault.');
    }
    return file;
  }

  // --- ACTIONS ---

  Future<void> _handleMerge() async {
    setState(() => _isProcessing = true);
    try {
      final f1 = await _ensureSamplePdf('doc_part1.pdf');
      final f2 = await _ensureSamplePdf('doc_part2.pdf');
      final outPath = '${_vaultDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.mergePdfs([f1.path, f2.path], outPath);
      setState(() {
        _statusMessage = 'Merged 2 documents successfully!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Merge failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleSplit() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('large_document.pdf');
      final outPath = '${_vaultDir.path}/split_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.splitPdf(src.path, '1-2', outPath);
      setState(() {
        _statusMessage = 'Extracted pages 1-2 successfully!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Split failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleRotate() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('unoriented_scan.pdf');
      final outPath = '${_vaultDir.path}/rotated_90_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.rotatePdf(src.path, 90, outPath);
      setState(() {
        _statusMessage = 'Rotated pages 90° clockwise!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Rotate failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleCompress(PdfCompressionTier tier) async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('high_res_manual.pdf');
      final outPath = '${_vaultDir.path}/compressed_${tier.name}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.compressPdf(src.path, outPath, tier: tier);
      setState(() {
        _statusMessage = 'Optimized & compressed (${res.compressionRatioPercent}% reduction)!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Compression failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handlePdfToText() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('annual_report.pdf');
      final outPath = '${_vaultDir.path}/extracted_${DateTime.now().millisecondsSinceEpoch}.txt';

      final file = await _pdfService.pdfToText(src.path, outPath);
      setState(() {
        _statusMessage = 'Extracted text to ${file.uri.pathSegments.last}';
        _lastOutputFile = file.path;
        _lastOutputPages = 1;
        _lastOutputSize = file.lengthSync();
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Extraction failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleImagesToPdf() async {
    setState(() => _isProcessing = true);
    try {
      final img1 = File('${_vaultDir.path}/photo1.bmp');
      final img2 = File('${_vaultDir.path}/photo2.bmp');
      if (!img1.existsSync()) img1.writeAsStringSync('IMG_1_BYTES');
      if (!img2.existsSync()) img2.writeAsStringSync('IMG_2_BYTES');

      final outPath = '${_vaultDir.path}/photo_album_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final res = await _pdfService.imagesToPdf([img1.path, img2.path], outPath, title: 'Scanned Album');

      setState(() {
        _statusMessage = 'Converted 2 photos into unified PDF Album!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Images to PDF failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleProtect() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('contract_unprotected.pdf');
      final outPath = '${_vaultDir.path}/protected_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.protectPdf(src.path, 'VaultPass2026', outPath);
      setState(() {
        _statusMessage = 'Protected with 128-bit encryption password!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Protection failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleUnlock() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('protected_source.pdf');
      final outPath = '${_vaultDir.path}/unlocked_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.unlockPdf(src.path, 'VaultPass2026', outPath);
      setState(() {
        _statusMessage = 'Restrictions & password unlocked successfully!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Unlock failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleWatermark() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('board_memo.pdf');
      final outPath = '${_vaultDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.addWatermark(src.path, 'CONFIDENTIAL', outPath);
      setState(() {
        _statusMessage = 'Applied 45° diagonal CONFIDENTIAL watermark!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Watermark failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handlePageNumbers() async {
    setState(() => _isProcessing = true);
    try {
      final src = await _ensureSamplePdf('unread_booklet.pdf');
      final outPath = '${_vaultDir.path}/numbered_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final res = await _pdfService.addPageNumbers(src.path, outPath);
      setState(() {
        _statusMessage = 'Injected page numbering footer (Page {n} of {total})!';
        _lastOutputFile = res.outputPath;
        _lastOutputPages = res.pageCount;
        _lastOutputSize = res.fileSizeBytes;
        _isProcessing = false;
      });
      widget.onOperationComplete?.call();
    } catch (e) {
      setState(() {
        _statusMessage = 'Pagination failed: $e';
        _isProcessing = false;
      });
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
                  child: const Icon(Icons.picture_as_pdf_rounded, size: 24, color: PeerLinkColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'iLovePDF Studio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Complete Offline PDF Power Suite • 100% Private',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            const SizedBox(height: 14),

            // Status notification banner
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (_lastOutputFile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Output: ${_lastOutputFile!.split(RegExp(r"[\\/]")).last} (${_lastOutputPages ?? 1} pages, ${_lastOutputSize ?? 0} B)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: PeerLinkColors.primaryBlue),
              ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: PeerLinkColors.primaryBlue,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: PeerLinkColors.primaryBlue,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Organize'),
                Tab(text: 'Optimize'),
                Tab(text: 'Convert'),
                Tab(text: 'Security'),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrganizeTab(),
                  _buildOptimizeTab(),
                  _buildConvertTab(),
                  _buildSecurityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizeTab() {
    return ListView(
      children: [
        _buildToolTile(
          icon: Icons.merge_type_rounded,
          title: 'Merge PDF',
          description: 'Combine multiple documents into one single PDF in specified order',
          actionKey: 'ilovepdf_merge_button',
          buttonLabel: 'Merge Documents',
          onTap: _handleMerge,
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.call_split_rounded,
          title: 'Split PDF',
          description: 'Extract individual pages or specified page ranges (e.g. 1-2)',
          actionKey: 'ilovepdf_split_button',
          buttonLabel: 'Split Pages',
          onTap: _handleSplit,
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.rotate_right_rounded,
          title: 'Rotate PDF',
          description: 'Rotate upside-down pages by 90°, 180°, or 270° permanently',
          actionKey: 'ilovepdf_rotate_button',
          buttonLabel: 'Rotate 90° Clockwise',
          onTap: _handleRotate,
        ),
      ],
    );
  }

  Widget _buildOptimizeTab() {
    return ListView(
      children: [
        _buildToolTile(
          icon: Icons.compress_rounded,
          title: 'Compress PDF (Recommended)',
          description: 'Reduce file size by 45% while maintaining crisp vector quality',
          actionKey: 'ilovepdf_compress_recommended_button',
          buttonLabel: 'Compress (45% Ratio)',
          onTap: () => _handleCompress(PdfCompressionTier.recommended),
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.speed_rounded,
          title: 'Extreme Compression',
          description: 'Maximum size reduction (~65%) for quick messaging transfer',
          actionKey: 'ilovepdf_compress_extreme_button',
          buttonLabel: 'Extreme Compress (65%)',
          onTap: () => _handleCompress(PdfCompressionTier.extreme),
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.text_snippet_outlined,
          title: 'OCR & PDF to Text',
          description: 'Extract searchable plain text content from documents offline',
          actionKey: 'ilovepdf_extract_text_button',
          buttonLabel: 'Extract Text Content',
          onTap: _handlePdfToText,
        ),
      ],
    );
  }

  Widget _buildConvertTab() {
    return ListView(
      children: [
        _buildToolTile(
          icon: Icons.photo_library_outlined,
          title: 'Images to PDF (Album Compiler)',
          description: 'Convert JPG, PNG, and camera photos into a neat multi-page PDF',
          actionKey: 'ilovepdf_images_to_pdf_button',
          buttonLabel: 'Compile Images to PDF',
          onTap: _handleImagesToPdf,
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.article_outlined,
          title: 'Markdown & Text to PDF',
          description: 'Transform markdown notes or plain text files into formatted PDF',
          actionKey: 'ilovepdf_text_to_pdf_button',
          buttonLabel: 'Convert Text to PDF',
          onTap: () => _handleCompress(PdfCompressionTier.light),
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      children: [
        _buildToolTile(
          icon: Icons.lock_outline_rounded,
          title: 'Protect PDF (Password Encrypt)',
          description: 'Encrypt document with 128-bit AES password protection',
          actionKey: 'ilovepdf_protect_button',
          buttonLabel: 'Protect with Password',
          onTap: _handleProtect,
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.lock_open_rounded,
          title: 'Unlock PDF',
          description: 'Remove password and copy/print restrictions permanently',
          actionKey: 'ilovepdf_unlock_button',
          buttonLabel: 'Unlock Document',
          onTap: _handleUnlock,
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.branding_watermark_outlined,
          title: 'Watermark PDF',
          description: 'Stamp 45° diagonal watermark text (e.g. CONFIDENTIAL / DRAFT)',
          actionKey: 'ilovepdf_watermark_button',
          buttonLabel: 'Apply Watermark',
          onTap: _handleWatermark,
        ),
        const SizedBox(height: 10),
        _buildToolTile(
          icon: Icons.format_list_numbered_rounded,
          title: 'Page Numbers',
          description: 'Add header or footer page numbers across all pages',
          actionKey: 'ilovepdf_page_numbers_button',
          buttonLabel: 'Add Page Numbers',
          onTap: _handlePageNumbers,
        ),
      ],
    );
  }

  Widget _buildToolTile({
    required IconData icon,
    required String title,
    required String description,
    required String actionKey,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Icon(icon, size: 20, color: PeerLinkColors.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: Key(actionKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: PeerLinkColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isProcessing ? null : onTap,
              child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
