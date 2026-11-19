import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/system_media_scanner_service.dart';
import 'package:peerlink/design_system/components/dedicated_tool_page.dart';
import 'package:peerlink/features/files/file_manager_home_screen.dart';
import 'package:peerlink/features/media/media_hub_flow_view.dart';
import 'package:peerlink/features/share/share_hub_flow_view.dart';
import 'package:peerlink/features/converter/file_converter_flow_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory picturesDir;
  late Directory musicDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_sys_media_test_');
    AppSettingsService.instance.saveLocation = tempDir.path;

    picturesDir = Directory('${tempDir.path}${Platform.pathSeparator}Pictures')..createSync();
    musicDir = Directory('${tempDir.path}${Platform.pathSeparator}Music')..createSync();

    File('${picturesDir.path}${Platform.pathSeparator}vacation.jpg')
      ..writeAsBytesSync([255, 216, 255, 224, 0, 16, 74, 70, 73, 70]);
    File('${musicDir.path}${Platform.pathSeparator}track01.mp3')
      ..writeAsBytesSync([73, 68, 51, 3, 0, 0]);
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('SystemMediaScannerService Tests', () {
    test('Scans media from specified system directory paths and categorizes items', () async {
      final scanner = SystemMediaScannerService.instance;
      final results = await scanner.scanDeviceStorage(customRootDir: picturesDir, forceRefresh: true);

      expect(results.isNotEmpty, isTrue);
      expect(results.any((f) => f.name == 'vacation.jpg' && f.isImage), isTrue);
    });

    test('cachedFiles returns list of cached items', () {
      final scanner = SystemMediaScannerService.instance;
      final cached = scanner.cachedFiles;
      expect(cached, isNotNull);
    });

    test('addCustomScanFolder, removeCustomScanFolder and customFolderPaths work correctly', () {
      final scanner = SystemMediaScannerService.instance;
      scanner.clearCustomScanFolders();
      expect(scanner.customFolderPaths.isEmpty, isTrue);

      scanner.addCustomScanFolder(picturesDir.path);
      expect(scanner.customFolderPaths.contains(picturesDir.path), isTrue);

      scanner.removeCustomScanFolder(picturesDir.path);
      expect(scanner.customFolderPaths.contains(picturesDir.path), isFalse);
    });
  });

  group('DedicatedToolPage Widget Tests', () {
    testWidgets('DedicatedToolPage renders title, subtitle, icon and pops on back button', (tester) async {
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_tool_button'),
                onPressed: () {
                  DedicatedToolPage.open(
                    ctx,
                    title: 'Studio Workspace',
                    subtitle: 'Full-Screen Testing Page',
                    icon: Icons.architecture_rounded,
                    child: const Text('Workspace Content Loaded'),
                  ).then((_) => popped = true);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_tool_button')));
      await tester.pumpAndSettle();

      expect(find.text('Studio Workspace'), findsOneWidget);
      expect(find.text('Full-Screen Testing Page'), findsOneWidget);
      expect(find.text('Workspace Content Loaded'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });

  group('4 Spaces & System Media Synchronization Flow Tests', () {
    testWidgets('FileManagerHomeScreen renders Space Context Header for all 4 spaces', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: FileManagerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Space 0: File Explorer Space
      expect(find.text('File Explorer Space'), findsOneWidget);
      expect(find.text('Local System Storage & Cryptographic Secure Vault'), findsOneWidget);

      // Tap Mode 1: Player Hub Space
      await tester.tap(find.byKey(const Key('appbar_mode_media')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Player Hub Space'), findsOneWidget);
      expect(find.text('Universal Device Media Player, Video Theater & Lossless Jukebox'), findsOneWidget);
      expect(find.byType(MediaHubFlowView), findsOneWidget);

      // Verify Storage Scope Selector and Sync System Storage Button
      expect(find.byKey(const Key('storage_scope_device_btn')), findsOneWidget);
      expect(find.byKey(const Key('storage_scope_vault_btn')), findsOneWidget);
      expect(find.byKey(const Key('storage_scope_unified_btn')), findsOneWidget);
      expect(find.byKey(const Key('sync_system_media_button')), findsOneWidget);

      // Switch Storage Scope to Vault
      await tester.tap(find.byKey(const Key('storage_scope_vault_btn')));
      await tester.pumpAndSettle();

      // Switch Storage Scope to Unified
      await tester.tap(find.byKey(const Key('storage_scope_unified_btn')));
      await tester.pumpAndSettle();

      // Tap Sync System Storage Button
      await tester.tap(find.byKey(const Key('sync_system_media_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Tap Mode 2: P2P Share & Link Space
      await tester.tap(find.byKey(const Key('appbar_mode_share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('P2P Share & Link Space'), findsOneWidget);
      expect(find.text('Decentralized Transfer Engine, WebBeam 2.0 & Wi-Fi Direct'), findsOneWidget);
      expect(find.byType(ShareHubFlowView), findsOneWidget);

      // Tap Mode 3: Conversion Studio Space
      await tester.tap(find.byKey(const Key('appbar_mode_conversions')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Conversion Studio Space'), findsOneWidget);
      expect(find.text('iLovePDF 23-Format Power Studio & Mobile Document Scanner'), findsOneWidget);
      expect(find.byType(FileConverterFlowView), findsOneWidget);
    });
  });
}
