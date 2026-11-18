import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class DocumentScannerService {
  DocumentScannerService._();
  static final DocumentScannerService instance = DocumentScannerService._();

  Future<File> compileScannedPagesToPdf({
    required List<File> pageFiles,
    required String documentTitle,
    required Directory destinationDir,
  }) async {
    final cleanTitle = documentTitle.trim().isEmpty ? 'Scanned_Document' : documentTitle.trim();
    final safeBaseName = cleanTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');

    final outFile = _resolveTargetPdfFile(destinationDir, safeBaseName);
    final pdfBytes = _generateMultiPagePdf(cleanTitle, pageFiles);
    outFile.writeAsBytesSync(pdfBytes, flush: true);

    return outFile;
  }

  Uint8List _generateMultiPagePdf(String title, List<File> pages) {
    final buffer = BytesBuilder();
    buffer.add(utf8.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));

    final objects = <int, String>{};
    int currentObjId = 1;

    final catalogId = currentObjId++;
    final pagesId = currentObjId++;

    final pageObjectIds = <int>[];

    for (int p = 0; p < pages.length; p++) {
      final pageFile = pages[p];
      final pageId = currentObjId++;
      final contentId = currentObjId++;
      pageObjectIds.add(pageId);

      final pageStream = StringBuffer();
      pageStream.writeln('BT');
      pageStream.writeln('/F1 12 Tf');
      pageStream.writeln('50 780 Td');
      pageStream.writeln('(${_escapePdf(title)} - Page ${p + 1}) Tj');
      pageStream.writeln('0 -30 Td');
      pageStream.writeln('(${_escapePdf(pageFile.uri.pathSegments.last)}) Tj');
      pageStream.writeln('ET');

      final streamBytes = utf8.encode(pageStream.toString());

      objects[pageId] =
          '<< /Type /Page /Parent $pagesId 0 R /MediaBox [0 0 595 842] /Contents $contentId 0 R /Resources << /Font << /F1 5 0 R >> >> >>';
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
