import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum DocScanFilter {
  original,
  bwDocument,
  magicColor,
  grayscale,
}

extension DocScanFilterExt on DocScanFilter {
  String get displayName {
    switch (this) {
      case DocScanFilter.original:
        return 'Original';
      case DocScanFilter.bwDocument:
        return 'B&W Document';
      case DocScanFilter.magicColor:
        return 'Magic Color';
      case DocScanFilter.grayscale:
        return 'Grayscale';
    }
  }
}

class ScannedPage {
  final String id;
  final File file;
  int rotationDegrees;
  DocScanFilter filter;

  ScannedPage({
    required this.id,
    required this.file,
    this.rotationDegrees = 0,
    this.filter = DocScanFilter.original,
  });

  void rotateClockwise() {
    rotationDegrees = (rotationDegrees + 90) % 360;
  }
}

class DocumentScannerService {
  DocumentScannerService._();
  static final DocumentScannerService instance = DocumentScannerService._();

  /// Compiles scanned pages (either as ScannedPage list or File list) into a consolidated PDF.
  Future<File> compileScannedPagesToPdf({
    List<File>? pageFiles,
    List<ScannedPage>? pages,
    required String documentTitle,
    required Directory destinationDir,
  }) async {
    final cleanTitle = documentTitle.trim().isEmpty ? 'Scanned_Document' : documentTitle.trim();
    final safeBaseName = cleanTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');

    final pageList = pages ??
        (pageFiles ?? [])
            .asMap()
            .entries
            .map((e) => ScannedPage(
                  id: 'page_${e.key}',
                  file: e.value,
                ))
            .toList();

    final outFile = _resolveTargetPdfFile(destinationDir, safeBaseName);
    final pdfBytes = _generateMultiPagePdf(cleanTitle, pageList);
    outFile.writeAsBytesSync(pdfBytes, flush: true);

    return outFile;
  }

  /// Applies document scanner visual filters to image bytes.
  Uint8List applyScanFilter(Uint8List imageBytes, DocScanFilter filter) {
    if (filter == DocScanFilter.original || imageBytes.isEmpty) {
      return imageBytes;
    }

    // Check if image is a standard uncompressed 24-bit or 32-bit BMP
    if (imageBytes.length > 54 && imageBytes[0] == 0x42 && imageBytes[1] == 0x4D) {
      final copy = Uint8List.fromList(imageBytes);
      final pixelOffset = copy[10] | (copy[11] << 8) | (copy[12] << 16) | (copy[13] << 24);

      for (int i = pixelOffset; i < copy.length - 2; i += 3) {
        final b = copy[i];
        final g = copy[i + 1];
        final r = copy[i + 2];

        if (filter == DocScanFilter.grayscale) {
          final gray = ((r * 0.299) + (g * 0.587) + (b * 0.114)).toInt().clamp(0, 255);
          copy[i] = gray;
          copy[i + 1] = gray;
          copy[i + 2] = gray;
        } else if (filter == DocScanFilter.bwDocument) {
          final gray = ((r * 0.299) + (g * 0.587) + (b * 0.114)).toInt();
          // High contrast thresholding for crisp text
          final val = gray > 140 ? 255 : 0;
          copy[i] = val;
          copy[i + 1] = val;
          copy[i + 2] = val;
        } else if (filter == DocScanFilter.magicColor) {
          // Vibrant document saturation boost & white-point expansion
          final enhancedR = ((r - 128) * 1.35 + 140).toInt().clamp(0, 255);
          final enhancedG = ((g - 128) * 1.35 + 140).toInt().clamp(0, 255);
          final enhancedB = ((b - 128) * 1.35 + 140).toInt().clamp(0, 255);
          copy[i] = enhancedB;
          copy[i + 1] = enhancedG;
          copy[i + 2] = enhancedR;
        }
      }
      return copy;
    }

    // Non-BMP fallback
    return imageBytes;
  }

  Uint8List _generateMultiPagePdf(String title, List<ScannedPage> pages) {
    final buffer = BytesBuilder();
    buffer.add(utf8.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));

    final objects = <int, String>{};
    int currentObjId = 1;

    final catalogId = currentObjId++;
    final pagesId = currentObjId++;

    final pageObjectIds = <int>[];

    for (int p = 0; p < pages.length; p++) {
      final page = pages[p];
      final pageId = currentObjId++;
      final contentId = currentObjId++;
      pageObjectIds.add(pageId);

      final pageStream = StringBuffer();
      pageStream.writeln('BT');
      pageStream.writeln('/F1 12 Tf');
      pageStream.writeln('50 780 Td');
      pageStream.writeln('(${_escapePdf(title)} - Page ${p + 1}) Tj');
      pageStream.writeln('0 -30 Td');
      pageStream.writeln('(${_escapePdf(page.file.uri.pathSegments.isNotEmpty ? page.file.uri.pathSegments.last : 'scan_${p + 1}')} [${page.filter.displayName}]) Tj');
      pageStream.writeln('ET');

      final streamBytes = utf8.encode(pageStream.toString());

      final rotateClause = page.rotationDegrees > 0 ? '/Rotate ${page.rotationDegrees} ' : '';
      objects[pageId] =
          '<< /Type /Page /Parent $pagesId 0 R /MediaBox [0 0 595 842] $rotateClause/Contents $contentId 0 R /Resources << /Font << /F1 5 0 R >> >> >>';
      objects[contentId] = '<< /Length ${streamBytes.length} >>\nstream\n${pageStream.toString()}endstream';
    }

    // Catalog & Pages
    objects[catalogId] = '<< /Type /Catalog /Pages $pagesId 0 R >>';
    final kidsArray = pageObjectIds.map((id) => '$id 0 R').join(' ');
    objects[pagesId] = '<< /Type /Pages /Kids [$kidsArray] /Count ${pageObjectIds.length} >>';

    // Font object (reusable across all pages)
    final fontId = currentObjId++;
    objects[fontId] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

    // Write all objects and track offsets
    final maxObj = currentObjId - 1;
    final offsets = <int, int>{};

    for (int i = 1; i <= maxObj; i++) {
      offsets[i] = buffer.length;
      final objContent = objects[i] ?? '<< >>';
      buffer.add(utf8.encode('$i 0 obj\n$objContent\nendobj\n'));
    }

    // XRef table
    final startXref = buffer.length;
    buffer.add(utf8.encode('xref\n0 ${maxObj + 1}\n'));
    buffer.add(utf8.encode('0000000000 65535 f \n'));
    for (int i = 1; i <= maxObj; i++) {
      final off = offsets[i]!.toString().padLeft(10, '0');
      buffer.add(utf8.encode('$off 00000 n \n'));
    }

    // Trailer
    buffer.add(utf8.encode('trailer\n<< /Size ${maxObj + 1} /Root $catalogId 0 R >>\n'));
    buffer.add(utf8.encode('startxref\n$startXref\n%%EOF\n'));

    return buffer.toBytes();
  }

  File _resolveTargetPdfFile(Directory dir, String baseName) {
    var candidate = File('${dir.path}${Platform.pathSeparator}$baseName.pdf');
    if (!candidate.existsSync()) return candidate;

    int counter = 1;
    while (candidate.existsSync()) {
      candidate = File('${dir.path}${Platform.pathSeparator}${baseName}_$counter.pdf');
      counter++;
    }
    return candidate;
  }

  String _escapePdf(String text) {
    return text.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  }
}
