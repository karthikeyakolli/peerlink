import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/core/remote_access_service.dart';
import 'package:peerlink/features/files/files_screen.dart';
import 'package:peerlink/features/files/remote_scoped_browser_sheet.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
  });

  group('RemoteAccessService: Security Sandboxing & ACCESS Contract (Rules 2, 6, 9, 10)', () {
    test('Rule 6: Reject browsing untrusted or unpaired peer', () async {
      expect(
        () => RemoteAccessService.instance.getSharesForPeer('unknown_untrusted_peer'),
        throwsA(isA<SandboxViolationException>()),
      );
    });

    test('Rule 2: Path traversal attempts are blocked deterministically', () async {
      DeviceTrustService.instance.pairDevice(
        const PairedDevice(
          id: 'peer-test-laptop',
          name: 'Test Laptop',
          deviceType: 'laptop',
          fingerprint: 'ed25519:testlaptop123',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
        ),
      );

      // Traversal using ..
      expect(
        () => RemoteAccessService.instance.browseDirectory(
          peerId: 'peer-test-laptop',
          shareId: 'default',
          relativePath: '../private/keys',
        ),
        throwsA(isA<SandboxViolationException>()),
      );

      // Traversal using leading root slash
      expect(
        () => RemoteAccessService.instance.browseDirectory(
          peerId: 'peer-test-laptop',
          shareId: 'default',
          relativePath: '/etc/shadow',
        ),
        throwsA(isA<SandboxViolationException>()),
      );

      // Traversal using Windows drive letter
      expect(
        () => RemoteAccessService.instance.browseDirectory(
          peerId: 'peer-test-laptop',
          shareId: 'default',
          relativePath: 'C:\\Windows\\System32',
        ),
        throwsA(isA<SandboxViolationException>()),
      );
    });

    test('Browsing returns sorted directory entries (folders first)', () async {
      DeviceTrustService.instance.pairDevice(
        const PairedDevice(
          id: 'peer-test-laptop',
          name: 'Test Laptop',
          deviceType: 'laptop',
          fingerprint: 'ed25519:testlaptop123',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
        ),
      );

      final rootItems = await RemoteAccessService.instance.browseDirectory(
        peerId: 'peer-test-laptop',
        shareId: 'default',
        relativePath: '',
      );

      expect(rootItems.isNotEmpty, isTrue);
      // First items should be directories
      expect(rootItems.first.isDirectory, isTrue);
      expect(rootItems.first.name, 'Media & Photos');
      expect(rootItems[1].isDirectory, isTrue);
      expect(rootItems[1].name, 'Shared Documents');

      // Following items should be files
      expect(rootItems[2].isDirectory, isFalse);
      expect(rootItems[2].name, 'Project Archive.zip');
    });

    test('Rule 10: downloadFile stages in quarantine (.part) and logs journal operations', () async {
      DeviceTrustService.instance.pairDevice(
        const PairedDevice(
          id: 'peer-test-laptop',
          name: 'Test Laptop',
          deviceType: 'laptop',
          fingerprint: 'ed25519:testlaptop123',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
        ),
      );

      final fileItem = RemoteFileItem(
        name: 'test_doc.pdf',
        relativePath: 'documents/test_doc.pdf',
        isDirectory: false,
        byteSize: 1024 * 100,
        modifiedTime: DateTime.now(),
        mimeType: 'application/pdf',
        contentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      final destinationPath = await RemoteAccessService.instance.downloadFile(
        peerId: 'peer-test-laptop',
        shareId: 'default',
        item: fileItem,
        destinationDir: '/storage/downloads',
      );

      expect(destinationPath, '/storage/downloads/test_doc.pdf');

      // Assert journal entry created and committed
      final ops = OperationJournalService.instance.operations;
      expect(ops.isNotEmpty, isTrue);
      final lastOp = ops.last;
      expect(lastOp.type, OperationType.receive);
      expect(lastOp.state, JournalOperationState.committed);
      expect(lastOp.stage, JournalStage.finalize);
      expect(lastOp.summary, contains('test_doc.pdf'));
    });
  });

  group('RemoteScopedBrowserSheet Widget & UX Navigation Tests', () {
    final testDevice = const PairedDevice(
      id: 'peer-work-pc',
      name: 'Work Desktop',
      deviceType: 'laptop',
      fingerprint: 'ed25519:workpc998877',
      trustLevel: DeviceTrustLevel.trustedPeer,
      isOnline: true,
      lastSeen: 'Active direct TLS',
    );

    testWidgets('Renders header, sandbox security notice, breadcrumbs, and directory items',
        (WidgetTester tester) async {
      DeviceTrustService.instance.pairDevice(testDevice);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteScopedBrowserSheet(device: testDevice),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header & Identity
      expect(find.text('Browse: Work Desktop'), findsOneWidget);
      expect(find.textContaining('Scoped Sandbox'), findsWidgets);
      expect(find.textContaining('Rule 2 Sandboxed'), findsOneWidget);

      // 2. Directory Listing
      expect(find.text('Shared Documents'), findsOneWidget);
      expect(find.text('Media & Photos'), findsOneWidget);
      expect(find.text('Project Archive.zip'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('Search filter narrows down visible items in real-time',
        (WidgetTester tester) async {
      DeviceTrustService.instance.pairDevice(testDevice);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteScopedBrowserSheet(device: testDevice),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'README');
      await tester.pumpAndSettle();

      // Only README.md should be visible
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('Shared Documents'), findsNothing);
      expect(find.text('Project Archive.zip'), findsNothing);

      // Clear search query
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Shared Documents'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('Drill down into subfolder and navigate back with breadcrumbs',
        (WidgetTester tester) async {
      DeviceTrustService.instance.pairDevice(testDevice);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteScopedBrowserSheet(device: testDevice),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Shared Documents" folder
      await tester.tap(find.text('Shared Documents'));
      await tester.pumpAndSettle();

      // Verify breadcrumbs update
      expect(find.text('documents'), findsOneWidget);

      // Verify folder contents
      expect(find.text('Engineering Spec v2.pdf'), findsOneWidget);
      expect(find.text('Security Audit Report.pdf'), findsOneWidget);
      expect(find.text('Financial Summary.xlsx'), findsOneWidget);

      // Tap Root breadcrumb to navigate back
      await tester.tap(find.text('Shared Workspace'));
      await tester.pumpAndSettle();

      // Verify root items reappear
      expect(find.text('Shared Documents'), findsOneWidget);
      expect(find.text('Media & Photos'), findsOneWidget);
    });

    testWidgets('File tap opens inspection modal and triggers safe download',
        (WidgetTester tester) async {
      DeviceTrustService.instance.pairDevice(testDevice);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteScopedBrowserSheet(device: testDevice),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "README.md"
      await tester.tap(find.text('README.md'));
      await tester.pumpAndSettle();

      // Assert inspection modal contents
      expect(find.text('README.md'), findsWidgets);
      expect(find.textContaining('Rule 10 Enforced'), findsOneWidget);
      expect(find.text('Download to This Device'), findsOneWidget);

      // Tap "Download to This Device"
      await tester.tap(find.text('Download to This Device'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Assert download completion message
      expect(find.text('Download Complete'), findsOneWidget);
      expect(find.textContaining('Saved to:'), findsOneWidget);
    });
  });

  group('FilesScreen: BROWSE PEER Navigation Tab Integration', () {
    testWidgets('FilesScreen renders 3 tabs: SEND, BROWSE PEER, ACTIVE & HISTORY',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert all 3 tabs are present
      expect(find.text('SEND'), findsOneWidget);
      expect(find.text('BROWSE PEER'), findsOneWidget);
      expect(find.text('ACTIVE & HISTORY'), findsOneWidget);

      // Tap BROWSE PEER tab
      await tester.tap(find.text('BROWSE PEER'));
      await tester.pumpAndSettle();

      // Verify explanation banner is visible
      expect(find.text('Remote Scoped Explorer (ACCESS Mode)'), findsOneWidget);
      expect(find.text('No Paired Devices'), findsOneWidget);
    });

    testWidgets('FilesScreen BROWSE PEER tab lists paired devices with Browse Files action',
        (WidgetTester tester) async {
      DeviceTrustService.instance.pairDevice(
        const PairedDevice(
          id: 'peer-nas-box',
          name: 'Home Media Server',
          deviceType: 'laptop',
          fingerprint: 'ed25519:nasbox123',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
          lastSeen: 'Connected via LAN',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap BROWSE PEER tab
      await tester.tap(find.text('BROWSE PEER'));
      await tester.pumpAndSettle();

      // Verify device is displayed
      expect(find.text('Home Media Server'), findsOneWidget);
      expect(find.text('Browse Files'), findsOneWidget);

      // Tap Browse Files
      await tester.tap(find.text('Browse Files'));
      await tester.pumpAndSettle();

      // Verify RemoteScopedBrowserSheet opens
      expect(find.text('Browse: Home Media Server'), findsOneWidget);
    });
  });
}
