// This is a generated file - do not edit.
//
// Generated from peerlink/v1/share.proto.

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
import 'share.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'share.pbenum.dart';

/// Opaque capability token carried by the holder.
/// A share link is a capability, not a URL to cloud storage.
class ShareCapabilityToken extends $pb.GeneratedMessage {
  factory ShareCapabilityToken({
    $core.String? tokenId,
    $core.String? shareId,
    ShareType? shareType,
    $core.Iterable<SharePermission>? permissions,
    $fixnum.Int64? issuedAtUtcMs,
    $fixnum.Int64? expiresAtUtcMs,
    $core.String? boundPeerId,
    $core.bool? isGuestToken,
    $core.String? hmacSignatureHex,
    $core.String? operationId,
  }) {
    final result = ShareCapabilityToken._();
    if (tokenId != null) result.tokenId = tokenId;
    if (shareId != null) result.shareId = shareId;
    if (shareType != null) result.shareType = shareType;
    if (permissions != null) result.permissions.addAll(permissions);
    if (issuedAtUtcMs != null) result.issuedAtUtcMs = issuedAtUtcMs;
    if (expiresAtUtcMs != null) result.expiresAtUtcMs = expiresAtUtcMs;
    if (boundPeerId != null) result.boundPeerId = boundPeerId;
    if (isGuestToken != null) result.isGuestToken = isGuestToken;
    if (hmacSignatureHex != null) result.hmacSignatureHex = hmacSignatureHex;
    if (operationId != null) result.operationId = operationId;
    return result;
  }

  ShareCapabilityToken._();

  factory ShareCapabilityToken.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareCapabilityToken()..mergeFromBuffer(data, registry);
  factory ShareCapabilityToken.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareCapabilityToken()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareCapabilityToken',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareCapabilityToken.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'tokenId')
    ..aOS(2, _omitFieldNames ? '' : 'shareId')
    ..aE<ShareType>(3, _omitFieldNames ? '' : 'shareType',
        enumValues: ShareType.values)
    ..pc<SharePermission>(
        4, _omitFieldNames ? '' : 'permissions', $pb.PbFieldType.KE,
        valueOf: SharePermission.valueOf,
        enumValues: SharePermission.values,
        defaultEnumValue: SharePermission.SHARE_PERMISSION_UNSPECIFIED)
    ..aInt64(5, _omitFieldNames ? '' : 'issuedAtUtcMs')
    ..aInt64(6, _omitFieldNames ? '' : 'expiresAtUtcMs')
    ..aOS(7, _omitFieldNames ? '' : 'boundPeerId')
    ..aOB(8, _omitFieldNames ? '' : 'isGuestToken')
    ..aOS(9, _omitFieldNames ? '' : 'hmacSignatureHex')
    ..aOS(10, _omitFieldNames ? '' : 'operationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareCapabilityToken clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareCapabilityToken copyWith(void Function(ShareCapabilityToken) updates) =>
      super.copyWith((message) => updates(message as ShareCapabilityToken))
          as ShareCapabilityToken;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ShareCapabilityToken() / ShareCapabilityToken.new instead')
  static ShareCapabilityToken create() => ShareCapabilityToken._();
  static $pb.GeneratedMessage $_createMessage() => ShareCapabilityToken._();
  @$core.override
  ShareCapabilityToken createEmptyInstance() => ShareCapabilityToken._();
  @$core.pragma('dart2js:noInline')
  static ShareCapabilityToken getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShareCapabilityToken>(
          ShareCapabilityToken.$_createMessage);
  static ShareCapabilityToken? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tokenId => $_getSZ(0);
  @$pb.TagNumber(1)
  set tokenId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTokenId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTokenId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get shareId => $_getSZ(1);
  @$pb.TagNumber(2)
  set shareId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShareId() => $_has(1);
  @$pb.TagNumber(2)
  void clearShareId() => $_clearField(2);

  @$pb.TagNumber(3)
  ShareType get shareType => $_getN(2);
  @$pb.TagNumber(3)
  set shareType(ShareType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasShareType() => $_has(2);
  @$pb.TagNumber(3)
  void clearShareType() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<SharePermission> get permissions => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get issuedAtUtcMs => $_getI64(4);
  @$pb.TagNumber(5)
  set issuedAtUtcMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIssuedAtUtcMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearIssuedAtUtcMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get expiresAtUtcMs => $_getI64(5);
  @$pb.TagNumber(6)
  set expiresAtUtcMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExpiresAtUtcMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearExpiresAtUtcMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get boundPeerId => $_getSZ(6);
  @$pb.TagNumber(7)
  set boundPeerId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBoundPeerId() => $_has(6);
  @$pb.TagNumber(7)
  void clearBoundPeerId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isGuestToken => $_getBF(7);
  @$pb.TagNumber(8)
  set isGuestToken($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsGuestToken() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsGuestToken() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get hmacSignatureHex => $_getSZ(8);
  @$pb.TagNumber(9)
  set hmacSignatureHex($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHmacSignatureHex() => $_has(8);
  @$pb.TagNumber(9)
  void clearHmacSignatureHex() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get operationId => $_getSZ(9);
  @$pb.TagNumber(10)
  set operationId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasOperationId() => $_has(9);
  @$pb.TagNumber(10)
  void clearOperationId() => $_clearField(10);
}

/// Represents a live share object on the owner's device.
class ShareObject extends $pb.GeneratedMessage {
  factory ShareObject({
    $core.String? shareId,
    $core.String? ownerPeerId,
    ShareType? shareType,
    ShareStatus? status,
    $core.String? displayLabel,
    $core.Iterable<$core.String>? allowedPeerIds,
    $core.Iterable<SharePermission>? permissions,
    $fixnum.Int64? createdAtUtcMs,
    $fixnum.Int64? expiresAtUtcMs,
    $fixnum.Int64? gracePeriodMs,
    $core.bool? isOneTime,
    $core.String? consumedByOperationId,
    $core.bool? revoked,
    $fixnum.Int64? revokedAtUtcMs,
    $core.String? revokeReason,
    $core.bool? guestAllowed,
    $core.String? qrPayload,
    $fixnum.Int64? lastActivityUtcMs,
  }) {
    final result = ShareObject._();
    if (shareId != null) result.shareId = shareId;
    if (ownerPeerId != null) result.ownerPeerId = ownerPeerId;
    if (shareType != null) result.shareType = shareType;
    if (status != null) result.status = status;
    if (displayLabel != null) result.displayLabel = displayLabel;
    if (allowedPeerIds != null) result.allowedPeerIds.addAll(allowedPeerIds);
    if (permissions != null) result.permissions.addAll(permissions);
    if (createdAtUtcMs != null) result.createdAtUtcMs = createdAtUtcMs;
    if (expiresAtUtcMs != null) result.expiresAtUtcMs = expiresAtUtcMs;
    if (gracePeriodMs != null) result.gracePeriodMs = gracePeriodMs;
    if (isOneTime != null) result.isOneTime = isOneTime;
    if (consumedByOperationId != null)
      result.consumedByOperationId = consumedByOperationId;
    if (revoked != null) result.revoked = revoked;
    if (revokedAtUtcMs != null) result.revokedAtUtcMs = revokedAtUtcMs;
    if (revokeReason != null) result.revokeReason = revokeReason;
    if (guestAllowed != null) result.guestAllowed = guestAllowed;
    if (qrPayload != null) result.qrPayload = qrPayload;
    if (lastActivityUtcMs != null) result.lastActivityUtcMs = lastActivityUtcMs;
    return result;
  }

  ShareObject._();

  factory ShareObject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareObject()..mergeFromBuffer(data, registry);
  factory ShareObject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareObject()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareObject',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareObject.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shareId')
    ..aOS(2, _omitFieldNames ? '' : 'ownerPeerId')
    ..aE<ShareType>(3, _omitFieldNames ? '' : 'shareType',
        enumValues: ShareType.values)
    ..aE<ShareStatus>(4, _omitFieldNames ? '' : 'status',
        enumValues: ShareStatus.values)
    ..aOS(5, _omitFieldNames ? '' : 'displayLabel')
    ..pPS(6, _omitFieldNames ? '' : 'allowedPeerIds')
    ..pc<SharePermission>(
        7, _omitFieldNames ? '' : 'permissions', $pb.PbFieldType.KE,
        valueOf: SharePermission.valueOf,
        enumValues: SharePermission.values,
        defaultEnumValue: SharePermission.SHARE_PERMISSION_UNSPECIFIED)
    ..aInt64(8, _omitFieldNames ? '' : 'createdAtUtcMs')
    ..aInt64(9, _omitFieldNames ? '' : 'expiresAtUtcMs')
    ..aInt64(10, _omitFieldNames ? '' : 'gracePeriodMs')
    ..aOB(11, _omitFieldNames ? '' : 'isOneTime')
    ..aOS(12, _omitFieldNames ? '' : 'consumedByOperationId')
    ..aOB(13, _omitFieldNames ? '' : 'revoked')
    ..aInt64(14, _omitFieldNames ? '' : 'revokedAtUtcMs')
    ..aOS(15, _omitFieldNames ? '' : 'revokeReason')
    ..aOB(16, _omitFieldNames ? '' : 'guestAllowed')
    ..aOS(17, _omitFieldNames ? '' : 'qrPayload')
    ..aInt64(18, _omitFieldNames ? '' : 'lastActivityUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareObject clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareObject copyWith(void Function(ShareObject) updates) =>
      super.copyWith((message) => updates(message as ShareObject))
          as ShareObject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShareObject() / ShareObject.new instead')
  static ShareObject create() => ShareObject._();
  static $pb.GeneratedMessage $_createMessage() => ShareObject._();
  @$core.override
  ShareObject createEmptyInstance() => ShareObject._();
  @$core.pragma('dart2js:noInline')
  static ShareObject getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareObject>(
          ShareObject.$_createMessage);
  static ShareObject? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get shareId => $_getSZ(0);
  @$pb.TagNumber(1)
  set shareId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShareId() => $_has(0);
  @$pb.TagNumber(1)
  void clearShareId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get ownerPeerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set ownerPeerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOwnerPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOwnerPeerId() => $_clearField(2);

  @$pb.TagNumber(3)
  ShareType get shareType => $_getN(2);
  @$pb.TagNumber(3)
  set shareType(ShareType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasShareType() => $_has(2);
  @$pb.TagNumber(3)
  void clearShareType() => $_clearField(3);

  @$pb.TagNumber(4)
  ShareStatus get status => $_getN(3);
  @$pb.TagNumber(4)
  set status(ShareStatus value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get displayLabel => $_getSZ(4);
  @$pb.TagNumber(5)
  set displayLabel($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDisplayLabel() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplayLabel() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get allowedPeerIds => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<SharePermission> get permissions => $_getList(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdAtUtcMs => $_getI64(7);
  @$pb.TagNumber(8)
  set createdAtUtcMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAtUtcMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAtUtcMs() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get expiresAtUtcMs => $_getI64(8);
  @$pb.TagNumber(9)
  set expiresAtUtcMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasExpiresAtUtcMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearExpiresAtUtcMs() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get gracePeriodMs => $_getI64(9);
  @$pb.TagNumber(10)
  set gracePeriodMs($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasGracePeriodMs() => $_has(9);
  @$pb.TagNumber(10)
  void clearGracePeriodMs() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get isOneTime => $_getBF(10);
  @$pb.TagNumber(11)
  set isOneTime($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIsOneTime() => $_has(10);
  @$pb.TagNumber(11)
  void clearIsOneTime() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get consumedByOperationId => $_getSZ(11);
  @$pb.TagNumber(12)
  set consumedByOperationId($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasConsumedByOperationId() => $_has(11);
  @$pb.TagNumber(12)
  void clearConsumedByOperationId() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get revoked => $_getBF(12);
  @$pb.TagNumber(13)
  set revoked($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRevoked() => $_has(12);
  @$pb.TagNumber(13)
  void clearRevoked() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get revokedAtUtcMs => $_getI64(13);
  @$pb.TagNumber(14)
  set revokedAtUtcMs($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRevokedAtUtcMs() => $_has(13);
  @$pb.TagNumber(14)
  void clearRevokedAtUtcMs() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get revokeReason => $_getSZ(14);
  @$pb.TagNumber(15)
  set revokeReason($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasRevokeReason() => $_has(14);
  @$pb.TagNumber(15)
  void clearRevokeReason() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.bool get guestAllowed => $_getBF(15);
  @$pb.TagNumber(16)
  set guestAllowed($core.bool value) => $_setBool(15, value);
  @$pb.TagNumber(16)
  $core.bool hasGuestAllowed() => $_has(15);
  @$pb.TagNumber(16)
  void clearGuestAllowed() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get qrPayload => $_getSZ(16);
  @$pb.TagNumber(17)
  set qrPayload($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasQrPayload() => $_has(16);
  @$pb.TagNumber(17)
  void clearQrPayload() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get lastActivityUtcMs => $_getI64(17);
  @$pb.TagNumber(18)
  set lastActivityUtcMs($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasLastActivityUtcMs() => $_has(17);
  @$pb.TagNumber(18)
  void clearLastActivityUtcMs() => $_clearField(18);
}

/// UI approval state surface (what the owner's UI shows)
class ShareApprovalState extends $pb.GeneratedMessage {
  factory ShareApprovalState({
    $core.String? shareId,
    ShareStatus? status,
    $core.bool? pendingOwnerApproval,
    $core.bool? ownerApproved,
    $core.bool? ownerDenied,
    $core.String? denialReason,
    $fixnum.Int64? approvalTimestampUtcMs,
    $core.Iterable<$core.String>? pendingGuestRequests,
  }) {
    final result = ShareApprovalState._();
    if (shareId != null) result.shareId = shareId;
    if (status != null) result.status = status;
    if (pendingOwnerApproval != null)
      result.pendingOwnerApproval = pendingOwnerApproval;
    if (ownerApproved != null) result.ownerApproved = ownerApproved;
    if (ownerDenied != null) result.ownerDenied = ownerDenied;
    if (denialReason != null) result.denialReason = denialReason;
    if (approvalTimestampUtcMs != null)
      result.approvalTimestampUtcMs = approvalTimestampUtcMs;
    if (pendingGuestRequests != null)
      result.pendingGuestRequests.addAll(pendingGuestRequests);
    return result;
  }

  ShareApprovalState._();

  factory ShareApprovalState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareApprovalState()..mergeFromBuffer(data, registry);
  factory ShareApprovalState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareApprovalState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareApprovalState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareApprovalState.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shareId')
    ..aE<ShareStatus>(2, _omitFieldNames ? '' : 'status',
        enumValues: ShareStatus.values)
    ..aOB(3, _omitFieldNames ? '' : 'pendingOwnerApproval')
    ..aOB(4, _omitFieldNames ? '' : 'ownerApproved')
    ..aOB(5, _omitFieldNames ? '' : 'ownerDenied')
    ..aOS(6, _omitFieldNames ? '' : 'denialReason')
    ..aInt64(7, _omitFieldNames ? '' : 'approvalTimestampUtcMs')
    ..pPS(8, _omitFieldNames ? '' : 'pendingGuestRequests')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareApprovalState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareApprovalState copyWith(void Function(ShareApprovalState) updates) =>
      super.copyWith((message) => updates(message as ShareApprovalState))
          as ShareApprovalState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShareApprovalState() / ShareApprovalState.new instead')
  static ShareApprovalState create() => ShareApprovalState._();
  static $pb.GeneratedMessage $_createMessage() => ShareApprovalState._();
  @$core.override
  ShareApprovalState createEmptyInstance() => ShareApprovalState._();
  @$core.pragma('dart2js:noInline')
  static ShareApprovalState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShareApprovalState>(
          ShareApprovalState.$_createMessage);
  static ShareApprovalState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get shareId => $_getSZ(0);
  @$pb.TagNumber(1)
  set shareId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShareId() => $_has(0);
  @$pb.TagNumber(1)
  void clearShareId() => $_clearField(1);

  @$pb.TagNumber(2)
  ShareStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(ShareStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get pendingOwnerApproval => $_getBF(2);
  @$pb.TagNumber(3)
  set pendingOwnerApproval($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPendingOwnerApproval() => $_has(2);
  @$pb.TagNumber(3)
  void clearPendingOwnerApproval() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get ownerApproved => $_getBF(3);
  @$pb.TagNumber(4)
  set ownerApproved($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOwnerApproved() => $_has(3);
  @$pb.TagNumber(4)
  void clearOwnerApproved() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get ownerDenied => $_getBF(4);
  @$pb.TagNumber(5)
  set ownerDenied($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOwnerDenied() => $_has(4);
  @$pb.TagNumber(5)
  void clearOwnerDenied() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get denialReason => $_getSZ(5);
  @$pb.TagNumber(6)
  set denialReason($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDenialReason() => $_has(5);
  @$pb.TagNumber(6)
  void clearDenialReason() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get approvalTimestampUtcMs => $_getI64(6);
  @$pb.TagNumber(7)
  set approvalTimestampUtcMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasApprovalTimestampUtcMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearApprovalTimestampUtcMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get pendingGuestRequests => $_getList(7);
}

/// Audit record for share lifecycle events
class ShareAuditRecord extends $pb.GeneratedMessage {
  factory ShareAuditRecord({
    $fixnum.Int64? timestampUtcMs,
    $core.String? shareId,
    $core.String? actorPeerId,
    ShareAuditEvent? event,
    $core.String? operationId,
    $core.String? detail,
  }) {
    final result = ShareAuditRecord._();
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (shareId != null) result.shareId = shareId;
    if (actorPeerId != null) result.actorPeerId = actorPeerId;
    if (event != null) result.event = event;
    if (operationId != null) result.operationId = operationId;
    if (detail != null) result.detail = detail;
    return result;
  }

  ShareAuditRecord._();

  factory ShareAuditRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareAuditRecord()..mergeFromBuffer(data, registry);
  factory ShareAuditRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareAuditRecord()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareAuditRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareAuditRecord.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'timestampUtcMs')
    ..aOS(2, _omitFieldNames ? '' : 'shareId')
    ..aOS(3, _omitFieldNames ? '' : 'actorPeerId')
    ..aE<ShareAuditEvent>(4, _omitFieldNames ? '' : 'event',
        enumValues: ShareAuditEvent.values)
    ..aOS(5, _omitFieldNames ? '' : 'operationId')
    ..aOS(6, _omitFieldNames ? '' : 'detail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareAuditRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareAuditRecord copyWith(void Function(ShareAuditRecord) updates) =>
      super.copyWith((message) => updates(message as ShareAuditRecord))
          as ShareAuditRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShareAuditRecord() / ShareAuditRecord.new instead')
  static ShareAuditRecord create() => ShareAuditRecord._();
  static $pb.GeneratedMessage $_createMessage() => ShareAuditRecord._();
  @$core.override
  ShareAuditRecord createEmptyInstance() => ShareAuditRecord._();
  @$core.pragma('dart2js:noInline')
  static ShareAuditRecord getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareAuditRecord>(
          ShareAuditRecord.$_createMessage);
  static ShareAuditRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get timestampUtcMs => $_getI64(0);
  @$pb.TagNumber(1)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimestampUtcMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestampUtcMs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get shareId => $_getSZ(1);
  @$pb.TagNumber(2)
  set shareId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShareId() => $_has(1);
  @$pb.TagNumber(2)
  void clearShareId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get actorPeerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set actorPeerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActorPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearActorPeerId() => $_clearField(3);

  @$pb.TagNumber(4)
  ShareAuditEvent get event => $_getN(3);
  @$pb.TagNumber(4)
  set event(ShareAuditEvent value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasEvent() => $_has(3);
  @$pb.TagNumber(4)
  void clearEvent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get operationId => $_getSZ(4);
  @$pb.TagNumber(5)
  set operationId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOperationId() => $_has(4);
  @$pb.TagNumber(5)
  void clearOperationId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get detail => $_getSZ(5);
  @$pb.TagNumber(6)
  set detail($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDetail() => $_has(5);
  @$pb.TagNumber(6)
  void clearDetail() => $_clearField(6);
}

/// Request to use a share capability (sent by holder to owner)
class ShareUseRequest extends $pb.GeneratedMessage {
  factory ShareUseRequest({
    $core.String? requestId,
    $core.String? tokenId,
    $core.String? shareId,
    $0.PeerId? requesterPeerId,
    SharePermission? requestedPermission,
    $core.String? operationId,
    $fixnum.Int64? timestampUtcMs,
    $core.bool? isGuest,
  }) {
    final result = ShareUseRequest._();
    if (requestId != null) result.requestId = requestId;
    if (tokenId != null) result.tokenId = tokenId;
    if (shareId != null) result.shareId = shareId;
    if (requesterPeerId != null) result.requesterPeerId = requesterPeerId;
    if (requestedPermission != null)
      result.requestedPermission = requestedPermission;
    if (operationId != null) result.operationId = operationId;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    if (isGuest != null) result.isGuest = isGuest;
    return result;
  }

  ShareUseRequest._();

  factory ShareUseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareUseRequest()..mergeFromBuffer(data, registry);
  factory ShareUseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareUseRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareUseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareUseRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'tokenId')
    ..aOS(3, _omitFieldNames ? '' : 'shareId')
    ..aOM<$0.PeerId>(4, _omitFieldNames ? '' : 'requesterPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aE<SharePermission>(5, _omitFieldNames ? '' : 'requestedPermission',
        enumValues: SharePermission.values)
    ..aOS(6, _omitFieldNames ? '' : 'operationId')
    ..aInt64(7, _omitFieldNames ? '' : 'timestampUtcMs')
    ..aOB(8, _omitFieldNames ? '' : 'isGuest')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareUseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareUseRequest copyWith(void Function(ShareUseRequest) updates) =>
      super.copyWith((message) => updates(message as ShareUseRequest))
          as ShareUseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShareUseRequest() / ShareUseRequest.new instead')
  static ShareUseRequest create() => ShareUseRequest._();
  static $pb.GeneratedMessage $_createMessage() => ShareUseRequest._();
  @$core.override
  ShareUseRequest createEmptyInstance() => ShareUseRequest._();
  @$core.pragma('dart2js:noInline')
  static ShareUseRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareUseRequest>(
          ShareUseRequest.$_createMessage);
  static ShareUseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tokenId => $_getSZ(1);
  @$pb.TagNumber(2)
  set tokenId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTokenId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTokenId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get shareId => $_getSZ(2);
  @$pb.TagNumber(3)
  set shareId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShareId() => $_has(2);
  @$pb.TagNumber(3)
  void clearShareId() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.PeerId get requesterPeerId => $_getN(3);
  @$pb.TagNumber(4)
  set requesterPeerId($0.PeerId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRequesterPeerId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequesterPeerId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.PeerId ensureRequesterPeerId() => $_ensure(3);

  @$pb.TagNumber(5)
  SharePermission get requestedPermission => $_getN(4);
  @$pb.TagNumber(5)
  set requestedPermission(SharePermission value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRequestedPermission() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestedPermission() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get operationId => $_getSZ(5);
  @$pb.TagNumber(6)
  set operationId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOperationId() => $_has(5);
  @$pb.TagNumber(6)
  void clearOperationId() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get timestampUtcMs => $_getI64(6);
  @$pb.TagNumber(7)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimestampUtcMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestampUtcMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isGuest => $_getBF(7);
  @$pb.TagNumber(8)
  set isGuest($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsGuest() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsGuest() => $_clearField(8);
}

/// Owner's response to a ShareUseRequest
class ShareUseResponse extends $pb.GeneratedMessage {
  factory ShareUseResponse({
    $core.String? requestId,
    $core.bool? authorized,
    ShareStatus? shareStatus,
    $1.ErrorDetail? error,
    $fixnum.Int64? authorizedUntilUtcMs,
    $core.bool? withinGracePeriod,
  }) {
    final result = ShareUseResponse._();
    if (requestId != null) result.requestId = requestId;
    if (authorized != null) result.authorized = authorized;
    if (shareStatus != null) result.shareStatus = shareStatus;
    if (error != null) result.error = error;
    if (authorizedUntilUtcMs != null)
      result.authorizedUntilUtcMs = authorizedUntilUtcMs;
    if (withinGracePeriod != null) result.withinGracePeriod = withinGracePeriod;
    return result;
  }

  ShareUseResponse._();

  factory ShareUseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareUseResponse()..mergeFromBuffer(data, registry);
  factory ShareUseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareUseResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareUseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareUseResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOB(2, _omitFieldNames ? '' : 'authorized')
    ..aE<ShareStatus>(3, _omitFieldNames ? '' : 'shareStatus',
        enumValues: ShareStatus.values)
    ..aOM<$1.ErrorDetail>(4, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..aInt64(5, _omitFieldNames ? '' : 'authorizedUntilUtcMs')
    ..aOB(6, _omitFieldNames ? '' : 'withinGracePeriod')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareUseResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareUseResponse copyWith(void Function(ShareUseResponse) updates) =>
      super.copyWith((message) => updates(message as ShareUseResponse))
          as ShareUseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShareUseResponse() / ShareUseResponse.new instead')
  static ShareUseResponse create() => ShareUseResponse._();
  static $pb.GeneratedMessage $_createMessage() => ShareUseResponse._();
  @$core.override
  ShareUseResponse createEmptyInstance() => ShareUseResponse._();
  @$core.pragma('dart2js:noInline')
  static ShareUseResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareUseResponse>(
          ShareUseResponse.$_createMessage);
  static ShareUseResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get authorized => $_getBF(1);
  @$pb.TagNumber(2)
  set authorized($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthorized() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthorized() => $_clearField(2);

  @$pb.TagNumber(3)
  ShareStatus get shareStatus => $_getN(2);
  @$pb.TagNumber(3)
  set shareStatus(ShareStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasShareStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearShareStatus() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.ErrorDetail get error => $_getN(3);
  @$pb.TagNumber(4)
  set error($1.ErrorDetail value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.ErrorDetail ensureError() => $_ensure(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get authorizedUntilUtcMs => $_getI64(4);
  @$pb.TagNumber(5)
  set authorizedUntilUtcMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAuthorizedUntilUtcMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearAuthorizedUntilUtcMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get withinGracePeriod => $_getBF(5);
  @$pb.TagNumber(6)
  set withinGracePeriod($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasWithinGracePeriod() => $_has(5);
  @$pb.TagNumber(6)
  void clearWithinGracePeriod() => $_clearField(6);
}

/// Revocation notice broadcast to known holders
class ShareRevocationNotice extends $pb.GeneratedMessage {
  factory ShareRevocationNotice({
    $core.String? shareId,
    $core.String? ownerPeerId,
    $core.String? revokeReason,
    $fixnum.Int64? revokedAtUtcMs,
    $fixnum.Int64? activeGraceEndsAtUtcMs,
  }) {
    final result = ShareRevocationNotice._();
    if (shareId != null) result.shareId = shareId;
    if (ownerPeerId != null) result.ownerPeerId = ownerPeerId;
    if (revokeReason != null) result.revokeReason = revokeReason;
    if (revokedAtUtcMs != null) result.revokedAtUtcMs = revokedAtUtcMs;
    if (activeGraceEndsAtUtcMs != null)
      result.activeGraceEndsAtUtcMs = activeGraceEndsAtUtcMs;
    return result;
  }

  ShareRevocationNotice._();

  factory ShareRevocationNotice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareRevocationNotice()..mergeFromBuffer(data, registry);
  factory ShareRevocationNotice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareRevocationNotice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareRevocationNotice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareRevocationNotice.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shareId')
    ..aOS(2, _omitFieldNames ? '' : 'ownerPeerId')
    ..aOS(3, _omitFieldNames ? '' : 'revokeReason')
    ..aInt64(4, _omitFieldNames ? '' : 'revokedAtUtcMs')
    ..aInt64(5, _omitFieldNames ? '' : 'activeGraceEndsAtUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareRevocationNotice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareRevocationNotice copyWith(
          void Function(ShareRevocationNotice) updates) =>
      super.copyWith((message) => updates(message as ShareRevocationNotice))
          as ShareRevocationNotice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ShareRevocationNotice() / ShareRevocationNotice.new instead')
  static ShareRevocationNotice create() => ShareRevocationNotice._();
  static $pb.GeneratedMessage $_createMessage() => ShareRevocationNotice._();
  @$core.override
  ShareRevocationNotice createEmptyInstance() => ShareRevocationNotice._();
  @$core.pragma('dart2js:noInline')
  static ShareRevocationNotice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShareRevocationNotice>(
          ShareRevocationNotice.$_createMessage);
  static ShareRevocationNotice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get shareId => $_getSZ(0);
  @$pb.TagNumber(1)
  set shareId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShareId() => $_has(0);
  @$pb.TagNumber(1)
  void clearShareId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get ownerPeerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set ownerPeerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOwnerPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOwnerPeerId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get revokeReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set revokeReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRevokeReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearRevokeReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get revokedAtUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set revokedAtUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRevokedAtUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearRevokedAtUtcMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get activeGraceEndsAtUtcMs => $_getI64(4);
  @$pb.TagNumber(5)
  set activeGraceEndsAtUtcMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasActiveGraceEndsAtUtcMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearActiveGraceEndsAtUtcMs() => $_clearField(5);
}

enum ShareWireMessage_Payload {
  useRequest,
  useResponse,
  revocationNotice,
  notSet
}

/// Wire envelope
class ShareWireMessage extends $pb.GeneratedMessage {
  factory ShareWireMessage({
    ShareUseRequest? useRequest,
    ShareUseResponse? useResponse,
    ShareRevocationNotice? revocationNotice,
  }) {
    final result = ShareWireMessage._();
    if (useRequest != null) result.useRequest = useRequest;
    if (useResponse != null) result.useResponse = useResponse;
    if (revocationNotice != null) result.revocationNotice = revocationNotice;
    return result;
  }

  ShareWireMessage._();

  factory ShareWireMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareWireMessage()..mergeFromBuffer(data, registry);
  factory ShareWireMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShareWireMessage()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ShareWireMessage_Payload>
      _ShareWireMessage_PayloadByTag = {
    1: ShareWireMessage_Payload.useRequest,
    2: ShareWireMessage_Payload.useResponse,
    3: ShareWireMessage_Payload.revocationNotice,
    0: ShareWireMessage_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShareWireMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ShareWireMessage.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<ShareUseRequest>(1, _omitFieldNames ? '' : 'useRequest',
        subBuilder: ShareUseRequest.$_createMessage)
    ..aOM<ShareUseResponse>(2, _omitFieldNames ? '' : 'useResponse',
        subBuilder: ShareUseResponse.$_createMessage)
    ..aOM<ShareRevocationNotice>(3, _omitFieldNames ? '' : 'revocationNotice',
        subBuilder: ShareRevocationNotice.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareWireMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShareWireMessage copyWith(void Function(ShareWireMessage) updates) =>
      super.copyWith((message) => updates(message as ShareWireMessage))
          as ShareWireMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShareWireMessage() / ShareWireMessage.new instead')
  static ShareWireMessage create() => ShareWireMessage._();
  static $pb.GeneratedMessage $_createMessage() => ShareWireMessage._();
  @$core.override
  ShareWireMessage createEmptyInstance() => ShareWireMessage._();
  @$core.pragma('dart2js:noInline')
  static ShareWireMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShareWireMessage>(
          ShareWireMessage.$_createMessage);
  static ShareWireMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  ShareWireMessage_Payload whichPayload() =>
      _ShareWireMessage_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ShareUseRequest get useRequest => $_getN(0);
  @$pb.TagNumber(1)
  set useRequest(ShareUseRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUseRequest() => $_has(0);
  @$pb.TagNumber(1)
  void clearUseRequest() => $_clearField(1);
  @$pb.TagNumber(1)
  ShareUseRequest ensureUseRequest() => $_ensure(0);

  @$pb.TagNumber(2)
  ShareUseResponse get useResponse => $_getN(1);
  @$pb.TagNumber(2)
  set useResponse(ShareUseResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUseResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearUseResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  ShareUseResponse ensureUseResponse() => $_ensure(1);

  @$pb.TagNumber(3)
  ShareRevocationNotice get revocationNotice => $_getN(2);
  @$pb.TagNumber(3)
  set revocationNotice(ShareRevocationNotice value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRevocationNotice() => $_has(2);
  @$pb.TagNumber(3)
  void clearRevocationNotice() => $_clearField(3);
  @$pb.TagNumber(3)
  ShareRevocationNotice ensureRevocationNotice() => $_ensure(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
