import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/protocol/peerlink/v1/capability.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/common.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/error.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/event.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/identity.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/object_reference.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/operation.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/session.pb.dart';

void main() {
  group('Cross-Platform Protocol Contract Compatibility (Dart ↔ Java ↔ Protobuf)', () {
    late Directory javaFixtureDir;
    late Directory dartOutDir;

    setUpAll(() {
      // Find the protocol target test-fixtures directory
      final current = Directory.current.path;
      // In flutter test, cwd is typically apps/peerlink-app
      Directory candidate = Directory('$current/../../protocol/target/test-fixtures');
      if (!candidate.existsSync()) {
        candidate = Directory('$current/protocol/target/test-fixtures');
      }
      expect(candidate.existsSync(), isTrue, reason: 'Java test-fixtures directory must exist at ${candidate.path}');
      javaFixtureDir = candidate;

      dartOutDir = Directory('${candidate.path}/dart-out');
      if (!dartOutDir.existsSync()) {
        dartOutDir.createSync(recursive: true);
      }
    });

    test('Dart successfully deserializes Java-generated PeerIdentity', () {
      final file = File('${javaFixtureDir.path}/peer_identity.bin');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final peer = PeerIdentity.fromBuffer(bytes);

      expect(peer.peerId.value, equals('peer_alice_99'));
      expect(peer.deviceId.value, equals('dev_desktop_win_01'));
      expect(peer.displayName, equals('Alice Desktop'));
      expect(peer.trustLevel, equals(TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED));
      expect(peer.identityKey.keyType, equals(KeyType.KEY_TYPE_ED25519));
      expect(peer.fingerprintHex, equals('SHA256:4a8b1c9d2e3f'));
      expect(peer.pairedAtUtcMs, equals(Int64(1760000010000)));
    });

    test('Dart successfully deserializes Java-generated ObjectReference and verifies invariants', () {
      final file = File('${javaFixtureDir.path}/object_reference.bin');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final objRef = ObjectReference.fromBuffer(bytes);

      // Invariant 1: Path is NOT object identity
      expect(objRef.objectId.value, equals('obj_8820c741-2a1e-4c7b-91d8-04b123456789'));
      expect(objRef.logicalName, equals('Financial_Report_2026.pdf'));
      expect(objRef.logicalName, isNot(equals(objRef.objectId.value)));
      expect(objRef.logicalName.contains(':\\'), isFalse);
      expect(objRef.logicalName.startsWith('/'), isFalse);

      // Invariant 2: Hash is separate from object identity
      expect(objRef.contentHash.algorithm, equals(HashAlgorithm.HASH_ALGORITHM_SHA256));
      expect(objRef.contentHash.hexDigest, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
      expect(objRef.contentHash.hexDigest, isNot(equals(objRef.objectId.value)));

      // Invariant 3: CausalClock vector clock is authoritative
      expect(objRef.causalClock.logicalCounter, equals(Int64(42)));
      expect(objRef.causalClock.actorPeerId, equals('peer_alice_99'));
      expect(objRef.causalClock.peerVectors['peer_alice_99'], equals(Int64(42)));
      expect(objRef.causalClock.peerVectors['peer_bob_12'], equals(Int64(15)));

      // Other properties
      expect(objRef.objectType, equals(ObjectType.OBJECT_TYPE_FILE));
      expect(objRef.byteSize, equals(Int64(1048576)));
      expect(objRef.mimeType, equals('application/pdf'));
      expect(objRef.isTombstone, isFalse);
      expect(objRef.metadata['author'], equals('Alice'));
    });

    test('Dart successfully deserializes Java-generated OperationRecord and checks idempotency contract', () {
      final file = File('${javaFixtureDir.path}/operation_record.bin');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final op = OperationRecord.fromBuffer(bytes);

      expect(op.operationId.value, equals('op_durable_uuid_777'));
      expect(op.intent, equals(OperationIntent.OPERATION_INTENT_SYNC));
      expect(op.actorPeerId.value, equals('peer_alice_99'));
      expect(op.targetObjects.length, equals(1));
      expect(op.targetObjects[0].objectId.value, equals('obj_8820c741'));
      expect(op.state, equals(OperationState.OPERATION_STATE_COMMITTED));
      expect(op.idempotencyKey, equals('idemp_seq_998124'));
      expect(op.causalClock.logicalCounter, equals(Int64(10)));
      expect(op.parameters['sync_mode'], equals('convergent_replica'));
    });

    test('Dart successfully deserializes Java-generated ErrorDetail (machine-readable + human-explainable)', () {
      final file = File('${javaFixtureDir.path}/error_detail.bin');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final error = ErrorDetail.fromBuffer(bytes);

      expect(error.code, equals(ErrorCode.ERROR_CODE_UNSUPPORTED_CAPABILITY));
      expect(error.errorName, equals('ERR_UNSUPPORTED_CAPABILITY'));
      expect(error.humanSummary, equals('Requested capability is not supported by target peer'));
      expect(error.humanExplanation, equals('The target peer is running mobile constraints without background QUIC transport'));
      expect(error.suggestedRecoveryAction, equals('Switch transport candidate to TCP/TLS or TURN relay'));
      expect(error.isRetryable, isTrue);
      expect(error.traceId, equals('trace_err_4048'));
      expect(error.errorContext['peer_id'], equals('peer_bob_mobile'));
    });

    test('Dart successfully deserializes Java-generated CapabilityNegotiationResponse with graceful degradation', () {
      final file = File('${javaFixtureDir.path}/capability_response.bin');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final resp = CapabilityNegotiationResponse.fromBuffer(bytes);

      expect(resp.isCompatible, isTrue);
      expect(resp.agreedProtocolVersion.major, equals(1));
      expect(resp.acceptedCapabilities.length, equals(1));
      expect(resp.acceptedCapabilities[0].capabilityName, equals('peerlink.transport.quic'));
      expect(resp.acceptedCapabilities[0].isEnabled, isTrue);

      // Graceful unsupported responses
      expect(resp.unsupportedFeatures, contains('FEATURE_BACKGROUND_SYNC'));
      expect(resp.unsupportedFeatures, contains('FEATURE_QUANTUM_COMPRESS'));
    });

    test('Dart successfully deserializes Java-generated PeerLinkEvent envelope', () {
      final file = File('${javaFixtureDir.path}/peerlink_event.bin');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final event = PeerLinkEvent.fromBuffer(bytes);

      expect(event.eventId, equals('evt_session_001'));
      expect(event.hasSessionEvent(), isTrue);
      expect(event.sessionEvent.sessionId.value, equals('sess_live_123'));
      expect(event.sessionEvent.initiatorPeerId.value, equals('peer_alice'));
      expect(event.sessionEvent.responderPeerId.value, equals('peer_bob'));
      expect(event.sessionEvent.state, equals(SessionState.SESSION_STATE_ESTABLISHED));
      expect(event.sessionEvent.transportType, equals(TransportType.TRANSPORT_TYPE_DIRECT_QUIC));
    });

    test('Dart serializes contracts to binary for Java verification (Dart → Protobuf → Java)', () {
      // 1. Dart creates a SessionDescriptor & writes to dart-out
      final session = SessionDescriptor()
        ..sessionId = (SessionId()..value = 'sess_dart_to_java_999')
        ..initiatorPeerId = (PeerId()..value = 'peer_dart_mobile')
        ..responderPeerId = (PeerId()..value = 'peer_java_desktop')
        ..state = SessionState.SESSION_STATE_ESTABLISHED
        ..transportType = TransportType.TRANSPORT_TYPE_DIRECT_TCP_TLS
        ..establishedAtUtcMs = Int64(1760001000000)
        ..expiresAtUtcMs = Int64(1760004600000)
        ..protocolVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0);

      final sessionFile = File('${dartOutDir.path}/dart_session.bin');
      sessionFile.writeAsBytesSync(session.writeToBuffer());
      expect(sessionFile.existsSync(), isTrue);

      // 2. Dart creates an OperationRecord with vector clock & writes to dart-out
      final op = OperationRecord()
        ..operationId = (OperationId()..value = 'op_dart_durable_888')
        ..intent = OperationIntent.OPERATION_INTENT_SEND
        ..state = OperationState.OPERATION_STATE_COMMITTED
        ..idempotencyKey = 'idemp_dart_seq_001'
        ..actorPeerId = (PeerId()..value = 'peer_dart_mobile')
        ..causalClock = (CausalClock()
          ..logicalCounter = Int64(77)
          ..actorPeerId = 'peer_dart_mobile'
          ..peerVectors['peer_dart_mobile'] = Int64(77)
          ..peerVectors['peer_java_desktop'] = Int64(42))
        ..createdAtUtcMs = Int64(1760001000000)
        ..parameters['sync_strategy'] = 'crdt_delta';

      final opFile = File('${dartOutDir.path}/dart_operation.bin');
      opFile.writeAsBytesSync(op.writeToBuffer());
      expect(opFile.existsSync(), isTrue);

      // 3. Dart creates an ErrorDetail
      final err = ErrorDetail()
        ..code = ErrorCode.ERROR_CODE_TRANSPORT_DISCONNECTED
        ..errorName = 'ERR_TRANSPORT_DISCONNECTED'
        ..humanSummary = 'Peer transport connection dropped'
        ..humanExplanation = 'TCP/TLS connection to remote peer was interrupted unexpectedly'
        ..suggestedRecoveryAction = 'Retry connection with exponential backoff or use relay'
        ..isRetryable = true
        ..traceId = 'trace_dart_err_111';

      final errFile = File('${dartOutDir.path}/dart_error.bin');
      errFile.writeAsBytesSync(err.writeToBuffer());
      expect(errFile.existsSync(), isTrue);
    });
  });
}
