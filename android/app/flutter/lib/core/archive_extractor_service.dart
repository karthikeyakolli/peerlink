import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ArchiveEntry {
  final String path;
  final String name;
  final int compressedSize;
  final int uncompressedSize;
  final bool isDirectory;
  final DateTime? modified;

  const ArchiveEntry({
    required this.path,
    required this.name,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.isDirectory,
    this.modified,
  });

  String get formattedSize {
    if (isDirectory) return 'Folder';
    if (uncompressedSize < 1024) return '$uncompressedSize B';
    if (uncompressedSize < 1024 * 1024) {
      return '${(uncompressedSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(uncompressedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ArchiveDetails {
  final String archivePath;
  final List<ArchiveEntry> entries;
  final int totalUncompressedSize;
  final int totalCompressedSize;
  final int fileCount;
  final int folderCount;

  const ArchiveDetails({
    required this.archivePath,
    required this.entries,
    required this.totalUncompressedSize,
    required this.totalCompressedSize,
    required this.fileCount,
    required this.folderCount,
  });

  String get formattedTotalSize {
    if (totalUncompressedSize < 1024) return '$totalUncompressedSize B';
    if (totalUncompressedSize < 1024 * 1024) {
      return '${(totalUncompressedSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalUncompressedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  double get compressionRatio {
    if (totalUncompressedSize == 0) return 1.0;
    return (totalCompressedSize / totalUncompressedSize).clamp(0.01, 1.0);
  }
}

/// In-App ZIP & Archive Viewer and Safe Extractor Engine.
/// Pure Dart header inspection without external dependencies.
/// Enforces Rule 10 & 11: Zero automatic execution; user-directed extraction only.
class ArchiveExtractorService {
  static final ArchiveExtractorService _instance = ArchiveExtractorService._internal();
  static ArchiveExtractorService get instance => _instance;

  ArchiveExtractorService._internal();

  /// Inspects a ZIP archive and extracts metadata and directory contents in pure Dart.
  Future<ArchiveDetails> inspectArchive(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return ArchiveDetails(
        archivePath: filePath,
        entries: const [],
        totalUncompressedSize: 0,
        totalCompressedSize: 0,
        fileCount: 0,
        folderCount: 0,
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final entries = <ArchiveEntry>[];
      int totalUncompressed = 0;
      int totalCompressed = 0;
      int fileCount = 0;
      int folderCount = 0;

      int offset = 0;
      final len = bytes.length;

      // Scan for ZIP Local File Headers: 0x04034b50 (PK\x03\x04)
      while (offset + 30 <= len) {
        if (bytes[offset] == 0x50 &&
            bytes[offset + 1] == 0x4b &&
            bytes[offset + 2] == 0x03 &&
            bytes[offset + 3] == 0x04) {
          final ByteData bd = ByteData.sublistView(bytes, offset, offset + 30);
          final int compSize = bd.getUint32(18, Endian.little);
          final int uncompSize = bd.getUint32(22, Endian.little);
          final int fileNameLen = bd.getUint16(26, Endian.little);
          final int extraLen = bd.getUint16(28, Endian.little);

          final int nameStart = offset + 30;
          if (nameStart + fileNameLen <= len) {
            final fileNameBytes = bytes.sublist(nameStart, nameStart + fileNameLen);
            final rawName = utf8.decode(fileNameBytes, allowMalformed: true);
            // Sanitize against path traversal attacks (Zip Slip)
            final cleanName = rawName.replaceAll('..', '_');
            final isDir = cleanName.endsWith('/') || cleanName.endsWith('\\');
            final baseName = cleanName.replaceAll(RegExp(r'[\\/]$'), '').split(RegExp(r'[\\/]')).last;

            if (isDir) {
              folderCount++;
            } else {
              fileCount++;
              totalUncompressed += uncompSize;
              totalCompressed += compSize;
            }

            entries.add(ArchiveEntry(
              path: cleanName,
              name: baseName.isEmpty ? cleanName : baseName,
              compressedSize: compSize,
              uncompressedSize: uncompSize,
              isDirectory: isDir,
            ));
          }

          // Advance past header, filename, extra, and compressed payload
          offset = nameStart + fileNameLen + extraLen + compSize;
        } else {
          offset++;
        }
      }

      return ArchiveDetails(
        archivePath: filePath,
        entries: entries,
        totalUncompressedSize: totalUncompressed,
        totalCompressedSize: totalCompressed,
        fileCount: fileCount,
        folderCount: folderCount,
      );
    } catch (_) {
      return ArchiveDetails(
        archivePath: filePath,
        entries: const [],
        totalUncompressedSize: 0,
        totalCompressedSize: 0,
        fileCount: 0,
        folderCount: 0,
      );
    }
  }

  /// Extracts an archive safely into a dedicated subfolder using OS utilities.
  /// Enforces Rule 10: Extracted files are NEVER auto-executed.
  Future<String> extractArchive(String archivePath, {String? targetDirectory}) async {
    final file = File(archivePath);
    if (!file.existsSync()) {
      throw Exception('Archive file not found: $archivePath');
    }

    final rawName = file.uri.pathSegments.last;
    final folderName = rawName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final destDir = Directory(targetDirectory ?? '${file.parent.path}/$folderName');

    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    try {
      if (Platform.isWindows) {
        // Built-in Windows tar.exe unpacks standard zip/tar archives
        final res = await Process.run('tar.exe', ['-xf', archivePath, '-C', destDir.path]);
        if (res.exitCode != 0) {
          // Fallback to powershell Expand-Archive
          await Process.run('powershell.exe', [
            '-NoProfile',
            '-Command',
            'Expand-Archive -LiteralPath "${archivePath.replaceAll('"', '`"')}" -DestinationPath "${destDir.path.replaceAll('"', '`"')}" -Force'
          ]);
        }
      } else if (Platform.isLinux || Platform.isAndroid || Platform.isMacOS) {
        final res = await Process.run('unzip', ['-q', '-o', archivePath, '-d', destDir.path]);
        if (res.exitCode != 0) {
          await Process.run('tar', ['-xf', archivePath, '-C', destDir.path]);
        }
      }
    } catch (_) {}

    // Pure Dart fallback for stored files if directory is still empty
    try {
      if (destDir.listSync().isEmpty) {
        final bytes = await file.readAsBytes();
        int offset = 0;
        final len = bytes.length;
        while (offset + 30 <= len) {
          if (bytes[offset] == 0x50 &&
              bytes[offset + 1] == 0x4b &&
              bytes[offset + 2] == 0x03 &&
              bytes[offset + 3] == 0x04) {
            final bd = ByteData.sublistView(bytes, offset, offset + 30);
            final method = bd.getUint16(8, Endian.little);
            final compSize = bd.getUint32(18, Endian.little);
            final uncompSize = bd.getUint32(22, Endian.little);
            final fileNameLen = bd.getUint16(26, Endian.little);
            final extraLen = bd.getUint16(28, Endian.little);
            final nameStart = offset + 30;
            if (nameStart + fileNameLen <= len) {
              final rawName = utf8.decode(bytes.sublist(nameStart, nameStart + fileNameLen), allowMalformed: true);
              final cleanName = rawName.replaceAll('..', '_').replaceAll('\\', '/');
              final payloadStart = nameStart + fileNameLen + extraLen;
              if (method == 0 && payloadStart + compSize <= len && !cleanName.endsWith('/')) {
                final targetFile = File('${destDir.path}/$cleanName');
                if (!targetFile.parent.existsSync()) {
                  targetFile.parent.createSync(recursive: true);
                }
                targetFile.writeAsBytesSync(bytes.sublist(payloadStart, payloadStart + compSize));
              }
            }
            offset = nameStart + fileNameLen + extraLen + compSize;
          } else {
            offset++;
          }
        }
      }
    } catch (_) {}

    return destDir.path;
  }

  /// Creates a standard valid PKZIP archive containing the specified file paths.
  /// Pure Dart, zero external dependencies, 100% platform-independent.
  Future<String> createZip(List<String> sourcePaths, String outputZipPath) async {
    final outputFile = File(outputZipPath);
    if (!outputFile.parent.existsSync()) {
      outputFile.parent.createSync(recursive: true);
    }
    final buffer = BytesBuilder();
    final centralDir = BytesBuilder();
    int centralDirEntries = 0;

    final filesToPack = <_ZipSourceItem>[];
    for (final src in sourcePaths) {
      if (File(src).existsSync()) {
        final f = File(src);
        final baseName = f.uri.pathSegments.where((s) => s.isNotEmpty).last;
        filesToPack.add(_ZipSourceItem(
          relativePath: baseName,
          bytes: f.readAsBytesSync(),
          modified: f.lastModifiedSync(),
        ));
      } else if (Directory(src).existsSync()) {
        final dir = Directory(src);
        final baseName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File) {
            final rel = entity.path.substring(dir.path.length).replaceAll('\\', '/');
            final cleanRel = rel.startsWith('/') ? rel.substring(1) : rel;
            filesToPack.add(_ZipSourceItem(
              relativePath: '$baseName/$cleanRel',
              bytes: entity.readAsBytesSync(),
              modified: entity.lastModifiedSync(),
            ));
          }
        }
      }
    }

    for (final entry in filesToPack) {
      final nameBytes = utf8.encode(entry.relativePath);
      final fileBytes = entry.bytes;
      final crc = _crc32(fileBytes);
      final compSize = fileBytes.length;
      final uncompSize = fileBytes.length;
      final dosTime = _toDosTime(entry.modified);
      final dosDate = _toDosDate(entry.modified);

      final entryLocalOffset = buffer.length;

      // Local File Header (30 bytes)
      final localHdr = ByteData(30);
      localHdr.setUint32(0, 0x04034b50, Endian.little); // PK\x03\x04
      localHdr.setUint16(4, 20, Endian.little);          // version needed (2.0)
      localHdr.setUint16(6, 0, Endian.little);           // flags
      localHdr.setUint16(8, 0, Endian.little);           // compression (0 = stored)
      localHdr.setUint16(10, dosTime, Endian.little);
      localHdr.setUint16(12, dosDate, Endian.little);
      localHdr.setUint32(14, crc, Endian.little);
      localHdr.setUint32(18, compSize, Endian.little);
      localHdr.setUint32(22, uncompSize, Endian.little);
      localHdr.setUint16(26, nameBytes.length, Endian.little);
      localHdr.setUint16(28, 0, Endian.little);          // extra len

      buffer.add(localHdr.buffer.asUint8List());
      buffer.add(nameBytes);
      buffer.add(fileBytes);

      // Central Directory Header (46 bytes)
      final cdHdr = ByteData(46);
      cdHdr.setUint32(0, 0x02014b50, Endian.little);     // PK\x01\x02
      cdHdr.setUint16(4, 20, Endian.little);             // version made by
      cdHdr.setUint16(6, 20, Endian.little);             // version needed
      cdHdr.setUint16(8, 0, Endian.little);              // flags
      cdHdr.setUint16(10, 0, Endian.little);             // compression (stored)
      cdHdr.setUint16(12, dosTime, Endian.little);
      cdHdr.setUint16(14, dosDate, Endian.little);
      cdHdr.setUint32(16, crc, Endian.little);
      cdHdr.setUint32(20, compSize, Endian.little);
      cdHdr.setUint32(24, uncompSize, Endian.little);
      cdHdr.setUint16(28, nameBytes.length, Endian.little);
      cdHdr.setUint16(30, 0, Endian.little);             // extra len
      cdHdr.setUint16(32, 0, Endian.little);             // comment len
      cdHdr.setUint16(34, 0, Endian.little);             // disk start
      cdHdr.setUint16(36, 0, Endian.little);             // internal attrs
      cdHdr.setUint32(38, 0, Endian.little);             // external attrs
      cdHdr.setUint32(42, entryLocalOffset, Endian.little); // offset

      centralDir.add(cdHdr.buffer.asUint8List());
      centralDir.add(nameBytes);
      centralDirEntries++;
    }

    final cdOffset = buffer.length;
    final cdBytes = centralDir.toBytes();
    buffer.add(cdBytes);

    // End of Central Directory (22 bytes)
    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little);        // PK\x05\x06
    eocd.setUint16(4, 0, Endian.little);                // disk num
    eocd.setUint16(6, 0, Endian.little);                // start disk
    eocd.setUint16(8, centralDirEntries, Endian.little); // entries this disk
    eocd.setUint16(10, centralDirEntries, Endian.little);// total entries
    eocd.setUint32(12, cdBytes.length, Endian.little);   // cd size
    eocd.setUint32(16, cdOffset, Endian.little);        // cd offset
    eocd.setUint16(20, 0, Endian.little);               // comment len

    buffer.add(eocd.buffer.asUint8List());

    outputFile.writeAsBytesSync(buffer.toBytes());
    return outputFile.path;
  }

  static int _crc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc ^= b;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >>> 1) ^ 0xEDB88320;
        } else {
          crc >>>= 1;
        }
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }

  static int _toDosTime(DateTime dt) {
    return ((dt.hour & 0x1F) << 11) | ((dt.minute & 0x3F) << 5) | ((dt.second ~/ 2) & 0x1F);
  }

  static int _toDosDate(DateTime dt) {
    final year = dt.year < 1980 ? 1980 : dt.year;
    return (((year - 1980) & 0x7F) << 9) | ((dt.month & 0x0F) << 5) | (dt.day & 0x1F);
  }
}

class _ZipSourceItem {
  final String relativePath;
  final Uint8List bytes;
  final DateTime modified;

  const _ZipSourceItem({
    required this.relativePath,
    required this.bytes,
    required this.modified,
  });
}
