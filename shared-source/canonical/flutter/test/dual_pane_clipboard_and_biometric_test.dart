import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/biometric_auth_service.dart';
import 'package:peerlink/core/p2p_clipboard_transport_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/features/files/dual_pane_vault_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory leftDir;
  late Directory rightDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peerlink_dual_pane_test_');
    leftDir = Directory('${tempDir.path}/left_vault')..createSync();
    rightDir = Directory('${tempDir.path}/right_vault')..createSync();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('P2pClipboardTransportService Tests', () {
    test('enforces opt-in and does not broadcast when sync is disabled', () {
      final service = P2pClipboardTransportService.instance;
      service.setEnabled(false);

      expect(service.isEnabled, isFalse);

      bool broadcasted = false;
      service.onBroadcastFrame = (frame) => broadcasted = true;

      service.handleLocalClipboardChanged('Secret snippet');
      expect(broadcasted, isFalse);
    });

    test('broadcasts authenticated frame when sync is enabled', () {
      final service = P2pClipboardTransportService.instance;
      service.setEnabled(true);

      Map<String, dynamic>? sentFrame;
      service.onBroadcastFrame = (frame) => sentFrame = frame;

      service.handleLocalClipboardChanged('Shared text from PeerLink');
      expect(sentFrame, isNotNull);
      expect(sentFrame!['type'], 'CLIPBOARD_SYNC');
      expect(sentFrame!['content'], 'Shared text from PeerLink');
      expect(sentFrame!['isOtp'], isFalse);

      // Test OTP auto-detection
      service.handleLocalClipboardChanged('849201');
      expect(sentFrame!['isOtp'], isTrue);

      service.setEnabled(false);
    });

    test('rejects incoming unauthenticated or malformed clipboard frame (Rule 12)', () {
      final service = P2pClipboardTransportService.instance;
      service.setEnabled(true);

      // Frame with missing type
      final invalid = service.processIncomingFrame({'content': 'Malicious injection'});
      expect(invalid, isFalse);

      // Valid frame
      final valid = service.processIncomingFrame({
        'type': 'CLIPBOARD_SYNC',
        'content': 'Valid text from phone',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isOtp': false,
      });
      expect(valid, isTrue);
      expect(service.lastReceivedContent, 'Valid text from phone');

      service.setEnabled(false);
    });
  });

  group('BiometricAuthService Tests', () {
    test('checks availability and authenticates successfully with fail-closed security', () async {
      final bio = BiometricAuthService.instance;
      bio.setMockBiometricAvailable(true);

      final canAuth = await bio.canAuthenticate();
      expect(canAuth, isTrue);

      bio.setMockAuthOutcome(true);
      final success = await bio.authenticate(reason: 'Unlock Safe Folder');
      expect(success, isTrue);

      // Fail-closed test: user cancels or biometric fails
      bio.setMockAuthOutcome(false);
      final failed = await bio.authenticate(reason: 'Unlock Safe Folder');
      expect(failed, isFalse);
    });

    test('inactivity auto-lock triggers when timeout expires', () {
      final bio = BiometricAuthService.instance;
      bool lockedOut = false;

      bio.startInactivityMonitor(
        timeout: const Duration(milliseconds: 50),
        onAutoLock: () => lockedOut = true,
      );

      expect(lockedOut, isFalse);
      sleep(const Duration(milliseconds: 70));
      bio.checkInactivityTimeout();
      expect(lockedOut, isTrue);

      bio.stopInactivityMonitor();
    });
  });

  group('DualPaneVaultView Widget Tests', () {
    testWidgets('renders single pane on mobile (< 960dp) and dual panes on desktop (>= 960dp)', (tester) async {
      final file1 = File('${leftDir.path}/doc1.txt')..writeAsStringSync('Doc 1 content');
      final file2 = File('${rightDir.path}/doc2.txt')..writeAsStringSync('Doc 2 content');

      final itemsLeft = [
        ReceivedFileItem(
          path: file1.path,
          name: 'doc1.txt',
          sizeBytes: 13,
          lastModified: DateTime.now(),
          category: ReceivedFileCategory.documents,
          extension: 'txt',
        ),
      ];

      final itemsRight = [
        ReceivedFileItem(
          path: file2.path,
          name: 'doc2.txt',
          sizeBytes: 13,
          lastModified: DateTime.now(),
          category: ReceivedFileCategory.documents,
          extension: 'txt',
        ),
      ];

      // 1. Mobile viewport (400 x 800) -> Single Pane
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: DualPaneVaultView(
                leftTitle: 'Vault Primary',
                rightTitle: 'Secondary Storage',
                leftItems: itemsLeft,
                rightItems: itemsRight,
                leftDirectory: leftDir,
                rightDirectory: rightDir,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('single_pane_view')), findsOneWidget);
      expect(find.byKey(const Key('dual_pane_split_view')), findsNothing);

      // 2. Desktop wide viewport (1200 x 800) -> Dual Pane Split View
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: DualPaneVaultView(
                leftTitle: 'Vault Primary',
                rightTitle: 'Secondary Storage',
                leftItems: itemsLeft,
                rightItems: itemsRight,
                leftDirectory: leftDir,
                rightDirectory: rightDir,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dual_pane_split_view')), findsOneWidget);
      expect(find.text('Vault Primary'), findsOneWidget);
      expect(find.text('Secondary Storage'), findsOneWidget);
      expect(find.text('doc1.txt'), findsOneWidget);
      expect(find.text('doc2.txt'), findsOneWidget);
      expect(find.byKey(const Key('copy_to_other_pane_button')), findsWidgets);
    });
  });
}
