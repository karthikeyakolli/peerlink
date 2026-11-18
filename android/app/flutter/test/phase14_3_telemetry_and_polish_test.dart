import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/core/quarantine_service.dart';
import 'package:peerlink/design_system/components/transfer_telemetry_card.dart';
import 'package:peerlink/features/activity/activity_screen.dart';

void main() {
  setUp(() {
    OperationJournalService.instance.resetForTesting();
    QuarantineService.instance.resetForTesting();
    FileStagingService.instance.clear();
  });

  tearDown(() {
    OperationJournalService.instance.resetForTesting();
    QuarantineService.instance.resetForTesting();
    FileStagingService.instance.clear();
  });

  group('Phase 14.3: TransferTelemetryCard Widget Tests', () {
    testWidgets('renders all telemetry metrics: speed gauge, progress, ETA, and transport route',
        (tester) async {
      bool cancelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferTelemetryCard(
              title: 'Sending 4K_Render.mp4',
              peerName: 'Desktop_Workstation',
              bytesTransferred: 50 * 1024 * 1024,
              totalBytes: 100 * 1024 * 1024,
              currentSpeedMbPerSec: 25.0,
              transportRoute: 'DIRECT P2P (Wi-Fi Direct)',
              verifiedChunks: 50,
              totalChunks: 100,
              onCancel: () => cancelTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sending 4K_Render.mp4'), findsOneWidget);
      expect(find.textContaining('Peer: Desktop_Workstation'), findsOneWidget);
      expect(find.text('25.0 MB/s'), findsOneWidget);
      expect(find.text('DIRECT P2P (Wi-Fi Direct)'), findsOneWidget);
      expect(find.text('50 of 100 Merkle chunks verified'), findsOneWidget);
      expect(find.textContaining('50.0 MB / 100.0 MB (50.0%)'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelTapped, isTrue);
    });
  });

  group('Phase 14.3: ActivityScreen Telemetry Card Integration', () {
    testWidgets('Active tab renders TransferTelemetryCard for running operations', (tester) async {
      OperationJournalService.instance.recordOperation(
        JournalOperation(
          operationId: 'op_telemetry_test',
          type: OperationType.send,
          state: JournalOperationState.executing,
          stage: JournalStage.execute,
          peerId: 'peer_render_node',
          summary: 'High-Speed Backup Stream (120 MB)',
          bytesTransferred: 60 * 1024 * 1024,
          totalBytes: 120 * 1024 * 1024,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ActivityScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('High-Speed Backup Stream (120 MB)'), findsOneWidget);
      expect(find.textContaining('MB/s'), findsOneWidget);
      expect(find.text('DIRECT P2P (Wi-Fi Direct)'), findsOneWidget);
    });
  });

  group('Phase 14.3: FileStagingService Universal Ingestion', () {
    test('addPaths ingests paths into persistent tray with name extraction', () {
      final staging = FileStagingService.instance;
      expect(staging.isEmpty, isTrue);

      staging.addPaths([
        'content://media/external/images/media/4242',
        '/storage/emulated/0/Download/presentation.pdf',
      ]);

      expect(staging.selectedCount, 2);
      expect(staging.stagedFiles.first.name, '4242');
      expect(staging.stagedFiles.last.name, 'presentation.pdf');
    });
  });
}
