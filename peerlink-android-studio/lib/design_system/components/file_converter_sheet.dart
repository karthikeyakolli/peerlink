import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/file_converter_service.dart';
import '../../core/received_files_service.dart';
import '../colors/peerlink_colors.dart';
import 'dedicated_tool_page.dart';

/// Minimalist Light-Only File Converter Sheet.
/// Converts files locally 100% offline with zero cloud relays.
class FileConverterSheet extends StatefulWidget {
  final ReceivedFileItem fileItem;
  final VoidCallback? onConversionComplete;
  final bool isPage;

  const FileConverterSheet({
    super.key,
    required this.fileItem,
    this.onConversionComplete,
    this.isPage = false,
  });

  static Future<void> show(
    BuildContext context,
    ReceivedFileItem item, {
    VoidCallback? onConversionComplete,
  }) {
    return DedicatedToolPage.open(
      context,
      title: 'Offline Format Converter',
      subtitle: 'Lossless Transcoding & Multi-Format Parsing (${item.name})',
      icon: Icons.transform_rounded,
      child: FileConverterSheet(
        fileItem: item,
        onConversionComplete: onConversionComplete,
        isPage: true,
      ),
    );
  }

  @override
  State<FileConverterSheet> createState() => _FileConverterSheetState();
}

class _FileConverterSheetState extends State<FileConverterSheet> {
  final FileConverterService _converter = FileConverterService.instance;
  late String _ext;
  late List<String> _availableFormats;
  late String _selectedFormat;
  bool _isConverting = false;
  ConversionResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ext = widget.fileItem.extension.toLowerCase();
    _availableFormats = _determineTargetFormats(_ext);
    _selectedFormat = _availableFormats.isNotEmpty ? _availableFormats.first : 'pdf';
  }

  List<String> _determineTargetFormats(String ext) {
    if (ext == 'csv') {
      return ['json', 'tsv', 'txt'];
    } else if (ext == 'json') {
      return ['csv', 'txt'];
    } else if (ext == 'tsv') {
      return ['csv', 'json', 'txt'];
    } else if (ext == 'md' || ext == 'markdown') {
      return ['html', 'txt', 'pdf'];
    } else if (ext == 'html' || ext == 'htm') {
      return ['txt', 'pdf'];
    } else if (['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'].contains(ext)) {
      return ['pdf', 'bmp'];
    } else if (['txt', 'log', 'ini', 'conf', 'dart', 'py', 'js', 'ts'].contains(ext)) {
      return ['pdf', 'html'];
    }
    return ['pdf', 'txt'];
  }

  Future<void> _performConversion() async {
    if (_isConverting) return;
    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _result = null;
    });

    final sourceFile = File(widget.fileItem.path);
    if (!sourceFile.existsSync()) {
      setState(() {
        _isConverting = false;
        _errorMessage = 'Source file no longer exists.';
      });
      return;
    }

    final destDir = sourceFile.parent;
    ConversionResult res;

    try {
      if (_ext == 'csv' && _selectedFormat == 'json') {
        res = await _converter.convertCsvToJson(source: sourceFile, destinationDir: destDir);
      } else if (_ext == 'json' && _selectedFormat == 'csv') {
        res = await _converter.convertJsonToCsv(source: sourceFile, destinationDir: destDir);
      } else if (_ext == 'csv' && _selectedFormat == 'tsv') {
        res = await _converter.convertDelimited(
          source: sourceFile,
          fromDelimiter: ',',
          toDelimiter: '\t',
          targetExtension: 'tsv',
          destinationDir: destDir,
        );
      } else if (_ext == 'tsv' && _selectedFormat == 'csv') {
        res = await _converter.convertDelimited(
          source: sourceFile,
          fromDelimiter: '\t',
          toDelimiter: ',',
          targetExtension: 'csv',
          destinationDir: destDir,
        );
      } else if ((_ext == 'md' || _ext == 'markdown') && _selectedFormat == 'html') {
        res = await _converter.convertMarkdownToHtml(source: sourceFile, destinationDir: destDir);
      } else if ((_ext == 'html' || _ext == 'htm') && _selectedFormat == 'txt') {
        res = await _converter.convertHtmlToPlainText(source: sourceFile, destinationDir: destDir);
      } else if (_selectedFormat == 'pdf') {
        if (['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'].contains(_ext)) {
          res = await _converter.compileImageToPdf(imageFile: sourceFile, destinationDir: destDir);
        } else {
          res = await _converter.compileTextToPdf(source: sourceFile, destinationDir: destDir);
        }
      } else {
        // Generic fallback to text
        res = await _converter.convertHtmlToPlainText(source: sourceFile, destinationDir: destDir);
      }

      setState(() {
        _isConverting = false;
        _result = res;
      });

      if (res.success) {
        widget.onConversionComplete?.call();
      }
    } catch (e) {
      setState(() {
        _isConverting = false;
        _errorMessage = 'Conversion failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Container(
      constraints: widget.isPage ? null : BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: isDesktop ? 600 : double.infinity,
      ),
      margin: (!widget.isPage && isDesktop) ? const EdgeInsets.symmetric(horizontal: 24, vertical: 24) : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isPage ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.transform, size: 20, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Convert File Format',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '100% Offline Local Conversion (Zero Cloud)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Source File Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 28, color: PeerLinkColors.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileItem.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Format: .${_ext.toUpperCase()} • ${widget.fileItem.formattedSize}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Target Format Selector
              const Text(
                'Convert to:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableFormats.map((fmt) {
                  final isSelected = _selectedFormat == fmt;
                  return ChoiceChip(
                    label: Text(
                      '.${fmt.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: PeerLinkColors.primaryBlue,
                    backgroundColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? PeerLinkColors.primaryBlue : const Color(0xFFE5E7EB),
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFormat = fmt;
                          _result = null;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Result Banner
              if (_result != null && _result!.success) ...[
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Conversion Successful!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Saved: ${_result!.outputFile.uri.pathSegments.last} (${_formatBytes(_result!.convertedBytes)})',
                              style: const TextStyle(color: Color(0xFF166534), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Convert Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _performConversion,
                  icon: _isConverting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.autorenew, size: 18),
                  label: Text(
                    _isConverting ? 'Converting Offline...' : 'Convert to .${_selectedFormat.toUpperCase()} & Save to Vault',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PeerLinkColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
