// This is a generated file - do not edit.
//
// Generated from peerlink/v1/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Sync mode determining directionality
class SyncModeProto extends $pb.ProtobufEnum {
  static const SyncModeProto SYNC_MODE_UNSPECIFIED =
      SyncModeProto._(0, _omitEnumNames ? '' : 'SYNC_MODE_UNSPECIFIED');
  static const SyncModeProto SYNC_MODE_BIDIRECTIONAL =
      SyncModeProto._(1, _omitEnumNames ? '' : 'SYNC_MODE_BIDIRECTIONAL');
  static const SyncModeProto SYNC_MODE_ONE_WAY_REPLICATION =
      SyncModeProto._(2, _omitEnumNames ? '' : 'SYNC_MODE_ONE_WAY_REPLICATION');
  static const SyncModeProto SYNC_MODE_RECEIVE_ONLY_IMPORT =
      SyncModeProto._(3, _omitEnumNames ? '' : 'SYNC_MODE_RECEIVE_ONLY_IMPORT');
  static const SyncModeProto SYNC_MODE_EXACT_MIRROR =
      SyncModeProto._(4, _omitEnumNames ? '' : 'SYNC_MODE_EXACT_MIRROR');

  static const $core.List<SyncModeProto> values = <SyncModeProto>[
    SYNC_MODE_UNSPECIFIED,
    SYNC_MODE_BIDIRECTIONAL,
    SYNC_MODE_ONE_WAY_REPLICATION,
    SYNC_MODE_RECEIVE_ONLY_IMPORT,
    SYNC_MODE_EXACT_MIRROR,
  ];

  static final $core.List<SyncModeProto?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SyncModeProto? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SyncModeProto._(super.value, super.name);
}

class SyncConflictType extends $pb.ProtobufEnum {
  static const SyncConflictType SYNC_CONFLICT_UNSPECIFIED =
      SyncConflictType._(0, _omitEnumNames ? '' : 'SYNC_CONFLICT_UNSPECIFIED');
  static const SyncConflictType SYNC_CONFLICT_CONCURRENT_CONTENT_EDIT =
      SyncConflictType._(
          1, _omitEnumNames ? '' : 'SYNC_CONFLICT_CONCURRENT_CONTENT_EDIT');
  static const SyncConflictType SYNC_CONFLICT_DELETE_VS_MODIFY =
      SyncConflictType._(
          2, _omitEnumNames ? '' : 'SYNC_CONFLICT_DELETE_VS_MODIFY');
  static const SyncConflictType SYNC_CONFLICT_CONCURRENT_RENAME =
      SyncConflictType._(
          3, _omitEnumNames ? '' : 'SYNC_CONFLICT_CONCURRENT_RENAME');
  static const SyncConflictType SYNC_CONFLICT_CONCURRENT_MOVE =
      SyncConflictType._(
          4, _omitEnumNames ? '' : 'SYNC_CONFLICT_CONCURRENT_MOVE');
  static const SyncConflictType SYNC_CONFLICT_BOTH_CREATED_SAME_PATH =
      SyncConflictType._(
          5, _omitEnumNames ? '' : 'SYNC_CONFLICT_BOTH_CREATED_SAME_PATH');
  static const SyncConflictType SYNC_CONFLICT_TOMBSTONE_VS_NEW_OBJECT =
      SyncConflictType._(
          6, _omitEnumNames ? '' : 'SYNC_CONFLICT_TOMBSTONE_VS_NEW_OBJECT');

  static const $core.List<SyncConflictType> values = <SyncConflictType>[
    SYNC_CONFLICT_UNSPECIFIED,
    SYNC_CONFLICT_CONCURRENT_CONTENT_EDIT,
    SYNC_CONFLICT_DELETE_VS_MODIFY,
    SYNC_CONFLICT_CONCURRENT_RENAME,
    SYNC_CONFLICT_CONCURRENT_MOVE,
    SYNC_CONFLICT_BOTH_CREATED_SAME_PATH,
    SYNC_CONFLICT_TOMBSTONE_VS_NEW_OBJECT,
  ];

  static final $core.List<SyncConflictType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static SyncConflictType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SyncConflictType._(super.value, super.name);
}

class SyncConflictResolution extends $pb.ProtobufEnum {
  static const SyncConflictResolution SYNC_RESOLUTION_DEFERRED =
      SyncConflictResolution._(
          0, _omitEnumNames ? '' : 'SYNC_RESOLUTION_DEFERRED');
  static const SyncConflictResolution SYNC_RESOLUTION_KEEP_LOCAL =
      SyncConflictResolution._(
          1, _omitEnumNames ? '' : 'SYNC_RESOLUTION_KEEP_LOCAL');
  static const SyncConflictResolution SYNC_RESOLUTION_KEEP_REMOTE =
      SyncConflictResolution._(
          2, _omitEnumNames ? '' : 'SYNC_RESOLUTION_KEEP_REMOTE');
  static const SyncConflictResolution SYNC_RESOLUTION_KEEP_BOTH =
      SyncConflictResolution._(
          3, _omitEnumNames ? '' : 'SYNC_RESOLUTION_KEEP_BOTH');
  static const SyncConflictResolution SYNC_RESOLUTION_MERGE =
      SyncConflictResolution._(
          4, _omitEnumNames ? '' : 'SYNC_RESOLUTION_MERGE');

  static const $core.List<SyncConflictResolution> values =
      <SyncConflictResolution>[
    SYNC_RESOLUTION_DEFERRED,
    SYNC_RESOLUTION_KEEP_LOCAL,
    SYNC_RESOLUTION_KEEP_REMOTE,
    SYNC_RESOLUTION_KEEP_BOTH,
    SYNC_RESOLUTION_MERGE,
  ];

  static final $core.List<SyncConflictResolution?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SyncConflictResolution? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SyncConflictResolution._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
