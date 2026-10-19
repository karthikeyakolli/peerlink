import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/transfer/transfer_progress_model.dart';

void main() {
  group('TransferProgressModel Truthful Progress Tests (Feature C)', () {
    test('all 16 states have valid user-facing descriptions and flags', () {
      for (final state in TransferState.values) {
        expect(state.userFacingDescription.isNotEmpty, isTrue,
            reason: 'State $state must have human-readable description');
      }

      expect(TransferState.completed.isTerminal, isTrue);
      expect(TransferState.failed.isTerminal, isTrue);
      expect(TransferState.cancelled.isTerminal, isTrue);
      expect(TransferState.transferring.isTerminal, isFalse);

      expect(TransferState.transferring.isOngoing, isTrue);
      expect(TransferState.preparing.isOngoing, isTrue);
      expect(TransferState.completed.isOngoing, isFalse);

      expect(TransferState.paused.isPausedOrInterrupted, isTrue);
      expect(TransferState.recoverableInterruption.isPausedOrInterrupted, isTrue);
    });

    test('indeterminate progress when total bytes are unknown', () {
      final model = TransferProgressModel(
        transferId: 'tx-100',
        remotePeerId: 'peer-1',
        initialTotalBytes: -1,
        initialTransferredBytes: 5000,
      );

      expect(model.isIndeterminate, isTrue);
      expect(model.progressRatio, isNull);
      expect(model.progressPercent, isNull);
      expect(model.formattedProgress, contains('(Unknown size)'));
    });

    test('truthful progress never shows 100% while still transferring', () {
      final model = TransferProgressModel(
        transferId: 'tx-101',
        remotePeerId: 'peer-1',
        initialState: TransferState.transferring,
        initialTotalBytes: 1000,
        initialTransferredBytes: 1000,
      );

      // Even if transferred bytes == total bytes, transferring state must not claim 100%
      expect(model.progressRatio, equals(0.99));
      expect(model.progressPercent, equals(99));

      // After explicit commit / complete acknowledgment, it reaches 100%
      model.updateState(TransferState.completed);
      expect(model.progressRatio, equals(1.0));
      expect(model.progressPercent, equals(100));
    });

    test('3-sample sliding window rate smoothing and ETA calculation', () {
      const startTime = 1000000;
      final model = TransferProgressModel(
        transferId: 'tx-102',
        remotePeerId: 'peer-2',
        initialState: TransferState.transferring,
        initialTotalBytes: 10 * 1024 * 1024, // 10 MB
        initialTransferredBytes: 0,
        startTimeMs: startTime,
      );

      // Sample 1: 0 bytes at t=0
      // With 1 sample, rate and ETA must be null
      expect(model.smoothedRateBytesPerSec, isNull);
      expect(model.estimatedRemainingTime, isNull);
      expect(model.formattedRate, equals('--'));
      expect(model.formattedEta, equals('--'));

      // Sample 2: 1 MB transferred after 1 second (1000ms)
      model.recordProgress(
        transferredBytes: 1024 * 1024,
        timestampMs: startTime + 1000,
      );

      // With 2 samples, rate is available (~1 MB/s), but ETA requires >= 3 reliable samples
      expect(model.smoothedRateBytesPerSec, isNotNull);
      expect(model.smoothedRateBytesPerSec! >= 1000000, isTrue);
      expect(model.estimatedRemainingTime, isNull); // ETA requires >= 3 samples!

      // Sample 3: 2 MB transferred after 2 seconds (2000ms)
      model.recordProgress(
        transferredBytes: 2 * 1024 * 1024,
        timestampMs: startTime + 2000,
      );

      // Now with 3 samples, ETA is reliably calculated
      expect(model.smoothedRateBytesPerSec, isNotNull);
      final eta = model.estimatedRemainingTime;
      expect(eta, isNotNull);
      // 8 MB remaining at ~1 MB/s = ~8 seconds
      expect(eta!.inSeconds, inInclusiveRange(7, 9));
      expect(model.formattedEta, contains('8s remaining'));

      // Sample 4: 3 MB transferred after 3 seconds (sliding window drops sample 1)
      model.recordProgress(
        transferredBytes: 3 * 1024 * 1024,
        timestampMs: startTime + 3000,
      );
      final eta4 = model.estimatedRemainingTime;
      expect(eta4, isNotNull);
      // 7 MB remaining at ~1 MB/s = ~7 seconds
      expect(eta4!.inSeconds, inInclusiveRange(6, 8));
    });

    test('sliding window ignores microsecond jitter (<50ms)', () {
      const startTime = 2000000;
      final model = TransferProgressModel(
        transferId: 'tx-103',
        remotePeerId: 'peer-3',
        initialState: TransferState.transferring,
        initialTotalBytes: 500000,
        initialTransferredBytes: 0,
        startTimeMs: startTime,
      );

      // Update with only 10ms difference
      model.recordProgress(
        transferredBytes: 10000,
        timestampMs: startTime + 10,
      );

      // Should not produce crazy division by near-zero
      expect(model.smoothedRateBytesPerSec, isNull);
    });

    test('multi-file batch items tracking', () {
      final items = [
        const TransferFileItem(
          id: 'item-1',
          name: 'photo1.jpg',
          sizeBytes: 2000,
          transferredBytes: 2000,
          isCompleted: true,
        ),
        const TransferFileItem(
          id: 'item-2',
          name: 'photo2.jpg',
          sizeBytes: 3000,
          transferredBytes: 1000,
          isCompleted: false,
        ),
      ];

      final model = TransferProgressModel(
        transferId: 'tx-104',
        remotePeerId: 'peer-4',
        initialState: TransferState.transferring,
        initialTotalBytes: 5000,
        initialTransferredBytes: 3000,
        items: items,
      );

      expect(model.totalItemCount, equals(2));
      expect(model.completedItemCount, equals(1));
    });
  });
}
