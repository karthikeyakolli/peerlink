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

  ReceivedFileItem? _selectedHashFile;
  String? _calculatedSha256;
  String? _calculatedMd5;
  bool _isHashing = false;
  bool? _checksumMatchesClipboard;

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
