// This is a generated file - do not edit.
//
// Generated from peerlink/v1/capability.proto.

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
import 'error.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'capability.pbenum.dart';

/// Descriptive capability declaration.
/// Invariant: Capability is descriptive and may become stale; does not guarantee current environment permission.
class CapabilityDescriptor extends $pb.GeneratedMessage {
  factory CapabilityDescriptor({
    $core.String? capabilityName,
    $0.ProtocolVersion? version,
    $fixnum.Int64? validUntilUtcMs,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? parameters,
    $core.bool? isEnabled,
  }) {
    final result = CapabilityDescriptor._();
    if (capabilityName != null) result.capabilityName = capabilityName;
    if (version != null) result.version = version;
    if (validUntilUtcMs != null) result.validUntilUtcMs = validUntilUtcMs;
    if (parameters != null) result.parameters.addEntries(parameters);
    if (isEnabled != null) result.isEnabled = isEnabled;
    return result;
  }

  CapabilityDescriptor._();

  factory CapabilityDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityDescriptor()..mergeFromBuffer(data, registry);
  factory CapabilityDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityDescriptor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CapabilityDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CapabilityDescriptor.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'capabilityName')
    ..aOM<$0.ProtocolVersion>(2, _omitFieldNames ? '' : 'version',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'validUntilUtcMs')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'parameters',
        entryClassName: 'CapabilityDescriptor.ParametersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..aOB(5, _omitFieldNames ? '' : 'isEnabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityDescriptor copyWith(void Function(CapabilityDescriptor) updates) =>
      super.copyWith((message) => updates(message as CapabilityDescriptor))
          as CapabilityDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CapabilityDescriptor() / CapabilityDescriptor.new instead')
  static CapabilityDescriptor create() => CapabilityDescriptor._();
  static $pb.GeneratedMessage $_createMessage() => CapabilityDescriptor._();
  @$core.override
  CapabilityDescriptor createEmptyInstance() => CapabilityDescriptor._();
  @$core.pragma('dart2js:noInline')
  static CapabilityDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CapabilityDescriptor>(
          CapabilityDescriptor.$_createMessage);
  static CapabilityDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get capabilityName => $_getSZ(0);
  @$pb.TagNumber(1)
  set capabilityName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCapabilityName() => $_has(0);
  @$pb.TagNumber(1)
  void clearCapabilityName() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.ProtocolVersion get version => $_getN(1);
  @$pb.TagNumber(2)
  set version($0.ProtocolVersion value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.ProtocolVersion ensureVersion() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get validUntilUtcMs => $_getI64(2);
  @$pb.TagNumber(3)
  set validUntilUtcMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValidUntilUtcMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearValidUntilUtcMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get parameters => $_getMap(3);

  @$pb.TagNumber(5)
  $core.bool get isEnabled => $_getBF(4);
  @$pb.TagNumber(5)
  set isEnabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsEnabled() => $_clearField(5);
}

/// Capability negotiation handshake request
class CapabilityNegotiationRequest extends $pb.GeneratedMessage {
  factory CapabilityNegotiationRequest({
    $0.ProtocolHeader? header,
    $0.PeerId? senderPeerId,
    $0.ProtocolVersion? clientProtocolVersion,
    $0.ProtocolVersion? minCompatibleVersion,
    $core.Iterable<CapabilityDescriptor>? offeredCapabilities,
    $core.Iterable<$core.String>? requestedFeatures,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? featureFlags,
  }) {
    final result = CapabilityNegotiationRequest._();
    if (header != null) result.header = header;
    if (senderPeerId != null) result.senderPeerId = senderPeerId;
    if (clientProtocolVersion != null)
      result.clientProtocolVersion = clientProtocolVersion;
    if (minCompatibleVersion != null)
      result.minCompatibleVersion = minCompatibleVersion;
    if (offeredCapabilities != null)
      result.offeredCapabilities.addAll(offeredCapabilities);
    if (requestedFeatures != null)
      result.requestedFeatures.addAll(requestedFeatures);
    if (featureFlags != null) result.featureFlags.addEntries(featureFlags);
    return result;
  }

  CapabilityNegotiationRequest._();

  factory CapabilityNegotiationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityNegotiationRequest()..mergeFromBuffer(data, registry);
  factory CapabilityNegotiationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityNegotiationRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CapabilityNegotiationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CapabilityNegotiationRequest.$_createMessage)
    ..aOM<$0.ProtocolHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOM<$0.PeerId>(2, _omitFieldNames ? '' : 'senderPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.ProtocolVersion>(3, _omitFieldNames ? '' : 'clientProtocolVersion',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..aOM<$0.ProtocolVersion>(4, _omitFieldNames ? '' : 'minCompatibleVersion',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..pPM<CapabilityDescriptor>(5, _omitFieldNames ? '' : 'offeredCapabilities',
        subBuilder: CapabilityDescriptor.$_createMessage)
    ..pPS(6, _omitFieldNames ? '' : 'requestedFeatures')
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'featureFlags',
        entryClassName: 'CapabilityNegotiationRequest.FeatureFlagsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityNegotiationRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityNegotiationRequest copyWith(
          void Function(CapabilityNegotiationRequest) updates) =>
      super.copyWith(
              (message) => updates(message as CapabilityNegotiationRequest))
          as CapabilityNegotiationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CapabilityNegotiationRequest() / CapabilityNegotiationRequest.new instead')
  static CapabilityNegotiationRequest create() =>
      CapabilityNegotiationRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      CapabilityNegotiationRequest._();
  @$core.override
  CapabilityNegotiationRequest createEmptyInstance() =>
      CapabilityNegotiationRequest._();
  @$core.pragma('dart2js:noInline')
  static CapabilityNegotiationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CapabilityNegotiationRequest>(
          CapabilityNegotiationRequest.$_createMessage);
  static CapabilityNegotiationRequest? _defaultInstance;

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
  $0.PeerId get senderPeerId => $_getN(1);
  @$pb.TagNumber(2)
  set senderPeerId($0.PeerId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSenderPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSenderPeerId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PeerId ensureSenderPeerId() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.ProtocolVersion get clientProtocolVersion => $_getN(2);
  @$pb.TagNumber(3)
  set clientProtocolVersion($0.ProtocolVersion value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasClientProtocolVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearClientProtocolVersion() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.ProtocolVersion ensureClientProtocolVersion() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.ProtocolVersion get minCompatibleVersion => $_getN(3);
  @$pb.TagNumber(4)
  set minCompatibleVersion($0.ProtocolVersion value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasMinCompatibleVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearMinCompatibleVersion() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.ProtocolVersion ensureMinCompatibleVersion() => $_ensure(3);

  @$pb.TagNumber(5)
  $pb.PbList<CapabilityDescriptor> get offeredCapabilities => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get requestedFeatures => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbMap<$core.String, $core.String> get featureFlags => $_getMap(6);
}

/// Capability negotiation handshake response with graceful unsupported feature reporting
class CapabilityNegotiationResponse extends $pb.GeneratedMessage {
  factory CapabilityNegotiationResponse({
    $0.ProtocolHeader? header,
    $core.bool? isCompatible,
    $0.ProtocolVersion? agreedProtocolVersion,
    $core.Iterable<CapabilityDescriptor>? acceptedCapabilities,
    $core.Iterable<$core.String>? unsupportedFeatures,
    $1.ErrorDetail? error,
  }) {
    final result = CapabilityNegotiationResponse._();
    if (header != null) result.header = header;
    if (isCompatible != null) result.isCompatible = isCompatible;
    if (agreedProtocolVersion != null)
      result.agreedProtocolVersion = agreedProtocolVersion;
    if (acceptedCapabilities != null)
      result.acceptedCapabilities.addAll(acceptedCapabilities);
    if (unsupportedFeatures != null)
      result.unsupportedFeatures.addAll(unsupportedFeatures);
    if (error != null) result.error = error;
    return result;
  }

  CapabilityNegotiationResponse._();

  factory CapabilityNegotiationResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityNegotiationResponse()..mergeFromBuffer(data, registry);
  factory CapabilityNegotiationResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CapabilityNegotiationResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CapabilityNegotiationResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CapabilityNegotiationResponse.$_createMessage)
    ..aOM<$0.ProtocolHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'isCompatible')
    ..aOM<$0.ProtocolVersion>(3, _omitFieldNames ? '' : 'agreedProtocolVersion',
        subBuilder: $0.ProtocolVersion.$_createMessage)
    ..pPM<CapabilityDescriptor>(
        4, _omitFieldNames ? '' : 'acceptedCapabilities',
        subBuilder: CapabilityDescriptor.$_createMessage)
    ..pPS(5, _omitFieldNames ? '' : 'unsupportedFeatures')
    ..aOM<$1.ErrorDetail>(6, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityNegotiationResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CapabilityNegotiationResponse copyWith(
          void Function(CapabilityNegotiationResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CapabilityNegotiationResponse))
          as CapabilityNegotiationResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CapabilityNegotiationResponse() / CapabilityNegotiationResponse.new instead')
  static CapabilityNegotiationResponse create() =>
      CapabilityNegotiationResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      CapabilityNegotiationResponse._();
  @$core.override
  CapabilityNegotiationResponse createEmptyInstance() =>
      CapabilityNegotiationResponse._();
  @$core.pragma('dart2js:noInline')
  static CapabilityNegotiationResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CapabilityNegotiationResponse>(
          CapabilityNegotiationResponse.$_createMessage);
  static CapabilityNegotiationResponse? _defaultInstance;

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
  $core.bool get isCompatible => $_getBF(1);
  @$pb.TagNumber(2)
  set isCompatible($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsCompatible() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsCompatible() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.ProtocolVersion get agreedProtocolVersion => $_getN(2);
  @$pb.TagNumber(3)
  set agreedProtocolVersion($0.ProtocolVersion value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAgreedProtocolVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgreedProtocolVersion() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.ProtocolVersion ensureAgreedProtocolVersion() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<CapabilityDescriptor> get acceptedCapabilities => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get unsupportedFeatures => $_getList(4);

  @$pb.TagNumber(6)
  $1.ErrorDetail get error => $_getN(5);
  @$pb.TagNumber(6)
  set error($1.ErrorDetail value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasError() => $_has(5);
  @$pb.TagNumber(6)
  void clearError() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.ErrorDetail ensureError() => $_ensure(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
