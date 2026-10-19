import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/platform/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.peerlink/android_node_methods');

  setUp(() {
    PlatformCapabilities.overrideIsAndroid = true;
    OperationJournalService.instance.resetForTesting();
  });

  tearDown(() {
    PlatformCapabilities.overrideIsAndroid = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('OperationJournalService Terminal State & Lifecycle Guards (Rule 4)', () {
    test('terminal state cannot be regressed by out-of-order progress events', () {
      final service = OperationJournalService.instance;
      final op = JournalOperation(
        operationId: 'op_test_001',
        type: OperationType.send,
        state: JournalOperationState.executing,
        stage: JournalStage.execute,
        peerId: 'peer_target',
        summary: 'photo.jpg',
        bytesTransferred: 500,
        totalBytes: 1000,
        timestamp: DateTime.now(),
      );

      service.recordOperation(op);
      expect(service.operations.first.bytesTransferred, equals(500));

      // Advance to committed terminal state
      service.updateState('op_test_001', JournalOperationState.committed);
      expect(service.operations.first.state, equals(JournalOperationState.committed));
      expect(service.operations.first.isTerminal, isTrue);

      // Stale / out-of-order progress event received after completion
      service.updateProgress('op_test_001', 300, 1000);
      expect(service.operations.first.bytesTransferred, equals(500),
          reason: 'Stale progress must not overwrite progress of terminal operation');

      // Attempting to regress state to executing must be rejected
      service.updateState('op_test_001', JournalOperationState.executing);
      expect(service.operations.first.state, equals(JournalOperationState.committed),
          reason: 'Committed operation must never regress to executing');
    });

    test('cancelled operations cannot be overwritten by non-terminal recordOperation', () {
      final service = OperationJournalService.instance;
      final op = JournalOperation(
        operationId: 'op_cancel_002',
        type: OperationType.receive,
        state: JournalOperationState.cancelled,
        stage: JournalStage.finalize,
        peerId: 'peer_sender',
        summary: 'document.pdf',
        bytesTransferred: 200,
        totalBytes: 1000,
        timestamp: DateTime.now(),
      );

      service.recordOperation(op);
      expect(service.operations.first.state, equals(JournalOperationState.cancelled));

      // Re-recording same operation as executing must be ignored
      final nonTerminalOp = op.copyWith(state: JournalOperationState.executing);
      service.recordOperation(nonTerminalOp);
      expect(service.operations.first.state, equals(JournalOperationState.cancelled));
    });
  });

  group('Authoritative Journal Reload & Independent Screen Changes (Rule 3)', () {
    test('reloadAuthoritativeJournal fetches and parses external SQLite operations', () async {
      final service = OperationJournalService.instance;

      final mockNativeRecords = [
        {
          'operationId': 'op_native_external_42',
          'intent': 'SEND',
          'actorPeerId': 'peer_bob',
          'targetObjectIds': 'video.mp4',
          'state': 'COMMITTED',
          'stage': 'FINALIZE',
          'idempotencyKey': 'idemp_42',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'notes': 'Transfer complete',
          'totalBytes': 2048000,
          'transferredBytes': 2048000,
        },
        {
          'operationId': 'op_native_external_43',
          'intent': 'RECEIVE',
          'actorPeerId': 'peer_alice',
          'targetObjectIds': 'archive.zip',
          'state': 'OUTCOME_UNKNOWN',
          'stage': 'INTENT',
          'idempotencyKey': 'idemp_43',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'notes': 'Interrupted by process restart',
          'totalBytes': 5000000,
          'transferredBytes': 1200000,
        }
      ];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getJournalOperations') {
          return mockNativeRecords;
        }
        return null;
      });

      expect(service.operations, isEmpty);

      // Perform reload
      await service.reloadAuthoritativeJournal();

      expect(service.operations.length, equals(2));

      final op42 = service.operations.firstWhere((o) => o.operationId == 'op_native_external_42');
      expect(op42.type, equals(OperationType.send));
      expect(op42.state, equals(JournalOperationState.committed));
      expect(op42.stage, equals(JournalStage.finalize));
      expect(op42.peerId, equals('peer_bob'));
      expect(op42.summary, equals('video.mp4'));
      expect(op42.totalBytes, equals(2048000));
      expect(op42.bytesTransferred, equals(2048000));

      final op43 = service.operations.firstWhere((o) => o.operationId == 'op_native_external_43');
      expect(op43.type, equals(OperationType.receive));
      expect(op43.state, equals(JournalOperationState.outcomeUnknown));
      expect(op43.isProblem, isTrue);

      // Avoid duplicates on subsequent reload
      await service.reloadAuthoritativeJournal();
      expect(service.operations.length, equals(2), reason: 'Must not duplicate existing records');
    });

    test('reconciles OUTCOME_UNKNOWN without destructive replay (Rule 9)', () async {
      final service = OperationJournalService.instance;
      final op = JournalOperation(
        operationId: 'op_unknown_reconcile',
        type: OperationType.send,
        state: JournalOperationState.outcomeUnknown,
        stage: JournalStage.intent,
        peerId: 'peer_target',
        summary: 'backup.tar',
        timestamp: DateTime.now(),
      );

      service.recordOperation(op);
      expect(service.problemOperations.length, equals(1));

      // Reconcile
      final result = await service.runDiagnosticsAndReconcile('op_unknown_reconcile');
      expect(result.success, isTrue);

      // Verify operation transitioned to committed and is no longer a problem
      expect(service.problemOperations, isEmpty);
      expect(service.historyOperations.first.state, equals(JournalOperationState.committed));
    });
  });
}
