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

import 'package:protobuf/protobuf.dart' as $pb;

class NodeExecutionStatus extends $pb.ProtobufEnum {
  static const NodeExecutionStatus NODE_EXECUTION_STATUS_UNSPECIFIED =
      NodeExecutionStatus._(
          0, _omitEnumNames ? '' : 'NODE_EXECUTION_STATUS_UNSPECIFIED');
  static const NodeExecutionStatus NODE_EXECUTION_STATUS_STARTING =
      NodeExecutionStatus._(
          1, _omitEnumNames ? '' : 'NODE_EXECUTION_STATUS_STARTING');
  static const NodeExecutionStatus NODE_EXECUTION_STATUS_RUNNING =
      NodeExecutionStatus._(
          2, _omitEnumNames ? '' : 'NODE_EXECUTION_STATUS_RUNNING');
  static const NodeExecutionStatus NODE_EXECUTION_STATUS_DEGRADED =
      NodeExecutionStatus._(
          3, _omitEnumNames ? '' : 'NODE_EXECUTION_STATUS_DEGRADED');
  static const NodeExecutionStatus NODE_EXECUTION_STATUS_STOPPING =
      NodeExecutionStatus._(
          4, _omitEnumNames ? '' : 'NODE_EXECUTION_STATUS_STOPPING');
  static const NodeExecutionStatus NODE_EXECUTION_STATUS_STOPPED =
      NodeExecutionStatus._(
          5, _omitEnumNames ? '' : 'NODE_EXECUTION_STATUS_STOPPED');

  static const $core.List<NodeExecutionStatus> values = <NodeExecutionStatus>[
    NODE_EXECUTION_STATUS_UNSPECIFIED,
    NODE_EXECUTION_STATUS_STARTING,
    NODE_EXECUTION_STATUS_RUNNING,
    NODE_EXECUTION_STATUS_DEGRADED,
    NODE_EXECUTION_STATUS_STOPPING,
    NODE_EXECUTION_STATUS_STOPPED,
  ];

  static final $core.List<NodeExecutionStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static NodeExecutionStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NodeExecutionStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
