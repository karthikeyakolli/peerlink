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

import 'package:protobuf/protobuf.dart' as $pb;

class FeatureCapability extends $pb.ProtobufEnum {
  static const FeatureCapability FEATURE_CAPABILITY_UNSPECIFIED =
      FeatureCapability._(
          0, _omitEnumNames ? '' : 'FEATURE_CAPABILITY_UNSPECIFIED');
  static const FeatureCapability FEATURE_TRANSFER_RESUME =
      FeatureCapability._(1, _omitEnumNames ? '' : 'FEATURE_TRANSFER_RESUME');
  static const FeatureCapability FEATURE_REMOTE_SEARCH =
      FeatureCapability._(2, _omitEnumNames ? '' : 'FEATURE_REMOTE_SEARCH');
  static const FeatureCapability FEATURE_CLIPBOARD_IMAGE =
      FeatureCapability._(3, _omitEnumNames ? '' : 'FEATURE_CLIPBOARD_IMAGE');
  static const FeatureCapability FEATURE_BACKGROUND_SYNC =
      FeatureCapability._(4, _omitEnumNames ? '' : 'FEATURE_BACKGROUND_SYNC');
  static const FeatureCapability FEATURE_QUIC =
      FeatureCapability._(5, _omitEnumNames ? '' : 'FEATURE_QUIC');
  static const FeatureCapability FEATURE_TCP_TLS =
      FeatureCapability._(6, _omitEnumNames ? '' : 'FEATURE_TCP_TLS');
  static const FeatureCapability FEATURE_TURN =
      FeatureCapability._(7, _omitEnumNames ? '' : 'FEATURE_TURN');
  static const FeatureCapability FEATURE_MALWARE_SCAN =
      FeatureCapability._(8, _omitEnumNames ? '' : 'FEATURE_MALWARE_SCAN');
  static const FeatureCapability FEATURE_ARCHIVE_INSPECTION =
      FeatureCapability._(
          9, _omitEnumNames ? '' : 'FEATURE_ARCHIVE_INSPECTION');
  static const FeatureCapability FEATURE_FILE_PROVIDER =
      FeatureCapability._(10, _omitEnumNames ? '' : 'FEATURE_FILE_PROVIDER');

  static const $core.List<FeatureCapability> values = <FeatureCapability>[
    FEATURE_CAPABILITY_UNSPECIFIED,
    FEATURE_TRANSFER_RESUME,
    FEATURE_REMOTE_SEARCH,
    FEATURE_CLIPBOARD_IMAGE,
    FEATURE_BACKGROUND_SYNC,
    FEATURE_QUIC,
    FEATURE_TCP_TLS,
    FEATURE_TURN,
    FEATURE_MALWARE_SCAN,
    FEATURE_ARCHIVE_INSPECTION,
    FEATURE_FILE_PROVIDER,
  ];

  static final $core.List<FeatureCapability?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static FeatureCapability? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FeatureCapability._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
