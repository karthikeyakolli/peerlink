// This is a generated file - do not edit.
//
// Generated from peerlink/v1/access.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class AccessRequestType extends $pb.ProtobufEnum {
  static const AccessRequestType ACCESS_REQUEST_TYPE_UNSPECIFIED =
      AccessRequestType._(
          0, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_UNSPECIFIED');
  static const AccessRequestType ACCESS_REQUEST_TYPE_BROWSE =
      AccessRequestType._(
          1, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_BROWSE');
  static const AccessRequestType ACCESS_REQUEST_TYPE_METADATA =
      AccessRequestType._(
          2, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_METADATA');
  static const AccessRequestType ACCESS_REQUEST_TYPE_SEARCH =
      AccessRequestType._(
          3, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_SEARCH');
  static const AccessRequestType ACCESS_REQUEST_TYPE_PREVIEW =
      AccessRequestType._(
          4, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_PREVIEW');
  static const AccessRequestType ACCESS_REQUEST_TYPE_DOWNLOAD =
      AccessRequestType._(
          5, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_DOWNLOAD');
  static const AccessRequestType ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT =
      AccessRequestType._(
          6, _omitEnumNames ? '' : 'ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT');

  static const $core.List<AccessRequestType> values = <AccessRequestType>[
    ACCESS_REQUEST_TYPE_UNSPECIFIED,
    ACCESS_REQUEST_TYPE_BROWSE,
    ACCESS_REQUEST_TYPE_METADATA,
    ACCESS_REQUEST_TYPE_SEARCH,
    ACCESS_REQUEST_TYPE_PREVIEW,
    ACCESS_REQUEST_TYPE_DOWNLOAD,
    ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT,
  ];

  static final $core.List<AccessRequestType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static AccessRequestType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AccessRequestType._(super.value, super.name);
}

class AccessScope extends $pb.ProtobufEnum {
  static const AccessScope ACCESS_SCOPE_UNSPECIFIED =
      AccessScope._(0, _omitEnumNames ? '' : 'ACCESS_SCOPE_UNSPECIFIED');
  static const AccessScope ACCESS_SCOPE_READ_METADATA =
      AccessScope._(1, _omitEnumNames ? '' : 'ACCESS_SCOPE_READ_METADATA');
  static const AccessScope ACCESS_SCOPE_BROWSE =
      AccessScope._(2, _omitEnumNames ? '' : 'ACCESS_SCOPE_BROWSE');
  static const AccessScope ACCESS_SCOPE_SEARCH =
      AccessScope._(3, _omitEnumNames ? '' : 'ACCESS_SCOPE_SEARCH');
  static const AccessScope ACCESS_SCOPE_PREVIEW =
      AccessScope._(4, _omitEnumNames ? '' : 'ACCESS_SCOPE_PREVIEW');
  static const AccessScope ACCESS_SCOPE_DOWNLOAD =
      AccessScope._(5, _omitEnumNames ? '' : 'ACCESS_SCOPE_DOWNLOAD');
  static const AccessScope ACCESS_SCOPE_FULL =
      AccessScope._(6, _omitEnumNames ? '' : 'ACCESS_SCOPE_FULL');

  static const $core.List<AccessScope> values = <AccessScope>[
    ACCESS_SCOPE_UNSPECIFIED,
    ACCESS_SCOPE_READ_METADATA,
    ACCESS_SCOPE_BROWSE,
    ACCESS_SCOPE_SEARCH,
    ACCESS_SCOPE_PREVIEW,
    ACCESS_SCOPE_DOWNLOAD,
    ACCESS_SCOPE_FULL,
  ];

  static final $core.List<AccessScope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static AccessScope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AccessScope._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
