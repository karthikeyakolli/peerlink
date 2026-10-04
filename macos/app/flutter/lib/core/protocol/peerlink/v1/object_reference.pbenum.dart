// This is a generated file - do not edit.
//
// Generated from peerlink/v1/object_reference.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ObjectType extends $pb.ProtobufEnum {
  static const ObjectType OBJECT_TYPE_UNSPECIFIED =
      ObjectType._(0, _omitEnumNames ? '' : 'OBJECT_TYPE_UNSPECIFIED');
  static const ObjectType OBJECT_TYPE_FILE =
      ObjectType._(1, _omitEnumNames ? '' : 'OBJECT_TYPE_FILE');
  static const ObjectType OBJECT_TYPE_DIRECTORY =
      ObjectType._(2, _omitEnumNames ? '' : 'OBJECT_TYPE_DIRECTORY');
  static const ObjectType OBJECT_TYPE_COLLECTION =
      ObjectType._(3, _omitEnumNames ? '' : 'OBJECT_TYPE_COLLECTION');
  static const ObjectType OBJECT_TYPE_TOMBSTONE =
      ObjectType._(4, _omitEnumNames ? '' : 'OBJECT_TYPE_TOMBSTONE');

  static const $core.List<ObjectType> values = <ObjectType>[
    OBJECT_TYPE_UNSPECIFIED,
    OBJECT_TYPE_FILE,
    OBJECT_TYPE_DIRECTORY,
    OBJECT_TYPE_COLLECTION,
    OBJECT_TYPE_TOMBSTONE,
  ];

  static final $core.List<ObjectType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ObjectType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ObjectType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
