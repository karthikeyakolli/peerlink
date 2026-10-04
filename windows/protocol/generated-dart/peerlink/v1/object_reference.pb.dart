// This is a generated file - do not edit.
//
// Generated from peerlink/v1/object_reference.proto.

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
import 'object_reference.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'object_reference.pbenum.dart';

/// Logical object reference across the distributed system.
/// Invariants enforced:
/// 1. Never encode OS-specific filesystem paths as object identity (ObjectId is independent).
/// 2. Object ID and ContentHash are strictly separated.
/// 3. Timestamps are NOT conflict authority (CausalClock provides deterministic precedence).
class ObjectReference extends $pb.GeneratedMessage {
  factory ObjectReference({
    $0.ObjectId? objectId,
    $0.ContentHash? contentHash,
    $0.VersionId? versionId,
    ObjectType? objectType,
    $fixnum.Int64? byteSize,
    $core.String? mimeType,
    $core.String? logicalName,
    $0.CausalClock? causalClock,
    $fixnum.Int64? clientModifiedHintUtcMs,
    $core.bool? isTombstone,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
  }) {
    final result = ObjectReference._();
    if (objectId != null) result.objectId = objectId;
    if (contentHash != null) result.contentHash = contentHash;
    if (versionId != null) result.versionId = versionId;
    if (objectType != null) result.objectType = objectType;
    if (byteSize != null) result.byteSize = byteSize;
    if (mimeType != null) result.mimeType = mimeType;
    if (logicalName != null) result.logicalName = logicalName;
    if (causalClock != null) result.causalClock = causalClock;
    if (clientModifiedHintUtcMs != null)
      result.clientModifiedHintUtcMs = clientModifiedHintUtcMs;
    if (isTombstone != null) result.isTombstone = isTombstone;
    if (metadata != null) result.metadata.addEntries(metadata);
    return result;
  }

  ObjectReference._();

  factory ObjectReference.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObjectReference()..mergeFromBuffer(data, registry);
  factory ObjectReference.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObjectReference()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ObjectReference',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ObjectReference.$_createMessage)
    ..aOM<$0.ObjectId>(1, _omitFieldNames ? '' : 'objectId',
        subBuilder: $0.ObjectId.$_createMessage)
    ..aOM<$0.ContentHash>(2, _omitFieldNames ? '' : 'contentHash',
        subBuilder: $0.ContentHash.$_createMessage)
    ..aOM<$0.VersionId>(3, _omitFieldNames ? '' : 'versionId',
        subBuilder: $0.VersionId.$_createMessage)
    ..aE<ObjectType>(4, _omitFieldNames ? '' : 'objectType',
        enumValues: ObjectType.values)
    ..aInt64(5, _omitFieldNames ? '' : 'byteSize')
    ..aOS(6, _omitFieldNames ? '' : 'mimeType')
    ..aOS(7, _omitFieldNames ? '' : 'logicalName')
    ..aOM<$0.CausalClock>(8, _omitFieldNames ? '' : 'causalClock',
        subBuilder: $0.CausalClock.$_createMessage)
    ..aInt64(9, _omitFieldNames ? '' : 'clientModifiedHintUtcMs')
    ..aOB(10, _omitFieldNames ? '' : 'isTombstone')
    ..m<$core.String, $core.String>(11, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'ObjectReference.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObjectReference clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObjectReference copyWith(void Function(ObjectReference) updates) =>
      super.copyWith((message) => updates(message as ObjectReference))
          as ObjectReference;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ObjectReference() / ObjectReference.new instead')
  static ObjectReference create() => ObjectReference._();
  static $pb.GeneratedMessage $_createMessage() => ObjectReference._();
  @$core.override
  ObjectReference createEmptyInstance() => ObjectReference._();
  @$core.pragma('dart2js:noInline')
  static ObjectReference getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ObjectReference>(
          ObjectReference.$_createMessage);
  static ObjectReference? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ObjectId get objectId => $_getN(0);
  @$pb.TagNumber(1)
  set objectId($0.ObjectId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ObjectId ensureObjectId() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.ContentHash get contentHash => $_getN(1);
  @$pb.TagNumber(2)
  set contentHash($0.ContentHash value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasContentHash() => $_has(1);
  @$pb.TagNumber(2)
  void clearContentHash() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.ContentHash ensureContentHash() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.VersionId get versionId => $_getN(2);
  @$pb.TagNumber(3)
  set versionId($0.VersionId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasVersionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersionId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.VersionId ensureVersionId() => $_ensure(2);

  @$pb.TagNumber(4)
  ObjectType get objectType => $_getN(3);
  @$pb.TagNumber(4)
  set objectType(ObjectType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasObjectType() => $_has(3);
  @$pb.TagNumber(4)
  void clearObjectType() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get byteSize => $_getI64(4);
  @$pb.TagNumber(5)
  set byteSize($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasByteSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearByteSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get mimeType => $_getSZ(5);
  @$pb.TagNumber(6)
  set mimeType($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMimeType() => $_has(5);
  @$pb.TagNumber(6)
  void clearMimeType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get logicalName => $_getSZ(6);
  @$pb.TagNumber(7)
  set logicalName($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLogicalName() => $_has(6);
  @$pb.TagNumber(7)
  void clearLogicalName() => $_clearField(7);

  @$pb.TagNumber(8)
  $0.CausalClock get causalClock => $_getN(7);
  @$pb.TagNumber(8)
  set causalClock($0.CausalClock value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCausalClock() => $_has(7);
  @$pb.TagNumber(8)
  void clearCausalClock() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.CausalClock ensureCausalClock() => $_ensure(7);

  @$pb.TagNumber(9)
  $fixnum.Int64 get clientModifiedHintUtcMs => $_getI64(8);
  @$pb.TagNumber(9)
  set clientModifiedHintUtcMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasClientModifiedHintUtcMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearClientModifiedHintUtcMs() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isTombstone => $_getBF(9);
  @$pb.TagNumber(10)
  set isTombstone($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsTombstone() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsTombstone() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
