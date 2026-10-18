import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/features/activity/activity_screen.dart';

void main() {
  setUp(() {
    OperationJournalService.instance.resetForTesting();
  });

  testWidgets('ActivityScreen: shows empty state when journal empty, contains no fake history or mock problems',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ActivityScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Assert NO hardcoded fake data
    expect(find.text('MacBook Pro'), findsNothing);
    expect(find.text('patch_tool.exe'), findsNothing);
    expect(find.text('Bob (Guest Share)'), findsNothing);
    expect(find.text('design_assets.zip'), findsNothing);
    expect(find.text('op_send_94fa21bc'), findsNothing);

    // 2. ACTIVE tab shows clean idle state
    expect(find.text('No In-Flight Operations'), findsOneWidget);

    // 3. Switch to HISTORY tab -> empty state
    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();
    expect(find.text('No Operation History Recorded'), findsOneWidget);

    // 4. Switch to PROBLEMS tab -> empty state
    await tester.tap(find.text('PROBLEMS'));
    await tester.pumpAndSettle();
    expect(find.text('Zero Unresolved Problems'), findsOneWidget);
  });

  testWidgets('ActivityScreen: Rule 9 - OUTCOME_UNKNOWN never provides blind replay button',
      (WidgetTester tester) async {
    // Add an OUTCOME_UNKNOWN operation to journal
    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: 'op_xfer_uncertain_1',
        type: OperationType.send,
        state: JournalOperationState.outcomeUnknown,
        stage: JournalStage.verify,
        peerId: 'peer_node_uncertain',
        summary: 'Send 4 financial documents (8.4 MB)',
        bytesTransferred: 8400000,
        totalBytes: 8400000,
        timestamp: DateTime.now(),
        errorNote: 'ACK lost after commit; network severed during confirmation',
        isDestructive: true,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ActivityScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Switch to PROBLEMS tab
    await tester.tap(find.text('PROBLEMS'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Outcome Uncertain', findRichText: true), findsOneWidget);

    // CRITICAL Rule 9 Invariant: NEVER provide a blind "Replay" or "Resend" button for OUTCOME_UNKNOWN
    expect(find.text('Replay'), findsNothing);
    expect(find.text('Resend'), findsNothing);
    expect(find.text('Replay Operation'), findsNothing);

    // Authoritative self-healing action must be diagnostic reconciliation
    expect(find.text('Run Diagnostics & Reconcile'), findsOneWidget);

    // Tap Run Diagnostics & Reconcile
    await tester.tap(find.text('Run Diagnostics & Reconcile'));
    await tester.pumpAndSettle();

    // Verify diagnostic was executed and reconciliation occurred
    expect(find.textContaining('Diagnostics completed', findRichText: true), findsOneWidget);
  });

  testWidgets('ActivityScreen: separates active in-flight transfers from terminal history',
      (WidgetTester tester) async {
    // Add active executing operation
    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: 'op_active_send',
        type: OperationType.send,
        state: JournalOperationState.executing,
        stage: JournalStage.execute,
        peerId: 'peer_workstation',
        summary: 'Streaming dataset.tar.gz (250 MB)',
        bytesTransferred: 125000000,
        totalBytes: 250000000,
        timestamp: DateTime.now(),
      ),
    );

    // Add committed historical operation
    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: 'op_past_backup',
        type: OperationType.backup,
        state: JournalOperationState.committed,
        stage: JournalStage.finalize,
        peerId: 'Local Storage',
        summary: 'Snapshot #12 verified with Merkle root',
        bytesTransferred: 45000000,
        totalBytes: 45000000,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ActivityScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Active tab has streaming operation
    expect(find.text('Streaming dataset.tar.gz (250 MB)'), findsOneWidget);
    expect(find.text('Snapshot #12 verified with Merkle root'), findsNothing);

    // Switch to HISTORY tab
    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();

    // History tab has past backup but NOT in-flight streaming
    expect(find.text('Snapshot #12 verified with Merkle root'), findsOneWidget);
    expect(find.text('Streaming dataset.tar.gz (250 MB)'), findsNothing);
  });
}
