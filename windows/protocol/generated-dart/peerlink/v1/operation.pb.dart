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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $0;
import 'error.pb.dart' as $2;
import 'object_reference.pb.dart' as $1;
import 'operation.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'operation.pbenum.dart';

/// Durable, idempotent operation contract.
class OperationRecord extends $pb.GeneratedMessage {
  factory OperationRecord({
    $0.OperationId? operationId,
    OperationIntent? intent,
    $0.PeerId? actorPeerId,
    $core.Iterable<$1.ObjectReference>? targetObjects,
    OperationState? state,
    $core.String? idempotencyKey,
    $0.CausalClock? causalClock,
    $fixnum.Int64? createdAtUtcMs,
    $fixnum.Int64? updatedAtUtcMs,
    $2.ErrorDetail? error,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? parameters,
  }) {
    final result = OperationRecord._();
    if (operationId != null) result.operationId = operationId;
    if (intent != null) result.intent = intent;
    if (actorPeerId != null) result.actorPeerId = actorPeerId;
    if (targetObjects != null) result.targetObjects.addAll(targetObjects);
    if (state != null) result.state = state;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (causalClock != null) result.causalClock = causalClock;
    if (createdAtUtcMs != null) result.createdAtUtcMs = createdAtUtcMs;
    if (updatedAtUtcMs != null) result.updatedAtUtcMs = updatedAtUtcMs;
    if (error != null) result.error = error;
    if (parameters != null) result.parameters.addEntries(parameters);
    return result;
  }

  OperationRecord._();

  factory OperationRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationRecord()..mergeFromBuffer(data, registry);
  factory OperationRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationRecord()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: OperationRecord.$_createMessage)
    ..aOM<$0.OperationId>(1, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..aE<OperationIntent>(2, _omitFieldNames ? '' : 'intent',
        enumValues: OperationIntent.values)
    ..aOM<$0.PeerId>(3, _omitFieldNames ? '' : 'actorPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..pPM<$1.ObjectReference>(4, _omitFieldNames ? '' : 'targetObjects',
        subBuilder: $1.ObjectReference.$_createMessage)
    ..aE<OperationState>(5, _omitFieldNames ? '' : 'state',
        enumValues: OperationState.values)
    ..aOS(6, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOM<$0.CausalClock>(7, _omitFieldNames ? '' : 'causalClock',
        subBuilder: $0.CausalClock.$_createMessage)
    ..aInt64(8, _omitFieldNames ? '' : 'createdAtUtcMs')
    ..aInt64(9, _omitFieldNames ? '' : 'updatedAtUtcMs')
    ..aOM<$2.ErrorDetail>(10, _omitFieldNames ? '' : 'error',
        subBuilder: $2.ErrorDetail.$_createMessage)
    ..m<$core.String, $core.String>(11, _omitFieldNames ? '' : 'parameters',
        entryClassName: 'OperationRecord.ParametersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationRecord copyWith(void Function(OperationRecord) updates) =>
      super.copyWith((message) => updates(message as OperationRecord))
          as OperationRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OperationRecord() / OperationRecord.new instead')
  static OperationRecord create() => OperationRecord._();
  static $pb.GeneratedMessage $_createMessage() => OperationRecord._();
  @$core.override
  OperationRecord createEmptyInstance() => OperationRecord._();
  @$core.pragma('dart2js:noInline')
  static OperationRecord getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationRecord>(
          OperationRecord.$_createMessage);
  static OperationRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $0.OperationId get operationId => $_getN(0);
  @$pb.TagNumber(1)
  set operationId($0.OperationId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOperationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOperationId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.OperationId ensureOperationId() => $_ensure(0);

  @$pb.TagNumber(2)
  OperationIntent get intent => $_getN(1);
  @$pb.TagNumber(2)
  set intent(OperationIntent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasIntent() => $_has(1);
  @$pb.TagNumber(2)
  void clearIntent() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.PeerId get actorPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set actorPeerId($0.PeerId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasActorPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearActorPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PeerId ensureActorPeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<$1.ObjectReference> get targetObjects => $_getList(3);

  @$pb.TagNumber(5)
  OperationState get state => $_getN(4);
  @$pb.TagNumber(5)
  set state(OperationState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasState() => $_has(4);
  @$pb.TagNumber(5)
  void clearState() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get idempotencyKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set idempotencyKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIdempotencyKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdempotencyKey() => $_clearField(6);

  @$pb.TagNumber(7)
  $0.CausalClock get causalClock => $_getN(6);
  @$pb.TagNumber(7)
  set causalClock($0.CausalClock value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCausalClock() => $_has(6);
  @$pb.TagNumber(7)
  void clearCausalClock() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.CausalClock ensureCausalClock() => $_ensure(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdAtUtcMs => $_getI64(7);
  @$pb.TagNumber(8)
  set createdAtUtcMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAtUtcMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAtUtcMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get updatedAtUtcMs => $_getI64(8);
  @$pb.TagNumber(9)
  set updatedAtUtcMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdatedAtUtcMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdatedAtUtcMs() => $_clearField(9);

  @$pb.TagNumber(10)
  $2.ErrorDetail get error => $_getN(9);
  @$pb.TagNumber(10)
  set error($2.ErrorDetail value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasError() => $_has(9);
  @$pb.TagNumber(10)
  void clearError() => $_clearField(10);
  @$pb.TagNumber(10)
  $2.ErrorDetail ensureError() => $_ensure(9);

  @$pb.TagNumber(11)
  $pb.PbMap<$core.String, $core.String> get parameters => $_getMap(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
