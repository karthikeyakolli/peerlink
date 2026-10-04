// This is a generated file - do not edit.
//
// Generated from peerlink/v1/share.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use shareTypeDescriptor instead')
const ShareType$json = {
  '1': 'ShareType',
  '2': [
    {'1': 'SHARE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'SHARE_TYPE_PEER_SPECIFIC', '2': 1},
    {'1': 'SHARE_TYPE_TEMPORARY', '2': 2},
    {'1': 'SHARE_TYPE_ONE_TIME', '2': 3},
    {'1': 'SHARE_TYPE_GUEST', '2': 4},
    {'1': 'SHARE_TYPE_QR', '2': 5},
  ],
};

/// Descriptor for `ShareType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List shareTypeDescriptor = $convert.base64Decode(
    'CglTaGFyZVR5cGUSGgoWU0hBUkVfVFlQRV9VTlNQRUNJRklFRBAAEhwKGFNIQVJFX1RZUEVfUE'
    'VFUl9TUEVDSUZJQxABEhgKFFNIQVJFX1RZUEVfVEVNUE9SQVJZEAISFwoTU0hBUkVfVFlQRV9P'
    'TkVfVElNRRADEhQKEFNIQVJFX1RZUEVfR1VFU1QQBBIRCg1TSEFSRV9UWVBFX1FSEAU=');

@$core.Deprecated('Use shareStatusDescriptor instead')
const ShareStatus$json = {
  '1': 'ShareStatus',
  '2': [
    {'1': 'SHARE_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'SHARE_STATUS_ACTIVE', '2': 1},
    {'1': 'SHARE_STATUS_EXPIRED', '2': 2},
    {'1': 'SHARE_STATUS_REVOKED', '2': 3},
    {'1': 'SHARE_STATUS_CONSUMED', '2': 4},
    {'1': 'SHARE_STATUS_OWNER_OFFLINE', '2': 5},
  ],
};

/// Descriptor for `ShareStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List shareStatusDescriptor = $convert.base64Decode(
    'CgtTaGFyZVN0YXR1cxIcChhTSEFSRV9TVEFUVVNfVU5TUEVDSUZJRUQQABIXChNTSEFSRV9TVE'
    'FUVVNfQUNUSVZFEAESGAoUU0hBUkVfU1RBVFVTX0VYUElSRUQQAhIYChRTSEFSRV9TVEFUVVNf'
    'UkVWT0tFRBADEhkKFVNIQVJFX1NUQVRVU19DT05TVU1FRBAEEh4KGlNIQVJFX1NUQVRVU19PV0'
    '5FUl9PRkZMSU5FEAU=');

@$core.Deprecated('Use sharePermissionDescriptor instead')
const SharePermission$json = {
  '1': 'SharePermission',
  '2': [
    {'1': 'SHARE_PERMISSION_UNSPECIFIED', '2': 0},
    {'1': 'SHARE_PERMISSION_BROWSE', '2': 1},
    {'1': 'SHARE_PERMISSION_SEARCH', '2': 2},
    {'1': 'SHARE_PERMISSION_PREVIEW', '2': 3},
    {'1': 'SHARE_PERMISSION_DOWNLOAD', '2': 4},
    {'1': 'SHARE_PERMISSION_DOWNLOAD_SINGLE', '2': 5},
  ],
};

/// Descriptor for `SharePermission`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sharePermissionDescriptor = $convert.base64Decode(
    'Cg9TaGFyZVBlcm1pc3Npb24SIAocU0hBUkVfUEVSTUlTU0lPTl9VTlNQRUNJRklFRBAAEhsKF1'
    'NIQVJFX1BFUk1JU1NJT05fQlJPV1NFEAESGwoXU0hBUkVfUEVSTUlTU0lPTl9TRUFSQ0gQAhIc'
    'ChhTSEFSRV9QRVJNSVNTSU9OX1BSRVZJRVcQAxIdChlTSEFSRV9QRVJNSVNTSU9OX0RPV05MT0'
    'FEEAQSJAogU0hBUkVfUEVSTUlTU0lPTl9ET1dOTE9BRF9TSU5HTEUQBQ==');

@$core.Deprecated('Use shareAuditEventDescriptor instead')
const ShareAuditEvent$json = {
  '1': 'ShareAuditEvent',
  '2': [
    {'1': 'SHARE_AUDIT_UNSPECIFIED', '2': 0},
    {'1': 'SHARE_AUDIT_CREATED', '2': 1},
    {'1': 'SHARE_AUDIT_CAPABILITY_ISSUED', '2': 2},
    {'1': 'SHARE_AUDIT_ACCESS_AUTHORIZED', '2': 3},
    {'1': 'SHARE_AUDIT_ACCESS_REJECTED', '2': 4},
    {'1': 'SHARE_AUDIT_REVOKED', '2': 5},
    {'1': 'SHARE_AUDIT_EXPIRED', '2': 6},
    {'1': 'SHARE_AUDIT_CONSUMED', '2': 7},
    {'1': 'SHARE_AUDIT_OPERATION_RETRY', '2': 8},
    {'1': 'SHARE_AUDIT_GRACE_PERIOD_STARTED', '2': 9},
    {'1': 'SHARE_AUDIT_GRACE_PERIOD_ENDED', '2': 10},
    {'1': 'SHARE_AUDIT_GUEST_ACCESS', '2': 11},
  ],
};

/// Descriptor for `ShareAuditEvent`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List shareAuditEventDescriptor = $convert.base64Decode(
    'Cg9TaGFyZUF1ZGl0RXZlbnQSGwoXU0hBUkVfQVVESVRfVU5TUEVDSUZJRUQQABIXChNTSEFSRV'
    '9BVURJVF9DUkVBVEVEEAESIQodU0hBUkVfQVVESVRfQ0FQQUJJTElUWV9JU1NVRUQQAhIhCh1T'
    'SEFSRV9BVURJVF9BQ0NFU1NfQVVUSE9SSVpFRBADEh8KG1NIQVJFX0FVRElUX0FDQ0VTU19SRU'
    'pFQ1RFRBAEEhcKE1NIQVJFX0FVRElUX1JFVk9LRUQQBRIXChNTSEFSRV9BVURJVF9FWFBJUkVE'
    'EAYSGAoUU0hBUkVfQVVESVRfQ09OU1VNRUQQBxIfChtTSEFSRV9BVURJVF9PUEVSQVRJT05fUk'
    'VUUlkQCBIkCiBTSEFSRV9BVURJVF9HUkFDRV9QRVJJT0RfU1RBUlRFRBAJEiIKHlNIQVJFX0FV'
    'RElUX0dSQUNFX1BFUklPRF9FTkRFRBAKEhwKGFNIQVJFX0FVRElUX0dVRVNUX0FDQ0VTUxAL');

@$core.Deprecated('Use shareCapabilityTokenDescriptor instead')
const ShareCapabilityToken$json = {
  '1': 'ShareCapabilityToken',
  '2': [
    {'1': 'token_id', '3': 1, '4': 1, '5': 9, '10': 'tokenId'},
    {'1': 'share_id', '3': 2, '4': 1, '5': 9, '10': 'shareId'},
    {
      '1': 'share_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ShareType',
      '10': 'shareType'
    },
    {
      '1': 'permissions',
      '3': 4,
      '4': 3,
      '5': 14,
      '6': '.peerlink.v1.SharePermission',
      '10': 'permissions'
    },
    {'1': 'issued_at_utc_ms', '3': 5, '4': 1, '5': 3, '10': 'issuedAtUtcMs'},
    {'1': 'expires_at_utc_ms', '3': 6, '4': 1, '5': 3, '10': 'expiresAtUtcMs'},
    {'1': 'bound_peer_id', '3': 7, '4': 1, '5': 9, '10': 'boundPeerId'},
    {'1': 'is_guest_token', '3': 8, '4': 1, '5': 8, '10': 'isGuestToken'},
    {
      '1': 'hmac_signature_hex',
      '3': 9,
      '4': 1,
      '5': 9,
      '10': 'hmacSignatureHex'
    },
    {'1': 'operation_id', '3': 10, '4': 1, '5': 9, '10': 'operationId'},
  ],
};

/// Descriptor for `ShareCapabilityToken`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareCapabilityTokenDescriptor = $convert.base64Decode(
    'ChRTaGFyZUNhcGFiaWxpdHlUb2tlbhIZCgh0b2tlbl9pZBgBIAEoCVIHdG9rZW5JZBIZCghzaG'
    'FyZV9pZBgCIAEoCVIHc2hhcmVJZBI1CgpzaGFyZV90eXBlGAMgASgOMhYucGVlcmxpbmsudjEu'
    'U2hhcmVUeXBlUglzaGFyZVR5cGUSPgoLcGVybWlzc2lvbnMYBCADKA4yHC5wZWVybGluay52MS'
    '5TaGFyZVBlcm1pc3Npb25SC3Blcm1pc3Npb25zEicKEGlzc3VlZF9hdF91dGNfbXMYBSABKANS'
    'DWlzc3VlZEF0VXRjTXMSKQoRZXhwaXJlc19hdF91dGNfbXMYBiABKANSDmV4cGlyZXNBdFV0Y0'
    '1zEiIKDWJvdW5kX3BlZXJfaWQYByABKAlSC2JvdW5kUGVlcklkEiQKDmlzX2d1ZXN0X3Rva2Vu'
    'GAggASgIUgxpc0d1ZXN0VG9rZW4SLAoSaG1hY19zaWduYXR1cmVfaGV4GAkgASgJUhBobWFjU2'
    'lnbmF0dXJlSGV4EiEKDG9wZXJhdGlvbl9pZBgKIAEoCVILb3BlcmF0aW9uSWQ=');

@$core.Deprecated('Use shareObjectDescriptor instead')
const ShareObject$json = {
  '1': 'ShareObject',
  '2': [
    {'1': 'share_id', '3': 1, '4': 1, '5': 9, '10': 'shareId'},
    {'1': 'owner_peer_id', '3': 2, '4': 1, '5': 9, '10': 'ownerPeerId'},
    {
      '1': 'share_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ShareType',
      '10': 'shareType'
    },
    {
      '1': 'status',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ShareStatus',
      '10': 'status'
    },
    {'1': 'display_label', '3': 5, '4': 1, '5': 9, '10': 'displayLabel'},
    {'1': 'allowed_peer_ids', '3': 6, '4': 3, '5': 9, '10': 'allowedPeerIds'},
    {
      '1': 'permissions',
      '3': 7,
      '4': 3,
      '5': 14,
      '6': '.peerlink.v1.SharePermission',
      '10': 'permissions'
    },
    {'1': 'created_at_utc_ms', '3': 8, '4': 1, '5': 3, '10': 'createdAtUtcMs'},
    {'1': 'expires_at_utc_ms', '3': 9, '4': 1, '5': 3, '10': 'expiresAtUtcMs'},
    {'1': 'grace_period_ms', '3': 10, '4': 1, '5': 3, '10': 'gracePeriodMs'},
    {'1': 'is_one_time', '3': 11, '4': 1, '5': 8, '10': 'isOneTime'},
    {
      '1': 'consumed_by_operation_id',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'consumedByOperationId'
    },
    {'1': 'revoked', '3': 13, '4': 1, '5': 8, '10': 'revoked'},
    {'1': 'revoked_at_utc_ms', '3': 14, '4': 1, '5': 3, '10': 'revokedAtUtcMs'},
    {'1': 'revoke_reason', '3': 15, '4': 1, '5': 9, '10': 'revokeReason'},
    {'1': 'guest_allowed', '3': 16, '4': 1, '5': 8, '10': 'guestAllowed'},
    {'1': 'qr_payload', '3': 17, '4': 1, '5': 9, '10': 'qrPayload'},
    {
      '1': 'last_activity_utc_ms',
      '3': 18,
      '4': 1,
      '5': 3,
      '10': 'lastActivityUtcMs'
    },
  ],
};

/// Descriptor for `ShareObject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareObjectDescriptor = $convert.base64Decode(
    'CgtTaGFyZU9iamVjdBIZCghzaGFyZV9pZBgBIAEoCVIHc2hhcmVJZBIiCg1vd25lcl9wZWVyX2'
    'lkGAIgASgJUgtvd25lclBlZXJJZBI1CgpzaGFyZV90eXBlGAMgASgOMhYucGVlcmxpbmsudjEu'
    'U2hhcmVUeXBlUglzaGFyZVR5cGUSMAoGc3RhdHVzGAQgASgOMhgucGVlcmxpbmsudjEuU2hhcm'
    'VTdGF0dXNSBnN0YXR1cxIjCg1kaXNwbGF5X2xhYmVsGAUgASgJUgxkaXNwbGF5TGFiZWwSKAoQ'
    'YWxsb3dlZF9wZWVyX2lkcxgGIAMoCVIOYWxsb3dlZFBlZXJJZHMSPgoLcGVybWlzc2lvbnMYBy'
    'ADKA4yHC5wZWVybGluay52MS5TaGFyZVBlcm1pc3Npb25SC3Blcm1pc3Npb25zEikKEWNyZWF0'
    'ZWRfYXRfdXRjX21zGAggASgDUg5jcmVhdGVkQXRVdGNNcxIpChFleHBpcmVzX2F0X3V0Y19tcx'
    'gJIAEoA1IOZXhwaXJlc0F0VXRjTXMSJgoPZ3JhY2VfcGVyaW9kX21zGAogASgDUg1ncmFjZVBl'
    'cmlvZE1zEh4KC2lzX29uZV90aW1lGAsgASgIUglpc09uZVRpbWUSNwoYY29uc3VtZWRfYnlfb3'
    'BlcmF0aW9uX2lkGAwgASgJUhVjb25zdW1lZEJ5T3BlcmF0aW9uSWQSGAoHcmV2b2tlZBgNIAEo'
    'CFIHcmV2b2tlZBIpChFyZXZva2VkX2F0X3V0Y19tcxgOIAEoA1IOcmV2b2tlZEF0VXRjTXMSIw'
    'oNcmV2b2tlX3JlYXNvbhgPIAEoCVIMcmV2b2tlUmVhc29uEiMKDWd1ZXN0X2FsbG93ZWQYECAB'
    'KAhSDGd1ZXN0QWxsb3dlZBIdCgpxcl9wYXlsb2FkGBEgASgJUglxclBheWxvYWQSLwoUbGFzdF'
    '9hY3Rpdml0eV91dGNfbXMYEiABKANSEWxhc3RBY3Rpdml0eVV0Y01z');

@$core.Deprecated('Use shareApprovalStateDescriptor instead')
const ShareApprovalState$json = {
  '1': 'ShareApprovalState',
  '2': [
    {'1': 'share_id', '3': 1, '4': 1, '5': 9, '10': 'shareId'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ShareStatus',
      '10': 'status'
    },
    {
      '1': 'pending_owner_approval',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'pendingOwnerApproval'
    },
    {'1': 'owner_approved', '3': 4, '4': 1, '5': 8, '10': 'ownerApproved'},
    {'1': 'owner_denied', '3': 5, '4': 1, '5': 8, '10': 'ownerDenied'},
    {'1': 'denial_reason', '3': 6, '4': 1, '5': 9, '10': 'denialReason'},
    {
      '1': 'approval_timestamp_utc_ms',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'approvalTimestampUtcMs'
    },
    {
      '1': 'pending_guest_requests',
      '3': 8,
      '4': 3,
      '5': 9,
      '10': 'pendingGuestRequests'
    },
  ],
};

/// Descriptor for `ShareApprovalState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareApprovalStateDescriptor = $convert.base64Decode(
    'ChJTaGFyZUFwcHJvdmFsU3RhdGUSGQoIc2hhcmVfaWQYASABKAlSB3NoYXJlSWQSMAoGc3RhdH'
    'VzGAIgASgOMhgucGVlcmxpbmsudjEuU2hhcmVTdGF0dXNSBnN0YXR1cxI0ChZwZW5kaW5nX293'
    'bmVyX2FwcHJvdmFsGAMgASgIUhRwZW5kaW5nT3duZXJBcHByb3ZhbBIlCg5vd25lcl9hcHByb3'
    'ZlZBgEIAEoCFINb3duZXJBcHByb3ZlZBIhCgxvd25lcl9kZW5pZWQYBSABKAhSC293bmVyRGVu'
    'aWVkEiMKDWRlbmlhbF9yZWFzb24YBiABKAlSDGRlbmlhbFJlYXNvbhI5ChlhcHByb3ZhbF90aW'
    '1lc3RhbXBfdXRjX21zGAcgASgDUhZhcHByb3ZhbFRpbWVzdGFtcFV0Y01zEjQKFnBlbmRpbmdf'
    'Z3Vlc3RfcmVxdWVzdHMYCCADKAlSFHBlbmRpbmdHdWVzdFJlcXVlc3Rz');

@$core.Deprecated('Use shareAuditRecordDescriptor instead')
const ShareAuditRecord$json = {
  '1': 'ShareAuditRecord',
  '2': [
    {'1': 'timestamp_utc_ms', '3': 1, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {'1': 'share_id', '3': 2, '4': 1, '5': 9, '10': 'shareId'},
    {'1': 'actor_peer_id', '3': 3, '4': 1, '5': 9, '10': 'actorPeerId'},
    {
      '1': 'event',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ShareAuditEvent',
      '10': 'event'
    },
    {'1': 'operation_id', '3': 5, '4': 1, '5': 9, '10': 'operationId'},
    {'1': 'detail', '3': 6, '4': 1, '5': 9, '10': 'detail'},
  ],
};

/// Descriptor for `ShareAuditRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareAuditRecordDescriptor = $convert.base64Decode(
    'ChBTaGFyZUF1ZGl0UmVjb3JkEigKEHRpbWVzdGFtcF91dGNfbXMYASABKANSDnRpbWVzdGFtcF'
    'V0Y01zEhkKCHNoYXJlX2lkGAIgASgJUgdzaGFyZUlkEiIKDWFjdG9yX3BlZXJfaWQYAyABKAlS'
    'C2FjdG9yUGVlcklkEjIKBWV2ZW50GAQgASgOMhwucGVlcmxpbmsudjEuU2hhcmVBdWRpdEV2ZW'
    '50UgVldmVudBIhCgxvcGVyYXRpb25faWQYBSABKAlSC29wZXJhdGlvbklkEhYKBmRldGFpbBgG'
    'IAEoCVIGZGV0YWls');

@$core.Deprecated('Use shareUseRequestDescriptor instead')
const ShareUseRequest$json = {
  '1': 'ShareUseRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'token_id', '3': 2, '4': 1, '5': 9, '10': 'tokenId'},
    {'1': 'share_id', '3': 3, '4': 1, '5': 9, '10': 'shareId'},
    {
      '1': 'requester_peer_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'requesterPeerId'
    },
    {
      '1': 'requested_permission',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.SharePermission',
      '10': 'requestedPermission'
    },
    {'1': 'operation_id', '3': 6, '4': 1, '5': 9, '10': 'operationId'},
    {'1': 'timestamp_utc_ms', '3': 7, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {'1': 'is_guest', '3': 8, '4': 1, '5': 8, '10': 'isGuest'},
  ],
};

/// Descriptor for `ShareUseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareUseRequestDescriptor = $convert.base64Decode(
    'Cg9TaGFyZVVzZVJlcXVlc3QSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEhkKCHRva2'
    'VuX2lkGAIgASgJUgd0b2tlbklkEhkKCHNoYXJlX2lkGAMgASgJUgdzaGFyZUlkEj8KEXJlcXVl'
    'c3Rlcl9wZWVyX2lkGAQgASgLMhMucGVlcmxpbmsudjEuUGVlcklkUg9yZXF1ZXN0ZXJQZWVySW'
    'QSTwoUcmVxdWVzdGVkX3Blcm1pc3Npb24YBSABKA4yHC5wZWVybGluay52MS5TaGFyZVBlcm1p'
    'c3Npb25SE3JlcXVlc3RlZFBlcm1pc3Npb24SIQoMb3BlcmF0aW9uX2lkGAYgASgJUgtvcGVyYX'
    'Rpb25JZBIoChB0aW1lc3RhbXBfdXRjX21zGAcgASgDUg50aW1lc3RhbXBVdGNNcxIZCghpc19n'
    'dWVzdBgIIAEoCFIHaXNHdWVzdA==');

@$core.Deprecated('Use shareUseResponseDescriptor instead')
const ShareUseResponse$json = {
  '1': 'ShareUseResponse',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'authorized', '3': 2, '4': 1, '5': 8, '10': 'authorized'},
    {
      '1': 'share_status',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ShareStatus',
      '10': 'shareStatus'
    },
    {
      '1': 'error',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
    {
      '1': 'authorized_until_utc_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'authorizedUntilUtcMs'
    },
    {
      '1': 'within_grace_period',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'withinGracePeriod'
    },
  ],
};

/// Descriptor for `ShareUseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareUseResponseDescriptor = $convert.base64Decode(
    'ChBTaGFyZVVzZVJlc3BvbnNlEh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZBIeCgphdX'
    'Rob3JpemVkGAIgASgIUgphdXRob3JpemVkEjsKDHNoYXJlX3N0YXR1cxgDIAEoDjIYLnBlZXJs'
    'aW5rLnYxLlNoYXJlU3RhdHVzUgtzaGFyZVN0YXR1cxIuCgVlcnJvchgEIAEoCzIYLnBlZXJsaW'
    '5rLnYxLkVycm9yRGV0YWlsUgVlcnJvchI1ChdhdXRob3JpemVkX3VudGlsX3V0Y19tcxgFIAEo'
    'A1IUYXV0aG9yaXplZFVudGlsVXRjTXMSLgoTd2l0aGluX2dyYWNlX3BlcmlvZBgGIAEoCFIRd2'
    'l0aGluR3JhY2VQZXJpb2Q=');

@$core.Deprecated('Use shareRevocationNoticeDescriptor instead')
const ShareRevocationNotice$json = {
  '1': 'ShareRevocationNotice',
  '2': [
    {'1': 'share_id', '3': 1, '4': 1, '5': 9, '10': 'shareId'},
    {'1': 'owner_peer_id', '3': 2, '4': 1, '5': 9, '10': 'ownerPeerId'},
    {'1': 'revoke_reason', '3': 3, '4': 1, '5': 9, '10': 'revokeReason'},
    {'1': 'revoked_at_utc_ms', '3': 4, '4': 1, '5': 3, '10': 'revokedAtUtcMs'},
    {
      '1': 'active_grace_ends_at_utc_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'activeGraceEndsAtUtcMs'
    },
  ],
};

/// Descriptor for `ShareRevocationNotice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareRevocationNoticeDescriptor = $convert.base64Decode(
    'ChVTaGFyZVJldm9jYXRpb25Ob3RpY2USGQoIc2hhcmVfaWQYASABKAlSB3NoYXJlSWQSIgoNb3'
    'duZXJfcGVlcl9pZBgCIAEoCVILb3duZXJQZWVySWQSIwoNcmV2b2tlX3JlYXNvbhgDIAEoCVIM'
    'cmV2b2tlUmVhc29uEikKEXJldm9rZWRfYXRfdXRjX21zGAQgASgDUg5yZXZva2VkQXRVdGNNcx'
    'I7ChthY3RpdmVfZ3JhY2VfZW5kc19hdF91dGNfbXMYBSABKANSFmFjdGl2ZUdyYWNlRW5kc0F0'
    'VXRjTXM=');

@$core.Deprecated('Use shareWireMessageDescriptor instead')
const ShareWireMessage$json = {
  '1': 'ShareWireMessage',
  '2': [
    {
      '1': 'use_request',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ShareUseRequest',
      '9': 0,
      '10': 'useRequest'
    },
    {
      '1': 'use_response',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ShareUseResponse',
      '9': 0,
      '10': 'useResponse'
    },
    {
      '1': 'revocation_notice',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ShareRevocationNotice',
      '9': 0,
      '10': 'revocationNotice'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `ShareWireMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shareWireMessageDescriptor = $convert.base64Decode(
    'ChBTaGFyZVdpcmVNZXNzYWdlEj8KC3VzZV9yZXF1ZXN0GAEgASgLMhwucGVlcmxpbmsudjEuU2'
    'hhcmVVc2VSZXF1ZXN0SABSCnVzZVJlcXVlc3QSQgoMdXNlX3Jlc3BvbnNlGAIgASgLMh0ucGVl'
    'cmxpbmsudjEuU2hhcmVVc2VSZXNwb25zZUgAUgt1c2VSZXNwb25zZRJRChFyZXZvY2F0aW9uX2'
    '5vdGljZRgDIAEoCzIiLnBlZXJsaW5rLnYxLlNoYXJlUmV2b2NhdGlvbk5vdGljZUgAUhByZXZv'
    'Y2F0aW9uTm90aWNlQgkKB3BheWxvYWQ=');
