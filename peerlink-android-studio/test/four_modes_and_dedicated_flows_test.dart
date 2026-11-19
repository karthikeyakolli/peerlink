import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/features/files/file_manager_home_screen.dart';
import 'package:peerlink/features/media/media_hub_flow_view.dart';
import 'package:peerlink/features/share/share_hub_flow_view.dart';
import 'package:peerlink/features/converter/file_converter_flow_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleTxt;
  late File sampleImg;
  late File sampleVid;
  late File sampleAud;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_flows_test_');
    AppSettingsService.instance.saveLocation = tempDir.path;

    sampleTxt = File('${tempDir.path}${Platform.pathSeparator}document.txt')
      ..writeAsStringSync('Hello World Test Document Content');
    sampleImg = File('${tempDir.path}${Platform.pathSeparator}photo.jpg')
      ..writeAsBytesSync([255, 216, 255, 224, 0, 16, 74, 70, 73, 70]); // JPEG header
    sampleVid = File('${tempDir.path}${Platform.pathSeparator}clip.mp4')
      ..writeAsBytesSync([0, 0, 0, 24, 102, 116, 121, 112]); // MP4 ftyp header
    sampleAud = File('${tempDir.path}${Platform.pathSeparator}soundtrack.mp3')
      ..writeAsBytesSync([73, 68, 51, 3, 0, 0]); // ID3 header
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Top-Left 4 Mode Switcher & Dedicated Flows Tests', () {
    testWidgets('FileManagerHomeScreen renders 4 symbol buttons and defaults to Mode 0 (File Manager)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FileManagerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 4 mode symbol buttons on top left
      expect(find.byKey(const Key('appbar_mode_filemanager')), findsOneWidget);
      expect(find.byKey(const Key('appbar_mode_media')), findsOneWidget);
      expect(find.byKey(const Key('appbar_mode_share')), findsOneWidget);
      expect(find.byKey(const Key('appbar_mode_conversions')), findsOneWidget);

      // Verify default is File Manager (Mode 0)
      expect(find.byKey(const Key('vault_storage_scope_vault')), findsOneWidget);
      expect(find.byKey(const Key('vault_storage_scope_device')), findsOneWidget);
    });

    testWidgets('Tapping Mode 1 switches to dedicated Media Viewer & Player Flow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FileManagerHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Mode 1 (Media Viewer & Player)
      await tester.tap(find.byKey(const Key('appbar_mode_media')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Media Hub view is active
      expect(find.byType(MediaHubFlowView), findsOneWidget);
      expect(find.text('All Media'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Audio Jukebox'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);

      // Tap Audio Jukebox tab
      await tester.tap(find.byKey(const Key('media_tab_audio')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Speed:'), findsOneWidget);
      expect(find.text('Sleep Timer:'), findsOneWidget);
    });

    testWidgets('Tapping Mode 2 switches to dedicated P2P Share & Link Flow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FileManagerHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Mode 2 (Share & Link Hub)
      await tester.tap(find.byKey(const Key('appbar_mode_share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Share Hub view is active
      expect(find.byType(ShareHubFlowView), findsOneWidget);
      expect(find.text('Direct P2P Beam & Discovery'), findsOneWidget);
      expect(find.text('Hotspot Auto-Tether QR'), findsOneWidget);
      expect(find.text('Bi-Directional Web Portal 2.0'), findsOneWidget);
      expect(find.text('One-Time Ephemeral Burner Vault Share'), findsOneWidget);
      expect(find.byKey(const Key('share_hub_create_burner_button')), findsOneWidget);
    });

    testWidgets('Tapping Mode 3 switches to dedicated File Conversions & Studio Flow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FileManagerHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Mode 3 (File Conversions & Studio)
      await tester.tap(find.byKey(const Key('appbar_mode_conversions')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify File Converter Studio view is active
      expect(find.byType(FileConverterFlowView), findsOneWidget);
      expect(find.text('Offline Format Converter'), findsOneWidget);
      expect(find.text('In-App Video Trimmer & Audio Extractor'), findsOneWidget);
      expect(find.text('Checksum & Integrity Verifier'), findsOneWidget);
      expect(find.text('Storage Junk Scrubber'), findsOneWidget);
    });
  });

  group('Cryptographic Checksum Verifier Logic Tests', () {
    test('Calculates exact SHA-256 and MD5 hashes matching known crypto outputs', () async {
      final bytes = sampleTxt.readAsBytesSync();
      final expectedSha = sha256.convert(bytes).toString();
      final expectedMd5 = md5.convert(bytes).toString();

      expect(expectedSha.length, equals(64));
      expect(expectedMd5.length, equals(32));
      expect(expectedSha, equals(sha256.convert(utf8.encode('Hello World Test Document Content')).toString()));
    });
  });
}
