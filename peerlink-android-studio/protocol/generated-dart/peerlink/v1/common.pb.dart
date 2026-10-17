// This is a generated file - do not edit.
//
// Generated from peerlink/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'common.pbenum.dart';

/// Semantic protocol versioning
class ProtocolVersion extends $pb.GeneratedMessage {
  factory ProtocolVersion({
    $core.int? major,
    $core.int? minor,
    $core.int? patch,
    $core.String? preRelease,
  }) {
    final result = ProtocolVersion._();
    if (major != null) result.major = major;
    if (minor != null) result.minor = minor;
    if (patch != null) result.patch = patch;
    if (preRelease != null) result.preRelease = preRelease;
    return result;
  }

  ProtocolVersion._();

  factory ProtocolVersion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProtocolVersion()..mergeFromBuffer(data, registry);
  factory ProtocolVersion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProtocolVersion()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolVersion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ProtocolVersion.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'major', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'minor', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'patch', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'preRelease')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolVersion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolVersion copyWith(void Function(ProtocolVersion) updates) =>
      super.copyWith((message) => updates(message as ProtocolVersion))
          as ProtocolVersion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProtocolVersion() / ProtocolVersion.new instead')
  static ProtocolVersion create() => ProtocolVersion._();
  static $pb.GeneratedMessage $_createMessage() => ProtocolVersion._();
  @$core.override
  ProtocolVersion createEmptyInstance() => ProtocolVersion._();
  @$core.pragma('dart2js:noInline')
  static ProtocolVersion getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtocolVersion>(
          ProtocolVersion.$_createMessage);
  static ProtocolVersion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get major => $_getIZ(0);
  @$pb.TagNumber(1)
  set major($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMajor() => $_has(0);
  @$pb.TagNumber(1)
  void clearMajor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get minor => $_getIZ(1);
  @$pb.TagNumber(2)
  set minor($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMinor() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get patch => $_getIZ(2);
  @$pb.TagNumber(3)
  set patch($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPatch() => $_has(2);
  @$pb.TagNumber(3)
  void clearPatch() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get preRelease => $_getSZ(3);
  @$pb.TagNumber(4)
  set preRelease($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPreRelease() => $_has(3);
  @$pb.TagNumber(4)
  void clearPreRelease() => $_clearField(4);
}

/// Universal protocol header for inter-node control and data messages
class ProtocolHeader extends $pb.GeneratedMessage {
  factory ProtocolHeader({
    ProtocolVersion? version,
    ProtocolVersion? minSupportedVersion,
    $core.String? traceId,
    $fixnum.Int64? timestampUtcMs,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? featureFlags,
  }) {
    final result = ProtocolHeader._();
    if (version != null) result.version = version;
    if (minSupportedVersion != null)
      result.minSupportedVersion = minSupportedVersion;
    if (traceId != null) result.traceId = traceId;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (featureFlags != null) result.featureFlags.addEntries(featureFlags);
    return result;
  }

  ProtocolHeader._();

  factory ProtocolHeader.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProtocolHeader()..mergeFromBuffer(data, registry);
  factory ProtocolHeader.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProtocolHeader()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolHeader',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ProtocolHeader.$_createMessage)
    ..aOM<ProtocolVersion>(1, _omitFieldNames ? '' : 'version',
        subBuilder: ProtocolVersion.$_createMessage)
    ..aOM<ProtocolVersion>(2, _omitFieldNames ? '' : 'minSupportedVersion',
        subBuilder: ProtocolVersion.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'traceId')
    ..aInt64(4, _omitFieldNames ? '' : 'timestampUtcMs')
    ..m<$core.String, $core.String>(5, _omitFieldNames ? '' : 'featureFlags',
        entryClassName: 'ProtocolHeader.FeatureFlagsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolHeader clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolHeader copyWith(void Function(ProtocolHeader) updates) =>
      super.copyWith((message) => updates(message as ProtocolHeader))
          as ProtocolHeader;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProtocolHeader() / ProtocolHeader.new instead')
  static ProtocolHeader create() => ProtocolHeader._();
  static $pb.GeneratedMessage $_createMessage() => ProtocolHeader._();
  @$core.override
  ProtocolHeader createEmptyInstance() => ProtocolHeader._();
  @$core.pragma('dart2js:noInline')
  static ProtocolHeader getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProtocolHeader>(
          ProtocolHeader.$_createMessage);
  static ProtocolHeader? _defaultInstance;

  @$pb.TagNumber(1)
  ProtocolVersion get version => $_getN(0);
  @$pb.TagNumber(1)
  set version(ProtocolVersion value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);
  @$pb.TagNumber(1)
  ProtocolVersion ensureVersion() => $_ensure(0);

  @$pb.TagNumber(2)
  ProtocolVersion get minSupportedVersion => $_getN(1);
  @$pb.TagNumber(2)
  set minSupportedVersion(ProtocolVersion value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMinSupportedVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinSupportedVersion() => $_clearField(2);
  @$pb.TagNumber(2)
  ProtocolVersion ensureMinSupportedVersion() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get traceId => $_getSZ(2);
  @$pb.TagNumber(3)
  set traceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTraceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTraceId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get timestampUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimestampUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimestampUtcMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $core.String> get featureFlags => $_getMap(4);
}

/// Causal vector clock for deterministic conflict resolution.
/// Invariant: Timestamps are metadata/hints only, NEVER conflict authority.
class CausalClock extends $pb.GeneratedMessage {
  factory CausalClock({
    $fixnum.Int64? logicalCounter,
    $core.String? actorPeerId,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>? peerVectors,
  }) {
    final result = CausalClock._();
    if (logicalCounter != null) result.logicalCounter = logicalCounter;
    if (actorPeerId != null) result.actorPeerId = actorPeerId;
    if (peerVectors != null) result.peerVectors.addEntries(peerVectors);
    return result;
  }

  CausalClock._();

  factory CausalClock.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CausalClock()..mergeFromBuffer(data, registry);
  factory CausalClock.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CausalClock()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CausalClock',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CausalClock.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'logicalCounter')
    ..aOS(2, _omitFieldNames ? '' : 'actorPeerId')
    ..m<$core.String, $fixnum.Int64>(3, _omitFieldNames ? '' : 'peerVectors',
        entryClassName: 'CausalClock.PeerVectorsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O6,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CausalClock clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CausalClock copyWith(void Function(CausalClock) updates) =>
      super.copyWith((message) => updates(message as CausalClock))
          as CausalClock;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CausalClock() / CausalClock.new instead')
  static CausalClock create() => CausalClock._();
  static $pb.GeneratedMessage $_createMessage() => CausalClock._();
  @$core.override
  CausalClock createEmptyInstance() => CausalClock._();
  @$core.pragma('dart2js:noInline')
  static CausalClock getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CausalClock>(
          CausalClock.$_createMessage);
  static CausalClock? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get logicalCounter => $_getI64(0);
  @$pb.TagNumber(1)
  set logicalCounter($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLogicalCounter() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogicalCounter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get actorPeerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set actorPeerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActorPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearActorPeerId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $fixnum.Int64> get peerVectors => $_getMap(2);
}

/// Content-addressed cryptographic hash.
/// Invariant: Content hash is verification/integrity, NOT logical object identity.
class ContentHash extends $pb.GeneratedMessage {
  factory ContentHash({
    HashAlgorithm? algorithm,
    $core.List<$core.int>? hashBytes,
    $core.String? hexDigest,
  }) {
    final result = ContentHash._();
    if (algorithm != null) result.algorithm = algorithm;
    if (hashBytes != null) result.hashBytes = hashBytes;
    if (hexDigest != null) result.hexDigest = hexDigest;
    return result;
  }

  ContentHash._();

  factory ContentHash.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContentHash()..mergeFromBuffer(data, registry);
  factory ContentHash.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContentHash()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContentHash',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ContentHash.$_createMessage)
    ..aE<HashAlgorithm>(1, _omitFieldNames ? '' : 'algorithm',
        enumValues: HashAlgorithm.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'hashBytes', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'hexDigest')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContentHash clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContentHash copyWith(void Function(ContentHash) updates) =>
      super.copyWith((message) => updates(message as ContentHash))
          as ContentHash;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContentHash() / ContentHash.new instead')
  static ContentHash create() => ContentHash._();
  static $pb.GeneratedMessage $_createMessage() => ContentHash._();
  @$core.override
  ContentHash createEmptyInstance() => ContentHash._();
  @$core.pragma('dart2js:noInline')
  static ContentHash getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContentHash>(
          ContentHash.$_createMessage);
  static ContentHash? _defaultInstance;

  @$pb.TagNumber(1)
  HashAlgorithm get algorithm => $_getN(0);
  @$pb.TagNumber(1)
  set algorithm(HashAlgorithm value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAlgorithm() => $_has(0);
  @$pb.TagNumber(1)
  void clearAlgorithm() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get hashBytes => $_getN(1);
  @$pb.TagNumber(2)
  set hashBytes($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHashBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearHashBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get hexDigest => $_getSZ(2);
  @$pb.TagNumber(3)
  set hexDigest($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHexDigest() => $_has(2);
  @$pb.TagNumber(3)
  void clearHexDigest() => $_clearField(3);
}

/// Logical object identity.
/// Invariant: Independent of physical filesystem paths.
class ObjectId extends $pb.GeneratedMessage {
  factory ObjectId({
    $core.String? value,
  }) {
    final result = ObjectId._();
    if (value != null) result.value = value;
    return result;
  }

  ObjectId._();

  factory ObjectId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObjectId()..mergeFromBuffer(data, registry);
  factory ObjectId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObjectId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ObjectId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ObjectId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObjectId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObjectId copyWith(void Function(ObjectId) updates) =>
      super.copyWith((message) => updates(message as ObjectId)) as ObjectId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ObjectId() / ObjectId.new instead')
  static ObjectId create() => ObjectId._();
  static $pb.GeneratedMessage $_createMessage() => ObjectId._();
  @$core.override
  ObjectId createEmptyInstance() => ObjectId._();
  @$core.pragma('dart2js:noInline')
  static ObjectId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ObjectId>(ObjectId.$_createMessage);
  static ObjectId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class DeviceId extends $pb.GeneratedMessage {
  factory DeviceId({
    $core.String? value,
  }) {
    final result = DeviceId._();
    if (value != null) result.value = value;
    return result;
  }

  DeviceId._();

  factory DeviceId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceId()..mergeFromBuffer(data, registry);
  factory DeviceId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: DeviceId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceId copyWith(void Function(DeviceId) updates) =>
      super.copyWith((message) => updates(message as DeviceId)) as DeviceId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeviceId() / DeviceId.new instead')
  static DeviceId create() => DeviceId._();
  static $pb.GeneratedMessage $_createMessage() => DeviceId._();
  @$core.override
  DeviceId createEmptyInstance() => DeviceId._();
  @$core.pragma('dart2js:noInline')
  static DeviceId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceId>(DeviceId.$_createMessage);
  static DeviceId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class PeerId extends $pb.GeneratedMessage {
  factory PeerId({
    $core.String? value,
  }) {
    final result = PeerId._();
    if (value != null) result.value = value;
    return result;
  }

  PeerId._();

  factory PeerId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerId()..mergeFromBuffer(data, registry);
  factory PeerId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PeerId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerId copyWith(void Function(PeerId) updates) =>
      super.copyWith((message) => updates(message as PeerId)) as PeerId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PeerId() / PeerId.new instead')
  static PeerId create() => PeerId._();
  static $pb.GeneratedMessage $_createMessage() => PeerId._();
  @$core.override
  PeerId createEmptyInstance() => PeerId._();
  @$core.pragma('dart2js:noInline')
  static PeerId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PeerId>(PeerId.$_createMessage);
  static PeerId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class ConnectionId extends $pb.GeneratedMessage {
  factory ConnectionId({
    $core.String? value,
  }) {
    final result = ConnectionId._();
    if (value != null) result.value = value;
    return result;
  }

  ConnectionId._();

  factory ConnectionId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConnectionId()..mergeFromBuffer(data, registry);
  factory ConnectionId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConnectionId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ConnectionId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionId copyWith(void Function(ConnectionId) updates) =>
      super.copyWith((message) => updates(message as ConnectionId))
          as ConnectionId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ConnectionId() / ConnectionId.new instead')
  static ConnectionId create() => ConnectionId._();
  static $pb.GeneratedMessage $_createMessage() => ConnectionId._();
  @$core.override
  ConnectionId createEmptyInstance() => ConnectionId._();
  @$core.pragma('dart2js:noInline')
  static ConnectionId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConnectionId>(
          ConnectionId.$_createMessage);
  static ConnectionId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class SessionId extends $pb.GeneratedMessage {
  factory SessionId({
    $core.String? value,
  }) {
    final result = SessionId._();
    if (value != null) result.value = value;
    return result;
  }

  SessionId._();

  factory SessionId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionId()..mergeFromBuffer(data, registry);
  factory SessionId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SessionId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionId copyWith(void Function(SessionId) updates) =>
      super.copyWith((message) => updates(message as SessionId)) as SessionId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionId() / SessionId.new instead')
  static SessionId create() => SessionId._();
  static $pb.GeneratedMessage $_createMessage() => SessionId._();
  @$core.override
  SessionId createEmptyInstance() => SessionId._();
  @$core.pragma('dart2js:noInline')
  static SessionId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionId>(SessionId.$_createMessage);
  static SessionId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class OperationId extends $pb.GeneratedMessage {
  factory OperationId({
    $core.String? value,
  }) {
    final result = OperationId._();
    if (value != null) result.value = value;
    return result;
  }

  OperationId._();

  factory OperationId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationId()..mergeFromBuffer(data, registry);
  factory OperationId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OperationId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OperationId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: OperationId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OperationId copyWith(void Function(OperationId) updates) =>
      super.copyWith((message) => updates(message as OperationId))
          as OperationId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OperationId() / OperationId.new instead')
  static OperationId create() => OperationId._();
  static $pb.GeneratedMessage $_createMessage() => OperationId._();
  @$core.override
  OperationId createEmptyInstance() => OperationId._();
  @$core.pragma('dart2js:noInline')
  static OperationId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OperationId>(
          OperationId.$_createMessage);
  static OperationId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class VersionId extends $pb.GeneratedMessage {
  factory VersionId({
    $core.String? value,
  }) {
    final result = VersionId._();
    if (value != null) result.value = value;
    return result;
  }

  VersionId._();

  factory VersionId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VersionId()..mergeFromBuffer(data, registry);
  factory VersionId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      VersionId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VersionId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: VersionId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VersionId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VersionId copyWith(void Function(VersionId) updates) =>
      super.copyWith((message) => updates(message as VersionId)) as VersionId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use VersionId() / VersionId.new instead')
  static VersionId create() => VersionId._();
  static $pb.GeneratedMessage $_createMessage() => VersionId._();
  @$core.override
  VersionId createEmptyInstance() => VersionId._();
  @$core.pragma('dart2js:noInline')
  static VersionId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VersionId>(VersionId.$_createMessage);
  static VersionId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);
}

class ChunkId extends $pb.GeneratedMessage {
  factory ChunkId({
    $core.String? value,
    $fixnum.Int64? index,
  }) {
    final result = ChunkId._();
    if (value != null) result.value = value;
    if (index != null) result.index = index;
    return result;
  }

  ChunkId._();

  factory ChunkId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChunkId()..mergeFromBuffer(data, registry);
  factory ChunkId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChunkId()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChunkId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ChunkId.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..aInt64(2, _omitFieldNames ? '' : 'index')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChunkId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChunkId copyWith(void Function(ChunkId) updates) =>
      super.copyWith((message) => updates(message as ChunkId)) as ChunkId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChunkId() / ChunkId.new instead')
  static ChunkId create() => ChunkId._();
  static $pb.GeneratedMessage $_createMessage() => ChunkId._();
  @$core.override
  ChunkId createEmptyInstance() => ChunkId._();
  @$core.pragma('dart2js:noInline')
  static ChunkId getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChunkId>(ChunkId.$_createMessage);
  static ChunkId? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get index => $_getI64(1);
  @$pb.TagNumber(2)
  set index($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearIndex() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
