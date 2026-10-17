// This is a generated file - do not edit.
//
// Generated from peerlink/v1/operation.proto.

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

@$core.Deprecated('Use operationStateDescriptor instead')
const OperationState$json = {
  '1': 'OperationState',
  '2': [
    {'1': 'OPERATION_STATE_UNSPECIFIED', '2': 0},
    {'1': 'OPERATION_STATE_CREATED', '2': 1},
    {'1': 'OPERATION_STATE_VALIDATED', '2': 2},
    {'1': 'OPERATION_STATE_AUTHORIZED', '2': 3},
    {'1': 'OPERATION_STATE_EXECUTING', '2': 4},
    {'1': 'OPERATION_STATE_WAITING', '2': 5},
    {'1': 'OPERATION_STATE_COMMITTED', '2': 6},
    {'1': 'OPERATION_STATE_FAILED', '2': 7},
    {'1': 'OPERATION_STATE_CANCELLED', '2': 8},
    {'1': 'OPERATION_STATE_OUTCOME_UNKNOWN', '2': 9},
    {'1': 'OPERATION_STATE_RECOVERY_REQUIRED', '2': 10},
  ],
};

/// Descriptor for `OperationState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List operationStateDescriptor = $convert.base64Decode(
    'Cg5PcGVyYXRpb25TdGF0ZRIfChtPUEVSQVRJT05fU1RBVEVfVU5TUEVDSUZJRUQQABIbChdPUE'
    'VSQVRJT05fU1RBVEVfQ1JFQVRFRBABEh0KGU9QRVJBVElPTl9TVEFURV9WQUxJREFURUQQAhIe'
    'ChpPUEVSQVRJT05fU1RBVEVfQVVUSE9SSVpFRBADEh0KGU9QRVJBVElPTl9TVEFURV9FWEVDVV'
    'RJTkcQBBIbChdPUEVSQVRJT05fU1RBVEVfV0FJVElORxAFEh0KGU9QRVJBVElPTl9TVEFURV9D'
    'T01NSVRURUQQBhIaChZPUEVSQVRJT05fU1RBVEVfRkFJTEVEEAcSHQoZT1BFUkFUSU9OX1NUQV'
    'RFX0NBTkNFTExFRBAIEiMKH09QRVJBVElPTl9TVEFURV9PVVRDT01FX1VOS05PV04QCRIlCiFP'
    'UEVSQVRJT05fU1RBVEVfUkVDT1ZFUllfUkVRVUlSRUQQCg==');

@$core.Deprecated('Use operationIntentDescriptor instead')
const OperationIntent$json = {
  '1': 'OperationIntent',
  '2': [
    {'1': 'OPERATION_INTENT_UNSPECIFIED', '2': 0},
    {'1': 'OPERATION_INTENT_SEND', '2': 1},
    {'1': 'OPERATION_INTENT_ACCESS', '2': 2},
    {'1': 'OPERATION_INTENT_SYNC', '2': 3},
    {'1': 'OPERATION_INTENT_BACKUP', '2': 4},
    {'1': 'OPERATION_INTENT_CONNECT', '2': 5},
  ],
};

/// Descriptor for `OperationIntent`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List operationIntentDescriptor = $convert.base64Decode(
    'Cg9PcGVyYXRpb25JbnRlbnQSIAocT1BFUkFUSU9OX0lOVEVOVF9VTlNQRUNJRklFRBAAEhkKFU'
    '9QRVJBVElPTl9JTlRFTlRfU0VORBABEhsKF09QRVJBVElPTl9JTlRFTlRfQUNDRVNTEAISGQoV'
    'T1BFUkFUSU9OX0lOVEVOVF9TWU5DEAMSGwoXT1BFUkFUSU9OX0lOVEVOVF9CQUNLVVAQBBIcCh'
    'hPUEVSQVRJT05fSU5URU5UX0NPTk5FQ1QQBQ==');

@$core.Deprecated('Use operationRecordDescriptor instead')
const OperationRecord$json = {
  '1': 'OperationRecord',
  '2': [
    {
      '1': 'operation_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {
      '1': 'intent',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.OperationIntent',
      '10': 'intent'
    },
    {
      '1': 'actor_peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'actorPeerId'
    },
    {
      '1': 'target_objects',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.ObjectReference',
      '10': 'targetObjects'
    },
    {
      '1': 'state',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.OperationState',
      '10': 'state'
    },
    {'1': 'idempotency_key', '3': 6, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {
      '1': 'causal_clock',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CausalClock',
      '10': 'causalClock'
    },
    {'1': 'created_at_utc_ms', '3': 8, '4': 1, '5': 3, '10': 'createdAtUtcMs'},
    {'1': 'updated_at_utc_ms', '3': 9, '4': 1, '5': 3, '10': 'updatedAtUtcMs'},
    {
      '1': 'error',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
    {
      '1': 'parameters',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.OperationRecord.ParametersEntry',
      '10': 'parameters'
    },
  ],
  '3': [OperationRecord_ParametersEntry$json],
};

@$core.Deprecated('Use operationRecordDescriptor instead')
const OperationRecord_ParametersEntry$json = {
  '1': 'ParametersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `OperationRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List operationRecordDescriptor = $convert.base64Decode(
    'Cg9PcGVyYXRpb25SZWNvcmQSOwoMb3BlcmF0aW9uX2lkGAEgASgLMhgucGVlcmxpbmsudjEuT3'
    'BlcmF0aW9uSWRSC29wZXJhdGlvbklkEjQKBmludGVudBgCIAEoDjIcLnBlZXJsaW5rLnYxLk9w'
    'ZXJhdGlvbkludGVudFIGaW50ZW50EjcKDWFjdG9yX3BlZXJfaWQYAyABKAsyEy5wZWVybGluay'
    '52MS5QZWVySWRSC2FjdG9yUGVlcklkEkMKDnRhcmdldF9vYmplY3RzGAQgAygLMhwucGVlcmxp'
    'bmsudjEuT2JqZWN0UmVmZXJlbmNlUg10YXJnZXRPYmplY3RzEjEKBXN0YXRlGAUgASgOMhsucG'
    'VlcmxpbmsudjEuT3BlcmF0aW9uU3RhdGVSBXN0YXRlEicKD2lkZW1wb3RlbmN5X2tleRgGIAEo'
    'CVIOaWRlbXBvdGVuY3lLZXkSOwoMY2F1c2FsX2Nsb2NrGAcgASgLMhgucGVlcmxpbmsudjEuQ2'
    'F1c2FsQ2xvY2tSC2NhdXNhbENsb2NrEikKEWNyZWF0ZWRfYXRfdXRjX21zGAggASgDUg5jcmVh'
    'dGVkQXRVdGNNcxIpChF1cGRhdGVkX2F0X3V0Y19tcxgJIAEoA1IOdXBkYXRlZEF0VXRjTXMSLg'
    'oFZXJyb3IYCiABKAsyGC5wZWVybGluay52MS5FcnJvckRldGFpbFIFZXJyb3ISTAoKcGFyYW1l'
    'dGVycxgLIAMoCzIsLnBlZXJsaW5rLnYxLk9wZXJhdGlvblJlY29yZC5QYXJhbWV0ZXJzRW50cn'
    'lSCnBhcmFtZXRlcnMaPQoPUGFyYW1ldGVyc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZh'
    'bHVlGAIgASgJUgV2YWx1ZToCOAE=');
