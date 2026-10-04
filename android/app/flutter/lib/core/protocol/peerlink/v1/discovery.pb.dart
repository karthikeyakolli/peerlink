// This is a generated file - do not edit.
//
// Generated from peerlink/v1/discovery.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'capability.pbenum.dart' as $1;
import 'common.pb.dart' as $0;
import 'discovery.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'discovery.pbenum.dart';

class DiscoveredPeer extends $pb.GeneratedMessage {
  factory DiscoveredPeer({
    $0.PeerId? peerId,
    $core.Iterable<$core.String>? socketAddresses,
    $core.Iterable<$1.FeatureCapability>? capabilities,
    $core.String? displayName,
    $fixnum.Int64? lastSeenUtcMs,
  }) {
    final result = DiscoveredPeer._();
    if (peerId != null) result.peerId = peerId;
    if (socketAddresses != null) result.socketAddresses.addAll(socketAddresses);
    if (capabilities != null) result.capabilities.addAll(capabilities);
    if (displayName != null) result.displayName = displayName;
    if (lastSeenUtcMs != null) result.lastSeenUtcMs = lastSeenUtcMs;
    return result;
  }

  DiscoveredPeer._();

  factory DiscoveredPeer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoveredPeer()..mergeFromBuffer(data, registry);
  factory DiscoveredPeer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoveredPeer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscoveredPeer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: DiscoveredPeer.$_createMessage)
    ..aOM<$0.PeerId>(1, _omitFieldNames ? '' : 'peerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..pPS(2, _omitFieldNames ? '' : 'socketAddresses')
    ..pc<$1.FeatureCapability>(
        3, _omitFieldNames ? '' : 'capabilities', $pb.PbFieldType.KE,
        valueOf: $1.FeatureCapability.valueOf,
        enumValues: $1.FeatureCapability.values,
        defaultEnumValue: $1.FeatureCapability.FEATURE_CAPABILITY_UNSPECIFIED)
    ..aOS(4, _omitFieldNames ? '' : 'displayName')
    ..aInt64(5, _omitFieldNames ? '' : 'lastSeenUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoveredPeer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoveredPeer copyWith(void Function(DiscoveredPeer) updates) =>
      super.copyWith((message) => updates(message as DiscoveredPeer))
          as DiscoveredPeer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DiscoveredPeer() / DiscoveredPeer.new instead')
  static DiscoveredPeer create() => DiscoveredPeer._();
  static $pb.GeneratedMessage $_createMessage() => DiscoveredPeer._();
  @$core.override
  DiscoveredPeer createEmptyInstance() => DiscoveredPeer._();
  @$core.pragma('dart2js:noInline')
  static DiscoveredPeer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DiscoveredPeer>(
          DiscoveredPeer.$_createMessage);
  static DiscoveredPeer? _defaultInstance;

  @$pb.TagNumber(1)
  $0.PeerId get peerId => $_getN(0);
  @$pb.TagNumber(1)
  set peerId($0.PeerId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.PeerId ensurePeerId() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get socketAddresses => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$1.FeatureCapability> get capabilities => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get displayName => $_getSZ(3);
  @$pb.TagNumber(4)
  set displayName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDisplayName() => $_has(3);
  @$pb.TagNumber(4)
  void clearDisplayName() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get lastSeenUtcMs => $_getI64(4);
  @$pb.TagNumber(5)
  set lastSeenUtcMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastSeenUtcMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastSeenUtcMs() => $_clearField(5);
}

class DiscoveryEvent extends $pb.GeneratedMessage {
  factory DiscoveryEvent({
    DiscoveryEventType? eventType,
    DiscoveredPeer? peer,
    $fixnum.Int64? timestampUtcMs,
  }) {
    final result = DiscoveryEvent._();
    if (eventType != null) result.eventType = eventType;
    if (peer != null) result.peer = peer;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    return result;
  }

  DiscoveryEvent._();

  factory DiscoveryEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoveryEvent()..mergeFromBuffer(data, registry);
  factory DiscoveryEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DiscoveryEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscoveryEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: DiscoveryEvent.$_createMessage)
    ..aE<DiscoveryEventType>(1, _omitFieldNames ? '' : 'eventType',
        enumValues: DiscoveryEventType.values)
    ..aOM<DiscoveredPeer>(2, _omitFieldNames ? '' : 'peer',
        subBuilder: DiscoveredPeer.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'timestampUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoveryEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscoveryEvent copyWith(void Function(DiscoveryEvent) updates) =>
      super.copyWith((message) => updates(message as DiscoveryEvent))
          as DiscoveryEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DiscoveryEvent() / DiscoveryEvent.new instead')
  static DiscoveryEvent create() => DiscoveryEvent._();
  static $pb.GeneratedMessage $_createMessage() => DiscoveryEvent._();
  @$core.override
  DiscoveryEvent createEmptyInstance() => DiscoveryEvent._();
  @$core.pragma('dart2js:noInline')
  static DiscoveryEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DiscoveryEvent>(
          DiscoveryEvent.$_createMessage);
  static DiscoveryEvent? _defaultInstance;

  @$pb.TagNumber(1)
  DiscoveryEventType get eventType => $_getN(0);
  @$pb.TagNumber(1)
  set eventType(DiscoveryEventType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEventType() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventType() => $_clearField(1);

  @$pb.TagNumber(2)
  DiscoveredPeer get peer => $_getN(1);
  @$pb.TagNumber(2)
  set peer(DiscoveredPeer value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPeer() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeer() => $_clearField(2);
  @$pb.TagNumber(2)
  DiscoveredPeer ensurePeer() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get timestampUtcMs => $_getI64(2);
  @$pb.TagNumber(3)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTimestampUtcMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimestampUtcMs() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
