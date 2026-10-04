// This is a generated file - do not edit.
//
// Generated from peerlink/v1/ipc.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'capability.pbenum.dart' as $4;
import 'common.pb.dart' as $1;
import 'ipc.pbenum.dart';
import 'operation.pb.dart' as $2;
import 'transfer.pb.dart' as $3;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'ipc.pbenum.dart';

class AuthenticateIpcRequest extends $pb.GeneratedMessage {
  factory AuthenticateIpcRequest({
    $core.String? authToken,
    $fixnum.Int64? clientPid,
    $core.String? clientVersion,
  }) {
    final result = AuthenticateIpcRequest._();
    if (authToken != null) result.authToken = authToken;
    if (clientPid != null) result.clientPid = clientPid;
    if (clientVersion != null) result.clientVersion = clientVersion;
    return result;
  }

  AuthenticateIpcRequest._();

  factory AuthenticateIpcRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AuthenticateIpcRequest()..mergeFromBuffer(data, registry);
  factory AuthenticateIpcRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AuthenticateIpcRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthenticateIpcRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AuthenticateIpcRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'authToken')
    ..aInt64(2, _omitFieldNames ? '' : 'clientPid')
    ..aOS(3, _omitFieldNames ? '' : 'clientVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthenticateIpcRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthenticateIpcRequest copyWith(
          void Function(AuthenticateIpcRequest) updates) =>
      super.copyWith((message) => updates(message as AuthenticateIpcRequest))
          as AuthenticateIpcRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AuthenticateIpcRequest() / AuthenticateIpcRequest.new instead')
  static AuthenticateIpcRequest create() => AuthenticateIpcRequest._();
  static $pb.GeneratedMessage $_createMessage() => AuthenticateIpcRequest._();
  @$core.override
  AuthenticateIpcRequest createEmptyInstance() => AuthenticateIpcRequest._();
  @$core.pragma('dart2js:noInline')
  static AuthenticateIpcRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthenticateIpcRequest>(
          AuthenticateIpcRequest.$_createMessage);
  static AuthenticateIpcRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get authToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set authToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get clientPid => $_getI64(1);
  @$pb.TagNumber(2)
  set clientPid($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientPid() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientPid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get clientVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set clientVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClientVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearClientVersion() => $_clearField(3);
}

class AuthenticateIpcResponse extends $pb.GeneratedMessage {
  factory AuthenticateIpcResponse({
    $core.bool? authenticated,
    $core.String? sessionToken,
    $core.String? nodeVersion,
    $1.PeerId? localPeerId,
    $core.String? errorMessage,
    $core.bool? isCompatible,
    $core.String? minCompatibleVersion,
  }) {
    final result = AuthenticateIpcResponse._();
    if (authenticated != null) result.authenticated = authenticated;
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (nodeVersion != null) result.nodeVersion = nodeVersion;
    if (localPeerId != null) result.localPeerId = localPeerId;
    if (errorMessage != null) result.errorMessage = errorMessage;
    if (isCompatible != null) result.isCompatible = isCompatible;
    if (minCompatibleVersion != null)
      result.minCompatibleVersion = minCompatibleVersion;
    return result;
  }

  AuthenticateIpcResponse._();

  factory AuthenticateIpcResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AuthenticateIpcResponse()..mergeFromBuffer(data, registry);
  factory AuthenticateIpcResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AuthenticateIpcResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthenticateIpcResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AuthenticateIpcResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'authenticated')
    ..aOS(2, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(3, _omitFieldNames ? '' : 'nodeVersion')
    ..aOM<$1.PeerId>(4, _omitFieldNames ? '' : 'localPeerId',
        subBuilder: $1.PeerId.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..aOB(6, _omitFieldNames ? '' : 'isCompatible')
    ..aOS(7, _omitFieldNames ? '' : 'minCompatibleVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthenticateIpcResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthenticateIpcResponse copyWith(
          void Function(AuthenticateIpcResponse) updates) =>
      super.copyWith((message) => updates(message as AuthenticateIpcResponse))
          as AuthenticateIpcResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AuthenticateIpcResponse() / AuthenticateIpcResponse.new instead')
  static AuthenticateIpcResponse create() => AuthenticateIpcResponse._();
  static $pb.GeneratedMessage $_createMessage() => AuthenticateIpcResponse._();
  @$core.override
  AuthenticateIpcResponse createEmptyInstance() => AuthenticateIpcResponse._();
  @$core.pragma('dart2js:noInline')
  static AuthenticateIpcResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthenticateIpcResponse>(
          AuthenticateIpcResponse.$_createMessage);
  static AuthenticateIpcResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get authenticated => $_getBF(0);
  @$pb.TagNumber(1)
  set authenticated($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthenticated() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthenticated() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get nodeVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set nodeVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNodeVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearNodeVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.PeerId get localPeerId => $_getN(3);
  @$pb.TagNumber(4)
  set localPeerId($1.PeerId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLocalPeerId() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocalPeerId() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.PeerId ensureLocalPeerId() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isCompatible => $_getBF(5);
  @$pb.TagNumber(6)
  set isCompatible($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsCompatible() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsCompatible() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get minCompatibleVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set minCompatibleVersion($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMinCompatibleVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearMinCompatibleVersion() => $_clearField(7);
}

class GetNodeStatusRequest extends $pb.GeneratedMessage {
  factory GetNodeStatusRequest({
    $core.String? sessionToken,
  }) {
    final result = GetNodeStatusRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    return result;
  }

  GetNodeStatusRequest._();

  factory GetNodeStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetNodeStatusRequest()..mergeFromBuffer(data, registry);
  factory GetNodeStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetNodeStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetNodeStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: GetNodeStatusRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNodeStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNodeStatusRequest copyWith(void Function(GetNodeStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetNodeStatusRequest))
          as GetNodeStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetNodeStatusRequest() / GetNodeStatusRequest.new instead')
  static GetNodeStatusRequest create() => GetNodeStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetNodeStatusRequest._();
  @$core.override
  GetNodeStatusRequest createEmptyInstance() => GetNodeStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static GetNodeStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetNodeStatusRequest>(
          GetNodeStatusRequest.$_createMessage);
  static GetNodeStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);
}

class GetNodeStatusResponse extends $pb.GeneratedMessage {
  factory GetNodeStatusResponse({
    NodeExecutionStatus? status,
    $1.PeerId? peerId,
    $core.int? listenPort,
    $core.Iterable<$4.FeatureCapability>? supportedCapabilities,
    $fixnum.Int64? uptimeSeconds,
    $fixnum.Int64? memoryUsedBytes,
    $core.String? nodeVersion,
    $core.int? activeSubscribers,
  }) {
    final result = GetNodeStatusResponse._();
    if (status != null) result.status = status;
    if (peerId != null) result.peerId = peerId;
    if (listenPort != null) result.listenPort = listenPort;
    if (supportedCapabilities != null)
      result.supportedCapabilities.addAll(supportedCapabilities);
    if (uptimeSeconds != null) result.uptimeSeconds = uptimeSeconds;
    if (memoryUsedBytes != null) result.memoryUsedBytes = memoryUsedBytes;
    if (nodeVersion != null) result.nodeVersion = nodeVersion;
    if (activeSubscribers != null) result.activeSubscribers = activeSubscribers;
    return result;
  }

  GetNodeStatusResponse._();

  factory GetNodeStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetNodeStatusResponse()..mergeFromBuffer(data, registry);
  factory GetNodeStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetNodeStatusResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetNodeStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: GetNodeStatusResponse.$_createMessage)
    ..aE<NodeExecutionStatus>(1, _omitFieldNames ? '' : 'status',
        enumValues: NodeExecutionStatus.values)
    ..aOM<$1.PeerId>(2, _omitFieldNames ? '' : 'peerId',
        subBuilder: $1.PeerId.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'listenPort')
    ..pc<$4.FeatureCapability>(
        4, _omitFieldNames ? '' : 'supportedCapabilities', $pb.PbFieldType.KE,
        valueOf: $4.FeatureCapability.valueOf,
        enumValues: $4.FeatureCapability.values,
        defaultEnumValue: $4.FeatureCapability.FEATURE_CAPABILITY_UNSPECIFIED)
    ..aInt64(5, _omitFieldNames ? '' : 'uptimeSeconds')
    ..aInt64(6, _omitFieldNames ? '' : 'memoryUsedBytes')
    ..aOS(7, _omitFieldNames ? '' : 'nodeVersion')
    ..aI(8, _omitFieldNames ? '' : 'activeSubscribers')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNodeStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNodeStatusResponse copyWith(
          void Function(GetNodeStatusResponse) updates) =>
      super.copyWith((message) => updates(message as GetNodeStatusResponse))
          as GetNodeStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetNodeStatusResponse() / GetNodeStatusResponse.new instead')
  static GetNodeStatusResponse create() => GetNodeStatusResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetNodeStatusResponse._();
  @$core.override
  GetNodeStatusResponse createEmptyInstance() => GetNodeStatusResponse._();
  @$core.pragma('dart2js:noInline')
  static GetNodeStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetNodeStatusResponse>(
          GetNodeStatusResponse.$_createMessage);
  static GetNodeStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  NodeExecutionStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(NodeExecutionStatus value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.PeerId get peerId => $_getN(1);
  @$pb.TagNumber(2)
  set peerId($1.PeerId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPeerId() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.PeerId ensurePeerId() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.int get listenPort => $_getIZ(2);
  @$pb.TagNumber(3)
  set listenPort($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasListenPort() => $_has(2);
  @$pb.TagNumber(3)
  void clearListenPort() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$4.FeatureCapability> get supportedCapabilities => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get uptimeSeconds => $_getI64(4);
  @$pb.TagNumber(5)
  set uptimeSeconds($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUptimeSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearUptimeSeconds() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get memoryUsedBytes => $_getI64(5);
  @$pb.TagNumber(6)
  set memoryUsedBytes($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMemoryUsedBytes() => $_has(5);
  @$pb.TagNumber(6)
  void clearMemoryUsedBytes() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get nodeVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set nodeVersion($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNodeVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearNodeVersion() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get activeSubscribers => $_getIZ(7);
  @$pb.TagNumber(8)
  set activeSubscribers($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasActiveSubscribers() => $_has(7);
  @$pb.TagNumber(8)
  void clearActiveSubscribers() => $_clearField(8);
}

class NodeEventSubscriptionRequest extends $pb.GeneratedMessage {
  factory NodeEventSubscriptionRequest({
    $core.String? sessionToken,
  }) {
    final result = NodeEventSubscriptionRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    return result;
  }

  NodeEventSubscriptionRequest._();

  factory NodeEventSubscriptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeEventSubscriptionRequest()..mergeFromBuffer(data, registry);
  factory NodeEventSubscriptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeEventSubscriptionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeEventSubscriptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: NodeEventSubscriptionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeEventSubscriptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeEventSubscriptionRequest copyWith(
          void Function(NodeEventSubscriptionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as NodeEventSubscriptionRequest))
          as NodeEventSubscriptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use NodeEventSubscriptionRequest() / NodeEventSubscriptionRequest.new instead')
  static NodeEventSubscriptionRequest create() =>
      NodeEventSubscriptionRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      NodeEventSubscriptionRequest._();
  @$core.override
  NodeEventSubscriptionRequest createEmptyInstance() =>
      NodeEventSubscriptionRequest._();
  @$core.pragma('dart2js:noInline')
  static NodeEventSubscriptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeEventSubscriptionRequest>(
          NodeEventSubscriptionRequest.$_createMessage);
  static NodeEventSubscriptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);
}

class NodeHeartbeat extends $pb.GeneratedMessage {
  factory NodeHeartbeat({
    $fixnum.Int64? timestampUtcMs,
    NodeExecutionStatus? status,
    $fixnum.Int64? uptimeSeconds,
    $fixnum.Int64? memoryUsedBytes,
    $fixnum.Int64? sequenceNumber,
  }) {
    final result = NodeHeartbeat._();
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (status != null) result.status = status;
    if (uptimeSeconds != null) result.uptimeSeconds = uptimeSeconds;
    if (memoryUsedBytes != null) result.memoryUsedBytes = memoryUsedBytes;
    if (sequenceNumber != null) result.sequenceNumber = sequenceNumber;
    return result;
  }

  NodeHeartbeat._();

  factory NodeHeartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeHeartbeat()..mergeFromBuffer(data, registry);
  factory NodeHeartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeHeartbeat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeHeartbeat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: NodeHeartbeat.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'timestampUtcMs')
    ..aE<NodeExecutionStatus>(2, _omitFieldNames ? '' : 'status',
        enumValues: NodeExecutionStatus.values)
    ..aInt64(3, _omitFieldNames ? '' : 'uptimeSeconds')
    ..aInt64(4, _omitFieldNames ? '' : 'memoryUsedBytes')
    ..aInt64(5, _omitFieldNames ? '' : 'sequenceNumber')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeHeartbeat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeHeartbeat copyWith(void Function(NodeHeartbeat) updates) =>
      super.copyWith((message) => updates(message as NodeHeartbeat))
          as NodeHeartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NodeHeartbeat() / NodeHeartbeat.new instead')
  static NodeHeartbeat create() => NodeHeartbeat._();
  static $pb.GeneratedMessage $_createMessage() => NodeHeartbeat._();
  @$core.override
  NodeHeartbeat createEmptyInstance() => NodeHeartbeat._();
  @$core.pragma('dart2js:noInline')
  static NodeHeartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NodeHeartbeat>(
          NodeHeartbeat.$_createMessage);
  static NodeHeartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get timestampUtcMs => $_getI64(0);
  @$pb.TagNumber(1)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimestampUtcMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestampUtcMs() => $_clearField(1);

  @$pb.TagNumber(2)
  NodeExecutionStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(NodeExecutionStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get uptimeSeconds => $_getI64(2);
  @$pb.TagNumber(3)
  set uptimeSeconds($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUptimeSeconds() => $_has(2);
  @$pb.TagNumber(3)
  void clearUptimeSeconds() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get memoryUsedBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set memoryUsedBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMemoryUsedBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearMemoryUsedBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get sequenceNumber => $_getI64(4);
  @$pb.TagNumber(5)
  set sequenceNumber($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSequenceNumber() => $_has(4);
  @$pb.TagNumber(5)
  void clearSequenceNumber() => $_clearField(5);
}

enum NodeEvent_Event {
  heartbeat,
  operationUpdate,
  securityAlert,
  lifecycleEvent,
  transferProgress,
  transferReceipt,
  notSet
}

class NodeEvent extends $pb.GeneratedMessage {
  factory NodeEvent({
    $fixnum.Int64? timestampUtcMs,
    NodeHeartbeat? heartbeat,
    $2.OperationRecord? operationUpdate,
    $core.String? securityAlert,
    $core.String? lifecycleEvent,
    $3.TransferProgress? transferProgress,
    $3.TransferCompletedReceipt? transferReceipt,
  }) {
    final result = NodeEvent._();
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (operationUpdate != null) result.operationUpdate = operationUpdate;
    if (securityAlert != null) result.securityAlert = securityAlert;
    if (lifecycleEvent != null) result.lifecycleEvent = lifecycleEvent;
    if (transferProgress != null) result.transferProgress = transferProgress;
    if (transferReceipt != null) result.transferReceipt = transferReceipt;
    return result;
  }

  NodeEvent._();

  factory NodeEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeEvent()..mergeFromBuffer(data, registry);
  factory NodeEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NodeEvent()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, NodeEvent_Event> _NodeEvent_EventByTag = {
    2: NodeEvent_Event.heartbeat,
    3: NodeEvent_Event.operationUpdate,
    4: NodeEvent_Event.securityAlert,
    5: NodeEvent_Event.lifecycleEvent,
    6: NodeEvent_Event.transferProgress,
    7: NodeEvent_Event.transferReceipt,
    0: NodeEvent_Event.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: NodeEvent.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 6, 7])
    ..aInt64(1, _omitFieldNames ? '' : 'timestampUtcMs')
    ..aOM<NodeHeartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: NodeHeartbeat.$_createMessage)
    ..aOM<$2.OperationRecord>(3, _omitFieldNames ? '' : 'operationUpdate',
        subBuilder: $2.OperationRecord.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'securityAlert')
    ..aOS(5, _omitFieldNames ? '' : 'lifecycleEvent')
    ..aOM<$3.TransferProgress>(6, _omitFieldNames ? '' : 'transferProgress',
        subBuilder: $3.TransferProgress.$_createMessage)
    ..aOM<$3.TransferCompletedReceipt>(
        7, _omitFieldNames ? '' : 'transferReceipt',
        subBuilder: $3.TransferCompletedReceipt.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeEvent copyWith(void Function(NodeEvent) updates) =>
      super.copyWith((message) => updates(message as NodeEvent)) as NodeEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NodeEvent() / NodeEvent.new instead')
  static NodeEvent create() => NodeEvent._();
  static $pb.GeneratedMessage $_createMessage() => NodeEvent._();
  @$core.override
  NodeEvent createEmptyInstance() => NodeEvent._();
  @$core.pragma('dart2js:noInline')
  static NodeEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeEvent>(NodeEvent.$_createMessage);
  static NodeEvent? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  NodeEvent_Event whichEvent() => _NodeEvent_EventByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearEvent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get timestampUtcMs => $_getI64(0);
  @$pb.TagNumber(1)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimestampUtcMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestampUtcMs() => $_clearField(1);

  @$pb.TagNumber(2)
  NodeHeartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat(NodeHeartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  NodeHeartbeat ensureHeartbeat() => $_ensure(1);

  @$pb.TagNumber(3)
  $2.OperationRecord get operationUpdate => $_getN(2);
  @$pb.TagNumber(3)
  set operationUpdate($2.OperationRecord value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOperationUpdate() => $_has(2);
  @$pb.TagNumber(3)
  void clearOperationUpdate() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.OperationRecord ensureOperationUpdate() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get securityAlert => $_getSZ(3);
  @$pb.TagNumber(4)
  set securityAlert($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSecurityAlert() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecurityAlert() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get lifecycleEvent => $_getSZ(4);
  @$pb.TagNumber(5)
  set lifecycleEvent($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLifecycleEvent() => $_has(4);
  @$pb.TagNumber(5)
  void clearLifecycleEvent() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.TransferProgress get transferProgress => $_getN(5);
  @$pb.TagNumber(6)
  set transferProgress($3.TransferProgress value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTransferProgress() => $_has(5);
  @$pb.TagNumber(6)
  void clearTransferProgress() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.TransferProgress ensureTransferProgress() => $_ensure(5);

  @$pb.TagNumber(7)
  $3.TransferCompletedReceipt get transferReceipt => $_getN(6);
  @$pb.TagNumber(7)
  set transferReceipt($3.TransferCompletedReceipt value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTransferReceipt() => $_has(6);
  @$pb.TagNumber(7)
  void clearTransferReceipt() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.TransferCompletedReceipt ensureTransferReceipt() => $_ensure(6);
}

class RestartNodeRequest extends $pb.GeneratedMessage {
  factory RestartNodeRequest({
    $core.String? sessionToken,
    $core.int? delayMs,
  }) {
    final result = RestartNodeRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (delayMs != null) result.delayMs = delayMs;
    return result;
  }

  RestartNodeRequest._();

  factory RestartNodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartNodeRequest()..mergeFromBuffer(data, registry);
  factory RestartNodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartNodeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestartNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RestartNodeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aI(2, _omitFieldNames ? '' : 'delayMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartNodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartNodeRequest copyWith(void Function(RestartNodeRequest) updates) =>
      super.copyWith((message) => updates(message as RestartNodeRequest))
          as RestartNodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RestartNodeRequest() / RestartNodeRequest.new instead')
  static RestartNodeRequest create() => RestartNodeRequest._();
  static $pb.GeneratedMessage $_createMessage() => RestartNodeRequest._();
  @$core.override
  RestartNodeRequest createEmptyInstance() => RestartNodeRequest._();
  @$core.pragma('dart2js:noInline')
  static RestartNodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestartNodeRequest>(
          RestartNodeRequest.$_createMessage);
  static RestartNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get delayMs => $_getIZ(1);
  @$pb.TagNumber(2)
  set delayMs($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDelayMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearDelayMs() => $_clearField(2);
}

class RestartNodeResponse extends $pb.GeneratedMessage {
  factory RestartNodeResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = RestartNodeResponse._();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  RestartNodeResponse._();

  factory RestartNodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartNodeResponse()..mergeFromBuffer(data, registry);
  factory RestartNodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartNodeResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestartNodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RestartNodeResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartNodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartNodeResponse copyWith(void Function(RestartNodeResponse) updates) =>
      super.copyWith((message) => updates(message as RestartNodeResponse))
          as RestartNodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RestartNodeResponse() / RestartNodeResponse.new instead')
  static RestartNodeResponse create() => RestartNodeResponse._();
  static $pb.GeneratedMessage $_createMessage() => RestartNodeResponse._();
  @$core.override
  RestartNodeResponse createEmptyInstance() => RestartNodeResponse._();
  @$core.pragma('dart2js:noInline')
  static RestartNodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestartNodeResponse>(
          RestartNodeResponse.$_createMessage);
  static RestartNodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class StopNodeRequest extends $pb.GeneratedMessage {
  factory StopNodeRequest({
    $core.String? sessionToken,
  }) {
    final result = StopNodeRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    return result;
  }

  StopNodeRequest._();

  factory StopNodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopNodeRequest()..mergeFromBuffer(data, registry);
  factory StopNodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopNodeRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: StopNodeRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopNodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopNodeRequest copyWith(void Function(StopNodeRequest) updates) =>
      super.copyWith((message) => updates(message as StopNodeRequest))
          as StopNodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopNodeRequest() / StopNodeRequest.new instead')
  static StopNodeRequest create() => StopNodeRequest._();
  static $pb.GeneratedMessage $_createMessage() => StopNodeRequest._();
  @$core.override
  StopNodeRequest createEmptyInstance() => StopNodeRequest._();
  @$core.pragma('dart2js:noInline')
  static StopNodeRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopNodeRequest>(
          StopNodeRequest.$_createMessage);
  static StopNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);
}

class StopNodeResponse extends $pb.GeneratedMessage {
  factory StopNodeResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = StopNodeResponse._();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  StopNodeResponse._();

  factory StopNodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopNodeResponse()..mergeFromBuffer(data, registry);
  factory StopNodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StopNodeResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StopNodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: StopNodeResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopNodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StopNodeResponse copyWith(void Function(StopNodeResponse) updates) =>
      super.copyWith((message) => updates(message as StopNodeResponse))
          as StopNodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StopNodeResponse() / StopNodeResponse.new instead')
  static StopNodeResponse create() => StopNodeResponse._();
  static $pb.GeneratedMessage $_createMessage() => StopNodeResponse._();
  @$core.override
  StopNodeResponse createEmptyInstance() => StopNodeResponse._();
  @$core.pragma('dart2js:noInline')
  static StopNodeResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StopNodeResponse>(
          StopNodeResponse.$_createMessage);
  static StopNodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class InitiateSendRequest extends $pb.GeneratedMessage {
  factory InitiateSendRequest({
    $core.String? sessionToken,
    $1.PeerId? targetPeerId,
    $core.Iterable<$core.String>? sourcePaths,
    $core.String? destinationFolder,
    $3.DuplicateDestinationPolicy? duplicatePolicy,
    $core.String? displayName,
  }) {
    final result = InitiateSendRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (targetPeerId != null) result.targetPeerId = targetPeerId;
    if (sourcePaths != null) result.sourcePaths.addAll(sourcePaths);
    if (destinationFolder != null) result.destinationFolder = destinationFolder;
    if (duplicatePolicy != null) result.duplicatePolicy = duplicatePolicy;
    if (displayName != null) result.displayName = displayName;
    return result;
  }

  InitiateSendRequest._();

  factory InitiateSendRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InitiateSendRequest()..mergeFromBuffer(data, registry);
  factory InitiateSendRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InitiateSendRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InitiateSendRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: InitiateSendRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOM<$1.PeerId>(2, _omitFieldNames ? '' : 'targetPeerId',
        subBuilder: $1.PeerId.$_createMessage)
    ..pPS(3, _omitFieldNames ? '' : 'sourcePaths')
    ..aOS(4, _omitFieldNames ? '' : 'destinationFolder')
    ..aE<$3.DuplicateDestinationPolicy>(
        5, _omitFieldNames ? '' : 'duplicatePolicy',
        enumValues: $3.DuplicateDestinationPolicy.values)
    ..aOS(6, _omitFieldNames ? '' : 'displayName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InitiateSendRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InitiateSendRequest copyWith(void Function(InitiateSendRequest) updates) =>
      super.copyWith((message) => updates(message as InitiateSendRequest))
          as InitiateSendRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use InitiateSendRequest() / InitiateSendRequest.new instead')
  static InitiateSendRequest create() => InitiateSendRequest._();
  static $pb.GeneratedMessage $_createMessage() => InitiateSendRequest._();
  @$core.override
  InitiateSendRequest createEmptyInstance() => InitiateSendRequest._();
  @$core.pragma('dart2js:noInline')
  static InitiateSendRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InitiateSendRequest>(
          InitiateSendRequest.$_createMessage);
  static InitiateSendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.PeerId get targetPeerId => $_getN(1);
  @$pb.TagNumber(2)
  set targetPeerId($1.PeerId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetPeerId() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.PeerId ensureTargetPeerId() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get sourcePaths => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get destinationFolder => $_getSZ(3);
  @$pb.TagNumber(4)
  set destinationFolder($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDestinationFolder() => $_has(3);
  @$pb.TagNumber(4)
  void clearDestinationFolder() => $_clearField(4);

  @$pb.TagNumber(5)
  $3.DuplicateDestinationPolicy get duplicatePolicy => $_getN(4);
  @$pb.TagNumber(5)
  set duplicatePolicy($3.DuplicateDestinationPolicy value) =>
      $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDuplicatePolicy() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuplicatePolicy() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get displayName => $_getSZ(5);
  @$pb.TagNumber(6)
  set displayName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDisplayName() => $_has(5);
  @$pb.TagNumber(6)
  void clearDisplayName() => $_clearField(6);
}

class InitiateSendResponse extends $pb.GeneratedMessage {
  factory InitiateSendResponse({
    $core.bool? accepted,
    $core.String? transferId,
    $1.OperationId? operationId,
    $fixnum.Int64? totalBytes,
    $core.int? fileCount,
    $core.String? errorMessage,
  }) {
    final result = InitiateSendResponse._();
    if (accepted != null) result.accepted = accepted;
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (fileCount != null) result.fileCount = fileCount;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  InitiateSendResponse._();

  factory InitiateSendResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InitiateSendResponse()..mergeFromBuffer(data, registry);
  factory InitiateSendResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InitiateSendResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InitiateSendResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: InitiateSendResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'transferId')
    ..aOM<$1.OperationId>(3, _omitFieldNames ? '' : 'operationId',
        subBuilder: $1.OperationId.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'totalBytes')
    ..aI(5, _omitFieldNames ? '' : 'fileCount')
    ..aOS(6, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InitiateSendResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InitiateSendResponse copyWith(void Function(InitiateSendResponse) updates) =>
      super.copyWith((message) => updates(message as InitiateSendResponse))
          as InitiateSendResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use InitiateSendResponse() / InitiateSendResponse.new instead')
  static InitiateSendResponse create() => InitiateSendResponse._();
  static $pb.GeneratedMessage $_createMessage() => InitiateSendResponse._();
  @$core.override
  InitiateSendResponse createEmptyInstance() => InitiateSendResponse._();
  @$core.pragma('dart2js:noInline')
  static InitiateSendResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InitiateSendResponse>(
          InitiateSendResponse.$_createMessage);
  static InitiateSendResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transferId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transferId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransferId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransferId() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.OperationId get operationId => $_getN(2);
  @$pb.TagNumber(3)
  set operationId($1.OperationId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasOperationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOperationId() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.OperationId ensureOperationId() => $_ensure(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get totalBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set totalBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get fileCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set fileCount($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFileCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearFileCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get errorMessage => $_getSZ(5);
  @$pb.TagNumber(6)
  set errorMessage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasErrorMessage() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorMessage() => $_clearField(6);
}

class CancelTransferRequest extends $pb.GeneratedMessage {
  factory CancelTransferRequest({
    $core.String? sessionToken,
    $core.String? transferId,
    $core.String? reason,
  }) {
    final result = CancelTransferRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (transferId != null) result.transferId = transferId;
    if (reason != null) result.reason = reason;
    return result;
  }

  CancelTransferRequest._();

  factory CancelTransferRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTransferRequest()..mergeFromBuffer(data, registry);
  factory CancelTransferRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTransferRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelTransferRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CancelTransferRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(2, _omitFieldNames ? '' : 'transferId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTransferRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTransferRequest copyWith(
          void Function(CancelTransferRequest) updates) =>
      super.copyWith((message) => updates(message as CancelTransferRequest))
          as CancelTransferRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CancelTransferRequest() / CancelTransferRequest.new instead')
  static CancelTransferRequest create() => CancelTransferRequest._();
  static $pb.GeneratedMessage $_createMessage() => CancelTransferRequest._();
  @$core.override
  CancelTransferRequest createEmptyInstance() => CancelTransferRequest._();
  @$core.pragma('dart2js:noInline')
  static CancelTransferRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelTransferRequest>(
          CancelTransferRequest.$_createMessage);
  static CancelTransferRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transferId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transferId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransferId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransferId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

class CancelTransferResponse extends $pb.GeneratedMessage {
  factory CancelTransferResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = CancelTransferResponse._();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  CancelTransferResponse._();

  factory CancelTransferResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTransferResponse()..mergeFromBuffer(data, registry);
  factory CancelTransferResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTransferResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelTransferResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CancelTransferResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTransferResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTransferResponse copyWith(
          void Function(CancelTransferResponse) updates) =>
      super.copyWith((message) => updates(message as CancelTransferResponse))
          as CancelTransferResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CancelTransferResponse() / CancelTransferResponse.new instead')
  static CancelTransferResponse create() => CancelTransferResponse._();
  static $pb.GeneratedMessage $_createMessage() => CancelTransferResponse._();
  @$core.override
  CancelTransferResponse createEmptyInstance() => CancelTransferResponse._();
  @$core.pragma('dart2js:noInline')
  static CancelTransferResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelTransferResponse>(
          CancelTransferResponse.$_createMessage);
  static CancelTransferResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class GetTransferRequest extends $pb.GeneratedMessage {
  factory GetTransferRequest({
    $core.String? sessionToken,
    $core.String? transferId,
  }) {
    final result = GetTransferRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (transferId != null) result.transferId = transferId;
    return result;
  }

  GetTransferRequest._();

  factory GetTransferRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTransferRequest()..mergeFromBuffer(data, registry);
  factory GetTransferRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTransferRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTransferRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: GetTransferRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(2, _omitFieldNames ? '' : 'transferId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTransferRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTransferRequest copyWith(void Function(GetTransferRequest) updates) =>
      super.copyWith((message) => updates(message as GetTransferRequest))
          as GetTransferRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetTransferRequest() / GetTransferRequest.new instead')
  static GetTransferRequest create() => GetTransferRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetTransferRequest._();
  @$core.override
  GetTransferRequest createEmptyInstance() => GetTransferRequest._();
  @$core.pragma('dart2js:noInline')
  static GetTransferRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTransferRequest>(
          GetTransferRequest.$_createMessage);
  static GetTransferRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transferId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transferId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransferId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransferId() => $_clearField(2);
}

class GetTransferResponse extends $pb.GeneratedMessage {
  factory GetTransferResponse({
    $3.TransferDescriptor? transferDescriptor,
    $3.TransferProgress? progress,
    $core.bool? found,
  }) {
    final result = GetTransferResponse._();
    if (transferDescriptor != null)
      result.transferDescriptor = transferDescriptor;
    if (progress != null) result.progress = progress;
    if (found != null) result.found = found;
    return result;
  }

  GetTransferResponse._();

  factory GetTransferResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTransferResponse()..mergeFromBuffer(data, registry);
  factory GetTransferResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTransferResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTransferResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: GetTransferResponse.$_createMessage)
    ..aOM<$3.TransferDescriptor>(1, _omitFieldNames ? '' : 'transferDescriptor',
        subBuilder: $3.TransferDescriptor.$_createMessage)
    ..aOM<$3.TransferProgress>(2, _omitFieldNames ? '' : 'progress',
        subBuilder: $3.TransferProgress.$_createMessage)
    ..aOB(3, _omitFieldNames ? '' : 'found')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTransferResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTransferResponse copyWith(void Function(GetTransferResponse) updates) =>
      super.copyWith((message) => updates(message as GetTransferResponse))
          as GetTransferResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use GetTransferResponse() / GetTransferResponse.new instead')
  static GetTransferResponse create() => GetTransferResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetTransferResponse._();
  @$core.override
  GetTransferResponse createEmptyInstance() => GetTransferResponse._();
  @$core.pragma('dart2js:noInline')
  static GetTransferResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTransferResponse>(
          GetTransferResponse.$_createMessage);
  static GetTransferResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $3.TransferDescriptor get transferDescriptor => $_getN(0);
  @$pb.TagNumber(1)
  set transferDescriptor($3.TransferDescriptor value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferDescriptor() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferDescriptor() => $_clearField(1);
  @$pb.TagNumber(1)
  $3.TransferDescriptor ensureTransferDescriptor() => $_ensure(0);

  @$pb.TagNumber(2)
  $3.TransferProgress get progress => $_getN(1);
  @$pb.TagNumber(2)
  set progress($3.TransferProgress value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.TransferProgress ensureProgress() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.bool get found => $_getBF(2);
  @$pb.TagNumber(3)
  set found($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFound() => $_has(2);
  @$pb.TagNumber(3)
  void clearFound() => $_clearField(3);
}

class ListTransfersRequest extends $pb.GeneratedMessage {
  factory ListTransfersRequest({
    $core.String? sessionToken,
    $core.bool? activeOnly,
  }) {
    final result = ListTransfersRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (activeOnly != null) result.activeOnly = activeOnly;
    return result;
  }

  ListTransfersRequest._();

  factory ListTransfersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTransfersRequest()..mergeFromBuffer(data, registry);
  factory ListTransfersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTransfersRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTransfersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ListTransfersRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOB(2, _omitFieldNames ? '' : 'activeOnly')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransfersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransfersRequest copyWith(void Function(ListTransfersRequest) updates) =>
      super.copyWith((message) => updates(message as ListTransfersRequest))
          as ListTransfersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListTransfersRequest() / ListTransfersRequest.new instead')
  static ListTransfersRequest create() => ListTransfersRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListTransfersRequest._();
  @$core.override
  ListTransfersRequest createEmptyInstance() => ListTransfersRequest._();
  @$core.pragma('dart2js:noInline')
  static ListTransfersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTransfersRequest>(
          ListTransfersRequest.$_createMessage);
  static ListTransfersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get activeOnly => $_getBF(1);
  @$pb.TagNumber(2)
  set activeOnly($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveOnly() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveOnly() => $_clearField(2);
}

class ListTransfersResponse extends $pb.GeneratedMessage {
  factory ListTransfersResponse({
    $core.Iterable<$3.TransferProgress>? transfers,
  }) {
    final result = ListTransfersResponse._();
    if (transfers != null) result.transfers.addAll(transfers);
    return result;
  }

  ListTransfersResponse._();

  factory ListTransfersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTransfersResponse()..mergeFromBuffer(data, registry);
  factory ListTransfersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTransfersResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTransfersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ListTransfersResponse.$_createMessage)
    ..pPM<$3.TransferProgress>(1, _omitFieldNames ? '' : 'transfers',
        subBuilder: $3.TransferProgress.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransfersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTransfersResponse copyWith(
          void Function(ListTransfersResponse) updates) =>
      super.copyWith((message) => updates(message as ListTransfersResponse))
          as ListTransfersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListTransfersResponse() / ListTransfersResponse.new instead')
  static ListTransfersResponse create() => ListTransfersResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListTransfersResponse._();
  @$core.override
  ListTransfersResponse createEmptyInstance() => ListTransfersResponse._();
  @$core.pragma('dart2js:noInline')
  static ListTransfersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTransfersResponse>(
          ListTransfersResponse.$_createMessage);
  static ListTransfersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$3.TransferProgress> get transfers => $_getList(0);
}

class RevealInFolderRequest extends $pb.GeneratedMessage {
  factory RevealInFolderRequest({
    $core.String? sessionToken,
    $core.String? fileOrFolderPath,
  }) {
    final result = RevealInFolderRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (fileOrFolderPath != null) result.fileOrFolderPath = fileOrFolderPath;
    return result;
  }

  RevealInFolderRequest._();

  factory RevealInFolderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevealInFolderRequest()..mergeFromBuffer(data, registry);
  factory RevealInFolderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevealInFolderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevealInFolderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RevealInFolderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(2, _omitFieldNames ? '' : 'fileOrFolderPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevealInFolderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevealInFolderRequest copyWith(
          void Function(RevealInFolderRequest) updates) =>
      super.copyWith((message) => updates(message as RevealInFolderRequest))
          as RevealInFolderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RevealInFolderRequest() / RevealInFolderRequest.new instead')
  static RevealInFolderRequest create() => RevealInFolderRequest._();
  static $pb.GeneratedMessage $_createMessage() => RevealInFolderRequest._();
  @$core.override
  RevealInFolderRequest createEmptyInstance() => RevealInFolderRequest._();
  @$core.pragma('dart2js:noInline')
  static RevealInFolderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevealInFolderRequest>(
          RevealInFolderRequest.$_createMessage);
  static RevealInFolderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fileOrFolderPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set fileOrFolderPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileOrFolderPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileOrFolderPath() => $_clearField(2);
}

class RevealInFolderResponse extends $pb.GeneratedMessage {
  factory RevealInFolderResponse({
    $core.bool? opened,
    $core.String? errorMessage,
  }) {
    final result = RevealInFolderResponse._();
    if (opened != null) result.opened = opened;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  RevealInFolderResponse._();

  factory RevealInFolderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevealInFolderResponse()..mergeFromBuffer(data, registry);
  factory RevealInFolderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevealInFolderResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevealInFolderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RevealInFolderResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'opened')
    ..aOS(2, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevealInFolderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevealInFolderResponse copyWith(
          void Function(RevealInFolderResponse) updates) =>
      super.copyWith((message) => updates(message as RevealInFolderResponse))
          as RevealInFolderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RevealInFolderResponse() / RevealInFolderResponse.new instead')
  static RevealInFolderResponse create() => RevealInFolderResponse._();
  static $pb.GeneratedMessage $_createMessage() => RevealInFolderResponse._();
  @$core.override
  RevealInFolderResponse createEmptyInstance() => RevealInFolderResponse._();
  @$core.pragma('dart2js:noInline')
  static RevealInFolderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevealInFolderResponse>(
          RevealInFolderResponse.$_createMessage);
  static RevealInFolderResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get opened => $_getBF(0);
  @$pb.TagNumber(1)
  set opened($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOpened() => $_has(0);
  @$pb.TagNumber(1)
  void clearOpened() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get errorMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set errorMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasErrorMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorMessage() => $_clearField(2);
}

class PauseTransferRequest extends $pb.GeneratedMessage {
  factory PauseTransferRequest({
    $core.String? sessionToken,
    $core.String? transferId,
    $core.String? reason,
  }) {
    final result = PauseTransferRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (transferId != null) result.transferId = transferId;
    if (reason != null) result.reason = reason;
    return result;
  }

  PauseTransferRequest._();

  factory PauseTransferRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PauseTransferRequest()..mergeFromBuffer(data, registry);
  factory PauseTransferRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PauseTransferRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PauseTransferRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PauseTransferRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(2, _omitFieldNames ? '' : 'transferId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PauseTransferRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PauseTransferRequest copyWith(void Function(PauseTransferRequest) updates) =>
      super.copyWith((message) => updates(message as PauseTransferRequest))
          as PauseTransferRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PauseTransferRequest() / PauseTransferRequest.new instead')
  static PauseTransferRequest create() => PauseTransferRequest._();
  static $pb.GeneratedMessage $_createMessage() => PauseTransferRequest._();
  @$core.override
  PauseTransferRequest createEmptyInstance() => PauseTransferRequest._();
  @$core.pragma('dart2js:noInline')
  static PauseTransferRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PauseTransferRequest>(
          PauseTransferRequest.$_createMessage);
  static PauseTransferRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transferId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transferId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransferId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransferId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

class PauseTransferResponse extends $pb.GeneratedMessage {
  factory PauseTransferResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = PauseTransferResponse._();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  PauseTransferResponse._();

  factory PauseTransferResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PauseTransferResponse()..mergeFromBuffer(data, registry);
  factory PauseTransferResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PauseTransferResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PauseTransferResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PauseTransferResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PauseTransferResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PauseTransferResponse copyWith(
          void Function(PauseTransferResponse) updates) =>
      super.copyWith((message) => updates(message as PauseTransferResponse))
          as PauseTransferResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PauseTransferResponse() / PauseTransferResponse.new instead')
  static PauseTransferResponse create() => PauseTransferResponse._();
  static $pb.GeneratedMessage $_createMessage() => PauseTransferResponse._();
  @$core.override
  PauseTransferResponse createEmptyInstance() => PauseTransferResponse._();
  @$core.pragma('dart2js:noInline')
  static PauseTransferResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PauseTransferResponse>(
          PauseTransferResponse.$_createMessage);
  static PauseTransferResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class ResumeTransferRequest extends $pb.GeneratedMessage {
  factory ResumeTransferRequest({
    $core.String? sessionToken,
    $core.String? transferId,
  }) {
    final result = ResumeTransferRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (transferId != null) result.transferId = transferId;
    return result;
  }

  ResumeTransferRequest._();

  factory ResumeTransferRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResumeTransferRequest()..mergeFromBuffer(data, registry);
  factory ResumeTransferRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResumeTransferRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResumeTransferRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ResumeTransferRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(2, _omitFieldNames ? '' : 'transferId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResumeTransferRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResumeTransferRequest copyWith(
          void Function(ResumeTransferRequest) updates) =>
      super.copyWith((message) => updates(message as ResumeTransferRequest))
          as ResumeTransferRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ResumeTransferRequest() / ResumeTransferRequest.new instead')
  static ResumeTransferRequest create() => ResumeTransferRequest._();
  static $pb.GeneratedMessage $_createMessage() => ResumeTransferRequest._();
  @$core.override
  ResumeTransferRequest createEmptyInstance() => ResumeTransferRequest._();
  @$core.pragma('dart2js:noInline')
  static ResumeTransferRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResumeTransferRequest>(
          ResumeTransferRequest.$_createMessage);
  static ResumeTransferRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transferId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transferId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransferId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransferId() => $_clearField(2);
}

class ResumeTransferResponse extends $pb.GeneratedMessage {
  factory ResumeTransferResponse({
    $core.bool? accepted,
    $core.String? message,
  }) {
    final result = ResumeTransferResponse._();
    if (accepted != null) result.accepted = accepted;
    if (message != null) result.message = message;
    return result;
  }

  ResumeTransferResponse._();

  factory ResumeTransferResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResumeTransferResponse()..mergeFromBuffer(data, registry);
  factory ResumeTransferResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResumeTransferResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResumeTransferResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ResumeTransferResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResumeTransferResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResumeTransferResponse copyWith(
          void Function(ResumeTransferResponse) updates) =>
      super.copyWith((message) => updates(message as ResumeTransferResponse))
          as ResumeTransferResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ResumeTransferResponse() / ResumeTransferResponse.new instead')
  static ResumeTransferResponse create() => ResumeTransferResponse._();
  static $pb.GeneratedMessage $_createMessage() => ResumeTransferResponse._();
  @$core.override
  ResumeTransferResponse createEmptyInstance() => ResumeTransferResponse._();
  @$core.pragma('dart2js:noInline')
  static ResumeTransferResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResumeTransferResponse>(
          ResumeTransferResponse.$_createMessage);
  static ResumeTransferResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class SetBandwidthLimitRequest extends $pb.GeneratedMessage {
  factory SetBandwidthLimitRequest({
    $core.String? sessionToken,
    $fixnum.Int64? maxBytesPerSec,
  }) {
    final result = SetBandwidthLimitRequest._();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (maxBytesPerSec != null) result.maxBytesPerSec = maxBytesPerSec;
    return result;
  }

  SetBandwidthLimitRequest._();

  factory SetBandwidthLimitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetBandwidthLimitRequest()..mergeFromBuffer(data, registry);
  factory SetBandwidthLimitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetBandwidthLimitRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetBandwidthLimitRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SetBandwidthLimitRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aInt64(2, _omitFieldNames ? '' : 'maxBytesPerSec')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetBandwidthLimitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetBandwidthLimitRequest copyWith(
          void Function(SetBandwidthLimitRequest) updates) =>
      super.copyWith((message) => updates(message as SetBandwidthLimitRequest))
          as SetBandwidthLimitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetBandwidthLimitRequest() / SetBandwidthLimitRequest.new instead')
  static SetBandwidthLimitRequest create() => SetBandwidthLimitRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetBandwidthLimitRequest._();
  @$core.override
  SetBandwidthLimitRequest createEmptyInstance() =>
      SetBandwidthLimitRequest._();
  @$core.pragma('dart2js:noInline')
  static SetBandwidthLimitRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetBandwidthLimitRequest>(
          SetBandwidthLimitRequest.$_createMessage);
  static SetBandwidthLimitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get maxBytesPerSec => $_getI64(1);
  @$pb.TagNumber(2)
  set maxBytesPerSec($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaxBytesPerSec() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaxBytesPerSec() => $_clearField(2);
}

class SetBandwidthLimitResponse extends $pb.GeneratedMessage {
  factory SetBandwidthLimitResponse({
    $core.bool? accepted,
    $fixnum.Int64? currentLimitBps,
  }) {
    final result = SetBandwidthLimitResponse._();
    if (accepted != null) result.accepted = accepted;
    if (currentLimitBps != null) result.currentLimitBps = currentLimitBps;
    return result;
  }

  SetBandwidthLimitResponse._();

  factory SetBandwidthLimitResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetBandwidthLimitResponse()..mergeFromBuffer(data, registry);
  factory SetBandwidthLimitResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetBandwidthLimitResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetBandwidthLimitResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: SetBandwidthLimitResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aInt64(2, _omitFieldNames ? '' : 'currentLimitBps')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetBandwidthLimitResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetBandwidthLimitResponse copyWith(
          void Function(SetBandwidthLimitResponse) updates) =>
      super.copyWith((message) => updates(message as SetBandwidthLimitResponse))
          as SetBandwidthLimitResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetBandwidthLimitResponse() / SetBandwidthLimitResponse.new instead')
  static SetBandwidthLimitResponse create() => SetBandwidthLimitResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      SetBandwidthLimitResponse._();
  @$core.override
  SetBandwidthLimitResponse createEmptyInstance() =>
      SetBandwidthLimitResponse._();
  @$core.pragma('dart2js:noInline')
  static SetBandwidthLimitResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetBandwidthLimitResponse>(
          SetBandwidthLimitResponse.$_createMessage);
  static SetBandwidthLimitResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get currentLimitBps => $_getI64(1);
  @$pb.TagNumber(2)
  set currentLimitBps($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrentLimitBps() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrentLimitBps() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
