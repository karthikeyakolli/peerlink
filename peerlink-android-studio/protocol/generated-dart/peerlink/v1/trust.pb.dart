// This is a generated file - do not edit.
//
// Generated from peerlink/v1/trust.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'error.pb.dart' as $1;
import 'identity.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class PairingRequest extends $pb.GeneratedMessage {
  factory PairingRequest({
    $0.PeerIdentity? initiator,
    $fixnum.Int64? timestampUtcMs,
    $core.String? pairingSecretHash,
  }) {
    final result = PairingRequest._();
    if (initiator != null) result.initiator = initiator;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (pairingSecretHash != null) result.pairingSecretHash = pairingSecretHash;
    return result;
  }

  PairingRequest._();

  factory PairingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingRequest()..mergeFromBuffer(data, registry);
  factory PairingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PairingRequest.$_createMessage)
    ..aOM<$0.PeerIdentity>(1, _omitFieldNames ? '' : 'initiator',
        subBuilder: $0.PeerIdentity.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'timestampUtcMs')
    ..aOS(3, _omitFieldNames ? '' : 'pairingSecretHash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingRequest copyWith(void Function(PairingRequest) updates) =>
      super.copyWith((message) => updates(message as PairingRequest))
          as PairingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairingRequest() / PairingRequest.new instead')
  static PairingRequest create() => PairingRequest._();
  static $pb.GeneratedMessage $_createMessage() => PairingRequest._();
  @$core.override
  PairingRequest createEmptyInstance() => PairingRequest._();
  @$core.pragma('dart2js:noInline')
  static PairingRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairingRequest>(
          PairingRequest.$_createMessage);
  static PairingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.PeerIdentity get initiator => $_getN(0);
  @$pb.TagNumber(1)
  set initiator($0.PeerIdentity value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasInitiator() => $_has(0);
  @$pb.TagNumber(1)
  void clearInitiator() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.PeerIdentity ensureInitiator() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get timestampUtcMs => $_getI64(1);
  @$pb.TagNumber(2)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimestampUtcMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestampUtcMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get pairingSecretHash => $_getSZ(2);
  @$pb.TagNumber(3)
  set pairingSecretHash($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPairingSecretHash() => $_has(2);
  @$pb.TagNumber(3)
  void clearPairingSecretHash() => $_clearField(3);
}

class PairingResponse extends $pb.GeneratedMessage {
  factory PairingResponse({
    $core.bool? accepted,
    $0.PeerIdentity? responder,
    $1.ErrorDetail? error,
  }) {
    final result = PairingResponse._();
    if (accepted != null) result.accepted = accepted;
    if (responder != null) result.responder = responder;
    if (error != null) result.error = error;
    return result;
  }

  PairingResponse._();

  factory PairingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingResponse()..mergeFromBuffer(data, registry);
  factory PairingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PairingResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'accepted')
    ..aOM<$0.PeerIdentity>(2, _omitFieldNames ? '' : 'responder',
        subBuilder: $0.PeerIdentity.$_createMessage)
    ..aOM<$1.ErrorDetail>(3, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingResponse copyWith(void Function(PairingResponse) updates) =>
      super.copyWith((message) => updates(message as PairingResponse))
          as PairingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairingResponse() / PairingResponse.new instead')
  static PairingResponse create() => PairingResponse._();
  static $pb.GeneratedMessage $_createMessage() => PairingResponse._();
  @$core.override
  PairingResponse createEmptyInstance() => PairingResponse._();
  @$core.pragma('dart2js:noInline')
  static PairingResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairingResponse>(
          PairingResponse.$_createMessage);
  static PairingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get accepted => $_getBF(0);
  @$pb.TagNumber(1)
  set accepted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.PeerIdentity get responder => $_getN(1);
  @$pb.TagNumber(2)
  set responder($0.PeerIdentity value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResponder() => $_has(1);
  @$pb.TagNumber(2)
  void clearResponder() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PeerIdentity ensureResponder() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.ErrorDetail get error => $_getN(2);
  @$pb.TagNumber(3)
  set error($1.ErrorDetail value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.ErrorDetail ensureError() => $_ensure(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
