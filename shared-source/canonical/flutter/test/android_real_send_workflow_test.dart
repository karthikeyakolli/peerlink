import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/features/files/files_screen.dart';
import 'package:peerlink/platform/android_node_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel =
      MethodChannel('org.peerlink/android_node_methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      if (call.method == 'getNodeState') {
        return 'ACTIVE';
      } else if (call.method == 'initiateSend') {
        final targetPeer = call.arguments['targetPeerId'] as String?;
        final uris = (call.arguments['contentUris'] as List<dynamic>?)?.cast<String>() ?? [];
        if (targetPeer == 'unreachable_peer') {
          return '';
        }
        // Genuine SAF URI check: must begin with content://
        for (final uri in uris) {
          if (!uri.startsWith('content://')) {
            throw PlatformException(
              code: 'INVALID_URI',
              message: 'SAF URI must begin with content://, got: $uri',
            );
          }
        }
        return 'xfer-saf-android-888';
      } else if (call.method == 'pickContentUris') {
        return [
          'content://com.android.providers.media.documents/document/image%3A54321',
        ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('Android Real SEND Workflow & SAF Tests', () {
    testWidgets('FilesScreen exposes genuine SAF content URIs without fake /storage/emulated/0 paths',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify NO fake mock filesystem paths exist
      expect(find.textContaining('/storage/emulated/0'), findsNothing);

      // Verify Pick SAF File action is available
      expect(find.text('Pick SAF File'), findsOneWidget);
    });

    testWidgets('Tapping Pick SAF File adds genuine content:// URI to selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final pickSafButton = find.text('Pick SAF File');
      expect(pickSafButton, findsOneWidget);
      await tester.tap(pickSafButton);
      await tester.pumpAndSettle();

      // Verify SAF Document was added (file name derived from image:54321 is '54321')
      expect(find.text('54321'), findsOneWidget);
    });

    testWidgets('Android SEND with genuine SAF URI triggers native initiateSend and initiates transfer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll ListView to reveal manual form
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final advancedTile = find.text('Advanced Manual Paths & Policy');
      expect(advancedTile, findsOneWidget);
      await tester.tap(advancedTile);
      await tester.pumpAndSettle();

      // Set target peer and genuine SAF URI
      final peerField = find.widgetWithText(TextField, 'Target Peer ID');
      await tester.enterText(peerField, 'peer_windows_workstation');

      final sourceField = find.widgetWithText(TextField, 'Source Paths (File or Folder)');
      await tester.enterText(sourceField, 'content://media/external/images/media/100001');
      await tester.pumpAndSettle();

      // Scroll to reveal Send button
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(FilledButton, 'SEND TO EXACT PEER ID');
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify transfer initiated with returned ID
      expect(find.textContaining('xfer-saf-android-888'), findsWidgets);
    });

    testWidgets('Rejection by Android Node preserves user selection without clearing input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll ListView to reveal manual form
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final advancedTile = find.text('Advanced Manual Paths & Policy');
      expect(advancedTile, findsOneWidget);
      await tester.tap(advancedTile);
      await tester.pumpAndSettle();

      // Target unreachable peer which triggers rejection
      final peerField = find.widgetWithText(TextField, 'Target Peer ID');
      await tester.enterText(peerField, 'unreachable_peer');

      final sourceField = find.widgetWithText(TextField, 'Source Paths (File or Folder)');
      await tester.enterText(sourceField, 'content://media/external/images/media/100001');
      await tester.pumpAndSettle();

      // Scroll to reveal Send button
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(FilledButton, 'SEND TO EXACT PEER ID');
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify rejection state displayed
      expect(find.textContaining('rejected'), findsWidgets);

      // Verify selection was NOT lost
      final textFieldWidget = tester.widget<TextField>(sourceField);
      expect(textFieldWidget.controller?.text, contains('content://media/external/images/media/100001'));
    });

    testWidgets('Real-time transfer progress updates in-flight card and history smoothly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Emit transferStarted
      AndroidNodeBridge.instance.emitEventForTesting({
        'type': 'transferStarted',
        'transferId': 'tx_live_flow_99',
        'remotePeer': 'peer_target_alpha',
        'fileName': 'vacation_clip.mp4',
        'totalBytes': 2048000,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Verify in-flight card appears with file name
      expect(find.text('vacation_clip.mp4'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cancel Transfer'), findsOneWidget);

      // Emit transferProgress
      AndroidNodeBridge.instance.emitEventForTesting({
        'type': 'transferProgress',
        'transferId': 'tx_live_flow_99',
        'percent': 50,
        'transferredBytes': 1024000,
        'totalBytes': 2048000,
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Verify progress updated across banner and in-flight card
      expect(find.textContaining('50%'), findsNWidgets(2));

      // Switch to ACTIVE & HISTORY tab
      await tester.tap(find.text('ACTIVE & HISTORY'));
      await tester.pumpAndSettle();

      // Verify transfer card is present in active section
      expect(find.text('vacation_clip.mp4'), findsWidgets);

      // Emit transferCompleted
      AndroidNodeBridge.instance.emitEventForTesting({
        'type': 'transferCompleted',
        'transferId': 'tx_live_flow_99',
        'success': true,
        'errorMessage': '',
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // In History tab, verify completion states
      expect(find.text('COMMITTED'), findsOneWidget);

      // Switch back to SEND tab to verify banner
      await tester.tap(find.text('SEND'));
      await tester.pumpAndSettle();
      expect(find.textContaining('completed successfully'), findsOneWidget);
    });
  });
}
