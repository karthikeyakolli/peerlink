// This is a generated file - do not edit.
//
// Generated from peerlink/v1/sync.proto.

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

@$core.Deprecated('Use syncModeProtoDescriptor instead')
const SyncModeProto$json = {
  '1': 'SyncModeProto',
  '2': [
    {'1': 'SYNC_MODE_UNSPECIFIED', '2': 0},
    {'1': 'SYNC_MODE_BIDIRECTIONAL', '2': 1},
    {'1': 'SYNC_MODE_ONE_WAY_REPLICATION', '2': 2},
    {'1': 'SYNC_MODE_RECEIVE_ONLY_IMPORT', '2': 3},
    {'1': 'SYNC_MODE_EXACT_MIRROR', '2': 4},
  ],
};

/// Descriptor for `SyncModeProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List syncModeProtoDescriptor = $convert.base64Decode(
    'Cg1TeW5jTW9kZVByb3RvEhkKFVNZTkNfTU9ERV9VTlNQRUNJRklFRBAAEhsKF1NZTkNfTU9ERV'
    '9CSURJUkVDVElPTkFMEAESIQodU1lOQ19NT0RFX09ORV9XQVlfUkVQTElDQVRJT04QAhIhCh1T'
    'WU5DX01PREVfUkVDRUlWRV9PTkxZX0lNUE9SVBADEhoKFlNZTkNfTU9ERV9FWEFDVF9NSVJST1'
    'IQBA==');

@$core.Deprecated('Use syncConflictTypeDescriptor instead')
const SyncConflictType$json = {
  '1': 'SyncConflictType',
  '2': [
    {'1': 'SYNC_CONFLICT_UNSPECIFIED', '2': 0},
    {'1': 'SYNC_CONFLICT_CONCURRENT_CONTENT_EDIT', '2': 1},
    {'1': 'SYNC_CONFLICT_DELETE_VS_MODIFY', '2': 2},
    {'1': 'SYNC_CONFLICT_CONCURRENT_RENAME', '2': 3},
    {'1': 'SYNC_CONFLICT_CONCURRENT_MOVE', '2': 4},
    {'1': 'SYNC_CONFLICT_BOTH_CREATED_SAME_PATH', '2': 5},
    {'1': 'SYNC_CONFLICT_TOMBSTONE_VS_NEW_OBJECT', '2': 6},
  ],
};

/// Descriptor for `SyncConflictType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List syncConflictTypeDescriptor = $convert.base64Decode(
    'ChBTeW5jQ29uZmxpY3RUeXBlEh0KGVNZTkNfQ09ORkxJQ1RfVU5TUEVDSUZJRUQQABIpCiVTWU'
    '5DX0NPTkZMSUNUX0NPTkNVUlJFTlRfQ09OVEVOVF9FRElUEAESIgoeU1lOQ19DT05GTElDVF9E'
    'RUxFVEVfVlNfTU9ESUZZEAISIwofU1lOQ19DT05GTElDVF9DT05DVVJSRU5UX1JFTkFNRRADEi'
    'EKHVNZTkNfQ09ORkxJQ1RfQ09OQ1VSUkVOVF9NT1ZFEAQSKAokU1lOQ19DT05GTElDVF9CT1RI'
    'X0NSRUFURURfU0FNRV9QQVRIEAUSKQolU1lOQ19DT05GTElDVF9UT01CU1RPTkVfVlNfTkVXX0'
    '9CSkVDVBAG');

@$core.Deprecated('Use syncConflictResolutionDescriptor instead')
const SyncConflictResolution$json = {
  '1': 'SyncConflictResolution',
  '2': [
    {'1': 'SYNC_RESOLUTION_DEFERRED', '2': 0},
    {'1': 'SYNC_RESOLUTION_KEEP_LOCAL', '2': 1},
    {'1': 'SYNC_RESOLUTION_KEEP_REMOTE', '2': 2},
    {'1': 'SYNC_RESOLUTION_KEEP_BOTH', '2': 3},
    {'1': 'SYNC_RESOLUTION_MERGE', '2': 4},
  ],
};

/// Descriptor for `SyncConflictResolution`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List syncConflictResolutionDescriptor = $convert.base64Decode(
    'ChZTeW5jQ29uZmxpY3RSZXNvbHV0aW9uEhwKGFNZTkNfUkVTT0xVVElPTl9ERUZFUlJFRBAAEh'
    '4KGlNZTkNfUkVTT0xVVElPTl9LRUVQX0xPQ0FMEAESHwobU1lOQ19SRVNPTFVUSU9OX0tFRVBf'
    'UkVNT1RFEAISHQoZU1lOQ19SRVNPTFVUSU9OX0tFRVBfQk9USBADEhkKFVNZTkNfUkVTT0xVVE'
    'lPTl9NRVJHRRAE');

@$core.Deprecated('Use syncObjectDescriptorDescriptor instead')
const SyncObjectDescriptor$json = {
  '1': 'SyncObjectDescriptor',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {'1': 'relative_path', '3': 2, '4': 1, '5': 9, '10': 'relativePath'},
    {'1': 'content_hash', '3': 3, '4': 1, '5': 9, '10': 'contentHash'},
    {'1': 'size_bytes', '3': 4, '4': 1, '5': 3, '10': 'sizeBytes'},
    {
      '1': 'last_modified_hint_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'lastModifiedHintMs'
    },
    {'1': 'is_directory', '3': 6, '4': 1, '5': 8, '10': 'isDirectory'},
    {
      '1': 'causal_clock',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.SyncObjectDescriptor.CausalClockEntry',
      '10': 'causalClock'
    },
    {
      '1': 'content_version_seq',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'contentVersionSeq'
    },
    {
      '1': 'metadata_version_seq',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'metadataVersionSeq'
    },
    {'1': 'deleted', '3': 10, '4': 1, '5': 8, '10': 'deleted'},
  ],
  '3': [SyncObjectDescriptor_CausalClockEntry$json],
};

@$core.Deprecated('Use syncObjectDescriptorDescriptor instead')
const SyncObjectDescriptor_CausalClockEntry$json = {
  '1': 'CausalClockEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SyncObjectDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncObjectDescriptorDescriptor = $convert.base64Decode(
    'ChRTeW5jT2JqZWN0RGVzY3JpcHRvchIbCglvYmplY3RfaWQYASABKAlSCG9iamVjdElkEiMKDX'
    'JlbGF0aXZlX3BhdGgYAiABKAlSDHJlbGF0aXZlUGF0aBIhCgxjb250ZW50X2hhc2gYAyABKAlS'
    'C2NvbnRlbnRIYXNoEh0KCnNpemVfYnl0ZXMYBCABKANSCXNpemVCeXRlcxIxChVsYXN0X21vZG'
    'lmaWVkX2hpbnRfbXMYBSABKANSEmxhc3RNb2RpZmllZEhpbnRNcxIhCgxpc19kaXJlY3RvcnkY'
    'BiABKAhSC2lzRGlyZWN0b3J5ElUKDGNhdXNhbF9jbG9jaxgHIAMoCzIyLnBlZXJsaW5rLnYxLl'
    'N5bmNPYmplY3REZXNjcmlwdG9yLkNhdXNhbENsb2NrRW50cnlSC2NhdXNhbENsb2NrEi4KE2Nv'
    'bnRlbnRfdmVyc2lvbl9zZXEYCCABKANSEWNvbnRlbnRWZXJzaW9uU2VxEjAKFG1ldGFkYXRhX3'
    'ZlcnNpb25fc2VxGAkgASgDUhJtZXRhZGF0YVZlcnNpb25TZXESGAoHZGVsZXRlZBgKIAEoCFIH'
    'ZGVsZXRlZBo+ChBDYXVzYWxDbG9ja0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGA'
    'IgASgDUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use syncTombstoneDescriptor instead')
const SyncTombstone$json = {
  '1': 'SyncTombstone',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {
      '1': 'deleted_at_relative_path',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'deletedAtRelativePath'
    },
    {'1': 'deleting_peer_id', '3': 3, '4': 1, '5': 9, '10': 'deletingPeerId'},
    {'1': 'deleted_at_utc_ms', '3': 4, '4': 1, '5': 3, '10': 'deletedAtUtcMs'},
    {
      '1': 'deletion_causal_clock',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.SyncTombstone.DeletionCausalClockEntry',
      '10': 'deletionCausalClock'
    },
  ],
  '3': [SyncTombstone_DeletionCausalClockEntry$json],
};

@$core.Deprecated('Use syncTombstoneDescriptor instead')
const SyncTombstone_DeletionCausalClockEntry$json = {
  '1': 'DeletionCausalClockEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SyncTombstone`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncTombstoneDescriptor = $convert.base64Decode(
    'Cg1TeW5jVG9tYnN0b25lEhsKCW9iamVjdF9pZBgBIAEoCVIIb2JqZWN0SWQSNwoYZGVsZXRlZF'
    '9hdF9yZWxhdGl2ZV9wYXRoGAIgASgJUhVkZWxldGVkQXRSZWxhdGl2ZVBhdGgSKAoQZGVsZXRp'
    'bmdfcGVlcl9pZBgDIAEoCVIOZGVsZXRpbmdQZWVySWQSKQoRZGVsZXRlZF9hdF91dGNfbXMYBC'
    'ABKANSDmRlbGV0ZWRBdFV0Y01zEmcKFWRlbGV0aW9uX2NhdXNhbF9jbG9jaxgFIAMoCzIzLnBl'
    'ZXJsaW5rLnYxLlN5bmNUb21ic3RvbmUuRGVsZXRpb25DYXVzYWxDbG9ja0VudHJ5UhNkZWxldG'
    'lvbkNhdXNhbENsb2NrGkYKGERlbGV0aW9uQ2F1c2FsQ2xvY2tFbnRyeRIQCgNrZXkYASABKAlS'
    'A2tleRIUCgV2YWx1ZRgCIAEoA1IFdmFsdWU6AjgB');

@$core.Deprecated('Use syncManifestMessageDescriptor instead')
const SyncManifestMessage$json = {
  '1': 'SyncManifestMessage',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'objects',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.SyncObjectDescriptor',
      '10': 'objects'
    },
    {
      '1': 'tombstones',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.SyncTombstone',
      '10': 'tombstones'
    },
    {
      '1': 'manifest_causal_clock',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.SyncManifestMessage.ManifestCausalClockEntry',
      '10': 'manifestCausalClock'
    },
  ],
  '3': [SyncManifestMessage_ManifestCausalClockEntry$json],
};

@$core.Deprecated('Use syncManifestMessageDescriptor instead')
const SyncManifestMessage_ManifestCausalClockEntry$json = {
  '1': 'ManifestCausalClockEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SyncManifestMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncManifestMessageDescriptor = $convert.base64Decode(
    'ChNTeW5jTWFuaWZlc3RNZXNzYWdlEhcKB3BlZXJfaWQYASABKAlSBnBlZXJJZBIdCgpzZXNzaW'
    '9uX2lkGAIgASgJUglzZXNzaW9uSWQSOwoHb2JqZWN0cxgDIAMoCzIhLnBlZXJsaW5rLnYxLlN5'
    'bmNPYmplY3REZXNjcmlwdG9yUgdvYmplY3RzEjoKCnRvbWJzdG9uZXMYBCADKAsyGi5wZWVybG'
    'luay52MS5TeW5jVG9tYnN0b25lUgp0b21ic3RvbmVzEm0KFW1hbmlmZXN0X2NhdXNhbF9jbG9j'
    'axgFIAMoCzI5LnBlZXJsaW5rLnYxLlN5bmNNYW5pZmVzdE1lc3NhZ2UuTWFuaWZlc3RDYXVzYW'
    'xDbG9ja0VudHJ5UhNtYW5pZmVzdENhdXNhbENsb2NrGkYKGE1hbmlmZXN0Q2F1c2FsQ2xvY2tF'
    'bnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoA1IFdmFsdWU6AjgB');

@$core.Deprecated('Use syncConflictNoticeDescriptor instead')
const SyncConflictNotice$json = {
  '1': 'SyncConflictNotice',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'object_id', '3': 2, '4': 1, '5': 9, '10': 'objectId'},
    {
      '1': 'conflict_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.SyncConflictType',
      '10': 'conflictType'
    },
    {
      '1': 'local_version',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SyncObjectDescriptor',
      '10': 'localVersion'
    },
    {
      '1': 'remote_version',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SyncObjectDescriptor',
      '10': 'remoteVersion'
    },
  ],
};

/// Descriptor for `SyncConflictNotice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncConflictNoticeDescriptor = $convert.base64Decode(
    'ChJTeW5jQ29uZmxpY3ROb3RpY2USHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhsKCW'
    '9iamVjdF9pZBgCIAEoCVIIb2JqZWN0SWQSQgoNY29uZmxpY3RfdHlwZRgDIAEoDjIdLnBlZXJs'
    'aW5rLnYxLlN5bmNDb25mbGljdFR5cGVSDGNvbmZsaWN0VHlwZRJGCg1sb2NhbF92ZXJzaW9uGA'
    'QgASgLMiEucGVlcmxpbmsudjEuU3luY09iamVjdERlc2NyaXB0b3JSDGxvY2FsVmVyc2lvbhJI'
    'Cg5yZW1vdGVfdmVyc2lvbhgFIAEoCzIhLnBlZXJsaW5rLnYxLlN5bmNPYmplY3REZXNjcmlwdG'
    '9yUg1yZW1vdGVWZXJzaW9u');

@$core.Deprecated('Use syncConflictResolutionDecisionDescriptor instead')
const SyncConflictResolutionDecision$json = {
  '1': 'SyncConflictResolutionDecision',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'object_id', '3': 2, '4': 1, '5': 9, '10': 'objectId'},
    {
      '1': 'resolution',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.SyncConflictResolution',
      '10': 'resolution'
    },
  ],
};

/// Descriptor for `SyncConflictResolutionDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncConflictResolutionDecisionDescriptor =
    $convert.base64Decode(
        'Ch5TeW5jQ29uZmxpY3RSZXNvbHV0aW9uRGVjaXNpb24SHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2'
        'Vzc2lvbklkEhsKCW9iamVjdF9pZBgCIAEoCVIIb2JqZWN0SWQSQwoKcmVzb2x1dGlvbhgDIAEo'
        'DjIjLnBlZXJsaW5rLnYxLlN5bmNDb25mbGljdFJlc29sdXRpb25SCnJlc29sdXRpb24=');

@$core.Deprecated('Use syncMassChangeHoldDescriptor instead')
const SyncMassChangeHold$json = {
  '1': 'SyncMassChangeHold',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'reasons', '3': 2, '4': 3, '5': 9, '10': 'reasons'},
    {'1': 'held_at_utc_ms', '3': 3, '4': 1, '5': 3, '10': 'heldAtUtcMs'},
  ],
};

/// Descriptor for `SyncMassChangeHold`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncMassChangeHoldDescriptor = $convert.base64Decode(
    'ChJTeW5jTWFzc0NoYW5nZUhvbGQSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhgKB3'
    'JlYXNvbnMYAiADKAlSB3JlYXNvbnMSIwoOaGVsZF9hdF91dGNfbXMYAyABKANSC2hlbGRBdFV0'
    'Y01z');
