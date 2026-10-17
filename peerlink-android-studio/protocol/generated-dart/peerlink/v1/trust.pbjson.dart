// This is a generated file - do not edit.
//
// Generated from peerlink/v1/trust.proto.

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

@$core.Deprecated('Use pairingRequestDescriptor instead')
const PairingRequest$json = {
  '1': 'PairingRequest',
  '2': [
    {
      '1': 'initiator',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'initiator'
    },
    {'1': 'timestamp_utc_ms', '3': 2, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {
      '1': 'pairing_secret_hash',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'pairingSecretHash'
    },
  ],
};

/// Descriptor for `PairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingRequestDescriptor = $convert.base64Decode(
    'Cg5QYWlyaW5nUmVxdWVzdBI3Cglpbml0aWF0b3IYASABKAsyGS5wZWVybGluay52MS5QZWVySW'
    'RlbnRpdHlSCWluaXRpYXRvchIoChB0aW1lc3RhbXBfdXRjX21zGAIgASgDUg50aW1lc3RhbXBV'
    'dGNNcxIuChNwYWlyaW5nX3NlY3JldF9oYXNoGAMgASgJUhFwYWlyaW5nU2VjcmV0SGFzaA==');

@$core.Deprecated('Use pairingResponseDescriptor instead')
const PairingResponse$json = {
  '1': 'PairingResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {
      '1': 'responder',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'responder'
    },
    {
      '1': 'error',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
  ],
};

/// Descriptor for `PairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingResponseDescriptor = $convert.base64Decode(
    'Cg9QYWlyaW5nUmVzcG9uc2USGgoIYWNjZXB0ZWQYASABKAhSCGFjY2VwdGVkEjcKCXJlc3Bvbm'
    'RlchgCIAEoCzIZLnBlZXJsaW5rLnYxLlBlZXJJZGVudGl0eVIJcmVzcG9uZGVyEi4KBWVycm9y'
    'GAMgASgLMhgucGVlcmxpbmsudjEuRXJyb3JEZXRhaWxSBWVycm9y');
