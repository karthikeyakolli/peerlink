// This is a generated file - do not edit.
//
// Generated from peerlink/v1/error.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ErrorCode extends $pb.ProtobufEnum {
  static const ErrorCode ERROR_CODE_UNSPECIFIED =
      ErrorCode._(0, _omitEnumNames ? '' : 'ERROR_CODE_UNSPECIFIED');
  static const ErrorCode ERROR_CODE_UNAUTHENTICATED =
      ErrorCode._(1, _omitEnumNames ? '' : 'ERROR_CODE_UNAUTHENTICATED');
  static const ErrorCode ERROR_CODE_UNAUTHORIZED =
      ErrorCode._(2, _omitEnumNames ? '' : 'ERROR_CODE_UNAUTHORIZED');
  static const ErrorCode ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION = ErrorCode._(
      3, _omitEnumNames ? '' : 'ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION');
  static const ErrorCode ERROR_CODE_UNSUPPORTED_CAPABILITY =
      ErrorCode._(4, _omitEnumNames ? '' : 'ERROR_CODE_UNSUPPORTED_CAPABILITY');
  static const ErrorCode ERROR_CODE_OBJECT_NOT_FOUND =
      ErrorCode._(5, _omitEnumNames ? '' : 'ERROR_CODE_OBJECT_NOT_FOUND');
  static const ErrorCode ERROR_CODE_CONFLICT_DETECTED =
      ErrorCode._(6, _omitEnumNames ? '' : 'ERROR_CODE_CONFLICT_DETECTED');
  static const ErrorCode ERROR_CODE_INTEGRITY_MISMATCH =
      ErrorCode._(7, _omitEnumNames ? '' : 'ERROR_CODE_INTEGRITY_MISMATCH');
  static const ErrorCode ERROR_CODE_MALWARE_DETECTED =
      ErrorCode._(8, _omitEnumNames ? '' : 'ERROR_CODE_MALWARE_DETECTED');
  static const ErrorCode ERROR_CODE_TRANSPORT_DISCONNECTED =
      ErrorCode._(9, _omitEnumNames ? '' : 'ERROR_CODE_TRANSPORT_DISCONNECTED');
  static const ErrorCode ERROR_CODE_RESOURCE_EXHAUSTED =
      ErrorCode._(10, _omitEnumNames ? '' : 'ERROR_CODE_RESOURCE_EXHAUSTED');
  static const ErrorCode ERROR_CODE_OPERATION_CANCELLED =
      ErrorCode._(11, _omitEnumNames ? '' : 'ERROR_CODE_OPERATION_CANCELLED');
  static const ErrorCode ERROR_CODE_INTERNAL_ERROR =
      ErrorCode._(12, _omitEnumNames ? '' : 'ERROR_CODE_INTERNAL_ERROR');

  static const $core.List<ErrorCode> values = <ErrorCode>[
    ERROR_CODE_UNSPECIFIED,
    ERROR_CODE_UNAUTHENTICATED,
    ERROR_CODE_UNAUTHORIZED,
    ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION,
    ERROR_CODE_UNSUPPORTED_CAPABILITY,
    ERROR_CODE_OBJECT_NOT_FOUND,
    ERROR_CODE_CONFLICT_DETECTED,
    ERROR_CODE_INTEGRITY_MISMATCH,
    ERROR_CODE_MALWARE_DETECTED,
    ERROR_CODE_TRANSPORT_DISCONNECTED,
    ERROR_CODE_RESOURCE_EXHAUSTED,
    ERROR_CODE_OPERATION_CANCELLED,
    ERROR_CODE_INTERNAL_ERROR,
  ];

  static final $core.List<ErrorCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static ErrorCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ErrorCode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
