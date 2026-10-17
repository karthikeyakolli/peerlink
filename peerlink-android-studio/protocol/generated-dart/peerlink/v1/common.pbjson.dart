// This is a generated file - do not edit.
//
// Generated from peerlink/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use hashAlgorithmDescriptor instead')
const HashAlgorithm$json = {
  '1': 'HashAlgorithm',
  '2': [
    {'1': 'HASH_ALGORITHM_UNSPECIFIED', '2': 0},
    {'1': 'HASH_ALGORITHM_SHA256', '2': 1},
    {'1': 'HASH_ALGORITHM_BLAKE3', '2': 2},
  ],
};

/// Descriptor for `HashAlgorithm`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List hashAlgorithmDescriptor = $convert.base64Decode(
    'Cg1IYXNoQWxnb3JpdGhtEh4KGkhBU0hfQUxHT1JJVEhNX1VOU1BFQ0lGSUVEEAASGQoVSEFTSF'
    '9BTEdPUklUSE1fU0hBMjU2EAESGQoVSEFTSF9BTEdPUklUSE1fQkxBS0UzEAI=');

@$core.Deprecated('Use protocolVersionDescriptor instead')
const ProtocolVersion$json = {
  '1': 'ProtocolVersion',
  '2': [
    {'1': 'major', '3': 1, '4': 1, '5': 13, '10': 'major'},
    {'1': 'minor', '3': 2, '4': 1, '5': 13, '10': 'minor'},
    {'1': 'patch', '3': 3, '4': 1, '5': 13, '10': 'patch'},
    {'1': 'pre_release', '3': 4, '4': 1, '5': 9, '10': 'preRelease'},
  ],
};

/// Descriptor for `ProtocolVersion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolVersionDescriptor = $convert.base64Decode(
    'Cg9Qcm90b2NvbFZlcnNpb24SFAoFbWFqb3IYASABKA1SBW1ham9yEhQKBW1pbm9yGAIgASgNUg'
    'VtaW5vchIUCgVwYXRjaBgDIAEoDVIFcGF0Y2gSHwoLcHJlX3JlbGVhc2UYBCABKAlSCnByZVJl'
    'bGVhc2U=');

@$core.Deprecated('Use protocolHeaderDescriptor instead')
const ProtocolHeader$json = {
  '1': 'ProtocolHeader',
  '2': [
    {
      '1': 'version',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'version'
    },
    {
      '1': 'min_supported_version',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'minSupportedVersion'
    },
    {'1': 'trace_id', '3': 3, '4': 1, '5': 9, '10': 'traceId'},
    {'1': 'timestamp_utc_ms', '3': 4, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {
      '1': 'feature_flags',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.ProtocolHeader.FeatureFlagsEntry',
      '10': 'featureFlags'
    },
  ],
  '3': [ProtocolHeader_FeatureFlagsEntry$json],
};

@$core.Deprecated('Use protocolHeaderDescriptor instead')
const ProtocolHeader_FeatureFlagsEntry$json = {
  '1': 'FeatureFlagsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ProtocolHeader`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolHeaderDescriptor = $convert.base64Decode(
    'Cg5Qcm90b2NvbEhlYWRlchI2Cgd2ZXJzaW9uGAEgASgLMhwucGVlcmxpbmsudjEuUHJvdG9jb2'
    'xWZXJzaW9uUgd2ZXJzaW9uElAKFW1pbl9zdXBwb3J0ZWRfdmVyc2lvbhgCIAEoCzIcLnBlZXJs'
    'aW5rLnYxLlByb3RvY29sVmVyc2lvblITbWluU3VwcG9ydGVkVmVyc2lvbhIZCgh0cmFjZV9pZB'
    'gDIAEoCVIHdHJhY2VJZBIoChB0aW1lc3RhbXBfdXRjX21zGAQgASgDUg50aW1lc3RhbXBVdGNN'
    'cxJSCg1mZWF0dXJlX2ZsYWdzGAUgAygLMi0ucGVlcmxpbmsudjEuUHJvdG9jb2xIZWFkZXIuRm'
    'VhdHVyZUZsYWdzRW50cnlSDGZlYXR1cmVGbGFncxo/ChFGZWF0dXJlRmxhZ3NFbnRyeRIQCgNr'
    'ZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use causalClockDescriptor instead')
const CausalClock$json = {
  '1': 'CausalClock',
  '2': [
    {'1': 'logical_counter', '3': 1, '4': 1, '5': 3, '10': 'logicalCounter'},
    {'1': 'actor_peer_id', '3': 2, '4': 1, '5': 9, '10': 'actorPeerId'},
    {
      '1': 'peer_vectors',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.CausalClock.PeerVectorsEntry',
      '10': 'peerVectors'
    },
  ],
  '3': [CausalClock_PeerVectorsEntry$json],
};

@$core.Deprecated('Use causalClockDescriptor instead')
const CausalClock_PeerVectorsEntry$json = {
  '1': 'PeerVectorsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `CausalClock`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List causalClockDescriptor = $convert.base64Decode(
    'CgtDYXVzYWxDbG9jaxInCg9sb2dpY2FsX2NvdW50ZXIYASABKANSDmxvZ2ljYWxDb3VudGVyEi'
    'IKDWFjdG9yX3BlZXJfaWQYAiABKAlSC2FjdG9yUGVlcklkEkwKDHBlZXJfdmVjdG9ycxgDIAMo'
    'CzIpLnBlZXJsaW5rLnYxLkNhdXNhbENsb2NrLlBlZXJWZWN0b3JzRW50cnlSC3BlZXJWZWN0b3'
    'JzGj4KEFBlZXJWZWN0b3JzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKANS'
    'BXZhbHVlOgI4AQ==');

@$core.Deprecated('Use contentHashDescriptor instead')
const ContentHash$json = {
  '1': 'ContentHash',
  '2': [
    {
      '1': 'algorithm',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.HashAlgorithm',
      '10': 'algorithm'
    },
    {'1': 'hash_bytes', '3': 2, '4': 1, '5': 12, '10': 'hashBytes'},
    {'1': 'hex_digest', '3': 3, '4': 1, '5': 9, '10': 'hexDigest'},
  ],
};

/// Descriptor for `ContentHash`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contentHashDescriptor = $convert.base64Decode(
    'CgtDb250ZW50SGFzaBI4CglhbGdvcml0aG0YASABKA4yGi5wZWVybGluay52MS5IYXNoQWxnb3'
    'JpdGhtUglhbGdvcml0aG0SHQoKaGFzaF9ieXRlcxgCIAEoDFIJaGFzaEJ5dGVzEh0KCmhleF9k'
    'aWdlc3QYAyABKAlSCWhleERpZ2VzdA==');

@$core.Deprecated('Use objectIdDescriptor instead')
const ObjectId$json = {
  '1': 'ObjectId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `ObjectId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List objectIdDescriptor =
    $convert.base64Decode('CghPYmplY3RJZBIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use deviceIdDescriptor instead')
const DeviceId$json = {
  '1': 'DeviceId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `DeviceId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceIdDescriptor =
    $convert.base64Decode('CghEZXZpY2VJZBIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use peerIdDescriptor instead')
const PeerId$json = {
  '1': 'PeerId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `PeerId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerIdDescriptor =
    $convert.base64Decode('CgZQZWVySWQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use connectionIdDescriptor instead')
const ConnectionId$json = {
  '1': 'ConnectionId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `ConnectionId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionIdDescriptor =
    $convert.base64Decode('CgxDb25uZWN0aW9uSWQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use sessionIdDescriptor instead')
const SessionId$json = {
  '1': 'SessionId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `SessionId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionIdDescriptor =
    $convert.base64Decode('CglTZXNzaW9uSWQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use operationIdDescriptor instead')
const OperationId$json = {
  '1': 'OperationId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `OperationId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationIdDescriptor =
    $convert.base64Decode('CgtPcGVyYXRpb25JZBIUCgV2YWx1ZRgBIAEoCVIFdmFsdWU=');

@$core.Deprecated('Use versionIdDescriptor instead')
const VersionId$json = {
  '1': 'VersionId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `VersionId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List versionIdDescriptor =
    $convert.base64Decode('CglWZXJzaW9uSWQSFAoFdmFsdWUYASABKAlSBXZhbHVl');

@$core.Deprecated('Use chunkIdDescriptor instead')
const ChunkId$json = {
  '1': 'ChunkId',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
    {'1': 'index', '3': 2, '4': 1, '5': 3, '10': 'index'},
  ],
};

/// Descriptor for `ChunkId`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chunkIdDescriptor = $convert.base64Decode(
    'CgdDaHVua0lkEhQKBXZhbHVlGAEgASgJUgV2YWx1ZRIUCgVpbmRleBgCIAEoA1IFaW5kZXg=');
