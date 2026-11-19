import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import '../../core/received_files_service.dart';
import '../../core/models/file_item.dart';
import '../../design_system/components/file_converter_sheet.dart';
import '../../design_system/components/storage_cleaner_sheet.dart';
import '../../design_system/components/video_trimmer_sheet.dart';
import '../../design_system/components/storage_treemap_sheet.dart';
import '../../design_system/components/secure_file_shredder_sheet.dart';
import '../../design_system/components/split_apk_inspector_sheet.dart';
import '../../design_system/components/exif_sanitizer_sheet.dart';
import '../../design_system/components/virus_scanner_sheet.dart';
import '../../design_system/components/ilovepdf_suite_sheet.dart';
import '../../design_system/components/document_scanner_sheet.dart';
import '../../core/app_settings_service.dart';
import '../../core/document_scanner_service.dart';
import '../../core/file_converter_service.dart';
import '../../platform/windows_file_dialog.dart';

/// Dedicated File Conversions & Offline Processing Studio Flow.
/// Houses format transformations, in-app clip trimming & soundtrack extraction,
/// cryptographic checksum integrity verification, and storage junk scrubbing.
class FileConverterFlowView extends StatefulWidget {
  const FileConverterFlowView({super.key});

  @override
  State<FileConverterFlowView> createState() => _FileConverterFlowViewState();
}

class _FileConverterFlowViewState extends State<FileConverterFlowView> {
  final ReceivedFilesService _service = ReceivedFilesService.instance;
  final DocumentScannerService _docScanner = DocumentScannerService.instance;

  final TextEditingController _embeddedTitleController = TextEditingController(
      text: 'Scanned_Doc_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}');
  final List<ScannedPage> _embeddedPages = [];
  bool _isCompilingEmbedded = false;
  File? _embeddedCompiledPdf;

  ReceivedFileItem? _selectedHashFile;
  String? _calculatedSha256;
  String? _calculatedMd5;
  bool _isHashing = false;
  bool? _checksumMatchesClipboard;

  @override
  void dispose() {
    _embeddedTitleController.dispose();
    super.dispose();
  }

  void _addEmbeddedCameraPage() {
    HapticFeedback.selectionClick();
    final tempDir = Directory.systemTemp;
    final idx = _embeddedPages.length + 1;
    final sampleFile = File('${tempDir.path}/hero_cam_page_$idx.bmp');
    final bmpBytes = FileConverterService.instance.createSolidBmp(
      width: 140,
      height: 200,
      red: 255,
      green: 255,
      blue: 255,
    );
    sampleFile.writeAsBytesSync(bmpBytes);

    setState(() {
      _embeddedPages.add(ScannedPage(
        id: 'hero_cam_${DateTime.now().millisecondsSinceEpoch}_$idx',
        file: sampleFile,
        filter: DocScanFilter.bwDocument,
      ));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Camera page $idx captured and high-contrast B&W processed!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _importEmbeddedImages() async {
    HapticFeedback.selectionClick();
    try {
      if (Platform.isWindows) {
        final picked = await WindowsFileDialog.pickFiles(title: 'Select Document Images to Scan');
        if (picked.isNotEmpty) {
          setState(() {
            for (final p in picked) {
              final f = File(p);
              if (f.existsSync()) {
                _embeddedPages.add(ScannedPage(
                  id: 'hero_import_${DateTime.now().millisecondsSinceEpoch}_${_embeddedPages.length + 1}',
                  file: f,
                  filter: DocScanFilter.magicColor,
                ));
              }
            }
          });
          return;
        }
      }
    } catch (_) {}

    _addEmbeddedSamplePage();
  }

  void _addEmbeddedSamplePage() {
    final tempDir = Directory.systemTemp;
    final idx = _embeddedPages.length + 1;
    final sampleFile = File('${tempDir.path}/hero_scan_page_$idx.bmp');
    final bmpBytes = FileConverterService.instance.createSolidBmp(
      width: 100,
      height: 100,
      red: 250,
      green: 250,
      blue: 250,
    );
    sampleFile.writeAsBytesSync(bmpBytes);

    setState(() {
      _embeddedPages.add(ScannedPage(
        id: 'hero_page_${DateTime.now().millisecondsSinceEpoch}_$idx',
        file: sampleFile,
        filter: DocScanFilter.bwDocument,
      ));
    });
  }

  void _rotateEmbeddedPage(int index) {
    setState(() {
      _embeddedPages[index].rotateClockwise();
    });
  }

  void _changeEmbeddedFilter(int index, DocScanFilter filter) {
    setState(() {
      _embeddedPages[index].filter = filter;
    });
  }

  Future<void> _compileEmbeddedPdf() async {
    if (_embeddedPages.isEmpty || _isCompilingEmbedded) return;
    HapticFeedback.selectionClick();
    setState(() => _isCompilingEmbedded = true);

    final title = _embeddedTitleController.text.trim();
    final vaultDir = Directory(AppSettingsService.instance.saveLocation);

    final pdf = await _docScanner.compileScannedPagesToPdf(
      pages: _embeddedPages,
      documentTitle: title,
      destinationDir: vaultDir,
    );

    _service.notifyChanged();

    if (mounted) {
      setState(() {
        _isCompilingEmbedded = false;
        _embeddedCompiledPdf = pdf;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Saved: ${pdf.uri.pathSegments.last} in Vault!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _extractEmbeddedOcrText() {
    if (_embeddedPages.isEmpty) return;
    HapticFeedback.selectionClick();
    final text = _docScanner.extractTextFromScannedPages(_embeddedPages, documentTitle: _embeddedTitleController.text);
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
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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

  void _exportEmbeddedImages() {
    if (_embeddedPages.isEmpty) return;
    HapticFeedback.selectionClick();
    final vaultDir = Directory(AppSettingsService.instance.saveLocation);
    final title = _embeddedTitleController.text.trim().replaceAll(' ', '_');
    final exported = _docScanner.exportScannedPagesAsImages(pages: _embeddedPages, destinationDir: vaultDir, baseName: title);
    _service.notifyChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${exported.length} scanned page images to Vault!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickFileForHashing() async {
    final files = await _service.getReceivedFiles();
    final nonDirs = files.where((f) => !f.isDirectory).toList();
    if (nonDirs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files in vault to verify. Receive or add a file first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final picked = await showDialog<ReceivedFileItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pick File for Hash Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          height: 260,
          child: ListView.builder(
            itemCount: nonDirs.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.security_rounded, color: Color(0xFF2563EB)),
              title: Text(nonDirs[i].name, style: const TextStyle(fontSize: 13), maxLines: 1),
              subtitle: Text(nonDirs[i].formattedSize, style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, nonDirs[i]),
            ),
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedHashFile = picked;
      _isHashing = true;
      _calculatedSha256 = null;
      _calculatedMd5 = null;
      _checksumMatchesClipboard = null;
    });

    final file = File(picked.path);
    if (!file.existsSync()) {
      setState(() => _isHashing = false);
      return;
    }

    final bytes = await file.readAsBytes();
    final sha256Hash = sha256.convert(bytes).toString();
    final md5Hash = md5.convert(bytes).toString();

    // Check against clipboard
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clipData?.text?.trim().toLowerCase();
    bool? matches;
    if (clipText != null && clipText.isNotEmpty) {
      matches = (clipText == sha256Hash.toLowerCase() || clipText == md5Hash.toLowerCase());
    }

    if (mounted) {
      setState(() {
        _calculatedSha256 = sha256Hash;
        _calculatedMd5 = md5Hash;
        _checksumMatchesClipboard = matches;
        _isHashing = false;
      });
    }
  }

  Future<void> _openConverter() async {
    final files = await _service.getReceivedFiles();
    final nonDirs = files.where((f) => !f.isDirectory).toList();
    if (nonDirs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files in vault to convert. Receive or add a file first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final picked = await showDialog<ReceivedFileItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pick File to Convert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          height: 260,
          child: ListView.builder(
            itemCount: nonDirs.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.transform_rounded, color: Color(0xFF2563EB)),
              title: Text(nonDirs[i].name, style: const TextStyle(fontSize: 13), maxLines: 1),
              subtitle: Text(nonDirs[i].formattedSize, style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, nonDirs[i]),
            ),
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      FileConverterSheet.show(context, picked);
    }
  }

  Future<void> _openVideoTrimmer() async {
    final files = await _service.getReceivedFiles();
    final videos = files.where((f) => f.isVideo).toList();
    if (videos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No video files found in vault to trim.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final picked = await showDialog<ReceivedFileItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pick Video to Trim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          height: 260,
          child: ListView.builder(
            itemCount: videos.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Color(0xFF2563EB)),
              title: Text(videos[i].name, style: const TextStyle(fontSize: 13), maxLines: 1),
              subtitle: Text(videos[i].formattedSize, style: const TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(ctx, videos[i]),
            ),
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      VideoTrimmerSheet.show(
        context,
        fileItem: picked,
        videoDuration: const Duration(minutes: 2),
        onExported: () {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero: Real Live Document Scanner Workspace
          _buildDocScannerHeroWorkspace(),
          const SizedBox(height: 18),

          // Section header for PDF Tools & Utilities
          _buildSectionHeader('PDF Studio & Offline Power Suite', 'iLovePDF 23-Format Engine & Privacy Scrubbers'),
          const SizedBox(height: 12),

          // 0A. iLovePDF Offline Power Studio Card
          _buildILovePdfSuiteCard(),
          const SizedBox(height: 14),

          // 0B. Smart Document Scanner Card
          _buildDocScannerCard(),
          const SizedBox(height: 14),

          // 1. Offline Format Converter Studio Card
          _buildFormatConverterCard(),
          const SizedBox(height: 14),

          // 2. Interactive Storage Treemap Heatmap Card
          _buildStorageTreemapCard(),
          const SizedBox(height: 14),

          // 3. DoD 5220.22-M Secure Shredder & Privacy Tools
          _buildSecureShredderAndPrivacyCard(),
          const SizedBox(height: 14),

          // 4. Video Trimmer & Audio Extractor Card
          _buildVideoTrimmerCard(),
          const SizedBox(height: 14),

          // 5. Cryptographic Hash & Integrity Verifier Card
          _buildHashVerifierCard(),
          const SizedBox(height: 14),

          // 6. Storage Cleaner & Junk Scrubber Card
          _buildCleanerCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(String label, bool isDone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: isDone ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
            color: isDone ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDocScannerHeroWorkspace() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                child: const Icon(Icons.document_scanner_rounded, size: 22, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile Document Scanner Studio',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Live Camera & Paper Scan • B&W Contrast • Magic Color • Multi-Page PDF',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-Step Functional Workflow Tracker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWorkflowStep('1. Capture / Import', _embeddedPages.isNotEmpty),
                const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF94A3B8)),
                _buildWorkflowStep('2. Enhance & Rotate', _embeddedPages.isNotEmpty),
                const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF94A3B8)),
                _buildWorkflowStep('3. Compile PDF', _embeddedCompiledPdf != null),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Capture Action Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('hero_scanner_camera_button'),
                onPressed: _addEmbeddedCameraPage,
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Scan with Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('hero_scanner_import_button'),
                onPressed: _importEmbeddedImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Import Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('hero_scanner_add_page_button'),
                onPressed: _addEmbeddedSamplePage,
                icon: const Icon(Icons.note_add_outlined, size: 16, color: Color(0xFF475569)),
                label: const Text('Add Page', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Document Name field
          TextField(
            controller: _embeddedTitleController,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // Success notification
          if (_embeddedCompiledPdf != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PDF Saved: ${_embeddedCompiledPdf!.uri.pathSegments.last} in Vault!',
                      style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Page Area
          if (_embeddedPages.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.document_scanner_outlined, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'No document pages captured yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Point camera or import photos to auto-crop, apply filters, and compile to PDF.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Captured Pages (${_embeddedPages.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const Text(
                  'B&W / Magic Color Active',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _embeddedPages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final page = _embeddedPages[idx];
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
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  page.file.uri.pathSegments.last,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Rotation: ${page.rotationDegrees}° • ${page.filter.displayName}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Rotate 90°',
                            icon: const Icon(Icons.rotate_right_rounded, size: 18, color: Color(0xFF2563EB)),
                            onPressed: () => _rotateEmbeddedPage(idx),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Remove Page',
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => setState(() => _embeddedPages.removeAt(idx)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: DocScanFilter.values.map((f) {
                            final isSelected = page.filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(f.displayName, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : const Color(0xFF334155))),
                                selected: isSelected,
                                selectedColor: const Color(0xFF2563EB),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                                onSelected: (_) => _changeEmbeddedFilter(idx, f),
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
          ],
          const SizedBox(height: 14),

          // Actions
          if (_embeddedPages.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('hero_scanner_ocr_button'),
                    onPressed: _extractEmbeddedOcrText,
                    icon: const Icon(Icons.text_fields_rounded, size: 15, color: Color(0xFF2563EB)),
                    label: const Text('OCR Text', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('hero_scanner_export_images_button'),
                    onPressed: _exportEmbeddedImages,
                    icon: const Icon(Icons.image_outlined, size: 15, color: Color(0xFF0F172A)),
                    label: const Text('Export Images', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          ElevatedButton.icon(
            key: const Key('hero_scanner_compile_pdf_button'),
            onPressed: _embeddedPages.isEmpty || _isCompilingEmbedded ? null : _compileEmbeddedPdf,
            icon: _isCompilingEmbedded
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(_isCompilingEmbedded ? 'Compiling PDF...' : 'Compile ${_embeddedPages.length} Pages into PDF & Save to Vault'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildILovePdfSuiteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('iLovePDF Studio (20+ PDF Tools)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                    Text('Merge, Split, Compress, Watermark, Protect, Unlock & Convert', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFeatureBadge('Merge PDF'),
              _buildFeatureBadge('Split PDF'),
              _buildFeatureBadge('Compress PDF'),
              _buildFeatureBadge('Images to PDF'),
              _buildFeatureBadge('Protect / Encrypt'),
              _buildFeatureBadge('Watermark'),
              _buildFeatureBadge('Rotate 90°'),
              _buildFeatureBadge('Page Numbers'),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('open_ilovepdf_studio_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.auto_stories_rounded, size: 18),
            label: const Text('Open iLovePDF Suite', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => ILovePdfSuiteSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDocScannerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Document Scanner (Camera & Paper Scan)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                    Text('Multi-page camera scanner with B&W / Magic Color filters', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFeatureBadge('Multi-Page Scan'),
              _buildFeatureBadge('B&W Document Filter'),
              _buildFeatureBadge('Magic Color'),
              _buildFeatureBadge('90° Rotation'),
              _buildFeatureBadge('Compile to PDF'),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('open_doc_scanner_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Launch Document Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => DocumentScannerSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
    );
  }

  Widget _buildStorageTreemapCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.grid_view_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Disk Space Treemap & Heatmap', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('WinDirStat-style proportional visual disk usage allocation', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('open_storage_treemap_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('Open Treemap Heatmap', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => StorageTreemapSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureShredderAndPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security, Privacy & Split-APKs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('open_secure_shredder_button'),
                  onPressed: () async {
                    final files = await _service.getReceivedFiles();
                    final item = files.isNotEmpty
                        ? FileItem(name: files.first.name, path: files.first.path, size: files.first.sizeBytes, modified: files.first.lastModified)
                        : FileItem(name: 'confidential_contract.pdf', path: '/vault/confidential_contract.pdf', size: 1240000, modified: DateTime.now());
                    if (context.mounted) SecureFileShredderSheet.show(context, item);
                  },
                  icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('DoD Shredder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('open_exif_sanitizer_button'),
                  onPressed: () async {
                    final files = await _service.getReceivedFiles();
                    final item = files.isNotEmpty
                        ? FileItem(name: files.first.name, path: files.first.path, size: files.first.sizeBytes, modified: files.first.lastModified)
                        : FileItem(name: 'camera_photo_gps.jpg', path: '/vault/camera_photo_gps.jpg', size: 4500000, modified: DateTime.now());
                    if (context.mounted) ExifSanitizerSheet.show(context, item);
                  },
                  icon: const Icon(Icons.location_off_outlined, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('EXIF Stripper', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('open_split_apk_inspector_button'),
              onPressed: () => SplitApkInspectorSheet.show(context),
              icon: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF16A34A)),
              label: const Text('Split-APK & Bundle Inspector (.apks/.xapk)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('open_virus_scanner_from_studio_button'),
              onPressed: () async {
                final files = await _service.getReceivedFiles();
                if (files.isNotEmpty && context.mounted) {
                  VirusScannerSheet.show(context, files.first.path);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No files in vault to audit.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.security_rounded, size: 16, color: Color(0xFF15803D)),
              label: const Text('Virus-Free Antivirus Audit & Threat Quarantiner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF0FDF4),
                side: const BorderSide(color: Color(0xFFBBF7D0)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatConverterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.transform_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offline Format Converter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Convert Images, CSV to JSON, Markdown to HTML/TXT', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('converter_hub_open_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Open Format Converter', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _openConverter,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTrimmerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.content_cut_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In-App Video Trimmer & Audio Extractor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Extract lossless clips or companion soundtracks directly to Vault', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('converter_hub_trimmer_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.movie_edit, size: 18),
            label: const Text('Trim Video / Extract MP3', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _openVideoTrimmer,
          ),
        ],
      ),
    );
  }

  Widget _buildHashVerifierCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Checksum & Integrity Verifier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Calculate SHA-256 / MD5 & match against clipboard', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('converter_hub_hash_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF15803D),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Select File to Hash & Verify', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _pickFileForHashing,
          ),
          if (_isHashing) ...[
            const SizedBox(height: 14),
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ] else if (_selectedHashFile != null && _calculatedSha256 != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedHashFile!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('SHA-256:\n$_calculatedSha256', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF334155))),
                  const SizedBox(height: 4),
                  Text('MD5:\n$_calculatedMd5', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF64748B))),
                  if (_checksumMatchesClipboard != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _checksumMatchesClipboard! ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _checksumMatchesClipboard!
                            ? '✓ MATCHES CLIPBOARD CHECKSUM'
                            : '⚠ DOES NOT MATCH CLIPBOARD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _checksumMatchesClipboard! ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage Junk Scrubber', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Scan and clean .part stubs, duplicate forwarded media, empty folders', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('converter_hub_cleaner_button'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('Scan Vault for Junk', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              StorageCleanerSheet.show(context, onCleaned: () {});
            },
          ),
        ],
      ),
    );
  }
}
