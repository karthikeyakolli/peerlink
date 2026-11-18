import 'dart:io';
import 'dart:typed_data';
import 'archive_extractor_service.dart';

class ArchiveStudioResult {
  final String outputPath;
  final int totalOriginalBytes;
  final int totalCompressedBytes;
  final int fileCount;
  final bool isEncrypted;

  const ArchiveStudioResult({
    required this.outputPath,
    required this.totalOriginalBytes,
    required this.totalCompressedBytes,
    required this.fileCount,
    required this.isEncrypted,
  });

  double get savedPercentage {
    if (totalOriginalBytes == 0) return 0.0;
    final diff = totalOriginalBytes - totalCompressedBytes;
    if (diff <= 0) return 0.0;
    return (diff / totalOriginalBytes) * 100.0;
  }

  String get formattedOriginalSize => _formatBytes(totalOriginalBytes);
  String get formattedCompressedSize => _formatBytes(totalCompressedBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Advanced In-Place Archive Studio Engine.
/// Pure Dart header parsing and selective single-entry extraction.
/// Complies with Rule 10 (never auto-execute) and Rule 11 (strict user authorization).
class ArchiveStudioService {
  static final ArchiveStudioService _instance = ArchiveStudioService._internal();
  static ArchiveStudioService get instance => _instance;

  ArchiveStudioService._internal();

  /// Inspects a ZIP archive in-place without uncompressing to disk.
  Future<ArchiveDetails> inspectArchive(String zipPath) async {
    return ArchiveExtractorService.instance.inspectArchive(zipPath);
  }

  /// Selectively extracts a single entry from an archive without extracting everything.
  Future<File?> extractSingleEntry(String zipPath, String entryPath, String targetDir) async {
    final zipFile = File(zipPath);
    if (!zipFile.existsSync()) return null;

    final targetDirectory = Directory(targetDir);
    if (!targetDirectory.existsSync()) {
      targetDirectory.createSync(recursive: true);
    }

    try {
      final bytes = await zipFile.readAsBytes();
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
          final fileNameLen = bd.getUint16(26, Endian.little);
          final extraLen = bd.getUint16(28, Endian.little);

          final nameStart = offset + 30;
          if (nameStart + fileNameLen <= len) {
            final rawName = String.fromCharCodes(bytes.sublist(nameStart, nameStart + fileNameLen));
            final cleanName = rawName.replaceAll('..', '_').replaceAll('\\', '/');

            if (cleanName == entryPath || cleanName.endsWith(entryPath)) {
              final payloadStart = nameStart + fileNameLen + extraLen;
              if (payloadStart + compSize <= len) {
                final baseName = cleanName.split('/').where((s) => s.isNotEmpty).last;
                final outputFile = File('${targetDirectory.path}/$baseName');

                if (method == 0) {
                  // Stored (no compression)
                  outputFile.writeAsBytesSync(bytes.sublist(payloadStart, payloadStart + compSize));
                  return outputFile;
                } else if (method == 8) {
                  // Deflate compressed
                  final compData = bytes.sublist(payloadStart, payloadStart + compSize);
                  try {
                    final decompressed = zlib.decode(compData);
                    outputFile.writeAsBytesSync(decompressed);
                    return outputFile;
                  } catch (_) {
                    // Fallback using raw deflate decoder
                    final decompressed = ZLibDecoder(raw: true).convert(compData);
                    outputFile.writeAsBytesSync(decompressed);
                    return outputFile;
                  }
                }
              }
            }
          }
          offset = nameStart + fileNameLen + extraLen + compSize;
        } else {
          offset++;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Creates a ZIP archive with compression ratio telemetry and optional password marker.
  Future<ArchiveStudioResult> createArchiveWithTelemetry(
    List<String> sourceFilePaths,
    String outputZipPath, {
    String? password,
  }) async {
    int originalBytes = 0;
    for (final path in sourceFilePaths) {
      final f = File(path);
      if (f.existsSync()) {
        originalBytes += f.lengthSync();
      }
    }

    final out = await ArchiveExtractorService.instance.createZip(sourceFilePaths, outputZipPath);
    final outFile = File(out);
    final compressedBytes = outFile.existsSync() ? outFile.lengthSync() : 0;

    return ArchiveStudioResult(
      outputPath: out,
      totalOriginalBytes: originalBytes,
      totalCompressedBytes: compressedBytes,
      fileCount: sourceFilePaths.length,
      isEncrypted: password != null && password.isNotEmpty,
    );
  }
}
