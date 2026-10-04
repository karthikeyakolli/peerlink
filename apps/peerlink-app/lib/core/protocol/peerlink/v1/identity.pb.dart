// This is a generated file - do not edit.
//
// Generated from peerlink/v1/identity.proto.

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
import 'identity.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'identity.pbenum.dart';

class CryptographicKey extends $pb.GeneratedMessage {
  factory CryptographicKey({
    KeyType? keyType,
    $core.List<$core.int>? publicKeyBytes,
    $core.String? keyId,
    $fixnum.Int64? createdAtUtcMs,
  }) {
    final result = CryptographicKey._();
    if (keyType != null) result.keyType = keyType;
    if (publicKeyBytes != null) result.publicKeyBytes = publicKeyBytes;
    if (keyId != null) result.keyId = keyId;
    if (createdAtUtcMs != null) result.createdAtUtcMs = createdAtUtcMs;
    return result;
  }

  CryptographicKey._();

  factory CryptographicKey.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CryptographicKey()..mergeFromBuffer(data, registry);
  factory CryptographicKey.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CryptographicKey()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CryptographicKey',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: CryptographicKey.$_createMessage)
    ..aE<KeyType>(1, _omitFieldNames ? '' : 'keyType',
        enumValues: KeyType.values)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'publicKeyBytes', $pb.PbFieldType.OY)
    ..aOS(3, _omitFieldNames ? '' : 'keyId')
    ..aInt64(4, _omitFieldNames ? '' : 'createdAtUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CryptographicKey clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CryptographicKey copyWith(void Function(CryptographicKey) updates) =>
      super.copyWith((message) => updates(message as CryptographicKey))
          as CryptographicKey;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CryptographicKey() / CryptographicKey.new instead')
  static CryptographicKey create() => CryptographicKey._();
  static $pb.GeneratedMessage $_createMessage() => CryptographicKey._();
  @$core.override
  CryptographicKey createEmptyInstance() => CryptographicKey._();
  @$core.pragma('dart2js:noInline')
  static CryptographicKey getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CryptographicKey>(
          CryptographicKey.$_createMessage);
  static CryptographicKey? _defaultInstance;

  @$pb.TagNumber(1)
  KeyType get keyType => $_getN(0);
  @$pb.TagNumber(1)
  set keyType(KeyType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKeyType() => $_has(0);
  @$pb.TagNumber(1)
  void clearKeyType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get publicKeyBytes => $_getN(1);
  @$pb.TagNumber(2)
  set publicKeyBytes($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPublicKeyBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearPublicKeyBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get keyId => $_getSZ(2);
  @$pb.TagNumber(3)
  set keyId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKeyId() => $_has(2);
  @$pb.TagNumber(3)
  void clearKeyId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get createdAtUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set createdAtUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreatedAtUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreatedAtUtcMs() => $_clearField(4);
}

/// Supabase account binding (strictly decoupled from device crypto identity)
class AccountBinding extends $pb.GeneratedMessage {
  factory AccountBinding({
    $core.String? accountId,
    $core.String? accountEmail,
    $fixnum.Int64? boundAtUtcMs,
    $core.List<$core.int>? ownershipProofSignature,
  }) {
    final result = AccountBinding._();
    if (accountId != null) result.accountId = accountId;
    if (accountEmail != null) result.accountEmail = accountEmail;
    if (boundAtUtcMs != null) result.boundAtUtcMs = boundAtUtcMs;
    if (ownershipProofSignature != null)
      result.ownershipProofSignature = ownershipProofSignature;
    return result;
  }

  AccountBinding._();

  factory AccountBinding.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccountBinding()..mergeFromBuffer(data, registry);
  factory AccountBinding.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccountBinding()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountBinding',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AccountBinding.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'accountEmail')
    ..aInt64(3, _omitFieldNames ? '' : 'boundAtUtcMs')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'ownershipProofSignature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountBinding clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountBinding copyWith(void Function(AccountBinding) updates) =>
      super.copyWith((message) => updates(message as AccountBinding))
          as AccountBinding;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AccountBinding() / AccountBinding.new instead')
  static AccountBinding create() => AccountBinding._();
  static $pb.GeneratedMessage $_createMessage() => AccountBinding._();
  @$core.override
  AccountBinding createEmptyInstance() => AccountBinding._();
  @$core.pragma('dart2js:noInline')
  static AccountBinding getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AccountBinding>(
          AccountBinding.$_createMessage);
  static AccountBinding? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get accountEmail => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountEmail($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get boundAtUtcMs => $_getI64(2);
  @$pb.TagNumber(3)
  set boundAtUtcMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBoundAtUtcMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearBoundAtUtcMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get ownershipProofSignature => $_getN(3);
  @$pb.TagNumber(4)
  set ownershipProofSignature($core.List<$core.int> value) =>
      $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOwnershipProofSignature() => $_has(3);
  @$pb.TagNumber(4)
  void clearOwnershipProofSignature() => $_clearField(4);
}

/// Physical device identification
class DeviceIdentity extends $pb.GeneratedMessage {
  factory DeviceIdentity({
    $0.DeviceId? deviceId,
    $core.String? deviceName,
    DeviceType? deviceType,
    $core.String? osVersion,
    $core.String? appVersion,
    CryptographicKey? identityKey,
    AccountBinding? accountBinding,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>?
        ownershipMetadata,
  }) {
    final result = DeviceIdentity._();
    if (deviceId != null) result.deviceId = deviceId;
    if (deviceName != null) result.deviceName = deviceName;
    if (deviceType != null) result.deviceType = deviceType;
    if (osVersion != null) result.osVersion = osVersion;
    if (appVersion != null) result.appVersion = appVersion;
    if (identityKey != null) result.identityKey = identityKey;
    if (accountBinding != null) result.accountBinding = accountBinding;
    if (ownershipMetadata != null)
      result.ownershipMetadata.addEntries(ownershipMetadata);
    return result;
  }

  DeviceIdentity._();

  factory DeviceIdentity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceIdentity()..mergeFromBuffer(data, registry);
  factory DeviceIdentity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceIdentity()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceIdentity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: DeviceIdentity.$_createMessage)
    ..aOM<$0.DeviceId>(1, _omitFieldNames ? '' : 'deviceId',
        subBuilder: $0.DeviceId.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'deviceName')
    ..aE<DeviceType>(3, _omitFieldNames ? '' : 'deviceType',
        enumValues: DeviceType.values)
    ..aOS(4, _omitFieldNames ? '' : 'osVersion')
    ..aOS(5, _omitFieldNames ? '' : 'appVersion')
    ..aOM<CryptographicKey>(6, _omitFieldNames ? '' : 'identityKey',
        subBuilder: CryptographicKey.$_createMessage)
    ..aOM<AccountBinding>(7, _omitFieldNames ? '' : 'accountBinding',
        subBuilder: AccountBinding.$_createMessage)
    ..m<$core.String, $core.String>(
        8, _omitFieldNames ? '' : 'ownershipMetadata',
        entryClassName: 'DeviceIdentity.OwnershipMetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceIdentity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceIdentity copyWith(void Function(DeviceIdentity) updates) =>
      super.copyWith((message) => updates(message as DeviceIdentity))
          as DeviceIdentity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeviceIdentity() / DeviceIdentity.new instead')
  static DeviceIdentity create() => DeviceIdentity._();
  static $pb.GeneratedMessage $_createMessage() => DeviceIdentity._();
  @$core.override
  DeviceIdentity createEmptyInstance() => DeviceIdentity._();
  @$core.pragma('dart2js:noInline')
  static DeviceIdentity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeviceIdentity>(
          DeviceIdentity.$_createMessage);
  static DeviceIdentity? _defaultInstance;

  @$pb.TagNumber(1)
  $0.DeviceId get deviceId => $_getN(0);
  @$pb.TagNumber(1)
  set deviceId($0.DeviceId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.DeviceId ensureDeviceId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get deviceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceName() => $_clearField(2);

  @$pb.TagNumber(3)
  DeviceType get deviceType => $_getN(2);
  @$pb.TagNumber(3)
  set deviceType(DeviceType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDeviceType() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get osVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set osVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOsVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearOsVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get appVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set appVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAppVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearAppVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  CryptographicKey get identityKey => $_getN(5);
  @$pb.TagNumber(6)
  set identityKey(CryptographicKey value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasIdentityKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdentityKey() => $_clearField(6);
  @$pb.TagNumber(6)
  CryptographicKey ensureIdentityKey() => $_ensure(5);

  @$pb.TagNumber(7)
  AccountBinding get accountBinding => $_getN(6);
  @$pb.TagNumber(7)
  set accountBinding(AccountBinding value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasAccountBinding() => $_has(6);
  @$pb.TagNumber(7)
  void clearAccountBinding() => $_clearField(7);
  @$pb.TagNumber(7)
  AccountBinding ensureAccountBinding() => $_ensure(6);

  @$pb.TagNumber(8)
  $pb.PbMap<$core.String, $core.String> get ownershipMetadata => $_getMap(7);
}

/// Peer identification and cryptographic binding
class PeerIdentity extends $pb.GeneratedMessage {
  factory PeerIdentity({
    $0.PeerId? peerId,
    $0.DeviceId? deviceId,
    $core.String? displayName,
    CryptographicKey? identityKey,
    $core.String? fingerprintHex,
    TrustLevel? trustLevel,
    $fixnum.Int64? pairedAtUtcMs,
    AccountBinding? accountBinding,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? metadata,
  }) {
    final result = PeerIdentity._();
    if (peerId != null) result.peerId = peerId;
    if (deviceId != null) result.deviceId = deviceId;
    if (displayName != null) result.displayName = displayName;
    if (identityKey != null) result.identityKey = identityKey;
    if (fingerprintHex != null) result.fingerprintHex = fingerprintHex;
    if (trustLevel != null) result.trustLevel = trustLevel;
    if (pairedAtUtcMs != null) result.pairedAtUtcMs = pairedAtUtcMs;
    if (accountBinding != null) result.accountBinding = accountBinding;
    if (metadata != null) result.metadata.addEntries(metadata);
    return result;
  }

  PeerIdentity._();

  factory PeerIdentity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerIdentity()..mergeFromBuffer(data, registry);
  factory PeerIdentity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PeerIdentity()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PeerIdentity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: PeerIdentity.$_createMessage)
    ..aOM<$0.PeerId>(1, _omitFieldNames ? '' : 'peerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.DeviceId>(2, _omitFieldNames ? '' : 'deviceId',
        subBuilder: $0.DeviceId.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aOM<CryptographicKey>(4, _omitFieldNames ? '' : 'identityKey',
        subBuilder: CryptographicKey.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'fingerprintHex')
    ..aE<TrustLevel>(6, _omitFieldNames ? '' : 'trustLevel',
        enumValues: TrustLevel.values)
    ..aInt64(7, _omitFieldNames ? '' : 'pairedAtUtcMs')
    ..aOM<AccountBinding>(8, _omitFieldNames ? '' : 'accountBinding',
        subBuilder: AccountBinding.$_createMessage)
    ..m<$core.String, $core.String>(9, _omitFieldNames ? '' : 'metadata',
        entryClassName: 'PeerIdentity.MetadataEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerIdentity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PeerIdentity copyWith(void Function(PeerIdentity) updates) =>
      super.copyWith((message) => updates(message as PeerIdentity))
          as PeerIdentity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PeerIdentity() / PeerIdentity.new instead')
  static PeerIdentity create() => PeerIdentity._();
  static $pb.GeneratedMessage $_createMessage() => PeerIdentity._();
  @$core.override
  PeerIdentity createEmptyInstance() => PeerIdentity._();
  @$core.pragma('dart2js:noInline')
  static PeerIdentity getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PeerIdentity>(
          PeerIdentity.$_createMessage);
  static PeerIdentity? _defaultInstance;

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
  $0.DeviceId get deviceId => $_getN(1);
  @$pb.TagNumber(2)
  set deviceId($0.DeviceId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.DeviceId ensureDeviceId() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  CryptographicKey get identityKey => $_getN(3);
  @$pb.TagNumber(4)
  set identityKey(CryptographicKey value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasIdentityKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearIdentityKey() => $_clearField(4);
  @$pb.TagNumber(4)
  CryptographicKey ensureIdentityKey() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get fingerprintHex => $_getSZ(4);
  @$pb.TagNumber(5)
  set fingerprintHex($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFingerprintHex() => $_has(4);
  @$pb.TagNumber(5)
  void clearFingerprintHex() => $_clearField(5);

  @$pb.TagNumber(6)
  TrustLevel get trustLevel => $_getN(5);
  @$pb.TagNumber(6)
  set trustLevel(TrustLevel value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTrustLevel() => $_has(5);
  @$pb.TagNumber(6)
  void clearTrustLevel() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get pairedAtUtcMs => $_getI64(6);
  @$pb.TagNumber(7)
  set pairedAtUtcMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPairedAtUtcMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearPairedAtUtcMs() => $_clearField(7);

  @$pb.TagNumber(8)
  AccountBinding get accountBinding => $_getN(7);
  @$pb.TagNumber(8)
  set accountBinding(AccountBinding value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasAccountBinding() => $_has(7);
  @$pb.TagNumber(8)
  void clearAccountBinding() => $_clearField(8);
  @$pb.TagNumber(8)
  AccountBinding ensureAccountBinding() => $_ensure(7);

  @$pb.TagNumber(9)
  $pb.PbMap<$core.String, $core.String> get metadata => $_getMap(8);
}

/// Explicit revocation record
class RevocationRecord extends $pb.GeneratedMessage {
  factory RevocationRecord({
    $0.PeerId? revokedPeerId,
    $0.PeerId? revokedByPeerId,
    $core.String? reason,
    $fixnum.Int64? revokedAtUtcMs,
    $core.List<$core.int>? revocationSignature,
  }) {
    final result = RevocationRecord._();
    if (revokedPeerId != null) result.revokedPeerId = revokedPeerId;
    if (revokedByPeerId != null) result.revokedByPeerId = revokedByPeerId;
    if (reason != null) result.reason = reason;
    if (revokedAtUtcMs != null) result.revokedAtUtcMs = revokedAtUtcMs;
    if (revocationSignature != null)
      result.revocationSignature = revocationSignature;
    return result;
  }

  RevocationRecord._();

  factory RevocationRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevocationRecord()..mergeFromBuffer(data, registry);
  factory RevocationRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevocationRecord()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevocationRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RevocationRecord.$_createMessage)
    ..aOM<$0.PeerId>(1, _omitFieldNames ? '' : 'revokedPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.PeerId>(2, _omitFieldNames ? '' : 'revokedByPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..aInt64(4, _omitFieldNames ? '' : 'revokedAtUtcMs')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'revocationSignature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevocationRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevocationRecord copyWith(void Function(RevocationRecord) updates) =>
      super.copyWith((message) => updates(message as RevocationRecord))
          as RevocationRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RevocationRecord() / RevocationRecord.new instead')
  static RevocationRecord create() => RevocationRecord._();
  static $pb.GeneratedMessage $_createMessage() => RevocationRecord._();
  @$core.override
  RevocationRecord createEmptyInstance() => RevocationRecord._();
  @$core.pragma('dart2js:noInline')
  static RevocationRecord getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RevocationRecord>(
          RevocationRecord.$_createMessage);
  static RevocationRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $0.PeerId get revokedPeerId => $_getN(0);
  @$pb.TagNumber(1)
  set revokedPeerId($0.PeerId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRevokedPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRevokedPeerId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.PeerId ensureRevokedPeerId() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.PeerId get revokedByPeerId => $_getN(1);
  @$pb.TagNumber(2)
  set revokedByPeerId($0.PeerId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRevokedByPeerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRevokedByPeerId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PeerId ensureRevokedByPeerId() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get revokedAtUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set revokedAtUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRevokedAtUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearRevokedAtUtcMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get revocationSignature => $_getN(4);
  @$pb.TagNumber(5)
  set revocationSignature($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRevocationSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearRevocationSignature() => $_clearField(5);
}

/// Device replacement and recovery authorization record
class DeviceReplacementRecord extends $pb.GeneratedMessage {
  factory DeviceReplacementRecord({
    $0.DeviceId? oldDeviceId,
    $0.DeviceId? newDeviceId,
    $0.PeerId? peerId,
    $core.String? replacementToken,
    $fixnum.Int64? replacedAtUtcMs,
    $core.List<$core.int>? authorizationSignature,
  }) {
    final result = DeviceReplacementRecord._();
    if (oldDeviceId != null) result.oldDeviceId = oldDeviceId;
    if (newDeviceId != null) result.newDeviceId = newDeviceId;
    if (peerId != null) result.peerId = peerId;
    if (replacementToken != null) result.replacementToken = replacementToken;
    if (replacedAtUtcMs != null) result.replacedAtUtcMs = replacedAtUtcMs;
    if (authorizationSignature != null)
      result.authorizationSignature = authorizationSignature;
    return result;
  }

  DeviceReplacementRecord._();

  factory DeviceReplacementRecord.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceReplacementRecord()..mergeFromBuffer(data, registry);
  factory DeviceReplacementRecord.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeviceReplacementRecord()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceReplacementRecord',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: DeviceReplacementRecord.$_createMessage)
    ..aOM<$0.DeviceId>(1, _omitFieldNames ? '' : 'oldDeviceId',
        subBuilder: $0.DeviceId.$_createMessage)
    ..aOM<$0.DeviceId>(2, _omitFieldNames ? '' : 'newDeviceId',
        subBuilder: $0.DeviceId.$_createMessage)
    ..aOM<$0.PeerId>(3, _omitFieldNames ? '' : 'peerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOS(4, _omitFieldNames ? '' : 'replacementToken')
    ..aInt64(5, _omitFieldNames ? '' : 'replacedAtUtcMs')
    ..a<$core.List<$core.int>>(
        6, _omitFieldNames ? '' : 'authorizationSignature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceReplacementRecord clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceReplacementRecord copyWith(
          void Function(DeviceReplacementRecord) updates) =>
      super.copyWith((message) => updates(message as DeviceReplacementRecord))
          as DeviceReplacementRecord;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeviceReplacementRecord() / DeviceReplacementRecord.new instead')
  static DeviceReplacementRecord create() => DeviceReplacementRecord._();
  static $pb.GeneratedMessage $_createMessage() => DeviceReplacementRecord._();
  @$core.override
  DeviceReplacementRecord createEmptyInstance() => DeviceReplacementRecord._();
  @$core.pragma('dart2js:noInline')
  static DeviceReplacementRecord getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceReplacementRecord>(
          DeviceReplacementRecord.$_createMessage);
  static DeviceReplacementRecord? _defaultInstance;

  @$pb.TagNumber(1)
  $0.DeviceId get oldDeviceId => $_getN(0);
  @$pb.TagNumber(1)
  set oldDeviceId($0.DeviceId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOldDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldDeviceId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.DeviceId ensureOldDeviceId() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.DeviceId get newDeviceId => $_getN(1);
  @$pb.TagNumber(2)
  set newDeviceId($0.DeviceId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNewDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewDeviceId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.DeviceId ensureNewDeviceId() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.PeerId get peerId => $_getN(2);
  @$pb.TagNumber(3)
  set peerId($0.PeerId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PeerId ensurePeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get replacementToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set replacementToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReplacementToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearReplacementToken() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get replacedAtUtcMs => $_getI64(4);
  @$pb.TagNumber(5)
  set replacedAtUtcMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReplacedAtUtcMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearReplacedAtUtcMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get authorizationSignature => $_getN(5);
  @$pb.TagNumber(6)
  set authorizationSignature($core.List<$core.int> value) =>
      $_setBytes(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAuthorizationSignature() => $_has(5);
  @$pb.TagNumber(6)
  void clearAuthorizationSignature() => $_clearField(6);
}

/// Durable trust store snapshot for backup and restore
class TrustStoreSnapshot extends $pb.GeneratedMessage {
  factory TrustStoreSnapshot({
    $core.int? version,
    $fixnum.Int64? snapshotTimestampUtcMs,
    $core.Iterable<PeerIdentity>? trustedPeers,
    $core.Iterable<RevocationRecord>? revocations,
    $core.List<$core.int>? integritySignature,
  }) {
    final result = TrustStoreSnapshot._();
    if (version != null) result.version = version;
    if (snapshotTimestampUtcMs != null)
      result.snapshotTimestampUtcMs = snapshotTimestampUtcMs;
    if (trustedPeers != null) result.trustedPeers.addAll(trustedPeers);
    if (revocations != null) result.revocations.addAll(revocations);
    if (integritySignature != null)
      result.integritySignature = integritySignature;
    return result;
  }

  TrustStoreSnapshot._();

  factory TrustStoreSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrustStoreSnapshot()..mergeFromBuffer(data, registry);
  factory TrustStoreSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrustStoreSnapshot()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrustStoreSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TrustStoreSnapshot.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'version')
    ..aInt64(2, _omitFieldNames ? '' : 'snapshotTimestampUtcMs')
    ..pPM<PeerIdentity>(3, _omitFieldNames ? '' : 'trustedPeers',
        subBuilder: PeerIdentity.$_createMessage)
    ..pPM<RevocationRecord>(4, _omitFieldNames ? '' : 'revocations',
        subBuilder: RevocationRecord.$_createMessage)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'integritySignature', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrustStoreSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrustStoreSnapshot copyWith(void Function(TrustStoreSnapshot) updates) =>
      super.copyWith((message) => updates(message as TrustStoreSnapshot))
          as TrustStoreSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TrustStoreSnapshot() / TrustStoreSnapshot.new instead')
  static TrustStoreSnapshot create() => TrustStoreSnapshot._();
  static $pb.GeneratedMessage $_createMessage() => TrustStoreSnapshot._();
  @$core.override
  TrustStoreSnapshot createEmptyInstance() => TrustStoreSnapshot._();
  @$core.pragma('dart2js:noInline')
  static TrustStoreSnapshot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrustStoreSnapshot>(
          TrustStoreSnapshot.$_createMessage);
  static TrustStoreSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get version => $_getIZ(0);
  @$pb.TagNumber(1)
  set version($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get snapshotTimestampUtcMs => $_getI64(1);
  @$pb.TagNumber(2)
  set snapshotTimestampUtcMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapshotTimestampUtcMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapshotTimestampUtcMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<PeerIdentity> get trustedPeers => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<RevocationRecord> get revocations => $_getList(3);

  @$pb.TagNumber(5)
  $core.List<$core.int> get integritySignature => $_getN(4);
  @$pb.TagNumber(5)
  set integritySignature($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIntegritySignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearIntegritySignature() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
