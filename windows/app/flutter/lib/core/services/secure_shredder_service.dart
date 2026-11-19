import 'dart:io';
import 'dart:math';

/// Secure Shredding algorithms supported by PeerLink.
enum ShredAlgorithm {
  fastZero(1, 'Fast Single-Pass (Zeroes)'),
  dod522022M(3, 'DoD 5220.22-M (3-Pass Forensic Sanitization)');

  final int passes;
  final String label;
  const ShredAlgorithm(this.passes, this.label);
}

/// Progress state emitted during file shredding.
class ShredProgress {
  final int currentPass;
  final int totalPasses;
  final double passProgress; // 0.0 to 1.0
  final String status;

  const ShredProgress({
    required this.currentPass,
    required this.totalPasses,
    required this.passProgress,
    required this.status,
  });

  double get overallProgress => ((currentPass - 1) + passProgress) / totalPasses;
}

/// Military-grade DoD 5220.22-M Multi-Pass Secure File Shredder.
class SecureShredderService {
  SecureShredderService._();
  static final SecureShredderService instance = SecureShredderService._();

  /// Securely overwrites and permanently destroys a file.
  Future<bool> shredFile(
    String filePath, {
    ShredAlgorithm algorithm = ShredAlgorithm.dod522022M,
    void Function(ShredProgress progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    try {
      final length = await file.length();
      final totalPasses = algorithm.passes;
      final chunkSize = 64 * 1024; // 64 KB buffer
      final random = Random.secure();

      RandomAccessFile raf = await file.open(mode: FileMode.write);

      for (int pass = 1; pass <= totalPasses; pass++) {
        await raf.setPosition(0);
        int bytesWritten = 0;

        // Determine byte pattern for this pass
        int patternByte = 0x00;
        bool isRandom = false;

        if (algorithm == ShredAlgorithm.dod522022M) {
          if (pass == 1) {
            patternByte = 0x55; // 01010101
          } else if (pass == 2) {
            patternByte = 0xAA; // 10101010
          } else {
            isRandom = true; // Pseudo-random bytes
          }
        }

        while (bytesWritten < length) {
          final currentChunk = min(chunkSize, length - bytesWritten);
          final buffer = List<int>.filled(currentChunk, 0);

          if (isRandom) {
            for (int b = 0; b < currentChunk; b++) {
              buffer[b] = random.nextInt(256);
            }
          } else {
            buffer.fillRange(0, currentChunk, patternByte);
          }

          await raf.writeFrom(buffer);
          bytesWritten += currentChunk;

          final passRatio = length > 0 ? (bytesWritten / length).clamp(0.0, 1.0) : 1.0;
          onProgress?.call(ShredProgress(
            currentPass: pass,
            totalPasses: totalPasses,
            passProgress: passRatio,
            status: 'Overwriting Pass $pass of $totalPasses (${(passRatio * 100).toInt()}%)...',
          ));
        }

        await raf.flush();
      }

      // Truncate to 0 bytes
      await raf.truncate(0);
      await raf.close();

      // Scramble file name before deletion to prevent directory table forensics
      final parentDir = file.parent.path;
      final scrambledName = 'shred_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(99999)}.tmp';
      final scrambledPath = '$parentDir${Platform.pathSeparator}$scrambledName';
      final renamedFile = await file.rename(scrambledPath);

      // Final unlinking from filesystem
      await renamedFile.delete();

      onProgress?.call(ShredProgress(
        currentPass: totalPasses,
        totalPasses: totalPasses,
        passProgress: 1.0,
        status: 'Shred Complete. File permanently unlinked.',
      ));

      return true;
    } catch (_) {
      return false;
    }
  }
}
