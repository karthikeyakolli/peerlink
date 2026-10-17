// This is a generated file - do not edit.
//
// Generated from peerlink/v1/session.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'capability.pb.dart' as $1;
import 'common.pb.dart' as $0;
import 'error.pb.dart' as $2;
import 'identity.pb.dart' as $3;
import 'session.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'session.pbenum.dart';

/// Inter-peer authenticated communication session descriptor
class SessionDescriptor extends $pb.GeneratedMessage {
  factory SessionDescriptor({
    $0.SessionId? sessionId,
    $0.PeerId? initiatorPeerId,
    $0.PeerId? responderPeerId,
    SessionState? state,
    TransportType? transportType,
    $fixnum.Int64? establishedAtUtcMs,
    $fixnum.Int64? expiresAtUtcMs,
    $core.Iterable<$1.FeatureCapability>? negotiatedCapabilities,
    $0.ProtocolVersion? protocolVersion,
  }) {
    final result = SessionDescriptor._();
    if (sessionId != null) result.sessionId = sessionId;
    if (initiatorPeerId != null) result.initiatorPeerId = initiatorPeerId;
    if (responderPeerId != null) result.responderPeerId = responderPeerId;
    if (state != null) result.state = state;
    if (transportType != null) result.transportType = transportType;
    if (establishedAtUtcMs != null)
      result.establishedAtUtcMs = establishedAtUtcMs;
    if (expiresAtUtcMs != null) result.expiresAtUtcMs = expiresAtUtcMs;
    if (negotiatedCapabilities != null)
      result.negotiatedCapabilities.addAll(negotiatedCapabilities);
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    return result;
  }

  SessionDescriptor._();

  factory SessionDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionDescriptor()..mergeFromBuffer(data, registry);
  factory SessionDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionDescriptor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SessionDescriptor.$_createMessage)
    ..aOM<$0.SessionId>(1, _omitFieldNames ? '' : 'sessionId',
        subBuilder: $0.SessionId.$_createMessage)
    ..aOM<$0.PeerId>(2, _omitFieldNames ? '' : 'initiatorPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.PeerId>(3, _omitFieldNames ? '' : 'responderPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aE<SessionState>(4, _omitFieldNames ? '' : 'state',
        enumValues: SessionState.values)
    ..aE<TransportType>(5, _omitFieldNames ? '' : 'transportType',
        enumValues: TransportType.values)
    ..aInt64(6, _omitFieldNames ? '' : 'establishedAtUtcMs')
    ..aInt64(7, _omitFieldNames ? '' : 'expiresAtUtcMs')
    ..pc<$1.FeatureCapability>(
        8, _omitFieldNames ? '' : 'negotiatedCapabilities', $pb.PbFieldType.KE,
        valueOf: $1.FeatureCapability.valueOf,
        enumValues: $1.FeatureCapability.values,
        defaultEnumValue: $1.FeatureCapability.FEATURE_CAPABILITY_UNSPECIFIED)
    ..aOM<$0.ProtocolVersion>(9, _omitFieldNames ? '' : 'protocolVersion',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionDescriptor copyWith(void Function(SessionDescriptor) updates) =>
      super.copyWith((message) => updates(message as SessionDescriptor))
          as SessionDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionDescriptor() / SessionDescriptor.new instead')
  static SessionDescriptor create() => SessionDescriptor._();
  static $pb.GeneratedMessage $_createMessage() => SessionDescriptor._();
  @$core.override
  SessionDescriptor createEmptyInstance() => SessionDescriptor._();
  @$core.pragma('dart2js:noInline')
  static SessionDescriptor getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionDescriptor>(
          SessionDescriptor.$_createMessage);
  static SessionDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $0.SessionId get sessionId => $_getN(0);
  @$pb.TagNumber(1)
  set sessionId($0.SessionId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.SessionId ensureSessionId() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.PeerId get initiatorPeerId => $_getN(1);
  @$pb.TagNumber(2)
  set initiatorPeerId($0.PeerId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasInitiatorPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearInitiatorPeerId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PeerId ensureInitiatorPeerId() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.PeerId get responderPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set responderPeerId($0.PeerId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasResponderPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearResponderPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PeerId ensureResponderPeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  SessionState get state => $_getN(3);
  @$pb.TagNumber(4)
  set state(SessionState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  TransportType get transportType => $_getN(4);
  @$pb.TagNumber(5)
  set transportType(TransportType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTransportType() => $_has(4);
  @$pb.TagNumber(5)
  void clearTransportType() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get establishedAtUtcMs => $_getI64(5);
  @$pb.TagNumber(6)
  set establishedAtUtcMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEstablishedAtUtcMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearEstablishedAtUtcMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get expiresAtUtcMs => $_getI64(6);
  @$pb.TagNumber(7)
  set expiresAtUtcMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExpiresAtUtcMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpiresAtUtcMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$1.FeatureCapability> get negotiatedCapabilities => $_getList(7);

  @$pb.TagNumber(9)
  $0.ProtocolVersion get protocolVersion => $_getN(8);
  @$pb.TagNumber(9)
  set protocolVersion($0.ProtocolVersion value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasProtocolVersion() => $_has(8);
  @$pb.TagNumber(9)
  void clearProtocolVersion() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.ProtocolVersion ensureProtocolVersion() => $_ensure(8);
}

class SessionInitiateRequest extends $pb.GeneratedMessage {
  factory SessionInitiateRequest({
    $0.ProtocolHeader? header,
    $0.SessionId? proposedSessionId,
    $0.PeerId? initiatorPeerId,
    TransportType? preferredTransport,
    $1.CapabilityNegotiationRequest? capabilityOffer,
  }) {
    final result = SessionInitiateRequest._();
    if (header != null) result.header = header;
    if (proposedSessionId != null) result.proposedSessionId = proposedSessionId;
    if (initiatorPeerId != null) result.initiatorPeerId = initiatorPeerId;
    if (preferredTransport != null)
      result.preferredTransport = preferredTransport;
    if (capabilityOffer != null) result.capabilityOffer = capabilityOffer;
    return result;
  }

  SessionInitiateRequest._();

  factory SessionInitiateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionInitiateRequest()..mergeFromBuffer(data, registry);
  factory SessionInitiateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionInitiateRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionInitiateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SessionInitiateRequest.$_createMessage)
    ..aOM<$0.ProtocolHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOM<$0.SessionId>(2, _omitFieldNames ? '' : 'proposedSessionId',
        subBuilder: $0.SessionId.$_createMessage)
    ..aOM<$0.PeerId>(3, _omitFieldNames ? '' : 'initiatorPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aE<TransportType>(4, _omitFieldNames ? '' : 'preferredTransport',
        enumValues: TransportType.values)
    ..aOM<$1.CapabilityNegotiationRequest>(
        5, _omitFieldNames ? '' : 'capabilityOffer',
        subBuilder: $1.CapabilityNegotiationRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInitiateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInitiateRequest copyWith(
          void Function(SessionInitiateRequest) updates) =>
      super.copyWith((message) => updates(message as SessionInitiateRequest))
          as SessionInitiateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SessionInitiateRequest() / SessionInitiateRequest.new instead')
  static SessionInitiateRequest create() => SessionInitiateRequest._();
  static $pb.GeneratedMessage $_createMessage() => SessionInitiateRequest._();
  @$core.override
  SessionInitiateRequest createEmptyInstance() => SessionInitiateRequest._();
  @$core.pragma('dart2js:noInline')
  static SessionInitiateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionInitiateRequest>(
          SessionInitiateRequest.$_createMessage);
  static SessionInitiateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ProtocolHeader get header => $_getN(0);
  @$pb.TagNumber(1)
  set header($0.ProtocolHeader value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHeader() => $_has(0);
  @$pb.TagNumber(1)
  void clearHeader() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ProtocolHeader ensureHeader() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.SessionId get proposedSessionId => $_getN(1);
  @$pb.TagNumber(2)
  set proposedSessionId($0.SessionId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProposedSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProposedSessionId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.SessionId ensureProposedSessionId() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.PeerId get initiatorPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set initiatorPeerId($0.PeerId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasInitiatorPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearInitiatorPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PeerId ensureInitiatorPeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  TransportType get preferredTransport => $_getN(3);
  @$pb.TagNumber(4)
  set preferredTransport(TransportType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPreferredTransport() => $_has(3);
  @$pb.TagNumber(4)
  void clearPreferredTransport() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.CapabilityNegotiationRequest get capabilityOffer => $_getN(4);
  @$pb.TagNumber(5)
  set capabilityOffer($1.CapabilityNegotiationRequest value) =>
      $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCapabilityOffer() => $_has(4);
  @$pb.TagNumber(5)
  void clearCapabilityOffer() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.CapabilityNegotiationRequest ensureCapabilityOffer() => $_ensure(4);
}

class SessionInitiateResponse extends $pb.GeneratedMessage {
  factory SessionInitiateResponse({
    $0.ProtocolHeader? header,
    $0.SessionId? sessionId,
    SessionState? state,
    TransportType? selectedTransport,
    $1.CapabilityNegotiationResponse? capabilityResponse,
    $2.ErrorDetail? error,
  }) {
    final result = SessionInitiateResponse._();
    if (header != null) result.header = header;
    if (sessionId != null) result.sessionId = sessionId;
    if (state != null) result.state = state;
    if (selectedTransport != null) result.selectedTransport = selectedTransport;
    if (capabilityResponse != null)
      result.capabilityResponse = capabilityResponse;
    if (error != null) result.error = error;
    return result;
  }

  SessionInitiateResponse._();

  factory SessionInitiateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionInitiateResponse()..mergeFromBuffer(data, registry);
  factory SessionInitiateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionInitiateResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionInitiateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SessionInitiateResponse.$_createMessage)
    ..aOM<$0.ProtocolHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOM<$0.SessionId>(2, _omitFieldNames ? '' : 'sessionId',
        subBuilder: $0.SessionId.$_createMessage)
    ..aE<SessionState>(3, _omitFieldNames ? '' : 'state',
        enumValues: SessionState.values)
    ..aE<TransportType>(4, _omitFieldNames ? '' : 'selectedTransport',
        enumValues: TransportType.values)
    ..aOM<$1.CapabilityNegotiationResponse>(
        5, _omitFieldNames ? '' : 'capabilityResponse',
        subBuilder: $1.CapabilityNegotiationResponse.$_createMessage)
    ..aOM<$2.ErrorDetail>(6, _omitFieldNames ? '' : 'error',
        subBuilder: $2.ErrorDetail.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInitiateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionInitiateResponse copyWith(
          void Function(SessionInitiateResponse) updates) =>
      super.copyWith((message) => updates(message as SessionInitiateResponse))
          as SessionInitiateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SessionInitiateResponse() / SessionInitiateResponse.new instead')
  static SessionInitiateResponse create() => SessionInitiateResponse._();
  static $pb.GeneratedMessage $_createMessage() => SessionInitiateResponse._();
  @$core.override
  SessionInitiateResponse createEmptyInstance() => SessionInitiateResponse._();
  @$core.pragma('dart2js:noInline')
  static SessionInitiateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionInitiateResponse>(
          SessionInitiateResponse.$_createMessage);
  static SessionInitiateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ProtocolHeader get header => $_getN(0);
  @$pb.TagNumber(1)
  set header($0.ProtocolHeader value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHeader() => $_has(0);
  @$pb.TagNumber(1)
  void clearHeader() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ProtocolHeader ensureHeader() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.SessionId get sessionId => $_getN(1);
  @$pb.TagNumber(2)
  set sessionId($0.SessionId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.SessionId ensureSessionId() => $_ensure(1);

  @$pb.TagNumber(3)
  SessionState get state => $_getN(2);
  @$pb.TagNumber(3)
  set state(SessionState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  TransportType get selectedTransport => $_getN(3);
  @$pb.TagNumber(4)
  set selectedTransport(TransportType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSelectedTransport() => $_has(3);
  @$pb.TagNumber(4)
  void clearSelectedTransport() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.CapabilityNegotiationResponse get capabilityResponse => $_getN(4);
  @$pb.TagNumber(5)
  set capabilityResponse($1.CapabilityNegotiationResponse value) =>
      $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCapabilityResponse() => $_has(4);
  @$pb.TagNumber(5)
  void clearCapabilityResponse() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.CapabilityNegotiationResponse ensureCapabilityResponse() => $_ensure(4);

  @$pb.TagNumber(6)
  $2.ErrorDetail get error => $_getN(5);
  @$pb.TagNumber(6)
  set error($2.ErrorDetail value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasError() => $_has(5);
  @$pb.TagNumber(6)
  void clearError() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.ErrorDetail ensureError() => $_ensure(5);
}

class HandshakeFrame extends $pb.GeneratedMessage {
  factory HandshakeFrame({
    HandshakePhase? phase,
    $0.ProtocolVersion? protocolVersion,
    $0.ProtocolVersion? minSupportedVersion,
    $0.ConnectionId? connectionId,
    $0.SessionId? sessionId,
    $3.PeerIdentity? peerIdentity,
    $3.DeviceIdentity? deviceIdentity,
    $core.List<$core.int>? nonce,
    $fixnum.Int64? timestampUtcMs,
    $core.List<$core.int>? signature,
    $core.Iterable<TransportType>? supportedTransports,
    TransportType? selectedTransport,
    $core.Iterable<$core.String>? supportedFeatures,
    $2.ErrorDetail? error,
  }) {
    final result = HandshakeFrame._();
    if (phase != null) result.phase = phase;
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (minSupportedVersion != null)
      result.minSupportedVersion = minSupportedVersion;
    if (connectionId != null) result.connectionId = connectionId;
    if (sessionId != null) result.sessionId = sessionId;
    if (peerIdentity != null) result.peerIdentity = peerIdentity;
    if (deviceIdentity != null) result.deviceIdentity = deviceIdentity;
    if (nonce != null) result.nonce = nonce;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (signature != null) result.signature = signature;
    if (supportedTransports != null)
      result.supportedTransports.addAll(supportedTransports);
    if (selectedTransport != null) result.selectedTransport = selectedTransport;
    if (supportedFeatures != null)
      result.supportedFeatures.addAll(supportedFeatures);
    if (error != null) result.error = error;
    return result;
  }

  HandshakeFrame._();

  factory HandshakeFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HandshakeFrame()..mergeFromBuffer(data, registry);
  factory HandshakeFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HandshakeFrame()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HandshakeFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: HandshakeFrame.$_createMessage)
    ..aE<HandshakePhase>(1, _omitFieldNames ? '' : 'phase',
        enumValues: HandshakePhase.values)
    ..aOM<$0.ProtocolVersion>(2, _omitFieldNames ? '' : 'protocolVersion',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..aOM<$0.ProtocolVersion>(3, _omitFieldNames ? '' : 'minSupportedVersion',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..aOM<$0.ConnectionId>(4, _omitFieldNames ? '' : 'connectionId',
        subBuilder: $0.ConnectionId.$_createMessage)
    ..aOM<$0.SessionId>(5, _omitFieldNames ? '' : 'sessionId',
        subBuilder: $0.SessionId.$_createMessage)
    ..aOM<$3.PeerIdentity>(6, _omitFieldNames ? '' : 'peerIdentity',
        subBuilder: $3.PeerIdentity.$_createMessage)
    ..aOM<$3.DeviceIdentity>(7, _omitFieldNames ? '' : 'deviceIdentity',
        subBuilder: $3.DeviceIdentity.$_createMessage)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..aInt64(9, _omitFieldNames ? '' : 'timestampUtcMs')
    ..a<$core.List<$core.int>>(
        10, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..pc<TransportType>(
        11, _omitFieldNames ? '' : 'supportedTransports', $pb.PbFieldType.KE,
        valueOf: TransportType.valueOf,
        enumValues: TransportType.values,
        defaultEnumValue: TransportType.TRANSPORT_TYPE_UNSPECIFIED)
    ..aE<TransportType>(12, _omitFieldNames ? '' : 'selectedTransport',
        enumValues: TransportType.values)
    ..pPS(13, _omitFieldNames ? '' : 'supportedFeatures')
    ..aOM<$2.ErrorDetail>(14, _omitFieldNames ? '' : 'error',
        subBuilder: $2.ErrorDetail.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HandshakeFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HandshakeFrame copyWith(void Function(HandshakeFrame) updates) =>
      super.copyWith((message) => updates(message as HandshakeFrame))
          as HandshakeFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HandshakeFrame() / HandshakeFrame.new instead')
  static HandshakeFrame create() => HandshakeFrame._();
  static $pb.GeneratedMessage $_createMessage() => HandshakeFrame._();
  @$core.override
  HandshakeFrame createEmptyInstance() => HandshakeFrame._();
  @$core.pragma('dart2js:noInline')
  static HandshakeFrame getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HandshakeFrame>(
          HandshakeFrame.$_createMessage);
  static HandshakeFrame? _defaultInstance;

  @$pb.TagNumber(1)
  HandshakePhase get phase => $_getN(0);
  @$pb.TagNumber(1)
  set phase(HandshakePhase value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhase() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhase() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.ProtocolVersion get protocolVersion => $_getN(1);
  @$pb.TagNumber(2)
  set protocolVersion($0.ProtocolVersion value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProtocolVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearProtocolVersion() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.ProtocolVersion ensureProtocolVersion() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.ProtocolVersion get minSupportedVersion => $_getN(2);
  @$pb.TagNumber(3)
  set minSupportedVersion($0.ProtocolVersion value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMinSupportedVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearMinSupportedVersion() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.ProtocolVersion ensureMinSupportedVersion() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.ConnectionId get connectionId => $_getN(3);
  @$pb.TagNumber(4)
  set connectionId($0.ConnectionId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasConnectionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearConnectionId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.ConnectionId ensureConnectionId() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.SessionId get sessionId => $_getN(4);
  @$pb.TagNumber(5)
  set sessionId($0.SessionId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionId() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.SessionId ensureSessionId() => $_ensure(4);

  @$pb.TagNumber(6)
  $3.PeerIdentity get peerIdentity => $_getN(5);
  @$pb.TagNumber(6)
  set peerIdentity($3.PeerIdentity value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPeerIdentity() => $_has(5);
  @$pb.TagNumber(6)
  void clearPeerIdentity() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.PeerIdentity ensurePeerIdentity() => $_ensure(5);

  @$pb.TagNumber(7)
  $3.DeviceIdentity get deviceIdentity => $_getN(6);
  @$pb.TagNumber(7)
  set deviceIdentity($3.DeviceIdentity value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDeviceIdentity() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeviceIdentity() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.DeviceIdentity ensureDeviceIdentity() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.List<$core.int> get nonce => $_getN(7);
  @$pb.TagNumber(8)
  set nonce($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNonce() => $_has(7);
  @$pb.TagNumber(8)
  void clearNonce() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get timestampUtcMs => $_getI64(8);
  @$pb.TagNumber(9)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTimestampUtcMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearTimestampUtcMs() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.List<$core.int> get signature => $_getN(9);
  @$pb.TagNumber(10)
  set signature($core.List<$core.int> value) => $_setBytes(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSignature() => $_has(9);
  @$pb.TagNumber(10)
  void clearSignature() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<TransportType> get supportedTransports => $_getList(10);

  @$pb.TagNumber(12)
  TransportType get selectedTransport => $_getN(11);
  @$pb.TagNumber(12)
  set selectedTransport(TransportType value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSelectedTransport() => $_has(11);
  @$pb.TagNumber(12)
  void clearSelectedTransport() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbList<$core.String> get supportedFeatures => $_getList(12);

  @$pb.TagNumber(14)
  $2.ErrorDetail get error => $_getN(13);
  @$pb.TagNumber(14)
  set error($2.ErrorDetail value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasError() => $_has(13);
  @$pb.TagNumber(14)
  void clearError() => $_clearField(14);
  @$pb.TagNumber(14)
  $2.ErrorDetail ensureError() => $_ensure(13);
}

class KeepalivePing extends $pb.GeneratedMessage {
  factory KeepalivePing({
    $core.String? pingId,
    $fixnum.Int64? timestampUtcMs,
  }) {
    final result = KeepalivePing._();
    if (pingId != null) result.pingId = pingId;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    return result;
  }

  KeepalivePing._();

  factory KeepalivePing.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeepalivePing()..mergeFromBuffer(data, registry);
  factory KeepalivePing.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeepalivePing()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeepalivePing',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: KeepalivePing.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pingId')
    ..aInt64(2, _omitFieldNames ? '' : 'timestampUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepalivePing clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepalivePing copyWith(void Function(KeepalivePing) updates) =>
      super.copyWith((message) => updates(message as KeepalivePing))
          as KeepalivePing;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KeepalivePing() / KeepalivePing.new instead')
  static KeepalivePing create() => KeepalivePing._();
  static $pb.GeneratedMessage $_createMessage() => KeepalivePing._();
  @$core.override
  KeepalivePing createEmptyInstance() => KeepalivePing._();
  @$core.pragma('dart2js:noInline')
  static KeepalivePing getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeepalivePing>(
          KeepalivePing.$_createMessage);
  static KeepalivePing? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pingId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pingId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPingId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPingId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get timestampUtcMs => $_getI64(1);
  @$pb.TagNumber(2)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimestampUtcMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestampUtcMs() => $_clearField(2);
}

class KeepalivePong extends $pb.GeneratedMessage {
  factory KeepalivePong({
    $core.String? pingId,
    $fixnum.Int64? echoTimestampUtcMs,
    $fixnum.Int64? responderTimestampUtcMs,
  }) {
    final result = KeepalivePong._();
    if (pingId != null) result.pingId = pingId;
    if (echoTimestampUtcMs != null)
      result.echoTimestampUtcMs = echoTimestampUtcMs;
    if (responderTimestampUtcMs != null)
      result.responderTimestampUtcMs = responderTimestampUtcMs;
    return result;
  }

  KeepalivePong._();

  factory KeepalivePong.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeepalivePong()..mergeFromBuffer(data, registry);
  factory KeepalivePong.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      KeepalivePong()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeepalivePong',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: KeepalivePong.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pingId')
    ..aInt64(2, _omitFieldNames ? '' : 'echoTimestampUtcMs')
    ..aInt64(3, _omitFieldNames ? '' : 'responderTimestampUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepalivePong clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeepalivePong copyWith(void Function(KeepalivePong) updates) =>
      super.copyWith((message) => updates(message as KeepalivePong))
          as KeepalivePong;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use KeepalivePong() / KeepalivePong.new instead')
  static KeepalivePong create() => KeepalivePong._();
  static $pb.GeneratedMessage $_createMessage() => KeepalivePong._();
  @$core.override
  KeepalivePong createEmptyInstance() => KeepalivePong._();
  @$core.pragma('dart2js:noInline')
  static KeepalivePong getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<KeepalivePong>(
          KeepalivePong.$_createMessage);
  static KeepalivePong? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pingId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pingId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPingId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPingId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get echoTimestampUtcMs => $_getI64(1);
  @$pb.TagNumber(2)
  set echoTimestampUtcMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEchoTimestampUtcMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearEchoTimestampUtcMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get responderTimestampUtcMs => $_getI64(2);
  @$pb.TagNumber(3)
  set responderTimestampUtcMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResponderTimestampUtcMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearResponderTimestampUtcMs() => $_clearField(3);
}

class SessionCloseFrame extends $pb.GeneratedMessage {
  factory SessionCloseFrame({
    $0.SessionId? sessionId,
    $core.int? reasonCode,
    $core.String? reasonMessage,
  }) {
    final result = SessionCloseFrame._();
    if (sessionId != null) result.sessionId = sessionId;
    if (reasonCode != null) result.reasonCode = reasonCode;
    if (reasonMessage != null) result.reasonMessage = reasonMessage;
    return result;
  }

  SessionCloseFrame._();

  factory SessionCloseFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionCloseFrame()..mergeFromBuffer(data, registry);
  factory SessionCloseFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SessionCloseFrame()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionCloseFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SessionCloseFrame.$_createMessage)
    ..aOM<$0.SessionId>(1, _omitFieldNames ? '' : 'sessionId',
        subBuilder: $0.SessionId.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'reasonCode', fieldType: $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'reasonMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionCloseFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionCloseFrame copyWith(void Function(SessionCloseFrame) updates) =>
      super.copyWith((message) => updates(message as SessionCloseFrame))
          as SessionCloseFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SessionCloseFrame() / SessionCloseFrame.new instead')
  static SessionCloseFrame create() => SessionCloseFrame._();
  static $pb.GeneratedMessage $_createMessage() => SessionCloseFrame._();
  @$core.override
  SessionCloseFrame createEmptyInstance() => SessionCloseFrame._();
  @$core.pragma('dart2js:noInline')
  static SessionCloseFrame getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SessionCloseFrame>(
          SessionCloseFrame.$_createMessage);
  static SessionCloseFrame? _defaultInstance;

  @$pb.TagNumber(1)
  $0.SessionId get sessionId => $_getN(0);
  @$pb.TagNumber(1)
  set sessionId($0.SessionId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.SessionId ensureSessionId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get reasonCode => $_getIZ(1);
  @$pb.TagNumber(2)
  set reasonCode($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReasonCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearReasonCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reasonMessage => $_getSZ(2);
  @$pb.TagNumber(3)
  set reasonMessage($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReasonMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearReasonMessage() => $_clearField(3);
}

enum TransportFrame_Frame { handshake, ping, pong, close, payload, notSet }

class TransportFrame extends $pb.GeneratedMessage {
  factory TransportFrame({
    HandshakeFrame? handshake,
    KeepalivePing? ping,
    KeepalivePong? pong,
    SessionCloseFrame? close,
    $core.List<$core.int>? payload,
  }) {
    final result = TransportFrame._();
    if (handshake != null) result.handshake = handshake;
    if (ping != null) result.ping = ping;
    if (pong != null) result.pong = pong;
    if (close != null) result.close = close;
    if (payload != null) result.payload = payload;
    return result;
  }

  TransportFrame._();

  factory TransportFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransportFrame()..mergeFromBuffer(data, registry);
  factory TransportFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransportFrame()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TransportFrame_Frame>
      _TransportFrame_FrameByTag = {
    1: TransportFrame_Frame.handshake,
    2: TransportFrame_Frame.ping,
    3: TransportFrame_Frame.pong,
    4: TransportFrame_Frame.close,
    5: TransportFrame_Frame.payload,
    0: TransportFrame_Frame.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransportFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransportFrame.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOM<HandshakeFrame>(1, _omitFieldNames ? '' : 'handshake',
        subBuilder: HandshakeFrame.$_createMessage)
    ..aOM<KeepalivePing>(2, _omitFieldNames ? '' : 'ping',
        subBuilder: KeepalivePing.$_createMessage)
    ..aOM<KeepalivePong>(3, _omitFieldNames ? '' : 'pong',
        subBuilder: KeepalivePong.$_createMessage)
    ..aOM<SessionCloseFrame>(4, _omitFieldNames ? '' : 'close',
        subBuilder: SessionCloseFrame.$_createMessage)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransportFrame copyWith(void Function(TransportFrame) updates) =>
      super.copyWith((message) => updates(message as TransportFrame))
          as TransportFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransportFrame() / TransportFrame.new instead')
  static TransportFrame create() => TransportFrame._();
  static $pb.GeneratedMessage $_createMessage() => TransportFrame._();
  @$core.override
  TransportFrame createEmptyInstance() => TransportFrame._();
  @$core.pragma('dart2js:noInline')
  static TransportFrame getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransportFrame>(
          TransportFrame.$_createMessage);
  static TransportFrame? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  TransportFrame_Frame whichFrame() =>
      _TransportFrame_FrameByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearFrame() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  HandshakeFrame get handshake => $_getN(0);
  @$pb.TagNumber(1)
  set handshake(HandshakeFrame value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHandshake() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandshake() => $_clearField(1);
  @$pb.TagNumber(1)
  HandshakeFrame ensureHandshake() => $_ensure(0);

  @$pb.TagNumber(2)
  KeepalivePing get ping => $_getN(1);
  @$pb.TagNumber(2)
  set ping(KeepalivePing value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPing() => $_has(1);
  @$pb.TagNumber(2)
  void clearPing() => $_clearField(2);
  @$pb.TagNumber(2)
  KeepalivePing ensurePing() => $_ensure(1);

  @$pb.TagNumber(3)
  KeepalivePong get pong => $_getN(2);
  @$pb.TagNumber(3)
  set pong(KeepalivePong value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPong() => $_has(2);
  @$pb.TagNumber(3)
  void clearPong() => $_clearField(3);
  @$pb.TagNumber(3)
  KeepalivePong ensurePong() => $_ensure(2);

  @$pb.TagNumber(4)
  SessionCloseFrame get close => $_getN(3);
  @$pb.TagNumber(4)
  set close(SessionCloseFrame value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasClose() => $_has(3);
  @$pb.TagNumber(4)
  void clearClose() => $_clearField(4);
  @$pb.TagNumber(4)
  SessionCloseFrame ensureClose() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.List<$core.int> get payload => $_getN(4);
  @$pb.TagNumber(5)
  set payload($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayload() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
