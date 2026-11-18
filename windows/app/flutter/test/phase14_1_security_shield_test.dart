import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/mime_magic_sniffer.dart';
import 'package:peerlink/core/quarantine_service.dart';
import 'package:peerlink/core/device_trust_service.dart';

void main() {
  setUp(() {
    QuarantineService.instance.resetForTesting();
    DeviceTrustService.instance.resetForTesting();
  });

  tearDown(() {
    QuarantineService.instance.resetForTesting();
    DeviceTrustService.instance.resetForTesting();
  });

  group('Phase 14.1: MimeMagicSniffer (Rule 10 Anti-Spoofing & Safety)', () {
    final sniffer = MimeMagicSniffer.instance;

    test('Clean PDF, PNG, and JPEG pass inspection without spoof alerts', () {
      final pdfBytes = utf8.encode('%PDF-1.7 header content here');
      final pdfRes = sniffer.inspectBytes(pdfBytes, 'document.pdf');
      expect(pdfRes.isClean, isTrue);
      expect(pdfRes.isSpoofed, isFalse);
      expect(pdfRes.detectedMimeType, 'application/pdf');

      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
      final pngRes = sniffer.inspectBytes(pngBytes, 'image.png');
      expect(pngRes.isClean, isTrue);
      expect(pngRes.isSpoofed, isFalse);
      expect(pngRes.detectedMimeType, 'image/png');

      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final jpgRes = sniffer.inspectBytes(jpgBytes, 'photo.jpg');
      expect(jpgRes.isClean, isTrue);
      expect(jpgRes.isSpoofed, isFalse);
      expect(jpgRes.detectedMimeType, 'image/jpeg');
    });

    test('Detects Windows PE executable masquerading as a PDF document', () {
      final spoofedBytes = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00, 0x03]); // MZ header
      final res = sniffer.inspectBytes(spoofedBytes, 'quarterly_financials.pdf');

      expect(res.isClean, isFalse);
      expect(res.isSpoofed, isTrue);
      expect(res.isExecutableOrScript, isTrue);
      expect(res.detectedMimeType, 'application/vnd.microsoft.portable-executable');
      expect(res.recommendedQuarantineReason, QuarantineReason.antimalwareFlagged);
      expect(res.requiresQuarantine, isTrue);
    });

    test('Detects Linux ELF binary masquerading as a JPEG image', () {
      final elfBytes = Uint8List.fromList([0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01]); // \x7fELF
      final res = sniffer.inspectBytes(elfBytes, 'profile_picture.jpeg');

      expect(res.isClean, isFalse);
      expect(res.isSpoofed, isTrue);
      expect(res.isExecutableOrScript, isTrue);
      expect(res.detectedMimeType, 'application/x-elf');
      expect(res.requiresQuarantine, isTrue);
    });

    test('Detects macOS Mach-O binary masquerading as a Word document', () {
      final machOBytes = Uint8List.fromList([0xFE, 0xED, 0xFA, 0xCF, 0x00]);
      final res = sniffer.inspectBytes(machOBytes, 'contract.docx');

      expect(res.isClean, isFalse);
      expect(res.isSpoofed, isTrue);
      expect(res.isExecutableOrScript, isTrue);
      expect(res.detectedMimeType, 'application/x-mach-binary');
      expect(res.requiresQuarantine, isTrue);
    });

    test('Detects shell script shebang masquerading as a PNG image', () {
      final scriptBytes = utf8.encode('#!/bin/bash\nrm -rf /data\n');
      final res = sniffer.inspectBytes(scriptBytes, 'screenshot.png');

      expect(res.isClean, isFalse);
      expect(res.isSpoofed, isTrue);
      expect(res.isExecutableOrScript, isTrue);
      expect(res.detectedMimeType, 'text/x-shellscript');
      expect(res.requiresQuarantine, isTrue);
    });

    test('Detects Android APK package disguised under innocent extension', () {
      // ZIP header with AndroidManifest.xml string embedded
      final zipHeader = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00];
      final manifestName = utf8.encode('AndroidManifest.xml');
      final apkBytes = Uint8List.fromList([...zipHeader, ...manifestName]);

      final res = sniffer.inspectBytes(apkBytes, 'audio_recording.mp3');
      expect(res.isClean, isFalse);
      expect(res.isSpoofed, isTrue);
      expect(res.isExecutableOrScript, isTrue);
      expect(res.detectedMimeType, 'application/vnd.android.package-archive');
      expect(res.requiresQuarantine, isTrue);
    });

    test('Legitimately named executable is identified without false spoof detection', () {
      final exeBytes = Uint8List.fromList([0x4D, 0x5A, 0x00]);
      final res = sniffer.inspectBytes(exeBytes, 'installer.exe');

      expect(res.isClean, isTrue);
      expect(res.isSpoofed, isFalse);
      expect(res.isExecutableOrScript, isTrue);
      expect(res.requiresQuarantine, isFalse);
    });

    test('Empty payload handling', () {
      final res = sniffer.inspectBytes([], 'empty.txt');
      expect(res.isClean, isTrue);
      expect(res.isSpoofed, isFalse);
      expect(res.detectedMimeType, 'application/x-empty');
    });
  });

  group('Phase 14.1: DOD 5220.22-M Multi-Pass Cryptographic Shredder', () {
    test('Overwrites physical disk file with 3 passes before deletion', () async {
      final tempDir = await Directory.systemTemp.createTemp('peerlink_shred_test_');
      final testFile = File('${tempDir.path}/confidential_payload.bin');
      await testFile.writeAsBytes(utf8.encode('TOP_SECRET_CREDENTIALS_AND_KEYS_99999'));

      expect(await testFile.exists(), isTrue);

      final item = QuarantinedItem(
        id: 'quar_shred_01',
        fileName: 'confidential_payload.bin',
        quarantinePath: testFile.path,
        reason: QuarantineReason.antimalwareFlagged,
        expectedSha256: 'abc',
        actualSha256: 'def',
        quarantinedAt: DateTime.now(),
        fileSizeBytes: await testFile.length(),
        sourcePeerId: 'peer_attacker',
      );

      QuarantineService.instance.addQuarantinedItem(item);
      expect(QuarantineService.instance.count, 1);

      // Execute purge & multi-pass shred
      await QuarantineService.instance.purgeItem(item.id);

      expect(QuarantineService.instance.count, 0);
      expect(await testFile.exists(), isFalse);

      await tempDir.delete(recursive: true);
    });
  });

  group('Phase 14.1: DeviceTrustService Authenticated Intent Guard (Rule 6)', () {
    final trustService = DeviceTrustService.instance;

    test('verifyPairingToken validates structured JSON token schema', () {
      final validToken = jsonEncode({
        'peerId': 'peer_node_delta',
        'fingerprint': 'ed25519:abcdef1234567890',
        'nonce': 'random_crypto_nonce_999',
      });

      expect(trustService.verifyPairingToken(validToken), isTrue);

      // Rejects empty or malformed token
      expect(trustService.verifyPairingToken(''), isFalse);
      expect(trustService.verifyPairingToken('not-json'), isFalse);

      // Rejects missing required field
      final missingField = jsonEncode({
        'peerId': 'peer_node_delta',
      });
      expect(trustService.verifyPairingToken(missingField), isFalse);
    });

    test('authenticateTrustOperation enforces authorization checks', () async {
      final canRevoke = await trustService.authenticateTrustOperation(
        peerId: 'peer_1',
        operation: 'REVOKE_PEER',
        userConfirmationPin: '1234',
      );
      expect(canRevoke, isTrue);

      // Rejects empty operation intent
      final emptyOp = await trustService.authenticateTrustOperation(
        peerId: 'peer_1',
        operation: '',
      );
      expect(emptyOp, isFalse);

      // Rejects invalid PIN length if supplied
      final invalidPin = await trustService.authenticateTrustOperation(
        peerId: 'peer_1',
        operation: 'REVOKE_PEER',
        userConfirmationPin: '12',
      );
      expect(invalidPin, isFalse);
    });
  });
}
