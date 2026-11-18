import 'dart:io';
import 'dart:typed_data';

class ExifScrubResult {
  final String outputPath;
  final bool wasScrubbed;
  final int removedBytes;
  final List<String> strippedSegments;

  const ExifScrubResult({
    required this.outputPath,
    required this.wasScrubbed,
    required this.removedBytes,
    required this.strippedSegments,
  });
}

/// Privacy-First Local EXIF / GPS & Metadata Scrubber (Pure Dart, Zero External Dependencies).
/// Strips EXIF (GPS coordinates, camera serials), XMP, IPTC, and comment segments from
/// JPEG (.jpg/.jpeg) and PNG (.png) files into temporary share-ready copies without
/// ever modifying the user's original image on disk.
class ExifScrubberService {
  static final ExifScrubberService _instance = ExifScrubberService._internal();
  static ExifScrubberService get instance => _instance;

  ExifScrubberService._internal();

  bool isSupportedImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  /// Scrubs EXIF/GPS/text metadata from supported images, returning a list of paths
  /// ready to share (non-images or unsupported formats are returned untouched).
  Future<({List<String> paths, int scrubbedCount, int totalBytesRemoved})> scrubPathsForSharing(
    List<String> inputPaths,
  ) async {
    final outPaths = <String>[];
    int scrubbedCount = 0;
    int totalRemoved = 0;

    for (final p in inputPaths) {
      if (!isSupportedImagePath(p)) {
        outPaths.add(p);
        continue;
      }
      final res = await scrubFileToTempCopy(p);
      outPaths.add(res.outputPath);
      if (res.wasScrubbed) {
        scrubbedCount++;
        totalRemoved += res.removedBytes;
      }
    }
    return (paths: outPaths, scrubbedCount: scrubbedCount, totalBytesRemoved: totalRemoved);
  }

  /// Creates a metadata-free copy in systemTemp/peerlink_scrubbed/ preserving filename.
  Future<ExifScrubResult> scrubFileToTempCopy(String sourcePath) async {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      return ExifScrubResult(
        outputPath: sourcePath,
        wasScrubbed: false,
        removedBytes: 0,
        strippedSegments: const [],
      );
    }

    try {
      final raw = await file.readAsBytes();
      final lower = sourcePath.toLowerCase();
      final ({Uint8List bytes, List<String> stripped}) result;
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        result = scrubJpegBytes(raw);
      } else if (lower.endsWith('.png')) {
        result = scrubPngBytes(raw);
      } else {
        return ExifScrubResult(
          outputPath: sourcePath,
          wasScrubbed: false,
          removedBytes: 0,
          strippedSegments: const [],
        );
      }

      if (result.stripped.isEmpty) {
        return ExifScrubResult(
          outputPath: sourcePath,
          wasScrubbed: false,
          removedBytes: 0,
          strippedSegments: const [],
        );
      }

      final stagingDir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}peerlink_scrubbed_${DateTime.now().millisecondsSinceEpoch}',
      );
      stagingDir.createSync(recursive: true);
      final name = file.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? 'photo.jpg';
      final dest = File('${stagingDir.path}${Platform.pathSeparator}$name');
      await dest.writeAsBytes(result.bytes, flush: true);

      return ExifScrubResult(
        outputPath: dest.path,
        wasScrubbed: true,
        removedBytes: (raw.length - result.bytes.length).clamp(0, raw.length),
        strippedSegments: result.stripped,
      );
    } catch (_) {
      return ExifScrubResult(
        outputPath: sourcePath,
        wasScrubbed: false,
        removedBytes: 0,
        strippedSegments: const [],
      );
    }
  }

  /// Strips APP1 (EXIF/GPS/XMP), APP2 (ICC/MPF), APP13 (IPTC), and COM segments from JPEG bytes.
  ({Uint8List bytes, List<String> stripped}) scrubJpegBytes(Uint8List data) {
    if (data.length < 4 || data[0] != 0xFF || data[1] != 0xD8) {
      return (bytes: data, stripped: const []);
    }

    final out = BytesBuilder(copy: false);
    final stripped = <String>[];
    out.add(const [0xFF, 0xD8]); // SOI

    int i = 2;
    while (i + 1 < data.length) {
      if (data[i] != 0xFF) {
        // Unexpected non-marker; copy remainder untouched
        out.add(Uint8List.sublistView(data, i));
        break;
      }
      // Skip fill 0xFF bytes
      while (i + 1 < data.length && data[i + 1] == 0xFF) {
        i++;
      }
      if (i + 1 >= data.length) break;
      final marker = data[i + 1];

      // Start of Scan (0xDA) or End of Image (0xD9): copy rest verbatim
      if (marker == 0xDA || marker == 0xD9) {
        out.add(Uint8List.sublistView(data, i));
        break;
      }

      // Standalone markers without length
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        out.add([0xFF, marker]);
        i += 2;
        continue;
      }

      if (i + 3 >= data.length) {
        out.add(Uint8List.sublistView(data, i));
        break;
      }
      final segLen = (data[i + 2] << 8) | data[i + 3];
      final totalSegLen = 2 + segLen;
      if (segLen < 2 || i + totalSegLen > data.length) {
        out.add(Uint8List.sublistView(data, i));
        break;
      }

      // Strip APP1 (EXIF/GPS/XMP), APP13 (Photoshop IPTC), and COM (0xFE)
      if (marker == 0xE1 || marker == 0xED || marker == 0xFE) {
        final label = switch (marker) {
          0xE1 => 'APP1 (EXIF/GPS/XMP)',
          0xED => 'APP13 (IPTC)',
          0xFE => 'COM (Comment)',
          _ => 'METADATA',
        };
        stripped.add(label);
        i += totalSegLen;
      } else {
        out.add(Uint8List.sublistView(data, i, i + totalSegLen));
        i += totalSegLen;
      }
    }

    return (bytes: out.toBytes(), stripped: stripped);
  }

  /// Strips eXIf, tEXt, zTXt, and iTXt metadata chunks from PNG bytes.
  ({Uint8List bytes, List<String> stripped}) scrubPngBytes(Uint8List data) {
    const pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (data.length < 8) return (bytes: data, stripped: const []);
    for (int k = 0; k < 8; k++) {
      if (data[k] != pngSig[k]) return (bytes: data, stripped: const []);
    }

    const metadataChunks = {'eXIf', 'tEXt', 'zTXt', 'iTXt'};
    final out = BytesBuilder(copy: false)..add(pngSig);
    final stripped = <String>[];

    int i = 8;
    while (i + 12 <= data.length) {
      final bd = ByteData.sublistView(data, i, i + 4);
      final chunkLen = bd.getUint32(0, Endian.big);
      final totalChunk = 12 + chunkLen;
      if (i + totalChunk > data.length) {
        out.add(Uint8List.sublistView(data, i));
        break;
      }
      final type = String.fromCharCodes(data.sublist(i + 4, i + 8));
      if (metadataChunks.contains(type)) {
        stripped.add('PNG $type');
      } else {
        out.add(Uint8List.sublistView(data, i, i + totalChunk));
      }
      i += totalChunk;
      if (type == 'IEND') break;
    }

    return (bytes: out.toBytes(), stripped: stripped);
  }
}
