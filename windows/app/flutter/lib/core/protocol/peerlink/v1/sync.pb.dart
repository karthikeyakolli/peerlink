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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'sync.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'sync.pbenum.dart';

class SyncObjectDescriptor extends $pb.GeneratedMessage {
  factory SyncObjectDescriptor({
    $core.String? objectId,
    $core.String? relativePath,
    $core.String? contentHash,
    $fixnum.Int64? sizeBytes,
    $fixnum.Int64? lastModifiedHintMs,
    $core.bool? isDirectory,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>? causalClock,
    $fixnum.Int64? contentVersionSeq,
    $fixnum.Int64? metadataVersionSeq,
    $core.bool? deleted,
  }) {
    final result = SyncObjectDescriptor._();
    if (objectId != null) result.objectId = objectId;
    if (relativePath != null) result.relativePath = relativePath;
    if (contentHash != null) result.contentHash = contentHash;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (lastModifiedHintMs != null)
      result.lastModifiedHintMs = lastModifiedHintMs;
    if (isDirectory != null) result.isDirectory = isDirectory;
    if (causalClock != null) result.causalClock.addEntries(causalClock);
    if (contentVersionSeq != null) result.contentVersionSeq = contentVersionSeq;
    if (metadataVersionSeq != null)
      result.metadataVersionSeq = metadataVersionSeq;
    if (deleted != null) result.deleted = deleted;
    return result;
  }

  SyncObjectDescriptor._();

  factory SyncObjectDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncObjectDescriptor()..mergeFromBuffer(data, registry);
  factory SyncObjectDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncObjectDescriptor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncObjectDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SyncObjectDescriptor.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..aOS(2, _omitFieldNames ? '' : 'relativePath')
    ..aOS(3, _omitFieldNames ? '' : 'contentHash')
    ..aInt64(4, _omitFieldNames ? '' : 'sizeBytes')
    ..aInt64(5, _omitFieldNames ? '' : 'lastModifiedHintMs')
    ..aOB(6, _omitFieldNames ? '' : 'isDirectory')
    ..m<$core.String, $fixnum.Int64>(7, _omitFieldNames ? '' : 'causalClock',
        entryClassName: 'SyncObjectDescriptor.CausalClockEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O6,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..aInt64(8, _omitFieldNames ? '' : 'contentVersionSeq')
    ..aInt64(9, _omitFieldNames ? '' : 'metadataVersionSeq')
    ..aOB(10, _omitFieldNames ? '' : 'deleted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncObjectDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncObjectDescriptor copyWith(void Function(SyncObjectDescriptor) updates) =>
      super.copyWith((message) => updates(message as SyncObjectDescriptor))
          as SyncObjectDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SyncObjectDescriptor() / SyncObjectDescriptor.new instead')
  static SyncObjectDescriptor create() => SyncObjectDescriptor._();
  static $pb.GeneratedMessage $_createMessage() => SyncObjectDescriptor._();
  @$core.override
  SyncObjectDescriptor createEmptyInstance() => SyncObjectDescriptor._();
  @$core.pragma('dart2js:noInline')
  static SyncObjectDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncObjectDescriptor>(
          SyncObjectDescriptor.$_createMessage);
  static SyncObjectDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get relativePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set relativePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelativePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelativePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get contentHash => $_getSZ(2);
  @$pb.TagNumber(3)
  set contentHash($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContentHash() => $_has(2);
  @$pb.TagNumber(3)
  void clearContentHash() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearSizeBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get lastModifiedHintMs => $_getI64(4);
  @$pb.TagNumber(5)
  set lastModifiedHintMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastModifiedHintMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastModifiedHintMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isDirectory => $_getBF(5);
  @$pb.TagNumber(6)
  set isDirectory($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsDirectory() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsDirectory() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, $fixnum.Int64> get causalClock => $_getMap(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get contentVersionSeq => $_getI64(7);
  @$pb.TagNumber(8)
  set contentVersionSeq($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasContentVersionSeq() => $_has(7);
  @$pb.TagNumber(8)
  void clearContentVersionSeq() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get metadataVersionSeq => $_getI64(8);
  @$pb.TagNumber(9)
  set metadataVersionSeq($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMetadataVersionSeq() => $_has(8);
  @$pb.TagNumber(9)
  void clearMetadataVersionSeq() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get deleted => $_getBF(9);
  @$pb.TagNumber(10)
  set deleted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDeleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearDeleted() => $_clearField(10);
}

class SyncTombstone extends $pb.GeneratedMessage {
  factory SyncTombstone({
    $core.String? objectId,
    $core.String? deletedAtRelativePath,
    $core.String? deletingPeerId,
    $fixnum.Int64? deletedAtUtcMs,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>?
        deletionCausalClock,
  }) {
    final result = SyncTombstone._();
    if (objectId != null) result.objectId = objectId;
    if (deletedAtRelativePath != null)
      result.deletedAtRelativePath = deletedAtRelativePath;
    if (deletingPeerId != null) result.deletingPeerId = deletingPeerId;
    if (deletedAtUtcMs != null) result.deletedAtUtcMs = deletedAtUtcMs;
    if (deletionCausalClock != null)
      result.deletionCausalClock.addEntries(deletionCausalClock);
    return result;
  }

  SyncTombstone._();

  factory SyncTombstone.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncTombstone()..mergeFromBuffer(data, registry);
  factory SyncTombstone.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncTombstone()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncTombstone',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SyncTombstone.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..aOS(2, _omitFieldNames ? '' : 'deletedAtRelativePath')
    ..aOS(3, _omitFieldNames ? '' : 'deletingPeerId')
    ..aInt64(4, _omitFieldNames ? '' : 'deletedAtUtcMs')
    ..m<$core.String, $fixnum.Int64>(
        5, _omitFieldNames ? '' : 'deletionCausalClock',
        entryClassName: 'SyncTombstone.DeletionCausalClockEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O6,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncTombstone clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncTombstone copyWith(void Function(SyncTombstone) updates) =>
      super.copyWith((message) => updates(message as SyncTombstone))
          as SyncTombstone;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SyncTombstone() / SyncTombstone.new instead')
  static SyncTombstone create() => SyncTombstone._();
  static $pb.GeneratedMessage $_createMessage() => SyncTombstone._();
  @$core.override
  SyncTombstone createEmptyInstance() => SyncTombstone._();
  @$core.pragma('dart2js:noInline')
  static SyncTombstone getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncTombstone>(
          SyncTombstone.$_createMessage);
  static SyncTombstone? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deletedAtRelativePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set deletedAtRelativePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeletedAtRelativePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeletedAtRelativePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get deletingPeerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set deletingPeerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDeletingPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeletingPeerId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get deletedAtUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set deletedAtUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeletedAtUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeletedAtUtcMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $fixnum.Int64> get deletionCausalClock => $_getMap(4);
}

class SyncManifestMessage extends $pb.GeneratedMessage {
  factory SyncManifestMessage({
    $core.String? peerId,
    $core.String? sessionId,
    $core.Iterable<SyncObjectDescriptor>? objects,
    $core.Iterable<SyncTombstone>? tombstones,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>?
        manifestCausalClock,
  }) {
    final result = SyncManifestMessage._();
    if (peerId != null) result.peerId = peerId;
    if (sessionId != null) result.sessionId = sessionId;
    if (objects != null) result.objects.addAll(objects);
    if (tombstones != null) result.tombstones.addAll(tombstones);
    if (manifestCausalClock != null)
      result.manifestCausalClock.addEntries(manifestCausalClock);
    return result;
  }

  SyncManifestMessage._();

  factory SyncManifestMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncManifestMessage()..mergeFromBuffer(data, registry);
  factory SyncManifestMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncManifestMessage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncManifestMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SyncManifestMessage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..pPM<SyncObjectDescriptor>(3, _omitFieldNames ? '' : 'objects',
        subBuilder: SyncObjectDescriptor.$_createMessage)
    ..pPM<SyncTombstone>(4, _omitFieldNames ? '' : 'tombstones',
        subBuilder: SyncTombstone.$_createMessage)
    ..m<$core.String, $fixnum.Int64>(
        5, _omitFieldNames ? '' : 'manifestCausalClock',
        entryClassName: 'SyncManifestMessage.ManifestCausalClockEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O6,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncManifestMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncManifestMessage copyWith(void Function(SyncManifestMessage) updates) =>
      super.copyWith((message) => updates(message as SyncManifestMessage))
          as SyncManifestMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SyncManifestMessage() / SyncManifestMessage.new instead')
  static SyncManifestMessage create() => SyncManifestMessage._();
  static $pb.GeneratedMessage $_createMessage() => SyncManifestMessage._();
  @$core.override
  SyncManifestMessage createEmptyInstance() => SyncManifestMessage._();
  @$core.pragma('dart2js:noInline')
  static SyncManifestMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncManifestMessage>(
          SyncManifestMessage.$_createMessage);
  static SyncManifestMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<SyncObjectDescriptor> get objects => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<SyncTombstone> get tombstones => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $fixnum.Int64> get manifestCausalClock => $_getMap(4);
}

class SyncConflictNotice extends $pb.GeneratedMessage {
  factory SyncConflictNotice({
    $core.String? sessionId,
    $core.String? objectId,
    SyncConflictType? conflictType,
    SyncObjectDescriptor? localVersion,
    SyncObjectDescriptor? remoteVersion,
  }) {
    final result = SyncConflictNotice._();
    if (sessionId != null) result.sessionId = sessionId;
    if (objectId != null) result.objectId = objectId;
    if (conflictType != null) result.conflictType = conflictType;
    if (localVersion != null) result.localVersion = localVersion;
    if (remoteVersion != null) result.remoteVersion = remoteVersion;
    return result;
  }

  SyncConflictNotice._();

  factory SyncConflictNotice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncConflictNotice()..mergeFromBuffer(data, registry);
  factory SyncConflictNotice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncConflictNotice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncConflictNotice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SyncConflictNotice.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'objectId')
    ..aE<SyncConflictType>(3, _omitFieldNames ? '' : 'conflictType',
        enumValues: SyncConflictType.values)
    ..aOM<SyncObjectDescriptor>(4, _omitFieldNames ? '' : 'localVersion',
        subBuilder: SyncObjectDescriptor.$_createMessage)
    ..aOM<SyncObjectDescriptor>(5, _omitFieldNames ? '' : 'remoteVersion',
        subBuilder: SyncObjectDescriptor.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncConflictNotice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncConflictNotice copyWith(void Function(SyncConflictNotice) updates) =>
      super.copyWith((message) => updates(message as SyncConflictNotice))
          as SyncConflictNotice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SyncConflictNotice() / SyncConflictNotice.new instead')
  static SyncConflictNotice create() => SyncConflictNotice._();
  static $pb.GeneratedMessage $_createMessage() => SyncConflictNotice._();
  @$core.override
  SyncConflictNotice createEmptyInstance() => SyncConflictNotice._();
  @$core.pragma('dart2js:noInline')
  static SyncConflictNotice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncConflictNotice>(
          SyncConflictNotice.$_createMessage);
  static SyncConflictNotice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get objectId => $_getSZ(1);
  @$pb.TagNumber(2)
  set objectId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasObjectId() => $_has(1);
  @$pb.TagNumber(2)
  void clearObjectId() => $_clearField(2);

  @$pb.TagNumber(3)
  SyncConflictType get conflictType => $_getN(2);
  @$pb.TagNumber(3)
  set conflictType(SyncConflictType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConflictType() => $_has(2);
  @$pb.TagNumber(3)
  void clearConflictType() => $_clearField(3);

  @$pb.TagNumber(4)
  SyncObjectDescriptor get localVersion => $_getN(3);
  @$pb.TagNumber(4)
  set localVersion(SyncObjectDescriptor value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLocalVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocalVersion() => $_clearField(4);
  @$pb.TagNumber(4)
  SyncObjectDescriptor ensureLocalVersion() => $_ensure(3);

  @$pb.TagNumber(5)
  SyncObjectDescriptor get remoteVersion => $_getN(4);
  @$pb.TagNumber(5)
  set remoteVersion(SyncObjectDescriptor value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRemoteVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemoteVersion() => $_clearField(5);
  @$pb.TagNumber(5)
  SyncObjectDescriptor ensureRemoteVersion() => $_ensure(4);
}

class SyncConflictResolutionDecision extends $pb.GeneratedMessage {
  factory SyncConflictResolutionDecision({
    $core.String? sessionId,
    $core.String? objectId,
    SyncConflictResolution? resolution,
  }) {
    final result = SyncConflictResolutionDecision._();
    if (sessionId != null) result.sessionId = sessionId;
    if (objectId != null) result.objectId = objectId;
    if (resolution != null) result.resolution = resolution;
    return result;
  }

  SyncConflictResolutionDecision._();

  factory SyncConflictResolutionDecision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncConflictResolutionDecision()..mergeFromBuffer(data, registry);
  factory SyncConflictResolutionDecision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncConflictResolutionDecision()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncConflictResolutionDecision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SyncConflictResolutionDecision.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'objectId')
    ..aE<SyncConflictResolution>(3, _omitFieldNames ? '' : 'resolution',
        enumValues: SyncConflictResolution.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncConflictResolutionDecision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncConflictResolutionDecision copyWith(
          void Function(SyncConflictResolutionDecision) updates) =>
      super.copyWith(
              (message) => updates(message as SyncConflictResolutionDecision))
          as SyncConflictResolutionDecision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SyncConflictResolutionDecision() / SyncConflictResolutionDecision.new instead')
  static SyncConflictResolutionDecision create() =>
      SyncConflictResolutionDecision._();
  static $pb.GeneratedMessage $_createMessage() =>
      SyncConflictResolutionDecision._();
  @$core.override
  SyncConflictResolutionDecision createEmptyInstance() =>
      SyncConflictResolutionDecision._();
  @$core.pragma('dart2js:noInline')
  static SyncConflictResolutionDecision getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncConflictResolutionDecision>(
          SyncConflictResolutionDecision.$_createMessage);
  static SyncConflictResolutionDecision? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get objectId => $_getSZ(1);
  @$pb.TagNumber(2)
  set objectId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasObjectId() => $_has(1);
  @$pb.TagNumber(2)
  void clearObjectId() => $_clearField(2);

  @$pb.TagNumber(3)
  SyncConflictResolution get resolution => $_getN(2);
  @$pb.TagNumber(3)
  set resolution(SyncConflictResolution value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasResolution() => $_has(2);
  @$pb.TagNumber(3)
  void clearResolution() => $_clearField(3);
}

class SyncMassChangeHold extends $pb.GeneratedMessage {
  factory SyncMassChangeHold({
    $core.String? sessionId,
    $core.Iterable<$core.String>? reasons,
    $fixnum.Int64? heldAtUtcMs,
  }) {
    final result = SyncMassChangeHold._();
    if (sessionId != null) result.sessionId = sessionId;
    if (reasons != null) result.reasons.addAll(reasons);
    if (heldAtUtcMs != null) result.heldAtUtcMs = heldAtUtcMs;
    return result;
  }

  SyncMassChangeHold._();

  factory SyncMassChangeHold.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncMassChangeHold()..mergeFromBuffer(data, registry);
  factory SyncMassChangeHold.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncMassChangeHold()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncMassChangeHold',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SyncMassChangeHold.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..pPS(2, _omitFieldNames ? '' : 'reasons')
    ..aInt64(3, _omitFieldNames ? '' : 'heldAtUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncMassChangeHold clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncMassChangeHold copyWith(void Function(SyncMassChangeHold) updates) =>
      super.copyWith((message) => updates(message as SyncMassChangeHold))
          as SyncMassChangeHold;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SyncMassChangeHold() / SyncMassChangeHold.new instead')
  static SyncMassChangeHold create() => SyncMassChangeHold._();
  static $pb.GeneratedMessage $_createMessage() => SyncMassChangeHold._();
  @$core.override
  SyncMassChangeHold createEmptyInstance() => SyncMassChangeHold._();
  @$core.pragma('dart2js:noInline')
  static SyncMassChangeHold getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncMassChangeHold>(
          SyncMassChangeHold.$_createMessage);
  static SyncMassChangeHold? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get reasons => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get heldAtUtcMs => $_getI64(2);
  @$pb.TagNumber(3)
  set heldAtUtcMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeldAtUtcMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeldAtUtcMs() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
