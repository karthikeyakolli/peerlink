import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/merkle_chunk_service.dart';
import 'package:peerlink/core/two_phase_commit_coordinator.dart';
import 'package:peerlink/core/bandwidth_throttle_service.dart';

void main() {
  setUp(() {
    TwoPhaseCommitCoordinator.instance.resetForTesting();
    BandwidthThrottleService.instance.resetForTesting();
  });

  tearDown(() {
    TwoPhaseCommitCoordinator.instance.resetForTesting();
    BandwidthThrottleService.instance.resetForTesting();
  });

  group('Phase 14.2: MerkleChunkService (Hierarchical Hashing & Resumption)', () {
    final merkle = MerkleChunkService.instance;

    test('buildManifest creates valid leaf hashes and Merkle Root for small file', () {
      final sampleData = utf8.encode('Hello PeerLink distributed transfer engine!');
      final manifest = merkle.buildManifest('file_1', 'greeting.txt', sampleData, chunkSize: 16);

      expect(manifest.fileId, 'file_1');
      expect(manifest.fileName, 'greeting.txt');
      expect(manifest.totalBytes, sampleData.length);
      expect(manifest.chunkSize, 16);
      expect(manifest.totalChunks, (sampleData.length + 15) ~/ 16);
      expect(manifest.chunkHashes.length, manifest.totalChunks);
      expect(manifest.rootHash.isNotEmpty, isTrue);

      // Verify each chunk against manifest
      for (int i = 0; i < manifest.totalChunks; i++) {
        final offset = i * 16;
        final length = (offset + 16 > sampleData.length) ? sampleData.length - offset : 16;
        final slice = sampleData.sublist(offset, offset + length);
        expect(merkle.verifyChunk(manifest, i, slice), isTrue);
      }
    });

    test('verifyChunk rejects tampered chunk data', () {
      final data = utf8.encode('Authoritative integrity slice');
      final manifest = merkle.buildManifest('f2', 'data.bin', data, chunkSize: 8);

      final validChunk = data.sublist(0, 8);
      expect(merkle.verifyChunk(manifest, 0, validChunk), isTrue);

      // Tampered chunk
      final tamperedChunk = utf8.encode('TAMPERED');
      expect(merkle.verifyChunk(manifest, 0, tamperedChunk), isFalse);

      // Out of bounds chunk index
      expect(merkle.verifyChunk(manifest, 999, validChunk), isFalse);
    });

    test('Empty payload manifest returns empty hash', () {
      final manifest = merkle.buildManifest('empty_id', 'empty.txt', []);
      expect(manifest.totalBytes, 0);
      expect(manifest.totalChunks, 0);
      expect(manifest.chunkHashes.isEmpty, isTrue);
      expect(manifest.rootHash.isNotEmpty, isTrue);
    });

    test('ChunkBitset accurately tracks received chunks and missing indexes', () {
      final bitset = ChunkBitset(5);
      expect(bitset.isComplete, isFalse);
      expect(bitset.completedChunksCount, 0);
      expect(bitset.progressFraction, 0.0);
      expect(bitset.missingChunkIndexes, [0, 1, 2, 3, 4]);

      bitset.markReceived(0);
      bitset.markReceived(2);
      bitset.markReceived(4);

      expect(bitset.completedChunksCount, 3);
      expect(bitset.progressFraction, 0.6);
      expect(bitset.missingChunkIndexes, [1, 3]);

      bitset.markReceived(1);
      bitset.markReceived(3);
      expect(bitset.isComplete, isTrue);
      expect(bitset.missingChunkIndexes.isEmpty, isTrue);

      // Serialization & Deserialization
      final serialized = bitset.serialize();
      expect(serialized, '11111');
      final restored = ChunkBitset.deserialize(serialized);
      expect(restored.isComplete, isTrue);
      expect(restored.totalChunks, 5);
    });
  });

  group('Phase 14.2: TwoPhaseCommitCoordinator (Rule 9 Determinism)', () {
    final coordinator = TwoPhaseCommitCoordinator.instance;

    test('Executes normal 2PC flow: initial -> preparing -> prepared -> committed', () {
      final tx = coordinator.beginTransaction(
        transactionId: 'tx_001',
        operationId: 'op_100',
        peerId: 'peer_node_alpha',
        payloadPath: '/staging/tx_001.part',
        targetPath: '/storage/final_file.pdf',
      );

      expect(tx.state, TwoPhaseCommitState.preparing);

      coordinator.markPrepared('tx_001');
      expect(coordinator.getTransaction('tx_001')?.state, TwoPhaseCommitState.prepared);

      coordinator.markCommitted('tx_001');
      expect(coordinator.getTransaction('tx_001')?.state, TwoPhaseCommitState.committed);
    });

    test('reconcileUncertainTransaction finalizes commit if PREPARED before disconnect', () async {
      coordinator.beginTransaction(
        transactionId: 'tx_uncertain_01',
        operationId: 'op_severed',
        peerId: 'peer_node_beta',
        payloadPath: '/staging/payload.part',
        targetPath: '/storage/payload.bin',
      );

      coordinator.markPrepared('tx_uncertain_01');

      // Network severed before commit ACK arrived -> Reconcile
      final result = await coordinator.reconcileUncertainTransaction('tx_uncertain_01');

      expect(result.isSuccess, isTrue);
      expect(result.finalState, TwoPhaseCommitState.committed);
      expect(result.message, contains('Verified PREPARED state; atomic commit finalized safely'));
    });

    test('reconcileUncertainTransaction aborts if severance happened before PREPARED state', () async {
      coordinator.beginTransaction(
        transactionId: 'tx_incomplete_02',
        operationId: 'op_halfway',
        peerId: 'peer_gamma',
        payloadPath: '/staging/halfway.part',
        targetPath: '/storage/halfway.bin',
      );

      // Severed while still preparing (chunks not all verified)
      final result = await coordinator.reconcileUncertainTransaction('tx_incomplete_02');

      expect(result.isSuccess, isFalse);
      expect(result.finalState, TwoPhaseCommitState.aborted);
      expect(result.message, contains('Duplicate commit avoided'));
    });
  });

  group('Phase 14.2: BandwidthThrottleService (Token-Bucket Limiter)', () {
    final throttle = BandwidthThrottleService.instance;

    test('Unthrottled line speed presets calculate zero delay', () async {
      throttle.setPreset(BandwidthLimitPreset.unlimited);
      expect(throttle.isThrottled, isFalse);
      expect(await throttle.calculateDelayMs(10 * 1024 * 1024), 0);
    });

    test('Throttled preset calculates proportional delay in milliseconds', () async {
      // 10 MB/s
      throttle.setPreset(BandwidthLimitPreset.medium10Mb);
      expect(throttle.isThrottled, isTrue);

      // 5 MB chunk at 10 MB/s should take ~500ms
      final delayMs = await throttle.calculateDelayMs(5 * 1024 * 1024);
      expect(delayMs, closeTo(500, 25));
    });

    test('Custom bytes-per-second limit overrides preset', () async {
      throttle.setCustomLimitBytesPerSec(1024 * 1024); // 1 MB/s
      expect(throttle.effectiveBytesPerSecond, 1024 * 1024);

      // 1 MB chunk at 1 MB/s -> ~1000ms
      final delayMs = await throttle.calculateDelayMs(1024 * 1024);
      expect(delayMs, closeTo(1000, 50));
    });
  });
}
