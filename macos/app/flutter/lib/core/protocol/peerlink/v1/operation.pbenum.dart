// This is a generated file - do not edit.
//
// Generated from peerlink/v1/operation.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class OperationState extends $pb.ProtobufEnum {
  static const OperationState OPERATION_STATE_UNSPECIFIED =
      OperationState._(0, _omitEnumNames ? '' : 'OPERATION_STATE_UNSPECIFIED');
  static const OperationState OPERATION_STATE_CREATED =
      OperationState._(1, _omitEnumNames ? '' : 'OPERATION_STATE_CREATED');
  static const OperationState OPERATION_STATE_VALIDATED =
      OperationState._(2, _omitEnumNames ? '' : 'OPERATION_STATE_VALIDATED');
  static const OperationState OPERATION_STATE_AUTHORIZED =
      OperationState._(3, _omitEnumNames ? '' : 'OPERATION_STATE_AUTHORIZED');
  static const OperationState OPERATION_STATE_EXECUTING =
      OperationState._(4, _omitEnumNames ? '' : 'OPERATION_STATE_EXECUTING');
  static const OperationState OPERATION_STATE_WAITING =
      OperationState._(5, _omitEnumNames ? '' : 'OPERATION_STATE_WAITING');
  static const OperationState OPERATION_STATE_COMMITTED =
      OperationState._(6, _omitEnumNames ? '' : 'OPERATION_STATE_COMMITTED');
  static const OperationState OPERATION_STATE_FAILED =
      OperationState._(7, _omitEnumNames ? '' : 'OPERATION_STATE_FAILED');
  static const OperationState OPERATION_STATE_CANCELLED =
      OperationState._(8, _omitEnumNames ? '' : 'OPERATION_STATE_CANCELLED');
  static const OperationState OPERATION_STATE_OUTCOME_UNKNOWN =
      OperationState._(
          9, _omitEnumNames ? '' : 'OPERATION_STATE_OUTCOME_UNKNOWN');
  static const OperationState OPERATION_STATE_RECOVERY_REQUIRED =
      OperationState._(
          10, _omitEnumNames ? '' : 'OPERATION_STATE_RECOVERY_REQUIRED');

  static const $core.List<OperationState> values = <OperationState>[
    OPERATION_STATE_UNSPECIFIED,
    OPERATION_STATE_CREATED,
    OPERATION_STATE_VALIDATED,
    OPERATION_STATE_AUTHORIZED,
    OPERATION_STATE_EXECUTING,
    OPERATION_STATE_WAITING,
    OPERATION_STATE_COMMITTED,
    OPERATION_STATE_FAILED,
    OPERATION_STATE_CANCELLED,
    OPERATION_STATE_OUTCOME_UNKNOWN,
    OPERATION_STATE_RECOVERY_REQUIRED,
  ];

  static final $core.List<OperationState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static OperationState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const OperationState._(super.value, super.name);
}

class OperationIntent extends $pb.ProtobufEnum {
  static const OperationIntent OPERATION_INTENT_UNSPECIFIED = OperationIntent._(
      0, _omitEnumNames ? '' : 'OPERATION_INTENT_UNSPECIFIED');
  static const OperationIntent OPERATION_INTENT_SEND =
      OperationIntent._(1, _omitEnumNames ? '' : 'OPERATION_INTENT_SEND');
  static const OperationIntent OPERATION_INTENT_ACCESS =
      OperationIntent._(2, _omitEnumNames ? '' : 'OPERATION_INTENT_ACCESS');
  static const OperationIntent OPERATION_INTENT_SYNC =
      OperationIntent._(3, _omitEnumNames ? '' : 'OPERATION_INTENT_SYNC');
  static const OperationIntent OPERATION_INTENT_BACKUP =
      OperationIntent._(4, _omitEnumNames ? '' : 'OPERATION_INTENT_BACKUP');
  static const OperationIntent OPERATION_INTENT_CONNECT =
      OperationIntent._(5, _omitEnumNames ? '' : 'OPERATION_INTENT_CONNECT');

  static const $core.List<OperationIntent> values = <OperationIntent>[
    OPERATION_INTENT_UNSPECIFIED,
    OPERATION_INTENT_SEND,
    OPERATION_INTENT_ACCESS,
    OPERATION_INTENT_SYNC,
    OPERATION_INTENT_BACKUP,
    OPERATION_INTENT_CONNECT,
  ];

  static final $core.List<OperationIntent?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static OperationIntent? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const OperationIntent._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
