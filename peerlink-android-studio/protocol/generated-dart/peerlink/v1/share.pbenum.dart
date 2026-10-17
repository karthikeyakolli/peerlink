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

import 'package:protobuf/protobuf.dart' as $pb;

class ShareType extends $pb.ProtobufEnum {
  static const ShareType SHARE_TYPE_UNSPECIFIED =
      ShareType._(0, _omitEnumNames ? '' : 'SHARE_TYPE_UNSPECIFIED');

  /// Peer-specific: bound to explicit trusted peer ID(s)
  static const ShareType SHARE_TYPE_PEER_SPECIFIC =
      ShareType._(1, _omitEnumNames ? '' : 'SHARE_TYPE_PEER_SPECIFIC');

  /// Temporary: scoped to a finite time window; unavailable when owner offline
  static const ShareType SHARE_TYPE_TEMPORARY =
      ShareType._(2, _omitEnumNames ? '' : 'SHARE_TYPE_TEMPORARY');

  /// One-time: capability consumed after first successful complete operation
  static const ShareType SHARE_TYPE_ONE_TIME =
      ShareType._(3, _omitEnumNames ? '' : 'SHARE_TYPE_ONE_TIME');

  /// Guest/browser: isolated, untrusted, no trusted-identity privileges
  static const ShareType SHARE_TYPE_GUEST =
      ShareType._(4, _omitEnumNames ? '' : 'SHARE_TYPE_GUEST');

  /// QR-link: opaque capability encoded for QR rendering
  static const ShareType SHARE_TYPE_QR =
      ShareType._(5, _omitEnumNames ? '' : 'SHARE_TYPE_QR');

  static const $core.List<ShareType> values = <ShareType>[
    SHARE_TYPE_UNSPECIFIED,
    SHARE_TYPE_PEER_SPECIFIC,
    SHARE_TYPE_TEMPORARY,
    SHARE_TYPE_ONE_TIME,
    SHARE_TYPE_GUEST,
    SHARE_TYPE_QR,
  ];

  static final $core.List<ShareType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ShareType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ShareType._(super.value, super.name);
}

class ShareStatus extends $pb.ProtobufEnum {
  static const ShareStatus SHARE_STATUS_UNSPECIFIED =
      ShareStatus._(0, _omitEnumNames ? '' : 'SHARE_STATUS_UNSPECIFIED');
  static const ShareStatus SHARE_STATUS_ACTIVE =
      ShareStatus._(1, _omitEnumNames ? '' : 'SHARE_STATUS_ACTIVE');
  static const ShareStatus SHARE_STATUS_EXPIRED =
      ShareStatus._(2, _omitEnumNames ? '' : 'SHARE_STATUS_EXPIRED');
  static const ShareStatus SHARE_STATUS_REVOKED =
      ShareStatus._(3, _omitEnumNames ? '' : 'SHARE_STATUS_REVOKED');
  static const ShareStatus SHARE_STATUS_CONSUMED =
      ShareStatus._(4, _omitEnumNames ? '' : 'SHARE_STATUS_CONSUMED');
  static const ShareStatus SHARE_STATUS_OWNER_OFFLINE =
      ShareStatus._(5, _omitEnumNames ? '' : 'SHARE_STATUS_OWNER_OFFLINE');

  static const $core.List<ShareStatus> values = <ShareStatus>[
    SHARE_STATUS_UNSPECIFIED,
    SHARE_STATUS_ACTIVE,
    SHARE_STATUS_EXPIRED,
    SHARE_STATUS_REVOKED,
    SHARE_STATUS_CONSUMED,
    SHARE_STATUS_OWNER_OFFLINE,
  ];

  static final $core.List<ShareStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ShareStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ShareStatus._(super.value, super.name);
}

class SharePermission extends $pb.ProtobufEnum {
  static const SharePermission SHARE_PERMISSION_UNSPECIFIED = SharePermission._(
      0, _omitEnumNames ? '' : 'SHARE_PERMISSION_UNSPECIFIED');
  static const SharePermission SHARE_PERMISSION_BROWSE =
      SharePermission._(1, _omitEnumNames ? '' : 'SHARE_PERMISSION_BROWSE');
  static const SharePermission SHARE_PERMISSION_SEARCH =
      SharePermission._(2, _omitEnumNames ? '' : 'SHARE_PERMISSION_SEARCH');
  static const SharePermission SHARE_PERMISSION_PREVIEW =
      SharePermission._(3, _omitEnumNames ? '' : 'SHARE_PERMISSION_PREVIEW');
  static const SharePermission SHARE_PERMISSION_DOWNLOAD =
      SharePermission._(4, _omitEnumNames ? '' : 'SHARE_PERMISSION_DOWNLOAD');
  static const SharePermission SHARE_PERMISSION_DOWNLOAD_SINGLE =
      SharePermission._(
          5, _omitEnumNames ? '' : 'SHARE_PERMISSION_DOWNLOAD_SINGLE');

  static const $core.List<SharePermission> values = <SharePermission>[
    SHARE_PERMISSION_UNSPECIFIED,
    SHARE_PERMISSION_BROWSE,
    SHARE_PERMISSION_SEARCH,
    SHARE_PERMISSION_PREVIEW,
    SHARE_PERMISSION_DOWNLOAD,
    SHARE_PERMISSION_DOWNLOAD_SINGLE,
  ];

  static final $core.List<SharePermission?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static SharePermission? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SharePermission._(super.value, super.name);
}

class ShareAuditEvent extends $pb.ProtobufEnum {
  static const ShareAuditEvent SHARE_AUDIT_UNSPECIFIED =
      ShareAuditEvent._(0, _omitEnumNames ? '' : 'SHARE_AUDIT_UNSPECIFIED');
  static const ShareAuditEvent SHARE_AUDIT_CREATED =
      ShareAuditEvent._(1, _omitEnumNames ? '' : 'SHARE_AUDIT_CREATED');
  static const ShareAuditEvent SHARE_AUDIT_CAPABILITY_ISSUED =
      ShareAuditEvent._(
          2, _omitEnumNames ? '' : 'SHARE_AUDIT_CAPABILITY_ISSUED');
  static const ShareAuditEvent SHARE_AUDIT_ACCESS_AUTHORIZED =
      ShareAuditEvent._(
          3, _omitEnumNames ? '' : 'SHARE_AUDIT_ACCESS_AUTHORIZED');
  static const ShareAuditEvent SHARE_AUDIT_ACCESS_REJECTED =
      ShareAuditEvent._(4, _omitEnumNames ? '' : 'SHARE_AUDIT_ACCESS_REJECTED');
  static const ShareAuditEvent SHARE_AUDIT_REVOKED =
      ShareAuditEvent._(5, _omitEnumNames ? '' : 'SHARE_AUDIT_REVOKED');
  static const ShareAuditEvent SHARE_AUDIT_EXPIRED =
      ShareAuditEvent._(6, _omitEnumNames ? '' : 'SHARE_AUDIT_EXPIRED');
  static const ShareAuditEvent SHARE_AUDIT_CONSUMED =
      ShareAuditEvent._(7, _omitEnumNames ? '' : 'SHARE_AUDIT_CONSUMED');
  static const ShareAuditEvent SHARE_AUDIT_OPERATION_RETRY =
      ShareAuditEvent._(8, _omitEnumNames ? '' : 'SHARE_AUDIT_OPERATION_RETRY');
  static const ShareAuditEvent SHARE_AUDIT_GRACE_PERIOD_STARTED =
      ShareAuditEvent._(
          9, _omitEnumNames ? '' : 'SHARE_AUDIT_GRACE_PERIOD_STARTED');
  static const ShareAuditEvent SHARE_AUDIT_GRACE_PERIOD_ENDED =
      ShareAuditEvent._(
          10, _omitEnumNames ? '' : 'SHARE_AUDIT_GRACE_PERIOD_ENDED');
  static const ShareAuditEvent SHARE_AUDIT_GUEST_ACCESS =
      ShareAuditEvent._(11, _omitEnumNames ? '' : 'SHARE_AUDIT_GUEST_ACCESS');

  static const $core.List<ShareAuditEvent> values = <ShareAuditEvent>[
    SHARE_AUDIT_UNSPECIFIED,
    SHARE_AUDIT_CREATED,
    SHARE_AUDIT_CAPABILITY_ISSUED,
    SHARE_AUDIT_ACCESS_AUTHORIZED,
    SHARE_AUDIT_ACCESS_REJECTED,
    SHARE_AUDIT_REVOKED,
    SHARE_AUDIT_EXPIRED,
    SHARE_AUDIT_CONSUMED,
    SHARE_AUDIT_OPERATION_RETRY,
    SHARE_AUDIT_GRACE_PERIOD_STARTED,
    SHARE_AUDIT_GRACE_PERIOD_ENDED,
    SHARE_AUDIT_GUEST_ACCESS,
  ];

  static final $core.List<ShareAuditEvent?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
  static ShareAuditEvent? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ShareAuditEvent._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
