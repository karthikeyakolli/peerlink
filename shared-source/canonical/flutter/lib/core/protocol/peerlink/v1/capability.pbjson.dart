// This is a generated file - do not edit.
//
// Generated from peerlink/v1/capability.proto.

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

@$core.Deprecated('Use featureCapabilityDescriptor instead')
const FeatureCapability$json = {
  '1': 'FeatureCapability',
  '2': [
    {'1': 'FEATURE_CAPABILITY_UNSPECIFIED', '2': 0},
    {'1': 'FEATURE_TRANSFER_RESUME', '2': 1},
    {'1': 'FEATURE_REMOTE_SEARCH', '2': 2},
    {'1': 'FEATURE_CLIPBOARD_IMAGE', '2': 3},
    {'1': 'FEATURE_BACKGROUND_SYNC', '2': 4},
    {'1': 'FEATURE_QUIC', '2': 5},
    {'1': 'FEATURE_TCP_TLS', '2': 6},
    {'1': 'FEATURE_TURN', '2': 7},
    {'1': 'FEATURE_MALWARE_SCAN', '2': 8},
    {'1': 'FEATURE_ARCHIVE_INSPECTION', '2': 9},
    {'1': 'FEATURE_FILE_PROVIDER', '2': 10},
  ],
};

/// Descriptor for `FeatureCapability`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List featureCapabilityDescriptor = $convert.base64Decode(
    'ChFGZWF0dXJlQ2FwYWJpbGl0eRIiCh5GRUFUVVJFX0NBUEFCSUxJVFlfVU5TUEVDSUZJRUQQAB'
    'IbChdGRUFUVVJFX1RSQU5TRkVSX1JFU1VNRRABEhkKFUZFQVRVUkVfUkVNT1RFX1NFQVJDSBAC'
    'EhsKF0ZFQVRVUkVfQ0xJUEJPQVJEX0lNQUdFEAMSGwoXRkVBVFVSRV9CQUNLR1JPVU5EX1NZTk'
    'MQBBIQCgxGRUFUVVJFX1FVSUMQBRITCg9GRUFUVVJFX1RDUF9UTFMQBhIQCgxGRUFUVVJFX1RV'
    'Uk4QBxIYChRGRUFUVVJFX01BTFdBUkVfU0NBThAIEh4KGkZFQVRVUkVfQVJDSElWRV9JTlNQRU'
    'NUSU9OEAkSGQoVRkVBVFVSRV9GSUxFX1BST1ZJREVSEAo=');

@$core.Deprecated('Use capabilityDescriptorDescriptor instead')
const CapabilityDescriptor$json = {
  '1': 'CapabilityDescriptor',
  '2': [
    {'1': 'capability_name', '3': 1, '4': 1, '5': 9, '10': 'capabilityName'},
    {
      '1': 'version',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'version'
    },
    {
      '1': 'valid_until_utc_ms',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'validUntilUtcMs'
    },
    {
      '1': 'parameters',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.CapabilityDescriptor.ParametersEntry',
      '10': 'parameters'
    },
    {'1': 'is_enabled', '3': 5, '4': 1, '5': 8, '10': 'isEnabled'},
  ],
  '3': [CapabilityDescriptor_ParametersEntry$json],
};

@$core.Deprecated('Use capabilityDescriptorDescriptor instead')
const CapabilityDescriptor_ParametersEntry$json = {
  '1': 'ParametersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `CapabilityDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityDescriptorDescriptor = $convert.base64Decode(
    'ChRDYXBhYmlsaXR5RGVzY3JpcHRvchInCg9jYXBhYmlsaXR5X25hbWUYASABKAlSDmNhcGFiaW'
    'xpdHlOYW1lEjYKB3ZlcnNpb24YAiABKAsyHC5wZWVybGluay52MS5Qcm90b2NvbFZlcnNpb25S'
    'B3ZlcnNpb24SKwoSdmFsaWRfdW50aWxfdXRjX21zGAMgASgDUg92YWxpZFVudGlsVXRjTXMSUQ'
    'oKcGFyYW1ldGVycxgEIAMoCzIxLnBlZXJsaW5rLnYxLkNhcGFiaWxpdHlEZXNjcmlwdG9yLlBh'
    'cmFtZXRlcnNFbnRyeVIKcGFyYW1ldGVycxIdCgppc19lbmFibGVkGAUgASgIUglpc0VuYWJsZW'
    'QaPQoPUGFyYW1ldGVyc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2'
    'YWx1ZToCOAE=');

@$core.Deprecated('Use capabilityNegotiationRequestDescriptor instead')
const CapabilityNegotiationRequest$json = {
  '1': 'CapabilityNegotiationRequest',
  '2': [
    {
      '1': 'header',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolHeader',
      '10': 'header'
    },
    {
      '1': 'sender_peer_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'senderPeerId'
    },
    {
      '1': 'client_protocol_version',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'clientProtocolVersion'
    },
    {
      '1': 'min_compatible_version',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'minCompatibleVersion'
    },
    {
      '1': 'offered_capabilities',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.CapabilityDescriptor',
      '10': 'offeredCapabilities'
    },
    {
      '1': 'requested_features',
      '3': 6,
      '4': 3,
      '5': 9,
      '10': 'requestedFeatures'
    },
    {
      '1': 'feature_flags',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.CapabilityNegotiationRequest.FeatureFlagsEntry',
      '10': 'featureFlags'
    },
  ],
  '3': [CapabilityNegotiationRequest_FeatureFlagsEntry$json],
};

@$core.Deprecated('Use capabilityNegotiationRequestDescriptor instead')
const CapabilityNegotiationRequest_FeatureFlagsEntry$json = {
  '1': 'FeatureFlagsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `CapabilityNegotiationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityNegotiationRequestDescriptor = $convert.base64Decode(
    'ChxDYXBhYmlsaXR5TmVnb3RpYXRpb25SZXF1ZXN0EjMKBmhlYWRlchgBIAEoCzIbLnBlZXJsaW'
    '5rLnYxLlByb3RvY29sSGVhZGVyUgZoZWFkZXISOQoOc2VuZGVyX3BlZXJfaWQYAiABKAsyEy5w'
    'ZWVybGluay52MS5QZWVySWRSDHNlbmRlclBlZXJJZBJUChdjbGllbnRfcHJvdG9jb2xfdmVyc2'
    'lvbhgDIAEoCzIcLnBlZXJsaW5rLnYxLlByb3RvY29sVmVyc2lvblIVY2xpZW50UHJvdG9jb2xW'
    'ZXJzaW9uElIKFm1pbl9jb21wYXRpYmxlX3ZlcnNpb24YBCABKAsyHC5wZWVybGluay52MS5Qcm'
    '90b2NvbFZlcnNpb25SFG1pbkNvbXBhdGlibGVWZXJzaW9uElQKFG9mZmVyZWRfY2FwYWJpbGl0'
    'aWVzGAUgAygLMiEucGVlcmxpbmsudjEuQ2FwYWJpbGl0eURlc2NyaXB0b3JSE29mZmVyZWRDYX'
    'BhYmlsaXRpZXMSLQoScmVxdWVzdGVkX2ZlYXR1cmVzGAYgAygJUhFyZXF1ZXN0ZWRGZWF0dXJl'
    'cxJgCg1mZWF0dXJlX2ZsYWdzGAcgAygLMjsucGVlcmxpbmsudjEuQ2FwYWJpbGl0eU5lZ290aW'
    'F0aW9uUmVxdWVzdC5GZWF0dXJlRmxhZ3NFbnRyeVIMZmVhdHVyZUZsYWdzGj8KEUZlYXR1cmVG'
    'bGFnc0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use capabilityNegotiationResponseDescriptor instead')
const CapabilityNegotiationResponse$json = {
  '1': 'CapabilityNegotiationResponse',
  '2': [
    {
      '1': 'header',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolHeader',
      '10': 'header'
    },
    {'1': 'is_compatible', '3': 2, '4': 1, '5': 8, '10': 'isCompatible'},
    {
      '1': 'agreed_protocol_version',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'agreedProtocolVersion'
    },
    {
      '1': 'accepted_capabilities',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.CapabilityDescriptor',
      '10': 'acceptedCapabilities'
    },
    {
      '1': 'unsupported_features',
      '3': 5,
      '4': 3,
      '5': 9,
      '10': 'unsupportedFeatures'
    },
    {
      '1': 'error',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
  ],
};

/// Descriptor for `CapabilityNegotiationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List capabilityNegotiationResponseDescriptor = $convert.base64Decode(
    'Ch1DYXBhYmlsaXR5TmVnb3RpYXRpb25SZXNwb25zZRIzCgZoZWFkZXIYASABKAsyGy5wZWVybG'
    'luay52MS5Qcm90b2NvbEhlYWRlclIGaGVhZGVyEiMKDWlzX2NvbXBhdGlibGUYAiABKAhSDGlz'
    'Q29tcGF0aWJsZRJUChdhZ3JlZWRfcHJvdG9jb2xfdmVyc2lvbhgDIAEoCzIcLnBlZXJsaW5rLn'
    'YxLlByb3RvY29sVmVyc2lvblIVYWdyZWVkUHJvdG9jb2xWZXJzaW9uElYKFWFjY2VwdGVkX2Nh'
    'cGFiaWxpdGllcxgEIAMoCzIhLnBlZXJsaW5rLnYxLkNhcGFiaWxpdHlEZXNjcmlwdG9yUhRhY2'
    'NlcHRlZENhcGFiaWxpdGllcxIxChR1bnN1cHBvcnRlZF9mZWF0dXJlcxgFIAMoCVITdW5zdXBw'
    'b3J0ZWRGZWF0dXJlcxIuCgVlcnJvchgGIAEoCzIYLnBlZXJsaW5rLnYxLkVycm9yRGV0YWlsUg'
    'VlcnJvcg==');
