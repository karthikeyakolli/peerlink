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

import 'package:protobuf/protobuf.dart' as $pb;

class DeviceType extends $pb.ProtobufEnum {
  static const DeviceType DEVICE_TYPE_UNSPECIFIED =
      DeviceType._(0, _omitEnumNames ? '' : 'DEVICE_TYPE_UNSPECIFIED');
  static const DeviceType DEVICE_TYPE_DESKTOP_WINDOWS =
      DeviceType._(1, _omitEnumNames ? '' : 'DEVICE_TYPE_DESKTOP_WINDOWS');
  static const DeviceType DEVICE_TYPE_DESKTOP_MACOS =
      DeviceType._(2, _omitEnumNames ? '' : 'DEVICE_TYPE_DESKTOP_MACOS');
  static const DeviceType DEVICE_TYPE_DESKTOP_LINUX =
      DeviceType._(3, _omitEnumNames ? '' : 'DEVICE_TYPE_DESKTOP_LINUX');
  static const DeviceType DEVICE_TYPE_MOBILE_ANDROID =
      DeviceType._(4, _omitEnumNames ? '' : 'DEVICE_TYPE_MOBILE_ANDROID');
  static const DeviceType DEVICE_TYPE_MOBILE_IOS =
      DeviceType._(5, _omitEnumNames ? '' : 'DEVICE_TYPE_MOBILE_IOS');
  static const DeviceType DEVICE_TYPE_HEADLESS_SERVER =
      DeviceType._(6, _omitEnumNames ? '' : 'DEVICE_TYPE_HEADLESS_SERVER');

  static const $core.List<DeviceType> values = <DeviceType>[
    DEVICE_TYPE_UNSPECIFIED,
    DEVICE_TYPE_DESKTOP_WINDOWS,
    DEVICE_TYPE_DESKTOP_MACOS,
    DEVICE_TYPE_DESKTOP_LINUX,
    DEVICE_TYPE_MOBILE_ANDROID,
    DEVICE_TYPE_MOBILE_IOS,
    DEVICE_TYPE_HEADLESS_SERVER,
  ];

  static final $core.List<DeviceType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static DeviceType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeviceType._(super.value, super.name);
}

class KeyType extends $pb.ProtobufEnum {
  static const KeyType KEY_TYPE_UNSPECIFIED =
      KeyType._(0, _omitEnumNames ? '' : 'KEY_TYPE_UNSPECIFIED');
  static const KeyType KEY_TYPE_ED25519 =
      KeyType._(1, _omitEnumNames ? '' : 'KEY_TYPE_ED25519');
  static const KeyType KEY_TYPE_X25519 =
      KeyType._(2, _omitEnumNames ? '' : 'KEY_TYPE_X25519');

  static const $core.List<KeyType> values = <KeyType>[
    KEY_TYPE_UNSPECIFIED,
    KEY_TYPE_ED25519,
    KEY_TYPE_X25519,
  ];

  static final $core.List<KeyType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static KeyType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const KeyType._(super.value, super.name);
}

class TrustLevel extends $pb.ProtobufEnum {
  static const TrustLevel TRUST_LEVEL_UNSPECIFIED =
      TrustLevel._(0, _omitEnumNames ? '' : 'TRUST_LEVEL_UNSPECIFIED');
  static const TrustLevel TRUST_LEVEL_UNTRUSTED =
      TrustLevel._(1, _omitEnumNames ? '' : 'TRUST_LEVEL_UNTRUSTED');
  static const TrustLevel TRUST_LEVEL_PAIRING_PENDING =
      TrustLevel._(2, _omitEnumNames ? '' : 'TRUST_LEVEL_PAIRING_PENDING');
  static const TrustLevel TRUST_LEVEL_TRUSTED_PAIRED =
      TrustLevel._(3, _omitEnumNames ? '' : 'TRUST_LEVEL_TRUSTED_PAIRED');
  static const TrustLevel TRUST_LEVEL_REVOKED =
      TrustLevel._(4, _omitEnumNames ? '' : 'TRUST_LEVEL_REVOKED');
  static const TrustLevel TRUST_LEVEL_BLOCKED =
      TrustLevel._(5, _omitEnumNames ? '' : 'TRUST_LEVEL_BLOCKED');

  static const $core.List<TrustLevel> values = <TrustLevel>[
    TRUST_LEVEL_UNSPECIFIED,
    TRUST_LEVEL_UNTRUSTED,
    TRUST_LEVEL_PAIRING_PENDING,
    TRUST_LEVEL_TRUSTED_PAIRED,
    TRUST_LEVEL_REVOKED,
    TRUST_LEVEL_BLOCKED,
  ];

  static final $core.List<TrustLevel?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static TrustLevel? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TrustLevel._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
