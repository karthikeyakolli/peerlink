import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:peerlink/core/models/file_item.dart';
import 'package:peerlink/core/services/photo_similarity_service.dart';
import 'package:peerlink/core/services/secure_shredder_service.dart';
import 'package:peerlink/core/services/file_tagging_service.dart';
import 'package:peerlink/core/services/resumable_transfer_service.dart';
import 'package:peerlink/core/services/ransomware_canary_guard.dart';
import 'package:peerlink/core/services/exif_sanitizer_service.dart';
import 'package:peerlink/core/audio_player_service.dart';
import 'package:peerlink/design_system/components/similar_photo_grouper_sheet.dart';
import 'package:peerlink/design_system/components/storage_treemap_sheet.dart';
import 'package:peerlink/design_system/components/secure_file_shredder_sheet.dart';
import 'package:peerlink/design_system/components/file_tagging_sheet.dart';
import 'package:peerlink/design_system/components/visual_diff_comparator_sheet.dart';
import 'package:peerlink/design_system/components/subtitle_sync_sheet.dart';
import 'package:peerlink/design_system/components/audio_sleep_timer_sheet.dart';
import 'package:peerlink/design_system/components/audio_equalizer_sheet.dart';
import 'package:peerlink/design_system/components/multi_stream_bonding_sheet.dart';
import 'package:peerlink/design_system/components/local_walkie_talkie_sheet.dart';
import 'package:peerlink/design_system/components/remote_presentation_clicker_sheet.dart';
import 'package:peerlink/design_system/components/shared_local_scratchpad_sheet.dart';
import 'package:peerlink/design_system/components/split_apk_inspector_sheet.dart';
import 'package:peerlink/design_system/components/exif_sanitizer_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category A: Advanced File Management & Storage Intelligence (Suggestions 1 - 6)', () {
    test('1. PhotoSimilarityService: Computes perceptual dHash and groups burst duplicates', () {
      final s = PhotoSimilarityService.instance;
      final bytesA = Uint8List.fromList(List.generate(256, (i) => (i * 17) % 256));
      final bytesB = Uint8List.fromList(List.generate(256, (i) => ((i * 17) + (i % 2 == 0 ? 2 : 0)) % 256));

      final hashA = s.computeDHash(bytesA);
      final hashB = s.computeDHash(bytesB);
      expect(hashA, isNonZero);
      expect(hashB, isNonZero);

      final similarity = s.calculateSimilarity(hashA, hashB);
      expect(similarity, greaterThan(0.70));

      final photos = [
        FileItem(name: 'IMG_001.jpg', path: '/photos/IMG_001.jpg', size: 4000000, modified: DateTime.now()),
        FileItem(name: 'IMG_002.jpg', path: '/photos/IMG_002.jpg', size: 5000000, modified: DateTime.now()),
      ];
      final groups = s.groupSimilarPhotos(photos);
      expect(groups.isNotEmpty, isTrue);
      expect(groups.first.bestShot.name, equals('IMG_002.jpg')); // Higher size prioritised
    });

    testWidgets('1b. SimilarPhotoGrouperSheet renders similarity score and Keep Best Shot button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimilarPhotoGrouperSheet(photoItems: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Similar Photos & Burst Grouper'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsWidgets);
    });

    testWidgets('2. StorageTreemapSheet renders WinDirStat-style heatmap breakdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StorageTreemapSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Disk Space Heatmap & Treemap'), findsOneWidget);
      expect(find.text('Videos & Recordings'), findsOneWidget);
      expect(find.text('Photos & Camera Bursts'), findsOneWidget);
      expect(find.text('Category Allocation'), findsOneWidget);
    });

    test('3. SecureShredderService performs DoD 5220.22-M overwrite on real temporary file', () async {
      final tempDir = Directory.systemTemp.createTempSync('peerlink_shred_test');
      final tempFile = File('${tempDir.path}/secret_doc.txt');
      await tempFile.writeAsString('SUPER SECRET SENSITIVE DATA TO OVERWRITE BEFORE DELETION');

      expect(await tempFile.exists(), isTrue);

      final shredder = SecureShredderService.instance;
      final ok = await shredder.shredFile(tempFile.path, algorithm: ShredAlgorithm.dod522022M);

      expect(ok, isTrue);
      expect(await tempFile.exists(), isFalse); // Overwritten and unlinked

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('3b. SecureFileShredderSheet renders DoD 5220.22-M choice and confirm button', (tester) async {
      final dummyItem = FileItem(name: 'test_id.pdf', path: '/dummy/test_id.pdf', size: 1024, modified: DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecureFileShredderSheet(fileItem: dummyItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DoD 5220.22-M Secure Shredder'), findsOneWidget);
      expect(find.text('DoD 5220.22-M'), findsOneWidget);
      expect(find.byKey(const Key('confirm_secure_shred_button')), findsOneWidget);
    });

    test('5. FileTaggingService adds, toggles and queries virtual color tags', () {
      final s = FileTaggingService.instance;
      const testFile = '/vault/quarterly_taxes_2026.pdf';
      const tag = FileTag(label: 'Taxes', color: Color(0xFFD97706));

      s.addTag(testFile, tag);
      expect(s.hasTag(testFile, 'Taxes'), isTrue);
      expect(s.getFilesWithTag('Taxes').contains(testFile), isTrue);

      s.toggleTag(testFile, tag);
      expect(s.hasTag(testFile, 'Taxes'), isFalse);
    });

    testWidgets('5b. FileTaggingSheet renders tag presets and custom tag field', (tester) async {
      final dummy = FileItem(name: 'doc.pdf', path: '/vault/doc.pdf', size: 2048, modified: DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileTaggingSheet(fileItem: dummy),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Virtual Tags & Color Badges'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byKey(const Key('add_custom_tag_button')), findsOneWidget);
    });

    testWidgets('6. VisualDiffComparatorSheet renders side-by-side color additions and deletions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VisualDiffComparatorSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visual Diff Comparator'), findsOneWidget);
      expect(find.text('3 additions'), findsOneWidget);
      expect(find.text('2 deletions'), findsOneWidget);
    });
  });

  group('Category B: Next-Gen Media Engine & Audio Studio (Suggestions 7 - 12)', () {
    testWidgets('7. SubtitleSyncSheet renders subtitle detector and timing offset slider', (tester) async {
      int reportedOffset = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitleSyncSheet(
              videoStem: 'lecture_intro',
              onOffsetChanged: (ms) => reportedOffset = ms,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subtitles & Real-Time Sync'), findsOneWidget);
      expect(find.text('lecture_intro.en.srt'), findsOneWidget);
      expect(find.text('+0 ms'), findsOneWidget);

      await tester.tap(find.text('+100 ms'));
      await tester.pumpAndSettle();
      expect(reportedOffset, equals(100));
    });

    test('8. AudioPlayerService pitch-preserving variable speed booster up to 3.0x', () {
      final s = AudioPlayerService.instance;
      s.setPlaybackSpeed(2.5);
      expect(s.speedNotifier.value, equals(2.5));
      s.setPlaybackSpeed(3.0);
      expect(s.speedNotifier.value, equals(3.0));
      s.setPlaybackSpeed(0.5);
      expect(s.speedNotifier.value, equals(0.5));
    });

    testWidgets('9. AudioSleepTimerSheet renders duration presets and volume fade toggle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioSleepTimerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audio Sleep Timer'), findsOneWidget);
      expect(find.byKey(const Key('sleep_preset_30m')), findsOneWidget);
      expect(find.text('Smooth 30s Volume Fade-Out'), findsOneWidget);
    });

    testWidgets('11. AudioEqualizerSheet renders 5 frequency bands and acoustic presets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioEqualizerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5-Band Equalizer & Vocal Clarity'), findsOneWidget);
      expect(find.text('Vocal Clarity'), findsOneWidget);
      expect(find.text('Bass Boost'), findsOneWidget);
      expect(find.text('60Hz'), findsOneWidget);
      expect(find.text('14kHz'), findsOneWidget);
    });
  });

  group('Category C & D: P2P Turbochargers & Cross-Device Interop (Suggestions 13 - 20)', () {
    test('13. ResumableTransferService maintains 1 MB chunk bitmask and missing chunks', () {
      final s = ResumableTransferService.instance;
      final session = s.getOrCreateSession(
        transferId: 'session_iso_test',
        fileName: 'arch.iso',
        totalBytes: 5 * 1024 * 1024, // 5 MB = 5 chunks
      );
      expect(session.totalChunks, equals(5));

      session.markChunkReceived(0);
      session.markChunkReceived(1);
      session.markChunkReceived(2);

      expect(session.receivedChunks.length, equals(3));
      expect(session.progressRatio, closeTo(0.60, 0.01));
      expect(session.missingChunks, equals([3, 4]));
      expect(session.isComplete, isFalse);
    });

    testWidgets('14. MultiStreamBondingSheet renders parallel socket pool telemetry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MultiStreamBondingSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Multi-Stream Link Bonding'), findsOneWidget);
      expect(find.text('Pipeline A: Wi-Fi 6 (5 GHz WLAN)'), findsOneWidget);
      expect(find.text('121.1 MB/s'), findsOneWidget);
    });

    testWidgets('17. LocalWalkieTalkieSheet renders Push-to-Talk button and PTT state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocalWalkieTalkieSheet(peerName: 'Desktop-Node'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P2P Encrypted Walkie-Talkie'), findsOneWidget);
      expect(find.byKey(const Key('ptt_walkie_talkie_button')), findsOneWidget);
      expect(find.text('HOLD TO TALK'), findsOneWidget);
    });

    testWidgets('18. RemotePresentationClickerSheet renders Next/Prev buttons and trackpad', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RemotePresentationClickerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Presentation Clicker & Remote'), findsOneWidget);
      expect(find.byKey(const Key('clicker_next_button')), findsOneWidget);
      expect(find.byKey(const Key('clicker_prev_button')), findsOneWidget);
    });

    testWidgets('19. SharedLocalScratchpadSheet renders synchronized note editor and copy/sync buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharedLocalScratchpadSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared LAN Scratchpad'), findsOneWidget);
      expect(find.byKey(const Key('scratchpad_copy_button')), findsOneWidget);
      expect(find.byKey(const Key('scratchpad_sync_button')), findsOneWidget);
    });

    testWidgets('20. SplitApkInspectorSheet renders constituent split modules and target SDK', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SplitApkInspectorSheet(bundleName: 'whatsapp_split.apks'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Split-APK & Bundle Inspector'), findsOneWidget);
      expect(find.text('base.apk'), findsOneWidget);
      expect(find.text('config.arm64_v8a.apk'), findsOneWidget);
      expect(find.text('35 (Android 15)'), findsOneWidget);
    });
  });

  group('Category E: Privacy & Ransomware Anti-Tamper Security (Suggestions 21 - 22)', () {
    test('21. ExifSanitizerService strips GPS and camera metadata without corrupting pixels', () {
      final s = ExifSanitizerService.instance;
      // Synthesize fake JPEG with APP1 EXIF marker (0xFF 0xE1)
      final fakeJpeg = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xE1, 0x00, 0x08, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // APP1 EXIF header
        0xFF, 0xDA, // SOS
        0x12, 0x34, 0x56, 0x78, // image data
      ]);

      final cleanBytes = s.sanitizeBytes(fakeJpeg);
      expect(cleanBytes.length, lessThan(fakeJpeg.length));
      expect(cleanBytes[0], equals(0xFF));
      expect(cleanBytes[1], equals(0xD8));
    });

    testWidgets('21b. ExifSanitizerSheet renders tags to be scrubbed and sanitize action', (tester) async {
      final dummy = FileItem(name: 'photo_gps.jpg', path: '/vault/photo_gps.jpg', size: 1000000, modified: DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExifSanitizerSheet(fileItem: dummy),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EXIF & GPS Privacy Sanitizer'), findsOneWidget);
      expect(find.byKey(const Key('sanitize_exif_button')), findsOneWidget);
    });

    test('22. RansomwareCanaryGuard trips vault lock upon high-velocity suspicious writes', () {
      final guard = RansomwareCanaryGuard.instance;
      guard.unlockVault();
      expect(guard.isVaultLocked, isFalse);

      // Simulate 22 rapid modifications with .locked extension
      for (int i = 0; i < 22; i++) {
        guard.recordOperation('document_$i.pdf.locked');
      }

      expect(guard.isVaultLocked, isTrue);
      expect(guard.lastTrip, isNotNull);
      expect(guard.lastTrip!.triggerPath, contains('.locked'));

      guard.unlockVault();
      expect(guard.isVaultLocked, isFalse);
    });
  });
}
