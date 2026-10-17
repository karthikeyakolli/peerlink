// This is a generated file - do not edit.
//
// Generated from peerlink/v1/backup.proto.

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

@$core.Deprecated('Use backupTypeProtoDescriptor instead')
const BackupTypeProto$json = {
  '1': 'BackupTypeProto',
  '2': [
    {'1': 'BACKUP_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'BACKUP_TYPE_FULL', '2': 1},
    {'1': 'BACKUP_TYPE_INCREMENTAL', '2': 2},
    {'1': 'BACKUP_TYPE_DIFFERENTIAL', '2': 3},
  ],
};

/// Descriptor for `BackupTypeProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List backupTypeProtoDescriptor = $convert.base64Decode(
    'Cg9CYWNrdXBUeXBlUHJvdG8SGwoXQkFDS1VQX1RZUEVfVU5TUEVDSUZJRUQQABIUChBCQUNLVV'
    'BfVFlQRV9GVUxMEAESGwoXQkFDS1VQX1RZUEVfSU5DUkVNRU5UQUwQAhIcChhCQUNLVVBfVFlQ'
    'RV9ESUZGRVJFTlRJQUwQAw==');

@$core.Deprecated('Use backupStatusProtoDescriptor instead')
const BackupStatusProto$json = {
  '1': 'BackupStatusProto',
  '2': [
    {'1': 'BACKUP_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'BACKUP_STATUS_PENDING', '2': 1},
    {'1': 'BACKUP_STATUS_IN_PROGRESS', '2': 2},
    {'1': 'BACKUP_STATUS_COMPLETED', '2': 3},
    {'1': 'BACKUP_STATUS_FAILED', '2': 4},
    {'1': 'BACKUP_STATUS_CANCELLED', '2': 5},
    {'1': 'BACKUP_STATUS_VERIFYING', '2': 6},
  ],
};

/// Descriptor for `BackupStatusProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List backupStatusProtoDescriptor = $convert.base64Decode(
    'ChFCYWNrdXBTdGF0dXNQcm90bxIdChlCQUNLVVBfU1RBVFVTX1VOU1BFQ0lGSUVEEAASGQoVQk'
    'FDS1VQX1NUQVRVU19QRU5ESU5HEAESHQoZQkFDS1VQX1NUQVRVU19JTl9QUk9HUkVTUxACEhsK'
    'F0JBQ0tVUF9TVEFUVVNfQ09NUExFVEVEEAMSGAoUQkFDS1VQX1NUQVRVU19GQUlMRUQQBBIbCh'
    'dCQUNLVVBfU1RBVFVTX0NBTkNFTExFRBAFEhsKF0JBQ0tVUF9TVEFUVVNfVkVSSUZZSU5HEAY=');

@$core.Deprecated('Use restoreConflictPolicyProtoDescriptor instead')
const RestoreConflictPolicyProto$json = {
  '1': 'RestoreConflictPolicyProto',
  '2': [
    {'1': 'RESTORE_CONFLICT_POLICY_UNSPECIFIED', '2': 0},
    {'1': 'RESTORE_CONFLICT_OVERWRITE_WITH_NEW_VERSION', '2': 1},
    {'1': 'RESTORE_CONFLICT_FAIL_ON_CONFLICT', '2': 2},
    {'1': 'RESTORE_CONFLICT_ALTERNATIVE_PATH', '2': 3},
  ],
};

/// Descriptor for `RestoreConflictPolicyProto`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List restoreConflictPolicyProtoDescriptor = $convert.base64Decode(
    'ChpSZXN0b3JlQ29uZmxpY3RQb2xpY3lQcm90bxInCiNSRVNUT1JFX0NPTkZMSUNUX1BPTElDWV'
    '9VTlNQRUNJRklFRBAAEi8KK1JFU1RPUkVfQ09ORkxJQ1RfT1ZFUldSSVRFX1dJVEhfTkVXX1ZF'
    'UlNJT04QARIlCiFSRVNUT1JFX0NPTkZMSUNUX0ZBSUxfT05fQ09ORkxJQ1QQAhIlCiFSRVNUT1'
    'JFX0NPTkZMSUNUX0FMVEVSTkFUSVZFX1BBVEgQAw==');

@$core.Deprecated('Use historicalVersionProtoDescriptor instead')
const HistoricalVersionProto$json = {
  '1': 'HistoricalVersionProto',
  '2': [
    {'1': 'object_id', '3': 1, '4': 1, '5': 9, '10': 'objectId'},
    {'1': 'relative_path', '3': 2, '4': 1, '5': 9, '10': 'relativePath'},
    {'1': 'content_hash', '3': 3, '4': 1, '5': 9, '10': 'contentHash'},
    {'1': 'size_bytes', '3': 4, '4': 1, '5': 3, '10': 'sizeBytes'},
    {'1': 'version_sequence', '3': 5, '4': 1, '5': 3, '10': 'versionSequence'},
    {
      '1': 'captured_at_utc_ms',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'capturedAtUtcMs'
    },
    {'1': 'is_deleted', '3': 7, '4': 1, '5': 8, '10': 'isDeleted'},
    {'1': 'storage_hash', '3': 8, '4': 1, '5': 9, '10': 'storageHash'},
    {'1': 'is_encrypted', '3': 9, '4': 1, '5': 8, '10': 'isEncrypted'},
    {'1': 'is_protected', '3': 10, '4': 1, '5': 8, '10': 'isProtected'},
  ],
};

/// Descriptor for `HistoricalVersionProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List historicalVersionProtoDescriptor = $convert.base64Decode(
    'ChZIaXN0b3JpY2FsVmVyc2lvblByb3RvEhsKCW9iamVjdF9pZBgBIAEoCVIIb2JqZWN0SWQSIw'
    'oNcmVsYXRpdmVfcGF0aBgCIAEoCVIMcmVsYXRpdmVQYXRoEiEKDGNvbnRlbnRfaGFzaBgDIAEo'
    'CVILY29udGVudEhhc2gSHQoKc2l6ZV9ieXRlcxgEIAEoA1IJc2l6ZUJ5dGVzEikKEHZlcnNpb2'
    '5fc2VxdWVuY2UYBSABKANSD3ZlcnNpb25TZXF1ZW5jZRIrChJjYXB0dXJlZF9hdF91dGNfbXMY'
    'BiABKANSD2NhcHR1cmVkQXRVdGNNcxIdCgppc19kZWxldGVkGAcgASgIUglpc0RlbGV0ZWQSIQ'
    'oMc3RvcmFnZV9oYXNoGAggASgJUgtzdG9yYWdlSGFzaBIhCgxpc19lbmNyeXB0ZWQYCSABKAhS'
    'C2lzRW5jcnlwdGVkEiEKDGlzX3Byb3RlY3RlZBgKIAEoCFILaXNQcm90ZWN0ZWQ=');

@$core.Deprecated('Use backupManifestProtoDescriptor instead')
const BackupManifestProto$json = {
  '1': 'BackupManifestProto',
  '2': [
    {'1': 'backup_id', '3': 1, '4': 1, '5': 9, '10': 'backupId'},
    {'1': 'job_id', '3': 2, '4': 1, '5': 9, '10': 'jobId'},
    {
      '1': 'backup_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.BackupTypeProto',
      '10': 'backupType'
    },
    {
      '1': 'snapshot_timestamp_utc_ms',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'snapshotTimestampUtcMs'
    },
    {'1': 'parent_backup_id', '3': 5, '4': 1, '5': 9, '10': 'parentBackupId'},
    {'1': 'total_files', '3': 6, '4': 1, '5': 3, '10': 'totalFiles'},
    {'1': 'total_bytes', '3': 7, '4': 1, '5': 3, '10': 'totalBytes'},
    {'1': 'is_blind', '3': 8, '4': 1, '5': 8, '10': 'isBlind'},
    {'1': 'manifest_digest', '3': 9, '4': 1, '5': 9, '10': 'manifestDigest'},
    {
      '1': 'items',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.HistoricalVersionProto',
      '10': 'items'
    },
  ],
};

/// Descriptor for `BackupManifestProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupManifestProtoDescriptor = $convert.base64Decode(
    'ChNCYWNrdXBNYW5pZmVzdFByb3RvEhsKCWJhY2t1cF9pZBgBIAEoCVIIYmFja3VwSWQSFQoGam'
    '9iX2lkGAIgASgJUgVqb2JJZBI9CgtiYWNrdXBfdHlwZRgDIAEoDjIcLnBlZXJsaW5rLnYxLkJh'
    'Y2t1cFR5cGVQcm90b1IKYmFja3VwVHlwZRI5ChlzbmFwc2hvdF90aW1lc3RhbXBfdXRjX21zGA'
    'QgASgDUhZzbmFwc2hvdFRpbWVzdGFtcFV0Y01zEigKEHBhcmVudF9iYWNrdXBfaWQYBSABKAlS'
    'DnBhcmVudEJhY2t1cElkEh8KC3RvdGFsX2ZpbGVzGAYgASgDUgp0b3RhbEZpbGVzEh8KC3RvdG'
    'FsX2J5dGVzGAcgASgDUgp0b3RhbEJ5dGVzEhkKCGlzX2JsaW5kGAggASgIUgdpc0JsaW5kEicK'
    'D21hbmlmZXN0X2RpZ2VzdBgJIAEoCVIObWFuaWZlc3REaWdlc3QSOQoFaXRlbXMYCiADKAsyIy'
    '5wZWVybGluay52MS5IaXN0b3JpY2FsVmVyc2lvblByb3RvUgVpdGVtcw==');

@$core.Deprecated('Use restorePlanProtoDescriptor instead')
const RestorePlanProto$json = {
  '1': 'RestorePlanProto',
  '2': [
    {'1': 'backup_id', '3': 1, '4': 1, '5': 9, '10': 'backupId'},
    {'1': 'target_directory', '3': 2, '4': 1, '5': 9, '10': 'targetDirectory'},
    {
      '1': 'conflict_policy',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.RestoreConflictPolicyProto',
      '10': 'conflictPolicy'
    },
    {'1': 'selected_paths', '3': 4, '4': 3, '5': 9, '10': 'selectedPaths'},
  ],
};

/// Descriptor for `RestorePlanProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restorePlanProtoDescriptor = $convert.base64Decode(
    'ChBSZXN0b3JlUGxhblByb3RvEhsKCWJhY2t1cF9pZBgBIAEoCVIIYmFja3VwSWQSKQoQdGFyZ2'
    'V0X2RpcmVjdG9yeRgCIAEoCVIPdGFyZ2V0RGlyZWN0b3J5ElAKD2NvbmZsaWN0X3BvbGljeRgD'
    'IAEoDjInLnBlZXJsaW5rLnYxLlJlc3RvcmVDb25mbGljdFBvbGljeVByb3RvUg5jb25mbGljdF'
    'BvbGljeRIlCg5zZWxlY3RlZF9wYXRocxgEIAMoCVINc2VsZWN0ZWRQYXRocw==');

@$core.Deprecated('Use restoreResultProtoDescriptor instead')
const RestoreResultProto$json = {
  '1': 'RestoreResultProto',
  '2': [
    {'1': 'restore_id', '3': 1, '4': 1, '5': 9, '10': 'restoreId'},
    {'1': 'backup_id', '3': 2, '4': 1, '5': 9, '10': 'backupId'},
    {'1': 'success', '3': 3, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'restored_files_count',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'restoredFilesCount'
    },
    {'1': 'restored_bytes', '3': 5, '4': 1, '5': 3, '10': 'restoredBytes'},
    {
      '1': 'created_versions_count',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'createdVersionsCount'
    },
    {'1': 'error_message', '3': 7, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `RestoreResultProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreResultProtoDescriptor = $convert.base64Decode(
    'ChJSZXN0b3JlUmVzdWx0UHJvdG8SHQoKcmVzdG9yZV9pZBgBIAEoCVIJcmVzdG9yZUlkEhsKCW'
    'JhY2t1cF9pZBgCIAEoCVIIYmFja3VwSWQSGAoHc3VjY2VzcxgDIAEoCFIHc3VjY2VzcxIwChRy'
    'ZXN0b3JlZF9maWxlc19jb3VudBgEIAEoA1IScmVzdG9yZWRGaWxlc0NvdW50EiUKDnJlc3Rvcm'
    'VkX2J5dGVzGAUgASgDUg1yZXN0b3JlZEJ5dGVzEjQKFmNyZWF0ZWRfdmVyc2lvbnNfY291bnQY'
    'BiABKANSFGNyZWF0ZWRWZXJzaW9uc0NvdW50EiMKDWVycm9yX21lc3NhZ2UYByABKAlSDGVycm'
    '9yTWVzc2FnZQ==');
