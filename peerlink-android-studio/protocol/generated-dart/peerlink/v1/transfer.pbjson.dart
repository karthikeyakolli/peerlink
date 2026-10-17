// This is a generated file - do not edit.
//
// Generated from peerlink/v1/transfer.proto.

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

@$core.Deprecated('Use transferStateDescriptor instead')
const TransferState$json = {
  '1': 'TransferState',
  '2': [
    {'1': 'TRANSFER_STATE_UNSPECIFIED', '2': 0},
    {'1': 'TRANSFER_STATE_PREPARING', '2': 1},
    {'1': 'TRANSFER_STATE_CONNECTING', '2': 2},
    {'1': 'TRANSFER_STATE_TRANSFERRING', '2': 3},
    {'1': 'TRANSFER_STATE_RECEIVED', '2': 4},
    {'1': 'TRANSFER_STATE_VERIFYING', '2': 5},
    {'1': 'TRANSFER_STATE_COMMITTING', '2': 6},
    {'1': 'TRANSFER_STATE_COMPLETED', '2': 7},
    {'1': 'TRANSFER_STATE_FAILED', '2': 8},
    {'1': 'TRANSFER_STATE_CANCELLED', '2': 9},
    {'1': 'TRANSFER_STATE_OUTCOME_UNKNOWN', '2': 10},
    {'1': 'TRANSFER_STATE_PAUSED', '2': 11},
  ],
};

/// Descriptor for `TransferState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List transferStateDescriptor = $convert.base64Decode(
    'Cg1UcmFuc2ZlclN0YXRlEh4KGlRSQU5TRkVSX1NUQVRFX1VOU1BFQ0lGSUVEEAASHAoYVFJBTl'
    'NGRVJfU1RBVEVfUFJFUEFSSU5HEAESHQoZVFJBTlNGRVJfU1RBVEVfQ09OTkVDVElORxACEh8K'
    'G1RSQU5TRkVSX1NUQVRFX1RSQU5TRkVSUklORxADEhsKF1RSQU5TRkVSX1NUQVRFX1JFQ0VJVk'
    'VEEAQSHAoYVFJBTlNGRVJfU1RBVEVfVkVSSUZZSU5HEAUSHQoZVFJBTlNGRVJfU1RBVEVfQ09N'
    'TUlUVElORxAGEhwKGFRSQU5TRkVSX1NUQVRFX0NPTVBMRVRFRBAHEhkKFVRSQU5TRkVSX1NUQV'
    'RFX0ZBSUxFRBAIEhwKGFRSQU5TRkVSX1NUQVRFX0NBTkNFTExFRBAJEiIKHlRSQU5TRkVSX1NU'
    'QVRFX09VVENPTUVfVU5LTk9XThAKEhkKFVRSQU5TRkVSX1NUQVRFX1BBVVNFRBAL');

@$core.Deprecated('Use chunkStatusDescriptor instead')
const ChunkStatus$json = {
  '1': 'ChunkStatus',
  '2': [
    {'1': 'CHUNK_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'CHUNK_STATUS_PENDING', '2': 1},
    {'1': 'CHUNK_STATUS_IN_FLIGHT', '2': 2},
    {'1': 'CHUNK_STATUS_ACKED', '2': 3},
    {'1': 'CHUNK_STATUS_FAILED', '2': 4},
  ],
};

/// Descriptor for `ChunkStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List chunkStatusDescriptor = $convert.base64Decode(
    'CgtDaHVua1N0YXR1cxIcChhDSFVOS19TVEFUVVNfVU5TUEVDSUZJRUQQABIYChRDSFVOS19TVE'
    'FUVVNfUEVORElORxABEhoKFkNIVU5LX1NUQVRVU19JTl9GTElHSFQQAhIWChJDSFVOS19TVEFU'
    'VVNfQUNLRUQQAxIXChNDSFVOS19TVEFUVVNfRkFJTEVEEAQ=');

@$core.Deprecated('Use duplicateDestinationPolicyDescriptor instead')
const DuplicateDestinationPolicy$json = {
  '1': 'DuplicateDestinationPolicy',
  '2': [
    {'1': 'DUPLICATE_DESTINATION_POLICY_UNSPECIFIED', '2': 0},
    {'1': 'DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS', '2': 1},
    {'1': 'DUPLICATE_DESTINATION_POLICY_OVERWRITE', '2': 2},
    {'1': 'DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX', '2': 3},
  ],
};

/// Descriptor for `DuplicateDestinationPolicy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List duplicateDestinationPolicyDescriptor = $convert.base64Decode(
    'ChpEdXBsaWNhdGVEZXN0aW5hdGlvblBvbGljeRIsCihEVVBMSUNBVEVfREVTVElOQVRJT05fUE'
    '9MSUNZX1VOU1BFQ0lGSUVEEAASLworRFVQTElDQVRFX0RFU1RJTkFUSU9OX1BPTElDWV9GQUlM'
    'X0lGX0VYSVNUUxABEioKJkRVUExJQ0FURV9ERVNUSU5BVElPTl9QT0xJQ1lfT1ZFUldSSVRFEA'
    'ISMwovRFVQTElDQVRFX0RFU1RJTkFUSU9OX1BPTElDWV9SRU5BTUVfV0lUSF9TVUZGSVgQAw==');

@$core.Deprecated('Use transferItemDescriptor instead')
const TransferItem$json = {
  '1': 'TransferItem',
  '2': [
    {'1': 'relative_path', '3': 1, '4': 1, '5': 9, '10': 'relativePath'},
    {'1': 'file_size_bytes', '3': 2, '4': 1, '5': 3, '10': 'fileSizeBytes'},
    {'1': 'sha256_hex', '3': 3, '4': 1, '5': 9, '10': 'sha256Hex'},
    {'1': 'is_directory', '3': 4, '4': 1, '5': 8, '10': 'isDirectory'},
    {
      '1': 'modified_time_utc_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'modifiedTimeUtcMs'
    },
  ],
};

/// Descriptor for `TransferItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferItemDescriptor = $convert.base64Decode(
    'CgxUcmFuc2Zlckl0ZW0SIwoNcmVsYXRpdmVfcGF0aBgBIAEoCVIMcmVsYXRpdmVQYXRoEiYKD2'
    'ZpbGVfc2l6ZV9ieXRlcxgCIAEoA1INZmlsZVNpemVCeXRlcxIdCgpzaGEyNTZfaGV4GAMgASgJ'
    'UglzaGEyNTZIZXgSIQoMaXNfZGlyZWN0b3J5GAQgASgIUgtpc0RpcmVjdG9yeRIvChRtb2RpZm'
    'llZF90aW1lX3V0Y19tcxgFIAEoA1IRbW9kaWZpZWRUaW1lVXRjTXM=');

@$core.Deprecated('Use transferManifestDescriptor instead')
const TransferManifest$json = {
  '1': 'TransferManifest',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'items',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.TransferItem',
      '10': 'items'
    },
    {'1': 'total_bytes', '3': 4, '4': 1, '5': 3, '10': 'totalBytes'},
    {'1': 'chunk_size_bytes', '3': 5, '4': 1, '5': 5, '10': 'chunkSizeBytes'},
    {
      '1': 'sender_peer_id',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'senderPeerId'
    },
    {
      '1': 'receiver_peer_id',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'receiverPeerId'
    },
    {'1': 'display_name', '3': 8, '4': 1, '5': 9, '10': 'displayName'},
    {
      '1': 'duplicate_policy',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.DuplicateDestinationPolicy',
      '10': 'duplicatePolicy'
    },
    {'1': 'target_directory', '3': 10, '4': 1, '5': 9, '10': 'targetDirectory'},
  ],
};

/// Descriptor for `TransferManifest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferManifestDescriptor = $convert.base64Decode(
    'ChBUcmFuc2Zlck1hbmlmZXN0Eh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEjsKDG'
    '9wZXJhdGlvbl9pZBgCIAEoCzIYLnBlZXJsaW5rLnYxLk9wZXJhdGlvbklkUgtvcGVyYXRpb25J'
    'ZBIvCgVpdGVtcxgDIAMoCzIZLnBlZXJsaW5rLnYxLlRyYW5zZmVySXRlbVIFaXRlbXMSHwoLdG'
    '90YWxfYnl0ZXMYBCABKANSCnRvdGFsQnl0ZXMSKAoQY2h1bmtfc2l6ZV9ieXRlcxgFIAEoBVIO'
    'Y2h1bmtTaXplQnl0ZXMSOQoOc2VuZGVyX3BlZXJfaWQYBiABKAsyEy5wZWVybGluay52MS5QZW'
    'VySWRSDHNlbmRlclBlZXJJZBI9ChByZWNlaXZlcl9wZWVyX2lkGAcgASgLMhMucGVlcmxpbmsu'
    'djEuUGVlcklkUg5yZWNlaXZlclBlZXJJZBIhCgxkaXNwbGF5X25hbWUYCCABKAlSC2Rpc3BsYX'
    'lOYW1lElIKEGR1cGxpY2F0ZV9wb2xpY3kYCSABKA4yJy5wZWVybGluay52MS5EdXBsaWNhdGVE'
    'ZXN0aW5hdGlvblBvbGljeVIPZHVwbGljYXRlUG9saWN5EikKEHRhcmdldF9kaXJlY3RvcnkYCi'
    'ABKAlSD3RhcmdldERpcmVjdG9yeQ==');

@$core.Deprecated('Use transferOfferDescriptor instead')
const TransferOffer$json = {
  '1': 'TransferOffer',
  '2': [
    {
      '1': 'manifest',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferManifest',
      '10': 'manifest'
    },
    {'1': 'timestamp_utc_ms', '3': 2, '4': 1, '5': 3, '10': 'timestampUtcMs'},
  ],
};

/// Descriptor for `TransferOffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferOfferDescriptor = $convert.base64Decode(
    'Cg1UcmFuc2Zlck9mZmVyEjkKCG1hbmlmZXN0GAEgASgLMh0ucGVlcmxpbmsudjEuVHJhbnNmZX'
    'JNYW5pZmVzdFIIbWFuaWZlc3QSKAoQdGltZXN0YW1wX3V0Y19tcxgCIAEoA1IOdGltZXN0YW1w'
    'VXRjTXM=');

@$core.Deprecated('Use transferResponseDescriptor instead')
const TransferResponse$json = {
  '1': 'TransferResponse',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'accepted', '3': 2, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'rejection_reason', '3': 3, '4': 1, '5': 9, '10': 'rejectionReason'},
    {
      '1': 'error',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
  ],
};

/// Descriptor for `TransferResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferResponseDescriptor = $convert.base64Decode(
    'ChBUcmFuc2ZlclJlc3BvbnNlEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEhoKCG'
    'FjY2VwdGVkGAIgASgIUghhY2NlcHRlZBIpChByZWplY3Rpb25fcmVhc29uGAMgASgJUg9yZWpl'
    'Y3Rpb25SZWFzb24SLgoFZXJyb3IYBCABKAsyGC5wZWVybGluay52MS5FcnJvckRldGFpbFIFZX'
    'Jyb3I=');

@$core.Deprecated('Use transferChunkDescriptor instead')
const TransferChunk$json = {
  '1': 'TransferChunk',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'item_index', '3': 2, '4': 1, '5': 5, '10': 'itemIndex'},
    {'1': 'chunk_index', '3': 3, '4': 1, '5': 3, '10': 'chunkIndex'},
    {'1': 'offset_bytes', '3': 4, '4': 1, '5': 3, '10': 'offsetBytes'},
    {'1': 'data', '3': 5, '4': 1, '5': 12, '10': 'data'},
    {'1': 'is_last_chunk', '3': 6, '4': 1, '5': 8, '10': 'isLastChunk'},
    {'1': 'chunk_sha256', '3': 7, '4': 1, '5': 9, '10': 'chunkSha256'},
  ],
};

/// Descriptor for `TransferChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferChunkDescriptor = $convert.base64Decode(
    'Cg1UcmFuc2ZlckNodW5rEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEh0KCml0ZW'
    '1faW5kZXgYAiABKAVSCWl0ZW1JbmRleBIfCgtjaHVua19pbmRleBgDIAEoA1IKY2h1bmtJbmRl'
    'eBIhCgxvZmZzZXRfYnl0ZXMYBCABKANSC29mZnNldEJ5dGVzEhIKBGRhdGEYBSABKAxSBGRhdG'
    'ESIgoNaXNfbGFzdF9jaHVuaxgGIAEoCFILaXNMYXN0Q2h1bmsSIQoMY2h1bmtfc2hhMjU2GAcg'
    'ASgJUgtjaHVua1NoYTI1Ng==');

@$core.Deprecated('Use transferChunkAckDescriptor instead')
const TransferChunkAck$json = {
  '1': 'TransferChunkAck',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'item_index', '3': 2, '4': 1, '5': 5, '10': 'itemIndex'},
    {'1': 'chunk_index', '3': 3, '4': 1, '5': 3, '10': 'chunkIndex'},
    {'1': 'bytes_received', '3': 4, '4': 1, '5': 3, '10': 'bytesReceived'},
    {'1': 'success', '3': 5, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error_message', '3': 6, '4': 1, '5': 9, '10': 'errorMessage'},
    {'1': 'retry_requested', '3': 7, '4': 1, '5': 8, '10': 'retryRequested'},
  ],
};

/// Descriptor for `TransferChunkAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferChunkAckDescriptor = $convert.base64Decode(
    'ChBUcmFuc2ZlckNodW5rQWNrEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEh0KCm'
    'l0ZW1faW5kZXgYAiABKAVSCWl0ZW1JbmRleBIfCgtjaHVua19pbmRleBgDIAEoA1IKY2h1bmtJ'
    'bmRleBIlCg5ieXRlc19yZWNlaXZlZBgEIAEoA1INYnl0ZXNSZWNlaXZlZBIYCgdzdWNjZXNzGA'
    'UgASgIUgdzdWNjZXNzEiMKDWVycm9yX21lc3NhZ2UYBiABKAlSDGVycm9yTWVzc2FnZRInCg9y'
    'ZXRyeV9yZXF1ZXN0ZWQYByABKAhSDnJldHJ5UmVxdWVzdGVk');

@$core.Deprecated('Use transferVerifyResultDescriptor instead')
const TransferVerifyResult$json = {
  '1': 'TransferVerifyResult',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'item_index', '3': 2, '4': 1, '5': 5, '10': 'itemIndex'},
    {'1': 'verified', '3': 3, '4': 1, '5': 8, '10': 'verified'},
    {'1': 'computed_sha256', '3': 4, '4': 1, '5': 9, '10': 'computedSha256'},
    {'1': 'expected_sha256', '3': 5, '4': 1, '5': 9, '10': 'expectedSha256'},
    {'1': 'details', '3': 6, '4': 1, '5': 9, '10': 'details'},
  ],
};

/// Descriptor for `TransferVerifyResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferVerifyResultDescriptor = $convert.base64Decode(
    'ChRUcmFuc2ZlclZlcmlmeVJlc3VsdBIfCgt0cmFuc2Zlcl9pZBgBIAEoCVIKdHJhbnNmZXJJZB'
    'IdCgppdGVtX2luZGV4GAIgASgFUglpdGVtSW5kZXgSGgoIdmVyaWZpZWQYAyABKAhSCHZlcmlm'
    'aWVkEicKD2NvbXB1dGVkX3NoYTI1NhgEIAEoCVIOY29tcHV0ZWRTaGEyNTYSJwoPZXhwZWN0ZW'
    'Rfc2hhMjU2GAUgASgJUg5leHBlY3RlZFNoYTI1NhIYCgdkZXRhaWxzGAYgASgJUgdkZXRhaWxz');

@$core.Deprecated('Use transferCommitSignalDescriptor instead')
const TransferCommitSignal$json = {
  '1': 'TransferCommitSignal',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'commit_confirmed', '3': 2, '4': 1, '5': 8, '10': 'commitConfirmed'},
  ],
};

/// Descriptor for `TransferCommitSignal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferCommitSignalDescriptor = $convert.base64Decode(
    'ChRUcmFuc2ZlckNvbW1pdFNpZ25hbBIfCgt0cmFuc2Zlcl9pZBgBIAEoCVIKdHJhbnNmZXJJZB'
    'IpChBjb21taXRfY29uZmlybWVkGAIgASgIUg9jb21taXRDb25maXJtZWQ=');

@$core.Deprecated('Use transferCompletedReceiptDescriptor instead')
const TransferCompletedReceipt$json = {
  '1': 'TransferCompletedReceipt',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'completion_timestamp_utc_ms',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'completionTimestampUtcMs'
    },
    {
      '1': 'total_bytes_transferred',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'totalBytesTransferred'
    },
    {'1': 'success', '3': 5, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'final_destination_path',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'finalDestinationPath'
    },
    {'1': 'error_message', '3': 7, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `TransferCompletedReceipt`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferCompletedReceiptDescriptor = $convert.base64Decode(
    'ChhUcmFuc2ZlckNvbXBsZXRlZFJlY2VpcHQSHwoLdHJhbnNmZXJfaWQYASABKAlSCnRyYW5zZm'
    'VySWQSOwoMb3BlcmF0aW9uX2lkGAIgASgLMhgucGVlcmxpbmsudjEuT3BlcmF0aW9uSWRSC29w'
    'ZXJhdGlvbklkEj0KG2NvbXBsZXRpb25fdGltZXN0YW1wX3V0Y19tcxgDIAEoA1IYY29tcGxldG'
    'lvblRpbWVzdGFtcFV0Y01zEjYKF3RvdGFsX2J5dGVzX3RyYW5zZmVycmVkGAQgASgDUhV0b3Rh'
    'bEJ5dGVzVHJhbnNmZXJyZWQSGAoHc3VjY2VzcxgFIAEoCFIHc3VjY2VzcxI0ChZmaW5hbF9kZX'
    'N0aW5hdGlvbl9wYXRoGAYgASgJUhRmaW5hbERlc3RpbmF0aW9uUGF0aBIjCg1lcnJvcl9tZXNz'
    'YWdlGAcgASgJUgxlcnJvck1lc3NhZ2U=');

@$core.Deprecated('Use transferCancelRequestDescriptor instead')
const TransferCancelRequest$json = {
  '1': 'TransferCancelRequest',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `TransferCancelRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferCancelRequestDescriptor = $convert.base64Decode(
    'ChVUcmFuc2ZlckNhbmNlbFJlcXVlc3QSHwoLdHJhbnNmZXJfaWQYASABKAlSCnRyYW5zZmVySW'
    'QSFgoGcmVhc29uGAIgASgJUgZyZWFzb24=');

@$core.Deprecated('Use transferPauseRequestDescriptor instead')
const TransferPauseRequest$json = {
  '1': 'TransferPauseRequest',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `TransferPauseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferPauseRequestDescriptor = $convert.base64Decode(
    'ChRUcmFuc2ZlclBhdXNlUmVxdWVzdBIfCgt0cmFuc2Zlcl9pZBgBIAEoCVIKdHJhbnNmZXJJZB'
    'IWCgZyZWFzb24YAiABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use transferPauseResponseDescriptor instead')
const TransferPauseResponse$json = {
  '1': 'TransferPauseResponse',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'acknowledged', '3': 2, '4': 1, '5': 8, '10': 'acknowledged'},
  ],
};

/// Descriptor for `TransferPauseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferPauseResponseDescriptor = $convert.base64Decode(
    'ChVUcmFuc2ZlclBhdXNlUmVzcG9uc2USHwoLdHJhbnNmZXJfaWQYASABKAlSCnRyYW5zZmVySW'
    'QSIgoMYWNrbm93bGVkZ2VkGAIgASgIUgxhY2tub3dsZWRnZWQ=');

@$core.Deprecated('Use transferResumeOfferDescriptor instead')
const TransferResumeOffer$json = {
  '1': 'TransferResumeOffer',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'manifest',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferManifest',
      '10': 'manifest'
    },
    {
      '1': 'resume_timestamp_utc_ms',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'resumeTimestampUtcMs'
    },
  ],
};

/// Descriptor for `TransferResumeOffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferResumeOfferDescriptor = $convert.base64Decode(
    'ChNUcmFuc2ZlclJlc3VtZU9mZmVyEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEj'
    'sKDG9wZXJhdGlvbl9pZBgCIAEoCzIYLnBlZXJsaW5rLnYxLk9wZXJhdGlvbklkUgtvcGVyYXRp'
    'b25JZBI5CghtYW5pZmVzdBgDIAEoCzIdLnBlZXJsaW5rLnYxLlRyYW5zZmVyTWFuaWZlc3RSCG'
    '1hbmlmZXN0EjUKF3Jlc3VtZV90aW1lc3RhbXBfdXRjX21zGAQgASgDUhRyZXN1bWVUaW1lc3Rh'
    'bXBVdGNNcw==');

@$core.Deprecated('Use transferResumeStateDescriptor instead')
const TransferResumeState$json = {
  '1': 'TransferResumeState',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'acked_chunk_indices',
      '3': 3,
      '4': 3,
      '5': 3,
      '10': 'ackedChunkIndices'
    },
    {
      '1': 'bytes_already_staged',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'bytesAlreadyStaged'
    },
    {
      '1': 'current_state',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransferState',
      '10': 'currentState'
    },
    {'1': 'can_resume', '3': 6, '4': 1, '5': 8, '10': 'canResume'},
    {'1': 'message', '3': 7, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `TransferResumeState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferResumeStateDescriptor = $convert.base64Decode(
    'ChNUcmFuc2ZlclJlc3VtZVN0YXRlEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEj'
    'sKDG9wZXJhdGlvbl9pZBgCIAEoCzIYLnBlZXJsaW5rLnYxLk9wZXJhdGlvbklkUgtvcGVyYXRp'
    'b25JZBIuChNhY2tlZF9jaHVua19pbmRpY2VzGAMgAygDUhFhY2tlZENodW5rSW5kaWNlcxIwCh'
    'RieXRlc19hbHJlYWR5X3N0YWdlZBgEIAEoA1ISYnl0ZXNBbHJlYWR5U3RhZ2VkEj8KDWN1cnJl'
    'bnRfc3RhdGUYBSABKA4yGi5wZWVybGluay52MS5UcmFuc2ZlclN0YXRlUgxjdXJyZW50U3RhdG'
    'USHQoKY2FuX3Jlc3VtZRgGIAEoCFIJY2FuUmVzdW1lEhgKB21lc3NhZ2UYByABKAlSB21lc3Nh'
    'Z2U=');

@$core.Deprecated('Use transferOperationStatusQueryDescriptor instead')
const TransferOperationStatusQuery$json = {
  '1': 'TransferOperationStatusQuery',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
  ],
};

/// Descriptor for `TransferOperationStatusQuery`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferOperationStatusQueryDescriptor =
    $convert.base64Decode(
        'ChxUcmFuc2Zlck9wZXJhdGlvblN0YXR1c1F1ZXJ5Eh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cm'
        'Fuc2ZlcklkEjsKDG9wZXJhdGlvbl9pZBgCIAEoCzIYLnBlZXJsaW5rLnYxLk9wZXJhdGlvbklk'
        'UgtvcGVyYXRpb25JZA==');

@$core.Deprecated('Use transferOperationStatusResponseDescriptor instead')
const TransferOperationStatusResponse$json = {
  '1': 'TransferOperationStatusResponse',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransferState',
      '10': 'state'
    },
    {'1': 'is_committed', '3': 4, '4': 1, '5': 8, '10': 'isCommitted'},
    {
      '1': 'receipt',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferCompletedReceipt',
      '10': 'receipt'
    },
    {'1': 'error_message', '3': 6, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `TransferOperationStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferOperationStatusResponseDescriptor = $convert.base64Decode(
    'Ch9UcmFuc2Zlck9wZXJhdGlvblN0YXR1c1Jlc3BvbnNlEh8KC3RyYW5zZmVyX2lkGAEgASgJUg'
    'p0cmFuc2ZlcklkEjsKDG9wZXJhdGlvbl9pZBgCIAEoCzIYLnBlZXJsaW5rLnYxLk9wZXJhdGlv'
    'bklkUgtvcGVyYXRpb25JZBIwCgVzdGF0ZRgDIAEoDjIaLnBlZXJsaW5rLnYxLlRyYW5zZmVyU3'
    'RhdGVSBXN0YXRlEiEKDGlzX2NvbW1pdHRlZBgEIAEoCFILaXNDb21taXR0ZWQSPwoHcmVjZWlw'
    'dBgFIAEoCzIlLnBlZXJsaW5rLnYxLlRyYW5zZmVyQ29tcGxldGVkUmVjZWlwdFIHcmVjZWlwdB'
    'IjCg1lcnJvcl9tZXNzYWdlGAYgASgJUgxlcnJvck1lc3NhZ2U=');

@$core.Deprecated('Use transferWireMessageDescriptor instead')
const TransferWireMessage$json = {
  '1': 'TransferWireMessage',
  '2': [
    {
      '1': 'offer',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferOffer',
      '9': 0,
      '10': 'offer'
    },
    {
      '1': 'response',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferResponse',
      '9': 0,
      '10': 'response'
    },
    {
      '1': 'chunk',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferChunk',
      '9': 0,
      '10': 'chunk'
    },
    {
      '1': 'ack',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferChunkAck',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'verify',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferVerifyResult',
      '9': 0,
      '10': 'verify'
    },
    {
      '1': 'commit',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferCommitSignal',
      '9': 0,
      '10': 'commit'
    },
    {
      '1': 'receipt',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferCompletedReceipt',
      '9': 0,
      '10': 'receipt'
    },
    {
      '1': 'cancel',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferCancelRequest',
      '9': 0,
      '10': 'cancel'
    },
    {
      '1': 'pause',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferPauseRequest',
      '9': 0,
      '10': 'pause'
    },
    {
      '1': 'pause_response',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferPauseResponse',
      '9': 0,
      '10': 'pauseResponse'
    },
    {
      '1': 'resume_offer',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferResumeOffer',
      '9': 0,
      '10': 'resumeOffer'
    },
    {
      '1': 'resume_state',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferResumeState',
      '9': 0,
      '10': 'resumeState'
    },
    {
      '1': 'status_query',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferOperationStatusQuery',
      '9': 0,
      '10': 'statusQuery'
    },
    {
      '1': 'status_response',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferOperationStatusResponse',
      '9': 0,
      '10': 'statusResponse'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `TransferWireMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferWireMessageDescriptor = $convert.base64Decode(
    'ChNUcmFuc2ZlcldpcmVNZXNzYWdlEjIKBW9mZmVyGAEgASgLMhoucGVlcmxpbmsudjEuVHJhbn'
    'NmZXJPZmZlckgAUgVvZmZlchI7CghyZXNwb25zZRgCIAEoCzIdLnBlZXJsaW5rLnYxLlRyYW5z'
    'ZmVyUmVzcG9uc2VIAFIIcmVzcG9uc2USMgoFY2h1bmsYAyABKAsyGi5wZWVybGluay52MS5Ucm'
    'Fuc2ZlckNodW5rSABSBWNodW5rEjEKA2FjaxgEIAEoCzIdLnBlZXJsaW5rLnYxLlRyYW5zZmVy'
    'Q2h1bmtBY2tIAFIDYWNrEjsKBnZlcmlmeRgFIAEoCzIhLnBlZXJsaW5rLnYxLlRyYW5zZmVyVm'
    'VyaWZ5UmVzdWx0SABSBnZlcmlmeRI7CgZjb21taXQYBiABKAsyIS5wZWVybGluay52MS5UcmFu'
    'c2ZlckNvbW1pdFNpZ25hbEgAUgZjb21taXQSQQoHcmVjZWlwdBgHIAEoCzIlLnBlZXJsaW5rLn'
    'YxLlRyYW5zZmVyQ29tcGxldGVkUmVjZWlwdEgAUgdyZWNlaXB0EjwKBmNhbmNlbBgIIAEoCzIi'
    'LnBlZXJsaW5rLnYxLlRyYW5zZmVyQ2FuY2VsUmVxdWVzdEgAUgZjYW5jZWwSOQoFcGF1c2UYCS'
    'ABKAsyIS5wZWVybGluay52MS5UcmFuc2ZlclBhdXNlUmVxdWVzdEgAUgVwYXVzZRJLCg5wYXVz'
    'ZV9yZXNwb25zZRgKIAEoCzIiLnBlZXJsaW5rLnYxLlRyYW5zZmVyUGF1c2VSZXNwb25zZUgAUg'
    '1wYXVzZVJlc3BvbnNlEkUKDHJlc3VtZV9vZmZlchgLIAEoCzIgLnBlZXJsaW5rLnYxLlRyYW5z'
    'ZmVyUmVzdW1lT2ZmZXJIAFILcmVzdW1lT2ZmZXISRQoMcmVzdW1lX3N0YXRlGAwgASgLMiAucG'
    'VlcmxpbmsudjEuVHJhbnNmZXJSZXN1bWVTdGF0ZUgAUgtyZXN1bWVTdGF0ZRJOCgxzdGF0dXNf'
    'cXVlcnkYDSABKAsyKS5wZWVybGluay52MS5UcmFuc2Zlck9wZXJhdGlvblN0YXR1c1F1ZXJ5SA'
    'BSC3N0YXR1c1F1ZXJ5ElcKD3N0YXR1c19yZXNwb25zZRgOIAEoCzIsLnBlZXJsaW5rLnYxLlRy'
    'YW5zZmVyT3BlcmF0aW9uU3RhdHVzUmVzcG9uc2VIAFIOc3RhdHVzUmVzcG9uc2VCCQoHcGF5bG'
    '9hZA==');

@$core.Deprecated('Use transferDescriptorDescriptor instead')
const TransferDescriptor$json = {
  '1': 'TransferDescriptor',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'object_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ObjectId',
      '10': 'objectId'
    },
    {
      '1': 'source_peer',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'sourcePeer'
    },
    {
      '1': 'destination_peer',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'destinationPeer'
    },
    {'1': 'display_name', '3': 6, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'total_bytes', '3': 7, '4': 1, '5': 3, '10': 'totalBytes'},
    {'1': 'chunk_size_bytes', '3': 8, '4': 1, '5': 5, '10': 'chunkSizeBytes'},
    {
      '1': 'expected_hash',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ContentHash',
      '10': 'expectedHash'
    },
    {'1': 'created_at_utc_ms', '3': 10, '4': 1, '5': 3, '10': 'createdAtUtcMs'},
    {
      '1': 'items',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.TransferItem',
      '10': 'items'
    },
    {
      '1': 'local_source_path',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'localSourcePath'
    },
    {'1': 'destination_path', '3': 13, '4': 1, '5': 9, '10': 'destinationPath'},
  ],
};

/// Descriptor for `TransferDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferDescriptorDescriptor = $convert.base64Decode(
    'ChJUcmFuc2ZlckRlc2NyaXB0b3ISHwoLdHJhbnNmZXJfaWQYASABKAlSCnRyYW5zZmVySWQSOw'
    'oMb3BlcmF0aW9uX2lkGAIgASgLMhgucGVlcmxpbmsudjEuT3BlcmF0aW9uSWRSC29wZXJhdGlv'
    'bklkEjIKCW9iamVjdF9pZBgDIAEoCzIVLnBlZXJsaW5rLnYxLk9iamVjdElkUghvYmplY3RJZB'
    'I0Cgtzb3VyY2VfcGVlchgEIAEoCzITLnBlZXJsaW5rLnYxLlBlZXJJZFIKc291cmNlUGVlchI+'
    'ChBkZXN0aW5hdGlvbl9wZWVyGAUgASgLMhMucGVlcmxpbmsudjEuUGVlcklkUg9kZXN0aW5hdG'
    'lvblBlZXISIQoMZGlzcGxheV9uYW1lGAYgASgJUgtkaXNwbGF5TmFtZRIfCgt0b3RhbF9ieXRl'
    'cxgHIAEoA1IKdG90YWxCeXRlcxIoChBjaHVua19zaXplX2J5dGVzGAggASgFUg5jaHVua1Npem'
    'VCeXRlcxI9Cg1leHBlY3RlZF9oYXNoGAkgASgLMhgucGVlcmxpbmsudjEuQ29udGVudEhhc2hS'
    'DGV4cGVjdGVkSGFzaBIpChFjcmVhdGVkX2F0X3V0Y19tcxgKIAEoA1IOY3JlYXRlZEF0VXRjTX'
    'MSLwoFaXRlbXMYCyADKAsyGS5wZWVybGluay52MS5UcmFuc2Zlckl0ZW1SBWl0ZW1zEioKEWxv'
    'Y2FsX3NvdXJjZV9wYXRoGAwgASgJUg9sb2NhbFNvdXJjZVBhdGgSKQoQZGVzdGluYXRpb25fcG'
    'F0aBgNIAEoCVIPZGVzdGluYXRpb25QYXRo');

@$core.Deprecated('Use transferProgressDescriptor instead')
const TransferProgress$json = {
  '1': 'TransferProgress',
  '2': [
    {'1': 'transfer_id', '3': 1, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'transferred_bytes',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'transferredBytes'
    },
    {'1': 'total_bytes', '3': 3, '4': 1, '5': 3, '10': 'totalBytes'},
    {
      '1': 'state',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransferState',
      '10': 'state'
    },
    {'1': 'speed_bps', '3': 5, '4': 1, '5': 3, '10': 'speedBps'},
    {
      '1': 'error',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
    {'1': 'current_file', '3': 7, '4': 1, '5': 9, '10': 'currentFile'},
    {
      '1': 'current_item_index',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'currentItemIndex'
    },
    {'1': 'total_items', '3': 9, '4': 1, '5': 5, '10': 'totalItems'},
    {'1': 'destination_path', '3': 10, '4': 1, '5': 9, '10': 'destinationPath'},
  ],
};

/// Descriptor for `TransferProgress`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferProgressDescriptor = $convert.base64Decode(
    'ChBUcmFuc2ZlclByb2dyZXNzEh8KC3RyYW5zZmVyX2lkGAEgASgJUgp0cmFuc2ZlcklkEisKEX'
    'RyYW5zZmVycmVkX2J5dGVzGAIgASgDUhB0cmFuc2ZlcnJlZEJ5dGVzEh8KC3RvdGFsX2J5dGVz'
    'GAMgASgDUgp0b3RhbEJ5dGVzEjAKBXN0YXRlGAQgASgOMhoucGVlcmxpbmsudjEuVHJhbnNmZX'
    'JTdGF0ZVIFc3RhdGUSGwoJc3BlZWRfYnBzGAUgASgDUghzcGVlZEJwcxIuCgVlcnJvchgGIAEo'
    'CzIYLnBlZXJsaW5rLnYxLkVycm9yRGV0YWlsUgVlcnJvchIhCgxjdXJyZW50X2ZpbGUYByABKA'
    'lSC2N1cnJlbnRGaWxlEiwKEmN1cnJlbnRfaXRlbV9pbmRleBgIIAEoBVIQY3VycmVudEl0ZW1J'
    'bmRleBIfCgt0b3RhbF9pdGVtcxgJIAEoBVIKdG90YWxJdGVtcxIpChBkZXN0aW5hdGlvbl9wYX'
    'RoGAogASgJUg9kZXN0aW5hdGlvblBhdGg=');
