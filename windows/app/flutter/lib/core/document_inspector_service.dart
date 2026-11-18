import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class OfficeDocumentPreview {
  final String documentType;
  final int sectionCount;
  final int archiveEntryCount;
  final String extractedText;
  final bool hasContent;

  const OfficeDocumentPreview({
    required this.documentType,
    required this.sectionCount,
    required this.archiveEntryCount,
    required this.extractedText,
    required this.hasContent,
  });
}

class CsvTablePreview {
  final List<String> headers;
  final List<List<String>> rows;
  final int totalRowCount;
  final bool truncated;

  const CsvTablePreview({
    required this.headers,
    required this.rows,
    required this.totalRowCount,
    required this.truncated,
  });
}

class BinaryInspectionResult {
  final String detectedType;
  final String magicHex;
  final int sampledBytes;
  final int totalBytes;
  final List<String> hexLines;
  final bool isLikelyText;
  final String? textSnippet;

  const BinaryInspectionResult({
    required this.detectedType,
    required this.magicHex,
    required this.sampledBytes,
    required this.totalBytes,
    required this.hexLines,
    required this.isLikelyText,
    this.textSnippet,
  });
}

/// Pure-Dart Universal Document & Binary Inspector Engine.
/// Brings Office documents (.docx/.pptx/.xlsx/.odt), CSV/TSV tables, JSON,
/// source code/configs, and arbitrary binary files to life in-app with zero
/// third-party dependencies and strict Rule 10 non-execution safety.
class DocumentInspectorService {
  static final DocumentInspectorService _instance = DocumentInspectorService._internal();
  static DocumentInspectorService get instance => _instance;

  DocumentInspectorService._internal();

  static const Set<String> _codeAndTextExts = {
    'txt', 'md', 'markdown', 'json', 'csv', 'tsv', 'log', 'xml', 'yaml', 'yml',
    'dart', 'java', 'kt', 'kts', 'py', 'js', 'jsx', 'ts', 'tsx', 'html', 'htm',
    'css', 'scss', 'sql', 'sh', 'bat', 'ps1', 'c', 'cpp', 'cc', 'h', 'hpp',
    'rs', 'go', 'rb', 'php', 'swift', 'ini', 'cfg', 'conf', 'toml', 'properties',
    'gradle', 'env', 'gitignore', 'dockerfile', 'rtf',
  };

  static const Set<String> _officeZipExts = {'docx', 'pptx', 'xlsx', 'odt'};

  bool isCodeOrText(String ext) => _codeAndTextExts.contains(_clean(ext));
  bool isCsvOrTsv(String ext) => _clean(ext) == 'csv' || _clean(ext) == 'tsv';
  bool isJson(String ext) => _clean(ext) == 'json';
  bool isPdf(String ext) => _clean(ext) == 'pdf';
  bool isOfficeZipDocument(String ext) => _officeZipExts.contains(_clean(ext));

  String _clean(String ext) => ext.toLowerCase().replaceAll('.', '').trim();

  /// Safely reads up to [maxChars] from a text/code file without exhausting memory.
  String readTextSnippet(String filePath, {int maxChars = 24576}) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return 'File does not exist on disk.';
      final raf = file.openSync(mode: FileMode.read);
      try {
        final totalLen = raf.lengthSync();
        final toRead = totalLen > maxChars * 2 ? maxChars * 2 : totalLen;
        final bytes = raf.readSync(toRead);
        final decoded = utf8.decode(bytes, allowMalformed: true);
        if (decoded.length > maxChars) {
          return '${decoded.substring(0, maxChars)}\n... [truncated for preview]';
        }
        if (totalLen > toRead) {
          return '$decoded\n... [truncated for preview]';
        }
        return decoded;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return 'Unable to read text preview.';
    }
  }

  /// Pretty-prints JSON content; falls back to the input string if invalid JSON.
  String prettyPrintJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  /// Parses CSV or TSV text into a bounded preview table (max 50 rows x 12 cols).
  CsvTablePreview parseCsvTable(
    String content, {
    String delimiter = ',',
    int maxRows = 50,
    int maxCols = 12,
  }) {
    final parsedRows = <List<String>>[];
    final currentRow = <String>[];
    final field = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == delimiter) {
          currentRow.add(field.toString().trim());
          field.clear();
        } else if (ch == '\r') {
          continue;
        } else if (ch == '\n') {
          currentRow.add(field.toString().trim());
          field.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            parsedRows.add(List<String>.from(currentRow));
          }
          currentRow.clear();
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(field.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        parsedRows.add(List<String>.from(currentRow));
      }
    }

    if (parsedRows.isEmpty) {
      return const CsvTablePreview(
        headers: [],
        rows: [],
        totalRowCount: 0,
        truncated: false,
      );
    }

    final rawHeaders = parsedRows.first;
    final colCount = rawHeaders.length > maxCols ? maxCols : rawHeaders.length;
    final headers = rawHeaders.take(colCount).toList();
    final dataRows = parsedRows.skip(1).toList();
    final truncated = dataRows.length > maxRows || rawHeaders.length > maxCols;
    final boundedRows = dataRows.take(maxRows).map((r) {
      final padded = List<String>.generate(
        colCount,
        (idx) => idx < r.length ? r[idx] : '',
      );
      return padded;
    }).toList();

    return CsvTablePreview(
      headers: headers,
      rows: boundedRows,
      totalRowCount: dataRows.length,
      truncated: truncated,
    );
  }

  /// Extracts readable text from OpenXML / ODF Office archives (.docx, .pptx, .xlsx, .odt)
  /// using pure-Dart PKZIP parsing (Central Directory + Local Header + raw DEFLATE).
  Future<OfficeDocumentPreview> extractOfficeText(String filePath, String ext) async {
    return extractOfficeTextSync(filePath, ext);
  }

  /// Synchronous variant for instant zero-flicker in-app preview of Office documents (<= 16 MB).
  OfficeDocumentPreview extractOfficeTextSync(String filePath, String ext) {
    final cleanExt = _clean(ext);
    final docType = switch (cleanExt) {
      'docx' => 'Word Document (DOCX)',
      'pptx' => 'PowerPoint Presentation (PPTX)',
      'xlsx' => 'Excel Workbook (XLSX)',
      'odt' => 'OpenDocument Text (ODT)',
      _ => 'Office Document',
    };

    final file = File(filePath);
    if (!file.existsSync()) {
      return OfficeDocumentPreview(
        documentType: docType,
        sectionCount: 0,
        archiveEntryCount: 0,
        extractedText: 'File not found on disk.',
        hasContent: false,
      );
    }

    try {
      if (file.lengthSync() > 16 * 1024 * 1024) {
        return OfficeDocumentPreview(
          documentType: docType,
          sectionCount: 0,
          archiveEntryCount: 0,
          extractedText: 'Document exceeds 16 MB inline preview cap. Tap "Open with App" to view natively.',
          hasContent: false,
        );
      }
      final bytes = file.readAsBytesSync();
      final entries = _readZipEntries(bytes);
      if (entries.isEmpty) {
        return OfficeDocumentPreview(
          documentType: docType,
          sectionCount: 0,
          archiveEntryCount: 0,
          extractedText: 'Could not read document archive structure. Tap "Open with App" to view natively.',
          hasContent: false,
        );
      }

      final buffer = StringBuffer();
      int sections = 0;

      if (cleanExt == 'docx') {
        final docXml = entries['word/document.xml'];
        if (docXml != null) {
          sections = 1;
          buffer.write(_extractWordXmlText(utf8.decode(docXml, allowMalformed: true)));
        }
      } else if (cleanExt == 'pptx') {
        final slideKeys = entries.keys
            .where((k) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(k))
            .toList()
          ..sort((a, b) {
            final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '0') ?? 0;
            final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '0') ?? 0;
            return na.compareTo(nb);
          });
        for (int i = 0; i < slideKeys.length && i < 30; i++) {
          final xml = utf8.decode(entries[slideKeys[i]]!, allowMalformed: true);
          final text = _extractGenericXmlParagraphs(xml, paragraphEndTag: '</a:p>');
          if (text.isNotEmpty) {
            sections++;
            if (buffer.isNotEmpty) buffer.writeln('\n');
            buffer.writeln('--- Slide ${i + 1} ---');
            buffer.write(text);
          }
        }
      } else if (cleanExt == 'xlsx') {
        final shared = entries['xl/sharedStrings.xml'];
        if (shared != null) {
          final xml = utf8.decode(shared, allowMalformed: true);
          final matches = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(xml);
          final cells = matches
              .map((m) => _decodeXmlEntities(m.group(1) ?? '').trim())
              .where((s) => s.isNotEmpty)
              .take(300)
              .toList();
          if (cells.isNotEmpty) {
            sections = 1;
            buffer.write(cells.join('  •  '));
          }
        }
        if (buffer.isEmpty) {
          final sheetKeys = entries.keys
              .where((k) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(k))
              .toList()
            ..sort();
          for (final key in sheetKeys.take(3)) {
            final xml = utf8.decode(entries[key]!, allowMalformed: true);
            final vals = RegExp(r'<v>(.*?)</v>', dotAll: true)
                .allMatches(xml)
                .map((m) => _decodeXmlEntities(m.group(1) ?? '').trim())
                .where((s) => s.isNotEmpty)
                .take(150)
                .toList();
            if (vals.isNotEmpty) {
              sections++;
              if (buffer.isNotEmpty) buffer.writeln('\n');
              buffer.writeln('--- $key ---');
              buffer.write(vals.join('  |  '));
            }
          }
        }
      } else if (cleanExt == 'odt') {
        final contentXml = entries['content.xml'];
        if (contentXml != null) {
          sections = 1;
          buffer.write(_extractGenericXmlParagraphs(
            utf8.decode(contentXml, allowMalformed: true),
            paragraphEndTag: '</text:p>',
          ));
        }
      }

      var resultText = buffer.toString().trim();
      if (resultText.length > 20000) {
        resultText = '${resultText.substring(0, 20000)}\n... [truncated for preview]';
      }

      return OfficeDocumentPreview(
        documentType: docType,
        sectionCount: sections,
        archiveEntryCount: entries.length,
        extractedText: resultText.isNotEmpty
            ? resultText
            : 'No readable inline text found (document may contain images or charts only).',
        hasContent: resultText.isNotEmpty,
      );
    } catch (_) {
      return OfficeDocumentPreview(
        documentType: docType,
        sectionCount: 0,
        archiveEntryCount: 0,
        extractedText: 'Unable to parse Office archive preview. Tap "Open with App" to view.',
        hasContent: false,
      );
    }
  }

  /// Inspects any unknown or binary file via Magic-Byte signature + Hex/ASCII header dump.
  BinaryInspectionResult inspectBinaryFile(String filePath, {int maxBytes = 256}) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const BinaryInspectionResult(
        detectedType: 'Missing File',
        magicHex: 'N/A',
        sampledBytes: 0,
        totalBytes: 0,
        hexLines: [],
        isLikelyText: false,
      );
    }

    try {
      final raf = file.openSync(mode: FileMode.read);
      final int totalBytes;
      final Uint8List sample;
      try {
        totalBytes = raf.lengthSync();
        final toRead = totalBytes < maxBytes ? totalBytes : maxBytes;
        sample = raf.readSync(toRead);
      } finally {
        raf.closeSync();
      }

      final magicCount = sample.length < 8 ? sample.length : 8;
      final magicHex = sample
          .take(magicCount)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');

      final isText = _looksLikeUtf8Text(sample);
      final detectedType = _identifyMagicBytes(sample, isText: isText);

      // 8 bytes per row fits cleanly on narrow 320dp mobile screens without wrapping
      final hexLines = <String>[];
      for (int offset = 0; offset < sample.length; offset += 8) {
        final end = (offset + 8 < sample.length) ? offset + 8 : sample.length;
        final addr = offset.toRadixString(16).padLeft(4, '0').toUpperCase();
        final hexBuf = StringBuffer();
        final asciiBuf = StringBuffer();
        for (int i = offset; i < offset + 8; i++) {
          if (i < end) {
            final b = sample[i];
            hexBuf.write('${b.toRadixString(16).padLeft(2, '0').toUpperCase()} ');
            asciiBuf.write((b >= 32 && b <= 126) ? String.fromCharCode(b) : '.');
          } else {
            hexBuf.write('   ');
            asciiBuf.write(' ');
          }
        }
        hexLines.add('$addr: ${hexBuf.toString()} $asciiBuf');
      }

      String? snippet;
      if (isText && sample.isNotEmpty) {
        snippet = utf8.decode(sample, allowMalformed: true);
      }

      return BinaryInspectionResult(
        detectedType: detectedType,
        magicHex: magicHex.isEmpty ? 'EMPTY' : magicHex,
        sampledBytes: sample.length,
        totalBytes: totalBytes,
        hexLines: hexLines,
        isLikelyText: isText,
        textSnippet: snippet,
      );
    } catch (_) {
      return const BinaryInspectionResult(
        detectedType: 'Unreadable File',
        magicHex: 'N/A',
        sampledBytes: 0,
        totalBytes: 0,
        hexLines: [],
        isLikelyText: false,
      );
    }
  }

  /// Reads ZIP entries preferring Central Directory (handles Data Descriptor bit 3 used by Office).
  Map<String, Uint8List> _readZipEntries(Uint8List bytes) {
    final result = <String, Uint8List>{};
    final len = bytes.length;
    if (len < 22) return result;

    // Locate End of Central Directory (PK\x05\x06) scanning backwards
    int eocdOffset = -1;
    final minSearch = len - 65557 > 0 ? len - 65557 : 0;
    for (int i = len - 22; i >= minSearch; i--) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4b &&
          bytes[i + 2] == 0x05 &&
          bytes[i + 3] == 0x06) {
        eocdOffset = i;
        break;
      }
    }

    if (eocdOffset != -1) {
      final eocd = ByteData.sublistView(bytes, eocdOffset, eocdOffset + 22);
      final cdSize = eocd.getUint32(12, Endian.little);
      final cdOffset = eocd.getUint32(16, Endian.little);
      int pos = cdOffset;
      final cdEnd = cdOffset + cdSize;

      while (pos + 46 <= len && pos < cdEnd) {
        if (bytes[pos] != 0x50 ||
            bytes[pos + 1] != 0x4b ||
            bytes[pos + 2] != 0x01 ||
            bytes[pos + 3] != 0x02) {
          break;
        }
        final cd = ByteData.sublistView(bytes, pos, pos + 46);
        final method = cd.getUint16(10, Endian.little);
        final compSize = cd.getUint32(20, Endian.little);
        final nameLen = cd.getUint16(28, Endian.little);
        final extraLen = cd.getUint16(30, Endian.little);
        final commentLen = cd.getUint16(32, Endian.little);
        final localHeaderOffset = cd.getUint32(42, Endian.little);

        if (pos + 46 + nameLen <= len) {
          final name = utf8.decode(
            bytes.sublist(pos + 46, pos + 46 + nameLen),
            allowMalformed: true,
          );
          if (!name.endsWith('/') && localHeaderOffset + 30 <= len) {
            final lh = ByteData.sublistView(bytes, localHeaderOffset, localHeaderOffset + 30);
            final lhNameLen = lh.getUint16(26, Endian.little);
            final lhExtraLen = lh.getUint16(28, Endian.little);
            final dataStart = localHeaderOffset + 30 + lhNameLen + lhExtraLen;
            if (dataStart + compSize <= len) {
              final rawSlice = bytes.sublist(dataStart, dataStart + compSize);
              final inflated = _inflateEntry(rawSlice, method);
              if (inflated != null) {
                result[name] = inflated;
              }
            }
          }
        }
        pos += 46 + nameLen + extraLen + commentLen;
      }
      if (result.isNotEmpty) return result;
    }

    // Fallback: sequential Local File Header scan (PK\x03\x04)
    int offset = 0;
    while (offset + 30 <= len) {
      if (bytes[offset] == 0x50 &&
          bytes[offset + 1] == 0x4b &&
          bytes[offset + 2] == 0x03 &&
          bytes[offset + 3] == 0x04) {
        final lh = ByteData.sublistView(bytes, offset, offset + 30);
        final method = lh.getUint16(8, Endian.little);
        final compSize = lh.getUint32(18, Endian.little);
        final nameLen = lh.getUint16(26, Endian.little);
        final extraLen = lh.getUint16(28, Endian.little);
        final nameStart = offset + 30;
        final dataStart = nameStart + nameLen + extraLen;
        if (dataStart + compSize <= len) {
          final name = utf8.decode(bytes.sublist(nameStart, nameStart + nameLen), allowMalformed: true);
          if (!name.endsWith('/')) {
            final rawSlice = bytes.sublist(dataStart, dataStart + compSize);
            final inflated = _inflateEntry(rawSlice, method);
            if (inflated != null) {
              result[name] = inflated;
            }
          }
        }
        offset = dataStart + compSize;
      } else {
        offset++;
      }
    }
    return result;
  }

  Uint8List? _inflateEntry(Uint8List data, int method) {
    try {
      if (method == 0) return data;
      if (method == 8) {
        return Uint8List.fromList(ZLibDecoder(raw: true).convert(data));
      }
    } catch (_) {}
    return null;
  }

  String _extractWordXmlText(String xml) {
    final withBreaks = xml
        .replaceAll(RegExp(r'<w:tab[^>]*/?>'), '\t')
        .replaceAll(RegExp(r'<w:br[^>]*/?>'), '\n')
        .replaceAll('</w:p>', '\n')
        .replaceAll('</w:tr>', '\n')
        .replaceAll('</w:tc>', '  ');
    final stripped = withBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
    return _decodeXmlEntities(stripped)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _extractGenericXmlParagraphs(String xml, {required String paragraphEndTag}) {
    final withBreaks = xml.replaceAll(paragraphEndTag, '\n');
    final stripped = withBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
    return _decodeXmlEntities(stripped)
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#10;', '\n')
        .replaceAll('&#13;', '');
  }

  bool _looksLikeUtf8Text(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    int controlBytes = 0;
    for (final b in bytes) {
      if (b == 0) return false;
      if (b < 9 || (b > 13 && b < 32)) {
        controlBytes++;
      }
    }
    return controlBytes <= (bytes.length * 0.05);
  }

  String _identifyMagicBytes(Uint8List b, {required bool isText}) {
    if (b.isEmpty) return 'Empty File (0 B)';
    bool starts(List<int> sig) {
      if (b.length < sig.length) return false;
      for (int i = 0; i < sig.length; i++) {
        if (b[i] != sig[i]) return false;
      }
      return true;
    }

    if (starts([0x89, 0x50, 0x4E, 0x47])) return 'PNG Image';
    if (starts([0xFF, 0xD8, 0xFF])) return 'JPEG Image';
    if (starts([0x47, 0x49, 0x46, 0x38])) return 'GIF Image';
    if (starts([0x25, 0x50, 0x44, 0x46, 0x2D])) return 'PDF Document';
    if (starts([0x50, 0x4B, 0x03, 0x04])) return 'ZIP / OpenXML / APK Archive';
    if (starts([0x52, 0x49, 0x46, 0x46])) return 'RIFF Media (WAV / AVI / WebP)';
    if (b.length >= 8 && b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return 'MP4 / QuickTime Video';
    }
    if (starts([0x1A, 0x45, 0xDF, 0xA3])) return 'Matroska / WebM Video';
    if (starts([0x49, 0x44, 0x33])) return 'MP3 Audio (ID3)';
    if (starts([0x66, 0x4C, 0x61, 0x43])) return 'FLAC Lossless Audio';
    if (starts([0x4F, 0x67, 0x67, 0x53])) return 'OGG Media';
    if (starts([0x53, 0x51, 0x4C, 0x69, 0x74, 0x65])) return 'SQLite 3 Database';
    if (starts([0x4D, 0x5A])) return 'Windows PE Executable (MZ)';
    if (starts([0x7F, 0x45, 0x4C, 0x46])) return 'Linux ELF Binary';
    if (starts([0x1F, 0x8B])) return 'GZIP Compressed Stream';
    if (starts([0x52, 0x61, 0x72, 0x21])) return 'RAR Archive';
    if (starts([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) return '7-Zip Archive';
    if (isText) return 'Plain UTF-8 Text';
    return 'Binary Data';
  }
}
