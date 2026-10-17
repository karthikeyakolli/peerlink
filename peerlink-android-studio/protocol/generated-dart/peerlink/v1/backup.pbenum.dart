// This is a generated file - do not edit.
//
// Generated from peerlink/v1/backup.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class BackupTypeProto extends $pb.ProtobufEnum {
  static const BackupTypeProto BACKUP_TYPE_UNSPECIFIED =
      BackupTypeProto._(0, _omitEnumNames ? '' : 'BACKUP_TYPE_UNSPECIFIED');
  static const BackupTypeProto BACKUP_TYPE_FULL =
      BackupTypeProto._(1, _omitEnumNames ? '' : 'BACKUP_TYPE_FULL');
  static const BackupTypeProto BACKUP_TYPE_INCREMENTAL =
      BackupTypeProto._(2, _omitEnumNames ? '' : 'BACKUP_TYPE_INCREMENTAL');
  static const BackupTypeProto BACKUP_TYPE_DIFFERENTIAL =
      BackupTypeProto._(3, _omitEnumNames ? '' : 'BACKUP_TYPE_DIFFERENTIAL');

  static const $core.List<BackupTypeProto> values = <BackupTypeProto>[
    BACKUP_TYPE_UNSPECIFIED,
    BACKUP_TYPE_FULL,
    BACKUP_TYPE_INCREMENTAL,
    BACKUP_TYPE_DIFFERENTIAL,
  ];

  static final $core.List<BackupTypeProto?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static BackupTypeProto? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BackupTypeProto._(super.value, super.name);
}

class BackupStatusProto extends $pb.ProtobufEnum {
  static const BackupStatusProto BACKUP_STATUS_UNSPECIFIED =
      BackupStatusProto._(0, _omitEnumNames ? '' : 'BACKUP_STATUS_UNSPECIFIED');
  static const BackupStatusProto BACKUP_STATUS_PENDING =
      BackupStatusProto._(1, _omitEnumNames ? '' : 'BACKUP_STATUS_PENDING');
  static const BackupStatusProto BACKUP_STATUS_IN_PROGRESS =
      BackupStatusProto._(2, _omitEnumNames ? '' : 'BACKUP_STATUS_IN_PROGRESS');
  static const BackupStatusProto BACKUP_STATUS_COMPLETED =
      BackupStatusProto._(3, _omitEnumNames ? '' : 'BACKUP_STATUS_COMPLETED');
  static const BackupStatusProto BACKUP_STATUS_FAILED =
      BackupStatusProto._(4, _omitEnumNames ? '' : 'BACKUP_STATUS_FAILED');
  static const BackupStatusProto BACKUP_STATUS_CANCELLED =
      BackupStatusProto._(5, _omitEnumNames ? '' : 'BACKUP_STATUS_CANCELLED');
  static const BackupStatusProto BACKUP_STATUS_VERIFYING =
      BackupStatusProto._(6, _omitEnumNames ? '' : 'BACKUP_STATUS_VERIFYING');

  static const $core.List<BackupStatusProto> values = <BackupStatusProto>[
    BACKUP_STATUS_UNSPECIFIED,
    BACKUP_STATUS_PENDING,
    BACKUP_STATUS_IN_PROGRESS,
    BACKUP_STATUS_COMPLETED,
    BACKUP_STATUS_FAILED,
    BACKUP_STATUS_CANCELLED,
    BACKUP_STATUS_VERIFYING,
  ];

  static final $core.List<BackupStatusProto?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static BackupStatusProto? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BackupStatusProto._(super.value, super.name);
}

class RestoreConflictPolicyProto extends $pb.ProtobufEnum {
  static const RestoreConflictPolicyProto RESTORE_CONFLICT_POLICY_UNSPECIFIED =
      RestoreConflictPolicyProto._(
          0, _omitEnumNames ? '' : 'RESTORE_CONFLICT_POLICY_UNSPECIFIED');
  static const RestoreConflictPolicyProto
      RESTORE_CONFLICT_OVERWRITE_WITH_NEW_VERSION =
      RestoreConflictPolicyProto._(1,
          _omitEnumNames ? '' : 'RESTORE_CONFLICT_OVERWRITE_WITH_NEW_VERSION');
  static const RestoreConflictPolicyProto RESTORE_CONFLICT_FAIL_ON_CONFLICT =
      RestoreConflictPolicyProto._(
          2, _omitEnumNames ? '' : 'RESTORE_CONFLICT_FAIL_ON_CONFLICT');
  static const RestoreConflictPolicyProto RESTORE_CONFLICT_ALTERNATIVE_PATH =
      RestoreConflictPolicyProto._(
          3, _omitEnumNames ? '' : 'RESTORE_CONFLICT_ALTERNATIVE_PATH');

  static const $core.List<RestoreConflictPolicyProto> values =
      <RestoreConflictPolicyProto>[
    RESTORE_CONFLICT_POLICY_UNSPECIFIED,
    RESTORE_CONFLICT_OVERWRITE_WITH_NEW_VERSION,
    RESTORE_CONFLICT_FAIL_ON_CONFLICT,
    RESTORE_CONFLICT_ALTERNATIVE_PATH,
  ];

  static final $core.List<RestoreConflictPolicyProto?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static RestoreConflictPolicyProto? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RestoreConflictPolicyProto._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
