import 'dart:convert';
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:peerlink/core/protocol/peerlink/v1/capability.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/common.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/error.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/event.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/identity.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/object_reference.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/operation.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/session.pb.dart';

void main() {
  final current = Directory.current.path;
  print('Generating cross-platform test fixtures from: $current');

  final outputDirs = [
    Directory('$current/../../protocol/target/test-fixtures'),
    Directory('$current/../../../protocol/target/test-fixtures'),
    Directory('$current/protocol/target/test-fixtures'),
  ];

  for (final dir in outputDirs) {
    dir.createSync(recursive: true);
    writeFixtures(dir);
    print('  Written fixtures to: ${dir.path}');
  }

  print('Test fixtures generated successfully.');
}

void writeFixtures(Directory dir) {
  // 1. peer_identity.bin
  final key = CryptographicKey()
    ..keyType = KeyType.KEY_TYPE_ED25519
    ..publicKeyBytes = utf8.encode('public-key-ed25519-bytes')
    ..keyId = 'key_ed25519_001'
    ..createdAtUtcMs = Int64(1760000000000);

  final peer = PeerIdentity()
    ..peerId = (PeerId()..value = 'peer_alice_99')
    ..deviceId = (DeviceId()..value = 'dev_desktop_win_01')
    ..displayName = 'Alice Desktop'
    ..identityKey = key
    ..fingerprintHex = 'SHA256:4a8b1c9d2e3f'
    ..trustLevel = TrustLevel.TRUST_LEVEL_TRUSTED_PAIRED
    ..pairedAtUtcMs = Int64(1760000010000);

  File('${dir.path}/peer_identity.bin').writeAsBytesSync(peer.writeToBuffer());

  // 2. object_reference.bin
  final causalClock = CausalClock()
    ..logicalCounter = Int64(42)
    ..actorPeerId = 'peer_alice_99'
    ..peerVectors['peer_alice_99'] = Int64(42)
    ..peerVectors['peer_bob_12'] = Int64(15);

  final contentHash = ContentHash()
    ..algorithm = HashAlgorithm.HASH_ALGORITHM_SHA256
    ..hexDigest = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    ..hashBytes = List.filled(32, 0);

  final objRef = ObjectReference()
    ..objectId = (ObjectId()..value = 'obj_8820c741-2a1e-4c7b-91d8-04b123456789')
    ..contentHash = contentHash
    ..versionId = (VersionId()..value = 'v_causal_42')
    ..objectType = ObjectType.OBJECT_TYPE_FILE
    ..byteSize = Int64(1048576)
    ..mimeType = 'application/pdf'
    ..logicalName = 'Financial_Report_2026.pdf'
    ..causalClock = causalClock
    ..clientModifiedHintUtcMs = Int64(1760000000000)
    ..isTombstone = false
    ..metadata['author'] = 'Alice';

  File('${dir.path}/object_reference.bin').writeAsBytesSync(objRef.writeToBuffer());

  // 3. operation_record.bin
  final targetObj = ObjectReference()
    ..objectId = (ObjectId()..value = 'obj_8820c741')
    ..logicalName = 'Shared_Document.txt';

  final op = OperationRecord()
    ..operationId = (OperationId()..value = 'op_durable_uuid_777')
    ..intent = OperationIntent.OPERATION_INTENT_SYNC
    ..actorPeerId = (PeerId()..value = 'peer_alice_99')
    ..targetObjects.add(targetObj)
    ..state = OperationState.OPERATION_STATE_COMMITTED
    ..idempotencyKey = 'idemp_seq_998124'
    ..causalClock = (CausalClock()..logicalCounter = Int64(10)..actorPeerId = 'peer_alice_99')
    ..createdAtUtcMs = Int64(1760000000000)
    ..updatedAtUtcMs = Int64(1760000002000)
    ..parameters['sync_mode'] = 'convergent_replica';

  File('${dir.path}/operation_record.bin').writeAsBytesSync(op.writeToBuffer());

  // 4. error_detail.bin
  final error = ErrorDetail()
    ..code = ErrorCode.ERROR_CODE_UNSUPPORTED_CAPABILITY
    ..errorName = 'ERR_UNSUPPORTED_CAPABILITY'
    ..humanSummary = 'Requested capability is not supported by target peer'
    ..humanExplanation = 'The target peer is running mobile constraints without background QUIC transport'
    ..suggestedRecoveryAction = 'Switch transport candidate to TCP/TLS or TURN relay'
    ..isRetryable = true
    ..traceId = 'trace_err_4048'
    ..timestampUtcMs = Int64(1760000003000)
    ..errorContext['peer_id'] = 'peer_bob_mobile'
    ..errorContext['requested_feature'] = 'FEATURE_QUIC';

  File('${dir.path}/error_detail.bin').writeAsBytesSync(error.writeToBuffer());

  // 5. capability_response.bin
  final acceptedCap = CapabilityDescriptor()
    ..capabilityName = 'peerlink.transport.quic'
    ..version = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
    ..validUntilUtcMs = Int64(1760003600000)
    ..isEnabled = true;

  final capResp = CapabilityNegotiationResponse()
    ..header = (ProtocolHeader()
      ..version = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
      ..traceId = 'neg_trace_01')
    ..isCompatible = true
    ..agreedProtocolVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
    ..acceptedCapabilities.add(acceptedCap)
    ..unsupportedFeatures.addAll(['FEATURE_BACKGROUND_SYNC', 'FEATURE_QUANTUM_COMPRESS']);

  File('${dir.path}/capability_response.bin').writeAsBytesSync(capResp.writeToBuffer());

  // 6. peerlink_event.bin
  final session = SessionDescriptor()
    ..sessionId = (SessionId()..value = 'sess_live_123')
    ..initiatorPeerId = (PeerId()..value = 'peer_alice')
    ..responderPeerId = (PeerId()..value = 'peer_bob')
    ..state = SessionState.SESSION_STATE_ESTABLISHED
    ..transportType = TransportType.TRANSPORT_TYPE_DIRECT_QUIC
    ..establishedAtUtcMs = Int64(1760000000000)
    ..expiresAtUtcMs = Int64(1760003600000)
    ..protocolVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0);

  final event = PeerLinkEvent()
    ..eventId = 'evt_session_001'
    ..header = (ProtocolHeader()
      ..version = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
      ..traceId = 'trace_evt_99')
    ..sessionEvent = session;

  File('${dir.path}/peerlink_event.bin').writeAsBytesSync(event.writeToBuffer());
}
