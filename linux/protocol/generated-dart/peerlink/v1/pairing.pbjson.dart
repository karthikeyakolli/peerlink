// This is a generated file - do not edit.
//
// Generated from peerlink/v1/pairing.proto.

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

@$core.Deprecated('Use pairingStateDescriptor instead')
const PairingState$json = {
  '1': 'PairingState',
  '2': [
    {'1': 'PAIRING_STATE_UNSPECIFIED', '2': 0},
    {'1': 'PAIRING_STATE_INITIATED', '2': 1},
    {'1': 'PAIRING_STATE_OFFERED', '2': 2},
    {'1': 'PAIRING_STATE_VERIFYING', '2': 3},
    {'1': 'PAIRING_STATE_CONFIRMED', '2': 4},
    {'1': 'PAIRING_STATE_REJECTED', '2': 5},
    {'1': 'PAIRING_STATE_REVOKED', '2': 6},
    {'1': 'PAIRING_STATE_EXPIRED', '2': 7},
  ],
};

/// Descriptor for `PairingState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pairingStateDescriptor = $convert.base64Decode(
    'CgxQYWlyaW5nU3RhdGUSHQoZUEFJUklOR19TVEFURV9VTlNQRUNJRklFRBAAEhsKF1BBSVJJTk'
    'dfU1RBVEVfSU5JVElBVEVEEAESGQoVUEFJUklOR19TVEFURV9PRkZFUkVEEAISGwoXUEFJUklO'
    'R19TVEFURV9WRVJJRllJTkcQAxIbChdQQUlSSU5HX1NUQVRFX0NPTkZJUk1FRBAEEhoKFlBBSV'
    'JJTkdfU1RBVEVfUkVKRUNURUQQBRIZChVQQUlSSU5HX1NUQVRFX1JFVk9LRUQQBhIZChVQQUlS'
    'SU5HX1NUQVRFX0VYUElSRUQQBw==');

@$core.Deprecated('Use pairingMethodDescriptor instead')
const PairingMethod$json = {
  '1': 'PairingMethod',
  '2': [
    {'1': 'PAIRING_METHOD_UNSPECIFIED', '2': 0},
    {'1': 'PAIRING_METHOD_QR_CODE', '2': 1},
    {'1': 'PAIRING_METHOD_NUMERIC_CODE', '2': 2},
    {'1': 'PAIRING_METHOD_MANUAL_VERIFICATION', '2': 3},
  ],
};

/// Descriptor for `PairingMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pairingMethodDescriptor = $convert.base64Decode(
    'Cg1QYWlyaW5nTWV0aG9kEh4KGlBBSVJJTkdfTUVUSE9EX1VOU1BFQ0lGSUVEEAASGgoWUEFJUk'
    'lOR19NRVRIT0RfUVJfQ09ERRABEh8KG1BBSVJJTkdfTUVUSE9EX05VTUVSSUNfQ09ERRACEiYK'
    'IlBBSVJJTkdfTUVUSE9EX01BTlVBTF9WRVJJRklDQVRJT04QAw==');

@$core.Deprecated('Use pairingOfferDescriptor instead')
const PairingOffer$json = {
  '1': 'PairingOffer',
  '2': [
    {
      '1': 'pairing_session_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'pairingSessionId'
    },
    {
      '1': 'initiator_peer',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'initiatorPeer'
    },
    {
      '1': 'initiator_device',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceIdentity',
      '10': 'initiatorDevice'
    },
    {'1': 'pairing_code', '3': 4, '4': 1, '5': 9, '10': 'pairingCode'},
    {'1': 'qr_payload', '3': 5, '4': 1, '5': 9, '10': 'qrPayload'},
    {
      '1': 'expected_fingerprint',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'expectedFingerprint'
    },
    {
      '1': 'method',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.PairingMethod',
      '10': 'method'
    },
    {'1': 'expires_at_utc_ms', '3': 8, '4': 1, '5': 3, '10': 'expiresAtUtcMs'},
    {'1': 'offer_signature', '3': 9, '4': 1, '5': 12, '10': 'offerSignature'},
  ],
};

/// Descriptor for `PairingOffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingOfferDescriptor = $convert.base64Decode(
    'CgxQYWlyaW5nT2ZmZXISLAoScGFpcmluZ19zZXNzaW9uX2lkGAEgASgJUhBwYWlyaW5nU2Vzc2'
    'lvbklkEkAKDmluaXRpYXRvcl9wZWVyGAIgASgLMhkucGVlcmxpbmsudjEuUGVlcklkZW50aXR5'
    'Ug1pbml0aWF0b3JQZWVyEkYKEGluaXRpYXRvcl9kZXZpY2UYAyABKAsyGy5wZWVybGluay52MS'
    '5EZXZpY2VJZGVudGl0eVIPaW5pdGlhdG9yRGV2aWNlEiEKDHBhaXJpbmdfY29kZRgEIAEoCVIL'
    'cGFpcmluZ0NvZGUSHQoKcXJfcGF5bG9hZBgFIAEoCVIJcXJQYXlsb2FkEjEKFGV4cGVjdGVkX2'
    'ZpbmdlcnByaW50GAYgASgJUhNleHBlY3RlZEZpbmdlcnByaW50EjIKBm1ldGhvZBgHIAEoDjIa'
    'LnBlZXJsaW5rLnYxLlBhaXJpbmdNZXRob2RSBm1ldGhvZBIpChFleHBpcmVzX2F0X3V0Y19tcx'
    'gIIAEoA1IOZXhwaXJlc0F0VXRjTXMSJwoPb2ZmZXJfc2lnbmF0dXJlGAkgASgMUg5vZmZlclNp'
    'Z25hdHVyZQ==');

@$core.Deprecated('Use pairingVerificationDescriptor instead')
const PairingVerification$json = {
  '1': 'PairingVerification',
  '2': [
    {
      '1': 'pairing_session_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'pairingSessionId'
    },
    {
      '1': 'responder_peer',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'responderPeer'
    },
    {
      '1': 'responder_device',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceIdentity',
      '10': 'responderDevice'
    },
    {'1': 'entered_code', '3': 4, '4': 1, '5': 9, '10': 'enteredCode'},
    {
      '1': 'verified_fingerprint',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'verifiedFingerprint'
    },
    {'1': 'timestamp_utc_ms', '3': 6, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {
      '1': 'verification_signature',
      '3': 7,
      '4': 1,
      '5': 12,
      '10': 'verificationSignature'
    },
  ],
};

/// Descriptor for `PairingVerification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingVerificationDescriptor = $convert.base64Decode(
    'ChNQYWlyaW5nVmVyaWZpY2F0aW9uEiwKEnBhaXJpbmdfc2Vzc2lvbl9pZBgBIAEoCVIQcGFpcm'
    'luZ1Nlc3Npb25JZBJACg5yZXNwb25kZXJfcGVlchgCIAEoCzIZLnBlZXJsaW5rLnYxLlBlZXJJ'
    'ZGVudGl0eVINcmVzcG9uZGVyUGVlchJGChByZXNwb25kZXJfZGV2aWNlGAMgASgLMhsucGVlcm'
    'xpbmsudjEuRGV2aWNlSWRlbnRpdHlSD3Jlc3BvbmRlckRldmljZRIhCgxlbnRlcmVkX2NvZGUY'
    'BCABKAlSC2VudGVyZWRDb2RlEjEKFHZlcmlmaWVkX2ZpbmdlcnByaW50GAUgASgJUhN2ZXJpZm'
    'llZEZpbmdlcnByaW50EigKEHRpbWVzdGFtcF91dGNfbXMYBiABKANSDnRpbWVzdGFtcFV0Y01z'
    'EjUKFnZlcmlmaWNhdGlvbl9zaWduYXR1cmUYByABKAxSFXZlcmlmaWNhdGlvblNpZ25hdHVyZQ'
    '==');

@$core.Deprecated('Use pairingResultDescriptor instead')
const PairingResult$json = {
  '1': 'PairingResult',
  '2': [
    {
      '1': 'pairing_session_id',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'pairingSessionId'
    },
    {
      '1': 'state',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.PairingState',
      '10': 'state'
    },
    {
      '1': 'error',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
    {
      '1': 'completed_at_utc_ms',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'completedAtUtcMs'
    },
    {
      '1': 'paired_peer',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'pairedPeer'
    },
  ],
};

/// Descriptor for `PairingResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingResultDescriptor = $convert.base64Decode(
    'Cg1QYWlyaW5nUmVzdWx0EiwKEnBhaXJpbmdfc2Vzc2lvbl9pZBgBIAEoCVIQcGFpcmluZ1Nlc3'
    'Npb25JZBIvCgVzdGF0ZRgCIAEoDjIZLnBlZXJsaW5rLnYxLlBhaXJpbmdTdGF0ZVIFc3RhdGUS'
    'LgoFZXJyb3IYAyABKAsyGC5wZWVybGluay52MS5FcnJvckRldGFpbFIFZXJyb3ISLQoTY29tcG'
    'xldGVkX2F0X3V0Y19tcxgEIAEoA1IQY29tcGxldGVkQXRVdGNNcxI6CgtwYWlyZWRfcGVlchgF'
    'IAEoCzIZLnBlZXJsaW5rLnYxLlBlZXJJZGVudGl0eVIKcGFpcmVkUGVlcg==');
