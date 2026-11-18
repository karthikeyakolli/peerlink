import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/design_system/components/transfer_speedometer.dart';
import 'package:peerlink/features/home/home_screen.dart';

void main() {
  group('TransferSpeedometer & Wi-Fi Diagnostic Bar Tests', () {
    testWidgets('TransferSpeedometer renders Wi-Fi band pill and advice banner cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: TransferSpeedometer(
              fileName: 'archive.tar.gz',
              currentItemIndex: 1,
              totalItems: 3,
              currentFileProgress: 0.45,
              totalBatchProgress: 0.60,
              speedMbps: 68.4,
              etaSeconds: 8,
              peerName: 'Xiaomi HyperOS Phone',
              isSender: false,
              networkRouteInfo: 'Wi-Fi Direct (5 GHz)',
              performanceAdvice: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('68.4'), findsOneWidget);
      expect(find.text('MB/s'), findsOneWidget);
      expect(find.text('Receiving from Xiaomi HyperOS Phone'), findsOneWidget);
      expect(find.byKey(const Key('wifi_band_diagnostic_pill')), findsOneWidget);
      expect(find.text('Wi-Fi Direct (5 GHz)'), findsOneWidget);
      expect(find.byKey(const Key('performance_advice_banner')), findsNothing);
    });

    testWidgets('TransferSpeedometer renders 2.4 GHz advisory and advice banner in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TransferSpeedometer(
              fileName: 'photo_album.zip',
              currentItemIndex: 2,
              totalItems: 5,
              currentFileProgress: 0.2,
              totalBatchProgress: 0.35,
              speedMbps: 3.2,
              etaSeconds: 45,
              peerName: 'Office Laptop',
              isSender: true,
              networkRouteInfo: 'Direct Link (2.4 GHz)',
              performanceAdvice: 'Using 2.4 GHz band. Switch to 5 GHz or Direct Hotspot for maximum speed.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3.2'), findsOneWidget);
      expect(find.text('Direct Link (2.4 GHz)'), findsOneWidget);
      expect(find.byKey(const Key('performance_advice_banner')), findsOneWidget);
      expect(find.textContaining('Switch to 5 GHz'), findsOneWidget);
    });

    testWidgets('HomeScreen reactively surfaces active transfer speedometer when operation is running', (tester) async {
      final journal = OperationJournalService.instance;
      const opId = 'test_live_tx_001';

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // No active transfer initially
      expect(find.byKey(const Key('home_active_transfer_speedometer')), findsNothing);

      // Start an in-flight operation
      journal.recordOperation(
        JournalOperation(
          operationId: opId,
          type: OperationType.send,
          state: JournalOperationState.executing,
          stage: JournalStage.execute,
          peerId: 'Galaxy Tab S9',
          summary: 'Dataset_Batch.zip',
          bytesTransferred: 50 * 1024 * 1024,
          totalBytes: 100 * 1024 * 1024,
          timestamp: DateTime.now().subtract(const Duration(seconds: 2)),
        ),
      );

      await tester.pumpAndSettle();

      // Speedometer should now appear on HomeScreen
      final speedometerFinder = find.byKey(const Key('home_active_transfer_speedometer'));
      expect(speedometerFinder, findsOneWidget);
      expect(
        find.descendant(of: speedometerFinder, matching: find.text('Dataset_Batch.zip')),
        findsOneWidget,
      );

      // Cancel the operation from the speedometer card
      final cancelBtn = find.byTooltip('Cancel Transfer');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Verify operation state is now cancelled and card disappears
      final op = journal.operations.firstWhere((o) => o.operationId == opId);
      expect(op.state, JournalOperationState.cancelled);
      expect(find.byKey(const Key('home_active_transfer_speedometer')), findsNothing);
    });
  });
}
