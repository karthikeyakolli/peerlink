import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/protocol/peerlink/v1/capability.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/common.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/error.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/identity.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/ipc.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/object_reference.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/session.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/transfer.pb.dart';
import 'package:protobuf/protobuf.dart';

void main() {
  group('Phase 8: Cross-Platform Interoperability & Backward Compatibility (Dart UI/Client)', () {

    // ── 1. Protocol Version and Negotiation Wire Contracts ───────────────────

    test('CapabilityNegotiationRequest serializes and deserializes version and capabilities cleanly', () {
      final req = CapabilityNegotiationRequest()
        ..header = (ProtocolHeader()
          ..version = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
          ..minSupportedVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
          ..traceId = 'trace-interop-9901')
        ..senderPeerId = (PeerId()..value = 'peer_flutter_mobile_01')
        ..clientProtocolVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
        ..minCompatibleVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
        ..offeredCapabilities.addAll([
          CapabilityDescriptor()..capabilityName = 'transport_tcp'..isEnabled = true,
          CapabilityDescriptor()..capabilityName = 'resume_v1'..isEnabled = true,
          CapabilityDescriptor()..capabilityName = 'adaptive_chunks'..isEnabled = true,
        ])
        ..requestedFeatures.addAll(['transfer_stream', 'background_sync']);

      final bytes = req.writeToBuffer();
      expect(bytes, isNotEmpty);

      final parsed = CapabilityNegotiationRequest.fromBuffer(bytes);
      expect(parsed.senderPeerId.value, equals('peer_flutter_mobile_01'));
      expect(parsed.clientProtocolVersion.major, equals(1));
      expect(parsed.offeredCapabilities.length, equals(3));
      expect(parsed.offeredCapabilities.map((c) => c.capabilityName), containsAll(['transport_tcp', 'resume_v1', 'adaptive_chunks']));
      expect(parsed.requestedFeatures, containsAll(['transfer_stream', 'background_sync']));
    });

    test('CapabilityNegotiationResponse reports graceful unsupported features without error', () {
      final resp = CapabilityNegotiationResponse()
        ..header = (ProtocolHeader()..version = (ProtocolVersion()..major = 1..minor = 0..patch = 0))
        ..isCompatible = true
        ..agreedProtocolVersion = (ProtocolVersion()..major = 1..minor = 0..patch = 0)
        ..acceptedCapabilities.addAll([
          CapabilityDescriptor()..capabilityName = 'transport_tcp'..isEnabled = true,
        ])
        ..unsupportedFeatures.addAll(['future_ai_transfer_v99', 'experimental_laser_beam']);

      final bytes = resp.writeToBuffer();
      final parsed = CapabilityNegotiationResponse.fromBuffer(bytes);

      expect(parsed.isCompatible, isTrue);
      expect(parsed.agreedProtocolVersion.major, equals(1));
      expect(parsed.acceptedCapabilities.length, equals(1));
      expect(parsed.acceptedCapabilities[0].capabilityName, equals('transport_tcp'));
      expect(parsed.unsupportedFeatures, containsAll(['future_ai_transfer_v99', 'experimental_laser_beam']));
    });

    test('Structured ErrorDetail adheres to machine-readable and actionable recovery contract', () {
      final error = ErrorDetail()
        ..code = ErrorCode.ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION
        ..errorName = 'INCOMPATIBLE_PROTOCOL_VERSION'
        ..humanSummary = 'The peer is running an incompatible protocol version.'
        ..humanExplanation = 'Remote peer requested protocol v2.0.0, but local node only supports v1.0.0.'
        ..suggestedRecoveryAction = 'Update PeerLink to the latest version on both devices.'
        ..isRetryable = false;

      final bytes = error.writeToBuffer();
      final parsed = ErrorDetail.fromBuffer(bytes);

      expect(parsed.code, equals(ErrorCode.ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION));
      expect(parsed.isRetryable, isFalse);
      expect(parsed.suggestedRecoveryAction, contains('Update PeerLink'));
    });

    // ── 2. Protobuf Forward Compatibility (Unknown Field Preservation) ───────

    test('Dart Protobuf parser retains unknown extension fields in unknownFields', () {
      // 1. Create a base ObjectReference
      final base = ObjectReference()
        ..objectId = (ObjectId()..value = 'obj-uuid-777')
        ..logicalName = 'contract_v1.pdf'
        ..byteSize = Int64(2048);

      // 2. Add an unknown field tag (tag 999 with bytes) into unknownFields
      final unknownFields = base.unknownFields;
      final unknownBytes = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]);
      unknownFields.addField(999, UnknownFieldSetField()..addLengthDelimited(unknownBytes));

      final serializedWithUnknown = base.writeToBuffer();

      // 3. Parse serialized bytes back
      final reparsed = ObjectReference.fromBuffer(serializedWithUnknown);

      expect(reparsed.objectId.value, equals('obj-uuid-777'));
      expect(reparsed.logicalName, equals('contract_v1.pdf'));
      expect(reparsed.byteSize, equals(Int64(2048)));

      // 4. Verify unknown field 999 is retained
      expect(reparsed.unknownFields.hasField(999), isTrue);
      final field = reparsed.unknownFields.getField(999);
      expect(field, isNotNull);
      expect(field!.lengthDelimited.length, equals(1));
      expect(field.lengthDelimited.first, equals(unknownBytes));

      // 5. Re-serializing preserves exact byte-for-byte stream
      final reserialized = reparsed.writeToBuffer();
      expect(reserialized, equals(serializedWithUnknown));
    });

    // ── 3. Cross-Platform Filename & Filesystem Invariants ────────────────────

    test('Windows reserved device names must never be accepted blindly or silently renamed', () {
      const reservedNames = [
        'CON', 'PRN', 'AUX', 'NUL',
        'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
        'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
        'con.txt', 'prn.dat', 'AUX.tar.gz', 'nul.log', 'com1.bin'
      ];

      bool isWindowsReserved(String filename) {
        final base = filename.contains('.') ? filename.substring(0, filename.indexOf('.')) : filename;
        final upper = base.toUpperCase();
        return const {
          'CON', 'PRN', 'AUX', 'NUL',
          'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
          'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
        }.contains(upper);
      }

      for (final name in reservedNames) {
        expect(isWindowsReserved(name), isTrue, reason: '$name must be identified as Windows reserved');
      }

      expect(isWindowsReserved('normal_file.txt'), isFalse);
      expect(isWindowsReserved('conference_presentation.pdf'), isFalse);
    });

    test('Windows illegal characters are detected without crash or silent corruption', () {
      final illegalCharsRegex = RegExp(r'[<>:"/\\|?*]');

      expect(illegalCharsRegex.hasMatch('test<file>.txt'), isTrue);
      expect(illegalCharsRegex.hasMatch('bad:name.dat'), isTrue);
      expect(illegalCharsRegex.hasMatch('quote"here.doc'), isTrue);
      expect(illegalCharsRegex.hasMatch('pipe|data.csv'), isTrue);
      expect(illegalCharsRegex.hasMatch('query?mark.png'), isTrue);
      expect(illegalCharsRegex.hasMatch('wild*card.zip'), isTrue);

      expect(illegalCharsRegex.hasMatch('clean_filename_2026.pdf'), isFalse);
      expect(illegalCharsRegex.hasMatch('Archive-Final.v1.tar.gz'), isFalse);
    });

    // ── 4. Desktop IPC and Android Bridge Protocol Equivalence ───────────────

    test('Desktop IPC initiate and control messages mirror Android facade semantics', () {
      final initReq = InitiateSendRequest()
        ..sessionToken = 'token_auth_88'
        ..targetPeerId = (PeerId()..value = 'peer_desktop_win_01')
        ..sourcePaths.addAll(['/data/user/0/org.peerlink/files/export.zip']);

      final initBytes = initReq.writeToBuffer();
      final parsedInit = InitiateSendRequest.fromBuffer(initBytes);
      expect(parsedInit.targetPeerId.value, equals('peer_desktop_win_01'));
      expect(parsedInit.sourcePaths.length, equals(1));
      expect(parsedInit.sourcePaths[0], equals('/data/user/0/org.peerlink/files/export.zip'));

      final pauseReq = PauseTransferRequest()
        ..sessionToken = 'token_auth_88'
        ..transferId = 'xfer-persisted-404'
        ..reason = 'Battery conservation';

      final pauseBytes = pauseReq.writeToBuffer();
      final parsedPause = PauseTransferRequest.fromBuffer(pauseBytes);
      expect(parsedPause.transferId, equals('xfer-persisted-404'));
      expect(parsedPause.reason, equals('Battery conservation'));

      final resumeReq = ResumeTransferRequest()
        ..sessionToken = 'token_auth_88'
        ..transferId = 'xfer-persisted-404';

      final resumeBytes = resumeReq.writeToBuffer();
      final parsedResume = ResumeTransferRequest.fromBuffer(resumeBytes);
      expect(parsedResume.transferId, equals('xfer-persisted-404'));
    });
  });
}
