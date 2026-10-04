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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'error.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'error.pbenum.dart';

/// Deterministic error model: machine-readable and human-explainable.
class ErrorDetail extends $pb.GeneratedMessage {
  factory ErrorDetail({
    ErrorCode? code,
    $core.String? errorName,
    $core.String? humanSummary,
    $core.String? humanExplanation,
    $core.String? suggestedRecoveryAction,
    $core.bool? isRetryable,
    $core.String? traceId,
    $fixnum.Int64? timestampUtcMs,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? errorContext,
  }) {
    final result = ErrorDetail._();
    if (code != null) result.code = code;
    if (errorName != null) result.errorName = errorName;
    if (humanSummary != null) result.humanSummary = humanSummary;
    if (humanExplanation != null) result.humanExplanation = humanExplanation;
    if (suggestedRecoveryAction != null)
      result.suggestedRecoveryAction = suggestedRecoveryAction;
    if (isRetryable != null) result.isRetryable = isRetryable;
    if (traceId != null) result.traceId = traceId;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (errorContext != null) result.errorContext.addEntries(errorContext);
    return result;
  }

  ErrorDetail._();

  factory ErrorDetail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ErrorDetail()..mergeFromBuffer(data, registry);
  factory ErrorDetail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ErrorDetail()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ErrorDetail',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ErrorDetail.$_createMessage)
    ..aE<ErrorCode>(1, _omitFieldNames ? '' : 'code',
        enumValues: ErrorCode.values)
    ..aOS(2, _omitFieldNames ? '' : 'errorName')
    ..aOS(3, _omitFieldNames ? '' : 'humanSummary')
    ..aOS(4, _omitFieldNames ? '' : 'humanExplanation')
    ..aOS(5, _omitFieldNames ? '' : 'suggestedRecoveryAction')
    ..aOB(6, _omitFieldNames ? '' : 'isRetryable')
    ..aOS(7, _omitFieldNames ? '' : 'traceId')
    ..aInt64(8, _omitFieldNames ? '' : 'timestampUtcMs')
    ..m<$core.String, $core.String>(9, _omitFieldNames ? '' : 'errorContext',
        entryClassName: 'ErrorDetail.ErrorContextEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorDetail copyWith(void Function(ErrorDetail) updates) =>
      super.copyWith((message) => updates(message as ErrorDetail))
          as ErrorDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ErrorDetail() / ErrorDetail.new instead')
  static ErrorDetail create() => ErrorDetail._();
  static $pb.GeneratedMessage $_createMessage() => ErrorDetail._();
  @$core.override
  ErrorDetail createEmptyInstance() => ErrorDetail._();
  @$core.pragma('dart2js:noInline')
  static ErrorDetail getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ErrorDetail>(
          ErrorDetail.$_createMessage);
  static ErrorDetail? _defaultInstance;

  @$pb.TagNumber(1)
  ErrorCode get code => $_getN(0);
  @$pb.TagNumber(1)
  set code(ErrorCode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errorName => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrorName() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get humanSummary => $_getSZ(2);
  @$pb.TagNumber(3)
  set humanSummary($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHumanSummary() => $_has(2);
  @$pb.TagNumber(3)
  void clearHumanSummary() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get humanExplanation => $_getSZ(3);
  @$pb.TagNumber(4)
  set humanExplanation($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHumanExplanation() => $_has(3);
  @$pb.TagNumber(4)
  void clearHumanExplanation() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get suggestedRecoveryAction => $_getSZ(4);
  @$pb.TagNumber(5)
  set suggestedRecoveryAction($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSuggestedRecoveryAction() => $_has(4);
  @$pb.TagNumber(5)
  void clearSuggestedRecoveryAction() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isRetryable => $_getBF(5);
  @$pb.TagNumber(6)
  set isRetryable($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsRetryable() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsRetryable() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get traceId => $_getSZ(6);
  @$pb.TagNumber(7)
  set traceId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTraceId() => $_has(6);
  @$pb.TagNumber(7)
  void clearTraceId() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get timestampUtcMs => $_getI64(7);
  @$pb.TagNumber(8)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTimestampUtcMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearTimestampUtcMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbMap<$core.String, $core.String> get errorContext => $_getMap(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
