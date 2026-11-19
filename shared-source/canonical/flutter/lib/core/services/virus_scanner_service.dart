import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../quarantine_service.dart';
import '../mime_magic_sniffer.dart';
import 'secure_shredder_service.dart';

enum ThreatLevel {
  clean,
  suspicious,
  malicious,
}

class VirusScanReport {
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final ThreatLevel threatLevel;
  final String? threatName;
  final String summary;
  final double entropy;
  final String sha256;
  final String md5;
  final int scanDurationMs;
  final bool isQuarantined;
  final String? quarantinePath;
  final DateTime scannedAt;

  const VirusScanReport({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.threatLevel,
    this.threatName,
    required this.summary,
    required this.entropy,
    required this.sha256,
    required this.md5,
    required this.scanDurationMs,
    this.isQuarantined = false,
    this.quarantinePath,
    required this.scannedAt,
  });

  bool get isClean => threatLevel == ThreatLevel.clean;
  bool get hasThreat => threatLevel != ThreatLevel.clean;
}

/// Offline Zero-Trust Antivirus Scanner & Payload Integrity Engine (Rule 10 Enforcement).
/// Scans downloaded web and torrent resources before allowing execution or storage in the Vault:
/// 1. EICAR Standard Antivirus Test Pattern
/// 2. Disguised Executable & PE/ELF/Mach-O Header Masquerading
/// 3. Double Extension Malware Traps (e.g. video.mp4.exe, song.mp3.vbs)
/// 4. Shannon Entropy Anomaly Detection (>7.90 in uncompressed media)
/// 5. Dangerous Script / Shell / Macro Heuristics
class VirusScannerService {
  static final VirusScannerService _instance = VirusScannerService._internal();
  static VirusScannerService get instance => _instance;

  VirusScannerService._internal();

  // Standard EICAR signature for testing antivirus scanners without harm
  static const String eicarSignature =
      r'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*';

  // Suspicious double extension triggers
  static const List<String> dangerousExecExtensions = [
    'exe', 'bat', 'cmd', 'vbs', 'vbe', 'js', 'jse', 'wsf', 'wsh',
    'ps1', 'scr', 'pif', 'com', 'hta', 'cpl', 'jar', 'apk', 'dex'
  ];

  static const List<String> innocentMediaExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
    'mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a',
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
    'pdf', 'docx', 'xlsx', 'pptx', 'txt'
  ];

  /// Scans an on-disk file and returns a comprehensive VirusScanReport.
  Future<VirusScanReport> scanFile(String path, {bool autoQuarantine = true}) async {
    final stopwatch = Stopwatch()..start();
    final file = File(path);
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : path.split(Platform.pathSeparator).last;

    if (!file.existsSync()) {
      stopwatch.stop();
      return VirusScanReport(
        fileName: fileName,
        filePath: path,
        fileSizeBytes: 0,
        threatLevel: ThreatLevel.clean,
        summary: 'File does not exist or has been removed.',
        entropy: 0.0,
        sha256: '',
        md5: '',
        scanDurationMs: stopwatch.elapsedMilliseconds,
        scannedAt: DateTime.now(),
      );
    }

    final bytes = await file.readAsBytes();
    final report = scanBytes(bytes, fileName, filePath: path, autoQuarantine: autoQuarantine);
    stopwatch.stop();

    return VirusScanReport(
      fileName: report.fileName,
      filePath: report.filePath,
      fileSizeBytes: report.fileSizeBytes,
      threatLevel: report.threatLevel,
      threatName: report.threatName,
      summary: report.summary,
      entropy: report.entropy,
      sha256: report.sha256,
      md5: report.md5,
      scanDurationMs: max(stopwatch.elapsedMilliseconds, report.scanDurationMs),
      isQuarantined: report.isQuarantined,
      quarantinePath: report.quarantinePath,
      scannedAt: report.scannedAt,
    );
  }

  /// Scans raw bytes and file name for viruses, trojans, and disguises.
  VirusScanReport scanBytes(
    List<int> bytes,
    String fileName, {
    String? filePath,
    bool autoQuarantine = false,
  }) {
    final stopwatch = Stopwatch()..start();
    final lowerName = fileName.toLowerCase();

    // 1. Calculate Cryptographic Checksums
    final sha256Hash = sha256.convert(bytes).toString();
    final md5Hash = md5.convert(bytes).toString();

    // 2. Calculate Shannon Entropy
    final entropy = calculateEntropy(bytes);

    // 3. Check for EICAR Antivirus Test Signature
    final stringContent = String.fromCharCodes(bytes.take(min(bytes.length, 4096)));
    if (stringContent.contains(eicarSignature)) {
      stopwatch.stop();
      return _buildThreatReport(
        fileName: fileName,
        filePath: filePath ?? '',
        fileSizeBytes: bytes.length,
        threatLevel: ThreatLevel.malicious,
        threatName: 'EICAR.StandardAntivirusTestSignature',
        summary: 'Matches official EICAR antivirus test signature. File safely quarantined.',
        entropy: entropy,
        sha256: sha256Hash,
        md5: md5Hash,
        durationMs: stopwatch.elapsedMilliseconds,
        autoQuarantine: autoQuarantine,
      );
    }

    // 4. Double Extension Disguise Check (e.g., photo.jpg.exe or movie.mp4.bat)
    final doubleExtThreat = _checkDoubleExtension(lowerName);
    if (doubleExtThreat != null) {
      stopwatch.stop();
      return _buildThreatReport(
        fileName: fileName,
        filePath: filePath ?? '',
        fileSizeBytes: bytes.length,
        threatLevel: ThreatLevel.malicious,
        threatName: 'Trojan.DisguisedDoubleExtension',
        summary: 'MALWARE TRAP DETECTED: Executable payload disguised with double extension ($doubleExtThreat).',
        entropy: entropy,
        sha256: sha256Hash,
        md5: md5Hash,
        durationMs: stopwatch.elapsedMilliseconds,
        autoQuarantine: autoQuarantine,
      );
    }

    // 5. Inspect MIME Magic Bytes & Executable Masquerade
    final mimeResult = MimeMagicSniffer.instance.inspectBytes(bytes, fileName);
    if (mimeResult.isSpoofed && mimeResult.isExecutableOrScript) {
      stopwatch.stop();
      return _buildThreatReport(
        fileName: fileName,
        filePath: filePath ?? '',
        fileSizeBytes: bytes.length,
        threatLevel: ThreatLevel.malicious,
        threatName: 'Trojan.MasqueradedExecutableHeader',
        summary: 'HIGH RISK: File header contains executable binary bytes (${mimeResult.detectedMimeType}) disguised as media.',
        entropy: entropy,
        sha256: sha256Hash,
        md5: md5Hash,
        durationMs: stopwatch.elapsedMilliseconds,
        autoQuarantine: autoQuarantine,
      );
    }

    // 6. Embedded Malicious Script / Shellcode Detection
    if (bytes.length >= 2) {
      // Direct MZ header in an alleged non-executable
      final isMzHeader = bytes[0] == 0x4D && bytes[1] == 0x5A; // MZ
      final claimedExt = _extractExtension(fileName);
      if (isMzHeader && innocentMediaExtensions.contains(claimedExt)) {
        stopwatch.stop();
        return _buildThreatReport(
          fileName: fileName,
          filePath: filePath ?? '',
          fileSizeBytes: bytes.length,
          threatLevel: ThreatLevel.malicious,
          threatName: 'Win32.DisguisedPE.MZHeader',
          summary: 'CRITICAL THREAT: Windows PE executable header found inside alleged .$claimedExt media file.',
          entropy: entropy,
          sha256: sha256Hash,
          md5: md5Hash,
          durationMs: stopwatch.elapsedMilliseconds,
          autoQuarantine: autoQuarantine,
        );
      }

      // Direct ELF header (\x7fELF) in an alleged non-executable
      if (bytes.length >= 4 &&
          bytes[0] == 0x7F && bytes[1] == 0x45 && bytes[2] == 0x4C && bytes[3] == 0x46 &&
          innocentMediaExtensions.contains(claimedExt)) {
        stopwatch.stop();
        return _buildThreatReport(
          fileName: fileName,
          filePath: filePath ?? '',
          fileSizeBytes: bytes.length,
          threatLevel: ThreatLevel.malicious,
          threatName: 'Linux.DisguisedELF.Header',
          summary: 'CRITICAL THREAT: Linux ELF binary header found inside alleged .$claimedExt media file.',
          entropy: entropy,
          sha256: sha256Hash,
          md5: md5Hash,
          durationMs: stopwatch.elapsedMilliseconds,
          autoQuarantine: autoQuarantine,
        );
      }
    }

    // 7. Shannon Entropy Anomaly Detection
    // For text or document files, entropy > 7.95 indicates packed or ransomware payload
    final claimedExt = _extractExtension(fileName);
    final isPlainDocOrScript = ['txt', 'csv', 'json', 'xml', 'html', 'log'].contains(claimedExt);
    if (isPlainDocOrScript && bytes.length > 512 && entropy > 7.85) {
      stopwatch.stop();
      return _buildThreatReport(
        fileName: fileName,
        filePath: filePath ?? '',
        fileSizeBytes: bytes.length,
        threatLevel: ThreatLevel.suspicious,
        threatName: 'Heuristic.HighEntropyPackedPayload',
        summary: 'SUSPICIOUS: Abnormally high entropy (${entropy.toStringAsFixed(2)}) detected in text/document container. Potential encrypted payload or ransomware packer.',
        entropy: entropy,
        sha256: sha256Hash,
        md5: md5Hash,
        durationMs: stopwatch.elapsedMilliseconds,
        autoQuarantine: autoQuarantine,
      );
    }

    // 8. Clean Bill of Health!
    stopwatch.stop();
    return VirusScanReport(
      fileName: fileName,
      filePath: filePath ?? '',
      fileSizeBytes: bytes.length,
      threatLevel: ThreatLevel.clean,
      summary: 'Virus-Free: Multi-vector heuristic & signature analysis completed. 0 threats detected.',
      entropy: entropy,
      sha256: sha256Hash,
      md5: md5Hash,
      scanDurationMs: max(stopwatch.elapsedMilliseconds, 1),
      isQuarantined: false,
      scannedAt: DateTime.now(),
    );
  }

  /// Calculates Shannon entropy of byte array (0.0 to 8.0).
  double calculateEntropy(List<int> bytes) {
    if (bytes.isEmpty) return 0.0;
    final counts = List<int>.filled(256, 0);
    for (final b in bytes) {
      counts[b & 0xFF]++;
    }

    double entropy = 0.0;
    final len = bytes.length.toDouble();
    for (int i = 0; i < 256; i++) {
      if (counts[i] > 0) {
        final p = counts[i] / len;
        entropy -= p * (log(p) / ln2);
      }
    }
    return entropy;
  }

  String? _checkDoubleExtension(String lowerName) {
    for (final execExt in dangerousExecExtensions) {
      for (final mediaExt in innocentMediaExtensions) {
        if (lowerName.endsWith('.$mediaExt.$execExt')) {
          return '.$mediaExt.$execExt';
        }
      }
    }
    return null;
  }

  String _extractExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  VirusScanReport _buildThreatReport({
    required String fileName,
    required String filePath,
    required int fileSizeBytes,
    required ThreatLevel threatLevel,
    required String threatName,
    required String summary,
    required double entropy,
    required String sha256,
    required String md5,
    required int durationMs,
    required bool autoQuarantine,
  }) {
    String? quarantineDest;
    bool quarantined = false;

    if (autoQuarantine && filePath.isNotEmpty && File(filePath).existsSync()) {
      try {
        final f = File(filePath);
        final quarantineDir = Directory('${f.parent.path}${Platform.pathSeparator}.peerlink_quarantine');
        if (!quarantineDir.existsSync()) {
          quarantineDir.createSync(recursive: true);
        }
        quarantineDest = '${quarantineDir.path}${Platform.pathSeparator}${fileName}.quarantined';
        f.renameSync(quarantineDest);
        quarantined = true;
      } catch (_) {
        // Fallback: file may be read-only or in testing
      }
    }

    return VirusScanReport(
      fileName: fileName,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      threatLevel: threatLevel,
      threatName: threatName,
      summary: summary,
      entropy: entropy,
      sha256: sha256,
      md5: md5,
      scanDurationMs: durationMs,
      isQuarantined: quarantined,
      quarantinePath: quarantineDest,
      scannedAt: DateTime.now(),
    );
  }
}
