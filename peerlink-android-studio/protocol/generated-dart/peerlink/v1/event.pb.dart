// This is a generated file - do not edit.
//
// Generated from peerlink/v1/event.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'capability.pb.dart' as $2;
import 'common.pb.dart' as $0;
import 'error.pb.dart' as $4;
import 'identity.pb.dart' as $5;
import 'operation.pb.dart' as $3;
import 'session.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum PeerLinkEvent_Payload {
  sessionEvent,
  capabilityEvent,
  operationEvent,
  errorEvent,
  peerEvent,
  notSet
}

/// Universal versionable event contract across the distributed system
class PeerLinkEvent extends $pb.GeneratedMessage {
  factory PeerLinkEvent({
    $core.String? eventId,
    $0.ProtocolHeader? header,
    $1.SessionDescriptor? sessionEvent,
    $2.CapabilityNegotiationResponse? capabilityEvent,
    $3.OperationRecord? operationEvent,
    $4.ErrorDetail? errorEvent,
    $5.PeerIdentity? peerEvent,
  }) {
    final result = PeerLinkEvent._();
    if (eventId != null) result.eventId = eventId;
    if (header != null) result.header = header;
    if (sessionEvent != null) result.sessionEvent = sessionEvent;
    if (capabilityEvent != null) result.capabilityEvent = capabilityEvent;
    if (operationEvent != null) result.operationEvent = operationEvent;
    if (errorEvent != null) result.errorEvent = errorEvent;
    if (peerEvent != null) result.peerEvent = peerEvent;
    return result;
  }

  PeerLinkEvent._();

  factory PeerLinkEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerLinkEvent()..mergeFromBuffer(data, registry);
  factory PeerLinkEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerLinkEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, PeerLinkEvent_Payload>
      _PeerLinkEvent_PayloadByTag = {
    3: PeerLinkEvent_Payload.sessionEvent,
    4: PeerLinkEvent_Payload.capabilityEvent,
    5: PeerLinkEvent_Payload.operationEvent,
    6: PeerLinkEvent_Payload.errorEvent,
    7: PeerLinkEvent_Payload.peerEvent,
    0: PeerLinkEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerLinkEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PeerLinkEvent.$_createMessage)
    ..oo(0, [3, 4, 5, 6, 7])
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..aOM<$0.ProtocolHeader>(2, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOM<$1.SessionDescriptor>(3, _omitFieldNames ? '' : 'sessionEvent',
        subBuilder: $1.SessionDescriptor.$_createMessage)
    ..aOM<$2.CapabilityNegotiationResponse>(
        4, _omitFieldNames ? '' : 'capabilityEvent',
        subBuilder: $2.CapabilityNegotiationResponse.$_createMessage)
    ..aOM<$3.OperationRecord>(5, _omitFieldNames ? '' : 'operationEvent',
        subBuilder: $3.OperationRecord.$_createMessage)
    ..aOM<$4.ErrorDetail>(6, _omitFieldNames ? '' : 'errorEvent',
        subBuilder: $4.ErrorDetail.$_createMessage)
    ..aOM<$5.PeerIdentity>(7, _omitFieldNames ? '' : 'peerEvent',
        subBuilder: $5.PeerIdentity.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerLinkEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerLinkEvent copyWith(void Function(PeerLinkEvent) updates) =>
      super.copyWith((message) => updates(message as PeerLinkEvent))
          as PeerLinkEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PeerLinkEvent() / PeerLinkEvent.new instead')
  static PeerLinkEvent create() => PeerLinkEvent._();
  static $pb.GeneratedMessage $_createMessage() => PeerLinkEvent._();
  @$core.override
  PeerLinkEvent createEmptyInstance() => PeerLinkEvent._();
  @$core.pragma('dart2js:noInline')
  static PeerLinkEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerLinkEvent>(
          PeerLinkEvent.$_createMessage);
  static PeerLinkEvent? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  PeerLinkEvent_Payload whichPayload() =>
      _PeerLinkEvent_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.ProtocolHeader get header => $_getN(1);
  @$pb.TagNumber(2)
  set header($0.ProtocolHeader value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeader() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeader() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.ProtocolHeader ensureHeader() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.SessionDescriptor get sessionEvent => $_getN(2);
  @$pb.TagNumber(3)
  set sessionEvent($1.SessionDescriptor value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionEvent() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionEvent() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.SessionDescriptor ensureSessionEvent() => $_ensure(2);

  @$pb.TagNumber(4)
  $2.CapabilityNegotiationResponse get capabilityEvent => $_getN(3);
  @$pb.TagNumber(4)
  set capabilityEvent($2.CapabilityNegotiationResponse value) =>
      $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCapabilityEvent() => $_has(3);
  @$pb.TagNumber(4)
  void clearCapabilityEvent() => $_clearField(4);
  @$pb.TagNumber(4)
  $2.CapabilityNegotiationResponse ensureCapabilityEvent() => $_ensure(3);

  @$pb.TagNumber(5)
  $3.OperationRecord get operationEvent => $_getN(4);
  @$pb.TagNumber(5)
  set operationEvent($3.OperationRecord value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasOperationEvent() => $_has(4);
  @$pb.TagNumber(5)
  void clearOperationEvent() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.OperationRecord ensureOperationEvent() => $_ensure(4);

  @$pb.TagNumber(6)
  $4.ErrorDetail get errorEvent => $_getN(5);
  @$pb.TagNumber(6)
  set errorEvent($4.ErrorDetail value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasErrorEvent() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorEvent() => $_clearField(6);
  @$pb.TagNumber(6)
  $4.ErrorDetail ensureErrorEvent() => $_ensure(5);

  @$pb.TagNumber(7)
  $5.PeerIdentity get peerEvent => $_getN(6);
  @$pb.TagNumber(7)
  set peerEvent($5.PeerIdentity value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPeerEvent() => $_has(6);
  @$pb.TagNumber(7)
  void clearPeerEvent() => $_clearField(7);
  @$pb.TagNumber(7)
  $5.PeerIdentity ensurePeerEvent() => $_ensure(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
