// This is a generated file - do not edit.
//
// Generated from peerlink/v1/error.proto.

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

@$core.Deprecated('Use errorCodeDescriptor instead')
const ErrorCode$json = {
  '1': 'ErrorCode',
  '2': [
    {'1': 'ERROR_CODE_UNSPECIFIED', '2': 0},
    {'1': 'ERROR_CODE_UNAUTHENTICATED', '2': 1},
    {'1': 'ERROR_CODE_UNAUTHORIZED', '2': 2},
    {'1': 'ERROR_CODE_INCOMPATIBLE_PROTOCOL_VERSION', '2': 3},
    {'1': 'ERROR_CODE_UNSUPPORTED_CAPABILITY', '2': 4},
    {'1': 'ERROR_CODE_OBJECT_NOT_FOUND', '2': 5},
    {'1': 'ERROR_CODE_CONFLICT_DETECTED', '2': 6},
    {'1': 'ERROR_CODE_INTEGRITY_MISMATCH', '2': 7},
    {'1': 'ERROR_CODE_MALWARE_DETECTED', '2': 8},
    {'1': 'ERROR_CODE_TRANSPORT_DISCONNECTED', '2': 9},
    {'1': 'ERROR_CODE_RESOURCE_EXHAUSTED', '2': 10},
    {'1': 'ERROR_CODE_OPERATION_CANCELLED', '2': 11},
    {'1': 'ERROR_CODE_INTERNAL_ERROR', '2': 12},
  ],
};

/// Descriptor for `ErrorCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List errorCodeDescriptor = $convert.base64Decode(
    'CglFcnJvckNvZGUSGgoWRVJST1JfQ09ERV9VTlNQRUNJRklFRBAAEh4KGkVSUk9SX0NPREVfVU'
    '5BVVRIRU5USUNBVEVEEAESGwoXRVJST1JfQ09ERV9VTkFVVEhPUklaRUQQAhIsCihFUlJPUl9D'
    'T0RFX0lOQ09NUEFUSUJMRV9QUk9UT0NPTF9WRVJTSU9OEAMSJQohRVJST1JfQ09ERV9VTlNVUF'
    'BPUlRFRF9DQVBBQklMSVRZEAQSHwobRVJST1JfQ09ERV9PQkpFQ1RfTk9UX0ZPVU5EEAUSIAoc'
    'RVJST1JfQ09ERV9DT05GTElDVF9ERVRFQ1RFRBAGEiEKHUVSUk9SX0NPREVfSU5URUdSSVRZX0'
    '1JU01BVENIEAcSHwobRVJST1JfQ09ERV9NQUxXQVJFX0RFVEVDVEVEEAgSJQohRVJST1JfQ09E'
    'RV9UUkFOU1BPUlRfRElTQ09OTkVDVEVEEAkSIQodRVJST1JfQ09ERV9SRVNPVVJDRV9FWEhBVV'
    'NURUQQChIiCh5FUlJPUl9DT0RFX09QRVJBVElPTl9DQU5DRUxMRUQQCxIdChlFUlJPUl9DT0RF'
    'X0lOVEVSTkFMX0VSUk9SEAw=');

@$core.Deprecated('Use errorDetailDescriptor instead')
const ErrorDetail$json = {
  '1': 'ErrorDetail',
  '2': [
    {
      '1': 'code',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ErrorCode',
      '10': 'code'
    },
    {'1': 'error_name', '3': 2, '4': 1, '5': 9, '10': 'errorName'},
    {'1': 'human_summary', '3': 3, '4': 1, '5': 9, '10': 'humanSummary'},
    {
      '1': 'human_explanation',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'humanExplanation'
    },
    {
      '1': 'suggested_recovery_action',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'suggestedRecoveryAction'
    },
    {'1': 'is_retryable', '3': 6, '4': 1, '5': 8, '10': 'isRetryable'},
    {'1': 'trace_id', '3': 7, '4': 1, '5': 9, '10': 'traceId'},
    {'1': 'timestamp_utc_ms', '3': 8, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {
      '1': 'error_context',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail.ErrorContextEntry',
      '10': 'errorContext'
    },
  ],
  '3': [ErrorDetail_ErrorContextEntry$json],
};

@$core.Deprecated('Use errorDetailDescriptor instead')
const ErrorDetail_ErrorContextEntry$json = {
  '1': 'ErrorContextEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ErrorDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDetailDescriptor = $convert.base64Decode(
    'CgtFcnJvckRldGFpbBIqCgRjb2RlGAEgASgOMhYucGVlcmxpbmsudjEuRXJyb3JDb2RlUgRjb2'
    'RlEh0KCmVycm9yX25hbWUYAiABKAlSCWVycm9yTmFtZRIjCg1odW1hbl9zdW1tYXJ5GAMgASgJ'
    'UgxodW1hblN1bW1hcnkSKwoRaHVtYW5fZXhwbGFuYXRpb24YBCABKAlSEGh1bWFuRXhwbGFuYX'
    'Rpb24SOgoZc3VnZ2VzdGVkX3JlY292ZXJ5X2FjdGlvbhgFIAEoCVIXc3VnZ2VzdGVkUmVjb3Zl'
    'cnlBY3Rpb24SIQoMaXNfcmV0cnlhYmxlGAYgASgIUgtpc1JldHJ5YWJsZRIZCgh0cmFjZV9pZB'
    'gHIAEoCVIHdHJhY2VJZBIoChB0aW1lc3RhbXBfdXRjX21zGAggASgDUg50aW1lc3RhbXBVdGNN'
    'cxJPCg1lcnJvcl9jb250ZXh0GAkgAygLMioucGVlcmxpbmsudjEuRXJyb3JEZXRhaWwuRXJyb3'
    'JDb250ZXh0RW50cnlSDGVycm9yQ29udGV4dBo/ChFFcnJvckNvbnRleHRFbnRyeRIQCgNrZXkY'
    'ASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');
