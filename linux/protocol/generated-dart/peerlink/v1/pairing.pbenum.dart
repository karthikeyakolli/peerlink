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

import 'package:protobuf/protobuf.dart' as $pb;

class PairingState extends $pb.ProtobufEnum {
  static const PairingState PAIRING_STATE_UNSPECIFIED =
      PairingState._(0, _omitEnumNames ? '' : 'PAIRING_STATE_UNSPECIFIED');
  static const PairingState PAIRING_STATE_INITIATED =
      PairingState._(1, _omitEnumNames ? '' : 'PAIRING_STATE_INITIATED');
  static const PairingState PAIRING_STATE_OFFERED =
      PairingState._(2, _omitEnumNames ? '' : 'PAIRING_STATE_OFFERED');
  static const PairingState PAIRING_STATE_VERIFYING =
      PairingState._(3, _omitEnumNames ? '' : 'PAIRING_STATE_VERIFYING');
  static const PairingState PAIRING_STATE_CONFIRMED =
      PairingState._(4, _omitEnumNames ? '' : 'PAIRING_STATE_CONFIRMED');
  static const PairingState PAIRING_STATE_REJECTED =
      PairingState._(5, _omitEnumNames ? '' : 'PAIRING_STATE_REJECTED');
  static const PairingState PAIRING_STATE_REVOKED =
      PairingState._(6, _omitEnumNames ? '' : 'PAIRING_STATE_REVOKED');
  static const PairingState PAIRING_STATE_EXPIRED =
      PairingState._(7, _omitEnumNames ? '' : 'PAIRING_STATE_EXPIRED');

  static const $core.List<PairingState> values = <PairingState>[
    PAIRING_STATE_UNSPECIFIED,
    PAIRING_STATE_INITIATED,
    PAIRING_STATE_OFFERED,
    PAIRING_STATE_VERIFYING,
    PAIRING_STATE_CONFIRMED,
    PAIRING_STATE_REJECTED,
    PAIRING_STATE_REVOKED,
    PAIRING_STATE_EXPIRED,
  ];

  static final $core.List<PairingState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static PairingState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PairingState._(super.value, super.name);
}

class PairingMethod extends $pb.ProtobufEnum {
  static const PairingMethod PAIRING_METHOD_UNSPECIFIED =
      PairingMethod._(0, _omitEnumNames ? '' : 'PAIRING_METHOD_UNSPECIFIED');
  static const PairingMethod PAIRING_METHOD_QR_CODE =
      PairingMethod._(1, _omitEnumNames ? '' : 'PAIRING_METHOD_QR_CODE');
  static const PairingMethod PAIRING_METHOD_NUMERIC_CODE =
      PairingMethod._(2, _omitEnumNames ? '' : 'PAIRING_METHOD_NUMERIC_CODE');
  static const PairingMethod PAIRING_METHOD_MANUAL_VERIFICATION =
      PairingMethod._(
          3, _omitEnumNames ? '' : 'PAIRING_METHOD_MANUAL_VERIFICATION');

  static const $core.List<PairingMethod> values = <PairingMethod>[
    PAIRING_METHOD_UNSPECIFIED,
    PAIRING_METHOD_QR_CODE,
    PAIRING_METHOD_NUMERIC_CODE,
    PAIRING_METHOD_MANUAL_VERIFICATION,
  ];

  static final $core.List<PairingMethod?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static PairingMethod? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PairingMethod._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
