// This is a generated file - do not edit.
//
// Generated from peerlink/v1/discovery.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class DiscoveryEventType extends $pb.ProtobufEnum {
  static const DiscoveryEventType DISCOVERY_EVENT_TYPE_UNSPECIFIED =
      DiscoveryEventType._(
          0, _omitEnumNames ? '' : 'DISCOVERY_EVENT_TYPE_UNSPECIFIED');
  static const DiscoveryEventType DISCOVERY_EVENT_TYPE_PEER_FOUND =
      DiscoveryEventType._(
          1, _omitEnumNames ? '' : 'DISCOVERY_EVENT_TYPE_PEER_FOUND');
  static const DiscoveryEventType DISCOVERY_EVENT_TYPE_PEER_LOST =
      DiscoveryEventType._(
          2, _omitEnumNames ? '' : 'DISCOVERY_EVENT_TYPE_PEER_LOST');
  static const DiscoveryEventType DISCOVERY_EVENT_TYPE_PEER_UPDATED =
      DiscoveryEventType._(
          3, _omitEnumNames ? '' : 'DISCOVERY_EVENT_TYPE_PEER_UPDATED');

  static const $core.List<DiscoveryEventType> values = <DiscoveryEventType>[
    DISCOVERY_EVENT_TYPE_UNSPECIFIED,
    DISCOVERY_EVENT_TYPE_PEER_FOUND,
    DISCOVERY_EVENT_TYPE_PEER_LOST,
    DISCOVERY_EVENT_TYPE_PEER_UPDATED,
  ];

  static final $core.List<DiscoveryEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static DiscoveryEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DiscoveryEventType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
