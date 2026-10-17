// This is a generated file - do not edit.
//
// Generated from peerlink/v1/pairing.proto.

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
import 'pairing.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'pairing.pbenum.dart';

class PairingOffer extends $pb.GeneratedMessage {
  factory PairingOffer({
    $core.String? pairingSessionId,
    $0.PeerIdentity? initiatorPeer,
    $0.DeviceIdentity? initiatorDevice,
    $core.String? pairingCode,
    $core.String? qrPayload,
    $core.String? expectedFingerprint,
    PairingMethod? method,
    $fixnum.Int64? expiresAtUtcMs,
    $core.List<$core.int>? offerSignature,
  }) {
    final result = PairingOffer._();
    if (pairingSessionId != null) result.pairingSessionId = pairingSessionId;
    if (initiatorPeer != null) result.initiatorPeer = initiatorPeer;
    if (initiatorDevice != null) result.initiatorDevice = initiatorDevice;
    if (pairingCode != null) result.pairingCode = pairingCode;
    if (qrPayload != null) result.qrPayload = qrPayload;
    if (expectedFingerprint != null)
      result.expectedFingerprint = expectedFingerprint;
    if (method != null) result.method = method;
    if (expiresAtUtcMs != null) result.expiresAtUtcMs = expiresAtUtcMs;
    if (offerSignature != null) result.offerSignature = offerSignature;
    return result;
  }

  PairingOffer._();

  factory PairingOffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingOffer()..mergeFromBuffer(data, registry);
  factory PairingOffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingOffer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingOffer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PairingOffer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pairingSessionId')
    ..aOM<$0.PeerIdentity>(2, _omitFieldNames ? '' : 'initiatorPeer',
        subBuilder: $0.PeerIdentity.$_createMessage)
    ..aOM<$0.DeviceIdentity>(3, _omitFieldNames ? '' : 'initiatorDevice',
        subBuilder: $0.DeviceIdentity.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'pairingCode')
    ..aOS(5, _omitFieldNames ? '' : 'qrPayload')
    ..aOS(6, _omitFieldNames ? '' : 'expectedFingerprint')
    ..aE<PairingMethod>(7, _omitFieldNames ? '' : 'method',
        enumValues: PairingMethod.values)
    ..aInt64(8, _omitFieldNames ? '' : 'expiresAtUtcMs')
    ..a<$core.List<$core.int>>(
        9, _omitFieldNames ? '' : 'offerSignature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingOffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingOffer copyWith(void Function(PairingOffer) updates) =>
      super.copyWith((message) => updates(message as PairingOffer))
          as PairingOffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairingOffer() / PairingOffer.new instead')
  static PairingOffer create() => PairingOffer._();
  static $pb.GeneratedMessage $_createMessage() => PairingOffer._();
  @$core.override
  PairingOffer createEmptyInstance() => PairingOffer._();
  @$core.pragma('dart2js:noInline')
  static PairingOffer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairingOffer>(
          PairingOffer.$_createMessage);
  static PairingOffer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairingSessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairingSessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairingSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairingSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.PeerIdentity get initiatorPeer => $_getN(1);
  @$pb.TagNumber(2)
  set initiatorPeer($0.PeerIdentity value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasInitiatorPeer() => $_has(1);
  @$pb.TagNumber(2)
  void clearInitiatorPeer() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PeerIdentity ensureInitiatorPeer() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.DeviceIdentity get initiatorDevice => $_getN(2);
  @$pb.TagNumber(3)
  set initiatorDevice($0.DeviceIdentity value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasInitiatorDevice() => $_has(2);
  @$pb.TagNumber(3)
  void clearInitiatorDevice() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.DeviceIdentity ensureInitiatorDevice() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get pairingCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set pairingCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPairingCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearPairingCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get qrPayload => $_getSZ(4);
  @$pb.TagNumber(5)
  set qrPayload($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQrPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearQrPayload() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get expectedFingerprint => $_getSZ(5);
  @$pb.TagNumber(6)
  set expectedFingerprint($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExpectedFingerprint() => $_has(5);
  @$pb.TagNumber(6)
  void clearExpectedFingerprint() => $_clearField(6);

  @$pb.TagNumber(7)
  PairingMethod get method => $_getN(6);
  @$pb.TagNumber(7)
  set method(PairingMethod value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMethod() => $_has(6);
  @$pb.TagNumber(7)
  void clearMethod() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get expiresAtUtcMs => $_getI64(7);
  @$pb.TagNumber(8)
  set expiresAtUtcMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExpiresAtUtcMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpiresAtUtcMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.List<$core.int> get offerSignature => $_getN(8);
  @$pb.TagNumber(9)
  set offerSignature($core.List<$core.int> value) => $_setBytes(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOfferSignature() => $_has(8);
  @$pb.TagNumber(9)
  void clearOfferSignature() => $_clearField(9);
}

class PairingVerification extends $pb.GeneratedMessage {
  factory PairingVerification({
    $core.String? pairingSessionId,
    $0.PeerIdentity? responderPeer,
    $0.DeviceIdentity? responderDevice,
    $core.String? enteredCode,
    $core.String? verifiedFingerprint,
    $fixnum.Int64? timestampUtcMs,
    $core.List<$core.int>? verificationSignature,
  }) {
    final result = PairingVerification._();
    if (pairingSessionId != null) result.pairingSessionId = pairingSessionId;
    if (responderPeer != null) result.responderPeer = responderPeer;
    if (responderDevice != null) result.responderDevice = responderDevice;
    if (enteredCode != null) result.enteredCode = enteredCode;
    if (verifiedFingerprint != null)
      result.verifiedFingerprint = verifiedFingerprint;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (verificationSignature != null)
      result.verificationSignature = verificationSignature;
    return result;
  }

  PairingVerification._();

  factory PairingVerification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingVerification()..mergeFromBuffer(data, registry);
  factory PairingVerification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingVerification()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingVerification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PairingVerification.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pairingSessionId')
    ..aOM<$0.PeerIdentity>(2, _omitFieldNames ? '' : 'responderPeer',
        subBuilder: $0.PeerIdentity.$_createMessage)
    ..aOM<$0.DeviceIdentity>(3, _omitFieldNames ? '' : 'responderDevice',
        subBuilder: $0.DeviceIdentity.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'enteredCode')
    ..aOS(5, _omitFieldNames ? '' : 'verifiedFingerprint')
    ..aInt64(6, _omitFieldNames ? '' : 'timestampUtcMs')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'verificationSignature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingVerification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingVerification copyWith(void Function(PairingVerification) updates) =>
      super.copyWith((message) => updates(message as PairingVerification))
          as PairingVerification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use PairingVerification() / PairingVerification.new instead')
  static PairingVerification create() => PairingVerification._();
  static $pb.GeneratedMessage $_createMessage() => PairingVerification._();
  @$core.override
  PairingVerification createEmptyInstance() => PairingVerification._();
  @$core.pragma('dart2js:noInline')
  static PairingVerification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PairingVerification>(
          PairingVerification.$_createMessage);
  static PairingVerification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairingSessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairingSessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairingSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairingSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.PeerIdentity get responderPeer => $_getN(1);
  @$pb.TagNumber(2)
  set responderPeer($0.PeerIdentity value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResponderPeer() => $_has(1);
  @$pb.TagNumber(2)
  void clearResponderPeer() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PeerIdentity ensureResponderPeer() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.DeviceIdentity get responderDevice => $_getN(2);
  @$pb.TagNumber(3)
  set responderDevice($0.DeviceIdentity value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasResponderDevice() => $_has(2);
  @$pb.TagNumber(3)
  void clearResponderDevice() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.DeviceIdentity ensureResponderDevice() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get enteredCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set enteredCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnteredCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnteredCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get verifiedFingerprint => $_getSZ(4);
  @$pb.TagNumber(5)
  set verifiedFingerprint($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVerifiedFingerprint() => $_has(4);
  @$pb.TagNumber(5)
  void clearVerifiedFingerprint() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get timestampUtcMs => $_getI64(5);
  @$pb.TagNumber(6)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTimestampUtcMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearTimestampUtcMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get verificationSignature => $_getN(6);
  @$pb.TagNumber(7)
  set verificationSignature($core.List<$core.int> value) =>
      $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVerificationSignature() => $_has(6);
  @$pb.TagNumber(7)
  void clearVerificationSignature() => $_clearField(7);
}

class PairingResult extends $pb.GeneratedMessage {
  factory PairingResult({
    $core.String? pairingSessionId,
    PairingState? state,
    $1.ErrorDetail? error,
    $fixnum.Int64? completedAtUtcMs,
    $0.PeerIdentity? pairedPeer,
  }) {
    final result = PairingResult._();
    if (pairingSessionId != null) result.pairingSessionId = pairingSessionId;
    if (state != null) result.state = state;
    if (error != null) result.error = error;
    if (completedAtUtcMs != null) result.completedAtUtcMs = completedAtUtcMs;
    if (pairedPeer != null) result.pairedPeer = pairedPeer;
    return result;
  }

  PairingResult._();

  factory PairingResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingResult()..mergeFromBuffer(data, registry);
  factory PairingResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PairingResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PairingResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PairingResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'pairingSessionId')
    ..aE<PairingState>(2, _omitFieldNames ? '' : 'state',
        enumValues: PairingState.values)
    ..aOM<$1.ErrorDetail>(3, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'completedAtUtcMs')
    ..aOM<$0.PeerIdentity>(5, _omitFieldNames ? '' : 'pairedPeer',
        subBuilder: $0.PeerIdentity.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PairingResult copyWith(void Function(PairingResult) updates) =>
      super.copyWith((message) => updates(message as PairingResult))
          as PairingResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PairingResult() / PairingResult.new instead')
  static PairingResult create() => PairingResult._();
  static $pb.GeneratedMessage $_createMessage() => PairingResult._();
  @$core.override
  PairingResult createEmptyInstance() => PairingResult._();
  @$core.pragma('dart2js:noInline')
  static PairingResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PairingResult>(
          PairingResult.$_createMessage);
  static PairingResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairingSessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairingSessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairingSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairingSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  PairingState get state => $_getN(1);
  @$pb.TagNumber(2)
  set state(PairingState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);

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

  @$pb.TagNumber(4)
  $fixnum.Int64 get completedAtUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set completedAtUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCompletedAtUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearCompletedAtUtcMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $0.PeerIdentity get pairedPeer => $_getN(4);
  @$pb.TagNumber(5)
  set pairedPeer($0.PeerIdentity value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPairedPeer() => $_has(4);
  @$pb.TagNumber(5)
  void clearPairedPeer() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.PeerIdentity ensurePairedPeer() => $_ensure(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
