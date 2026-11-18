import 'dart:convert';
import 'dart:typed_data';
import 'quarantine_service.dart';

class MimeInspectionResult {
  final bool isClean;
  final bool isSpoofed;
  final bool isExecutableOrScript;
  final String detectedMimeType;
  final String claimedExtension;
  final String summary;
  final QuarantineReason? recommendedQuarantineReason;

  const MimeInspectionResult({
    required this.isClean,
    required this.isSpoofed,
    required this.isExecutableOrScript,
    required this.detectedMimeType,
    required this.claimedExtension,
    required this.summary,
    this.recommendedQuarantineReason,
  });

  bool get requiresQuarantine => recommendedQuarantineReason != null;
}

/// Zero-Trust MIME Magic Byte Sniffer & Executable Stripper (Rule 10 Enforcement).
/// Inspects raw binary header bytes to prevent extension spoofing and unauthorized
/// execution of masqueraded binaries, shell scripts, and package archives.
class MimeMagicSniffer {
  static const MimeMagicSniffer _instance = MimeMagicSniffer._internal();
  static MimeMagicSniffer get instance => _instance;

  const MimeMagicSniffer._internal();

  /// Inspects file header bytes against authoritative magic number signatures.
  MimeInspectionResult inspectBytes(List<int> bytes, String fileName) {
    final ext = _extractExtension(fileName).toLowerCase();

    if (bytes.isEmpty) {
      return MimeInspectionResult(
        isClean: true,
        isSpoofed: false,
        isExecutableOrScript: false,
        detectedMimeType: 'application/x-empty',
        claimedExtension: ext,
        summary: 'Payload is empty.',
      );
    }

    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    // 1. Windows Portable Executable (PE / MZ)
    if (_matchesPE(uint8)) {
      final isExpectedExt = ['exe', 'dll', 'sys', 'scr', 'efi'].contains(ext);
      return MimeInspectionResult(
        isClean: isExpectedExt,
        isSpoofed: !isExpectedExt,
        isExecutableOrScript: true,
        detectedMimeType: 'application/vnd.microsoft.portable-executable',
        claimedExtension: ext,
        summary: isExpectedExt
            ? 'Windows executable binary recognized (Rule 10 execute protection active).'
            : 'SPOOF DETECTED: Windows executable binary masquerading as .$ext (Rule 10).',
        recommendedQuarantineReason: isExpectedExt ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 2. Linux ELF Executable
    if (_matchesELF(uint8)) {
      final isExpectedExt = ['elf', 'bin', 'so', ''].contains(ext);
      return MimeInspectionResult(
        isClean: isExpectedExt,
        isSpoofed: !isExpectedExt,
        isExecutableOrScript: true,
        detectedMimeType: 'application/x-elf',
        claimedExtension: ext,
        summary: isExpectedExt
            ? 'Linux ELF executable binary recognized.'
            : 'SPOOF DETECTED: Linux ELF binary masquerading as .$ext (Rule 10).',
        recommendedQuarantineReason: isExpectedExt ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 3. Apple Mach-O Binary
    if (_matchesMachO(uint8)) {
      final isExpectedExt = ['dylib', 'bin', ''].contains(ext);
      return MimeInspectionResult(
        isClean: isExpectedExt,
        isSpoofed: !isExpectedExt,
        isExecutableOrScript: true,
        detectedMimeType: 'application/x-mach-binary',
        claimedExtension: ext,
        summary: isExpectedExt
            ? 'macOS Mach-O binary recognized.'
            : 'SPOOF DETECTED: macOS Mach-O binary masquerading as .$ext (Rule 10).',
        recommendedQuarantineReason: isExpectedExt ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 4. Shell Script Shebang (#!)
    if (_matchesShebang(uint8)) {
      final isScriptExt = ['sh', 'bash', 'zsh', 'py', 'pl', 'rb', 'php'].contains(ext);
      return MimeInspectionResult(
        isClean: isScriptExt,
        isSpoofed: !isScriptExt,
        isExecutableOrScript: true,
        detectedMimeType: 'text/x-shellscript',
        claimedExtension: ext,
        summary: isScriptExt
            ? 'Script file with shebang interpreter recognized.'
            : 'SPOOF DETECTED: Script payload masquerading as .$ext (Rule 10).',
        recommendedQuarantineReason: isScriptExt ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 5. ZIP Archive / Android APK / Java JAR
    if (_matchesZip(uint8)) {
      final isApk = _containsString(uint8, 'AndroidManifest.xml') ||
          _containsString(uint8, 'classes.dex');

      if (isApk) {
        final isApkExt = ['apk', 'aab', 'xapk'].contains(ext);
        return MimeInspectionResult(
          isClean: isApkExt,
          isSpoofed: !isApkExt,
          isExecutableOrScript: true,
          detectedMimeType: 'application/vnd.android.package-archive',
          claimedExtension: ext,
          summary: isApkExt
              ? 'Android application package (APK) verified.'
              : 'SPOOF DETECTED: Android APK package masquerading as .$ext (Rule 10).',
          recommendedQuarantineReason: isApkExt ? null : QuarantineReason.antimalwareFlagged,
        );
      }

      final isArchiveExt = ['zip', 'jar', 'apk', 'docx', 'xlsx', 'pptx', 'epub', 'cbz'].contains(ext);
      return MimeInspectionResult(
        isClean: isArchiveExt,
        isSpoofed: !isArchiveExt,
        isExecutableOrScript: false,
        detectedMimeType: 'application/zip',
        claimedExtension: ext,
        summary: isArchiveExt
            ? 'ZIP archive or container format verified.'
            : 'SPOOF DETECTED: ZIP archive masquerading as .$ext (Rule 10).',
        recommendedQuarantineReason: isArchiveExt ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 6. PDF Document
    if (_matchesPDF(uint8)) {
      final isPdf = ext == 'pdf';
      return MimeInspectionResult(
        isClean: isPdf,
        isSpoofed: !isPdf,
        isExecutableOrScript: false,
        detectedMimeType: 'application/pdf',
        claimedExtension: ext,
        summary: isPdf ? 'PDF document verified.' : 'PDF document disguised under .$ext.',
        recommendedQuarantineReason: isPdf ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 7. PNG Image
    if (_matchesPNG(uint8)) {
      final isPng = ext == 'png';
      return MimeInspectionResult(
        isClean: isPng,
        isSpoofed: !isPng,
        isExecutableOrScript: false,
        detectedMimeType: 'image/png',
        claimedExtension: ext,
        summary: isPng ? 'PNG image verified.' : 'PNG image disguised under .$ext.',
        recommendedQuarantineReason: isPng ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // 8. JPEG Image
    if (_matchesJPEG(uint8)) {
      final isJpg = ['jpg', 'jpeg', 'jpe'].contains(ext);
      return MimeInspectionResult(
        isClean: isJpg,
        isSpoofed: !isJpg,
        isExecutableOrScript: false,
        detectedMimeType: 'image/jpeg',
        claimedExtension: ext,
        summary: isJpg ? 'JPEG image verified.' : 'JPEG image disguised under .$ext.',
        recommendedQuarantineReason: isJpg ? null : QuarantineReason.antimalwareFlagged,
      );
    }

    // Default: Generic binary or text
    return MimeInspectionResult(
      isClean: true,
      isSpoofed: false,
      isExecutableOrScript: false,
      detectedMimeType: 'application/octet-stream',
      claimedExtension: ext,
      summary: 'Generic data stream inspected without critical spoofing signatures.',
    );
  }

  static String _extractExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1);
  }

  static bool _matchesPE(Uint8List b) {
    if (b.length < 2) return false;
    return b[0] == 0x4D && b[1] == 0x5A; // MZ
  }

  static bool _matchesELF(Uint8List b) {
    if (b.length < 4) return false;
    return b[0] == 0x7F && b[1] == 0x45 && b[2] == 0x4C && b[3] == 0x46; // \x7fELF
  }

  static bool _matchesMachO(Uint8List b) {
    if (b.length < 4) return false;
    // 32-bit & 64-bit Big/Little Endian + Universal Binary FAT
    return (b[0] == 0xFE && b[1] == 0xED && b[2] == 0xFA && b[3] == 0xCE) ||
        (b[0] == 0xCE && b[1] == 0xFA && b[2] == 0xED && b[3] == 0xFE) ||
        (b[0] == 0xFE && b[1] == 0xED && b[2] == 0xFA && b[3] == 0xCF) ||
        (b[0] == 0xCF && b[1] == 0xFA && b[2] == 0xED && b[3] == 0xFE) ||
        (b[0] == 0xCA && b[1] == 0xFE && b[2] == 0xBA && b[3] == 0xBE);
  }

  static bool _matchesShebang(Uint8List b) {
    if (b.length < 2) return false;
    return b[0] == 0x23 && b[1] == 0x21; // #!
  }

  static bool _matchesZip(Uint8List b) {
    if (b.length < 4) return false;
    return b[0] == 0x50 && b[1] == 0x4B && (b[2] == 0x03 || b[2] == 0x05) && (b[3] == 0x04 || b[3] == 0x06);
  }

  static bool _matchesPDF(Uint8List b) {
    if (b.length < 4) return false;
    return b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46; // %PDF
  }

  static bool _matchesPNG(Uint8List b) {
    if (b.length < 8) return false;
    return b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A;
  }

  static bool _matchesJPEG(Uint8List b) {
    if (b.length < 3) return false;
    return b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
  }

  static bool _containsString(Uint8List data, String needle) {
    final needleBytes = utf8.encode(needle);
    if (needleBytes.isEmpty || data.length < needleBytes.length) return false;

    final maxOffset = data.length - needleBytes.length;
    for (int i = 0; i <= maxOffset; i++) {
      bool match = true;
      for (int j = 0; j < needleBytes.length; j++) {
        if (data[i + j] != needleBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
}
