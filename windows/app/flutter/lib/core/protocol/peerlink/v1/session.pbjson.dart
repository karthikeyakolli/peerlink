// This is a generated file - do not edit.
//
// Generated from peerlink/v1/session.proto.

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

@$core.Deprecated('Use sessionStateDescriptor instead')
const SessionState$json = {
  '1': 'SessionState',
  '2': [
    {'1': 'SESSION_STATE_UNSPECIFIED', '2': 0},
    {'1': 'SESSION_STATE_INITIATING', '2': 1},
    {'1': 'SESSION_STATE_ESTABLISHED', '2': 2},
    {'1': 'SESSION_STATE_REKEYING', '2': 3},
    {'1': 'SESSION_STATE_CLOSING', '2': 4},
    {'1': 'SESSION_STATE_CLOSED', '2': 5},
    {'1': 'SESSION_STATE_REJECTED', '2': 6},
  ],
};

/// Descriptor for `SessionState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sessionStateDescriptor = $convert.base64Decode(
    'CgxTZXNzaW9uU3RhdGUSHQoZU0VTU0lPTl9TVEFURV9VTlNQRUNJRklFRBAAEhwKGFNFU1NJT0'
    '5fU1RBVEVfSU5JVElBVElORxABEh0KGVNFU1NJT05fU1RBVEVfRVNUQUJMSVNIRUQQAhIaChZT'
    'RVNTSU9OX1NUQVRFX1JFS0VZSU5HEAMSGQoVU0VTU0lPTl9TVEFURV9DTE9TSU5HEAQSGAoUU0'
    'VTU0lPTl9TVEFURV9DTE9TRUQQBRIaChZTRVNTSU9OX1NUQVRFX1JFSkVDVEVEEAY=');

@$core.Deprecated('Use transportTypeDescriptor instead')
const TransportType$json = {
  '1': 'TransportType',
  '2': [
    {'1': 'TRANSPORT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'TRANSPORT_TYPE_DIRECT_QUIC', '2': 1},
    {'1': 'TRANSPORT_TYPE_DIRECT_TCP_TLS', '2': 2},
    {'1': 'TRANSPORT_TYPE_RELAY_TURN', '2': 3},
  ],
};

/// Descriptor for `TransportType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List transportTypeDescriptor = $convert.base64Decode(
    'Cg1UcmFuc3BvcnRUeXBlEh4KGlRSQU5TUE9SVF9UWVBFX1VOU1BFQ0lGSUVEEAASHgoaVFJBTl'
    'NQT1JUX1RZUEVfRElSRUNUX1FVSUMQARIhCh1UUkFOU1BPUlRfVFlQRV9ESVJFQ1RfVENQX1RM'
    'UxACEh0KGVRSQU5TUE9SVF9UWVBFX1JFTEFZX1RVUk4QAw==');

@$core.Deprecated('Use handshakePhaseDescriptor instead')
const HandshakePhase$json = {
  '1': 'HandshakePhase',
  '2': [
    {'1': 'HANDSHAKE_PHASE_UNSPECIFIED', '2': 0},
    {'1': 'HANDSHAKE_PHASE_SYN', '2': 1},
    {'1': 'HANDSHAKE_PHASE_SYN_ACK', '2': 2},
    {'1': 'HANDSHAKE_PHASE_ACK', '2': 3},
    {'1': 'HANDSHAKE_PHASE_REJECT', '2': 4},
  ],
};

/// Descriptor for `HandshakePhase`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List handshakePhaseDescriptor = $convert.base64Decode(
    'Cg5IYW5kc2hha2VQaGFzZRIfChtIQU5EU0hBS0VfUEhBU0VfVU5TUEVDSUZJRUQQABIXChNIQU'
    '5EU0hBS0VfUEhBU0VfU1lOEAESGwoXSEFORFNIQUtFX1BIQVNFX1NZTl9BQ0sQAhIXChNIQU5E'
    'U0hBS0VfUEhBU0VfQUNLEAMSGgoWSEFORFNIQUtFX1BIQVNFX1JFSkVDVBAE');

@$core.Deprecated('Use sessionDescriptorDescriptor instead')
const SessionDescriptor$json = {
  '1': 'SessionDescriptor',
  '2': [
    {
      '1': 'session_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionId',
      '10': 'sessionId'
    },
    {
      '1': 'initiator_peer_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'initiatorPeerId'
    },
    {
      '1': 'responder_peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'responderPeerId'
    },
    {
      '1': 'state',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.SessionState',
      '10': 'state'
    },
    {
      '1': 'transport_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransportType',
      '10': 'transportType'
    },
    {
      '1': 'established_at_utc_ms',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'establishedAtUtcMs'
    },
    {'1': 'expires_at_utc_ms', '3': 7, '4': 1, '5': 3, '10': 'expiresAtUtcMs'},
    {
      '1': 'negotiated_capabilities',
      '3': 8,
      '4': 3,
      '5': 14,
      '6': '.peerlink.v1.FeatureCapability',
      '10': 'negotiatedCapabilities'
    },
    {
      '1': 'protocol_version',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'protocolVersion'
    },
  ],
};

/// Descriptor for `SessionDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionDescriptorDescriptor = $convert.base64Decode(
    'ChFTZXNzaW9uRGVzY3JpcHRvchI1CgpzZXNzaW9uX2lkGAEgASgLMhYucGVlcmxpbmsudjEuU2'
    'Vzc2lvbklkUglzZXNzaW9uSWQSPwoRaW5pdGlhdG9yX3BlZXJfaWQYAiABKAsyEy5wZWVybGlu'
    'ay52MS5QZWVySWRSD2luaXRpYXRvclBlZXJJZBI/ChFyZXNwb25kZXJfcGVlcl9pZBgDIAEoCz'
    'ITLnBlZXJsaW5rLnYxLlBlZXJJZFIPcmVzcG9uZGVyUGVlcklkEi8KBXN0YXRlGAQgASgOMhku'
    'cGVlcmxpbmsudjEuU2Vzc2lvblN0YXRlUgVzdGF0ZRJBCg50cmFuc3BvcnRfdHlwZRgFIAEoDj'
    'IaLnBlZXJsaW5rLnYxLlRyYW5zcG9ydFR5cGVSDXRyYW5zcG9ydFR5cGUSMQoVZXN0YWJsaXNo'
    'ZWRfYXRfdXRjX21zGAYgASgDUhJlc3RhYmxpc2hlZEF0VXRjTXMSKQoRZXhwaXJlc19hdF91dG'
    'NfbXMYByABKANSDmV4cGlyZXNBdFV0Y01zElcKF25lZ290aWF0ZWRfY2FwYWJpbGl0aWVzGAgg'
    'AygOMh4ucGVlcmxpbmsudjEuRmVhdHVyZUNhcGFiaWxpdHlSFm5lZ290aWF0ZWRDYXBhYmlsaX'
    'RpZXMSRwoQcHJvdG9jb2xfdmVyc2lvbhgJIAEoCzIcLnBlZXJsaW5rLnYxLlByb3RvY29sVmVy'
    'c2lvblIPcHJvdG9jb2xWZXJzaW9u');

@$core.Deprecated('Use sessionInitiateRequestDescriptor instead')
const SessionInitiateRequest$json = {
  '1': 'SessionInitiateRequest',
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
      '1': 'proposed_session_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionId',
      '10': 'proposedSessionId'
    },
    {
      '1': 'initiator_peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'initiatorPeerId'
    },
    {
      '1': 'preferred_transport',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransportType',
      '10': 'preferredTransport'
    },
    {
      '1': 'capability_offer',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CapabilityNegotiationRequest',
      '10': 'capabilityOffer'
    },
  ],
};

/// Descriptor for `SessionInitiateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionInitiateRequestDescriptor = $convert.base64Decode(
    'ChZTZXNzaW9uSW5pdGlhdGVSZXF1ZXN0EjMKBmhlYWRlchgBIAEoCzIbLnBlZXJsaW5rLnYxLl'
    'Byb3RvY29sSGVhZGVyUgZoZWFkZXISRgoTcHJvcG9zZWRfc2Vzc2lvbl9pZBgCIAEoCzIWLnBl'
    'ZXJsaW5rLnYxLlNlc3Npb25JZFIRcHJvcG9zZWRTZXNzaW9uSWQSPwoRaW5pdGlhdG9yX3BlZX'
    'JfaWQYAyABKAsyEy5wZWVybGluay52MS5QZWVySWRSD2luaXRpYXRvclBlZXJJZBJLChNwcmVm'
    'ZXJyZWRfdHJhbnNwb3J0GAQgASgOMhoucGVlcmxpbmsudjEuVHJhbnNwb3J0VHlwZVIScHJlZm'
    'VycmVkVHJhbnNwb3J0ElQKEGNhcGFiaWxpdHlfb2ZmZXIYBSABKAsyKS5wZWVybGluay52MS5D'
    'YXBhYmlsaXR5TmVnb3RpYXRpb25SZXF1ZXN0Ug9jYXBhYmlsaXR5T2ZmZXI=');

@$core.Deprecated('Use sessionInitiateResponseDescriptor instead')
const SessionInitiateResponse$json = {
  '1': 'SessionInitiateResponse',
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
      '1': 'session_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionId',
      '10': 'sessionId'
    },
    {
      '1': 'state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.SessionState',
      '10': 'state'
    },
    {
      '1': 'selected_transport',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransportType',
      '10': 'selectedTransport'
    },
    {
      '1': 'capability_response',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CapabilityNegotiationResponse',
      '10': 'capabilityResponse'
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

/// Descriptor for `SessionInitiateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionInitiateResponseDescriptor = $convert.base64Decode(
    'ChdTZXNzaW9uSW5pdGlhdGVSZXNwb25zZRIzCgZoZWFkZXIYASABKAsyGy5wZWVybGluay52MS'
    '5Qcm90b2NvbEhlYWRlclIGaGVhZGVyEjUKCnNlc3Npb25faWQYAiABKAsyFi5wZWVybGluay52'
    'MS5TZXNzaW9uSWRSCXNlc3Npb25JZBIvCgVzdGF0ZRgDIAEoDjIZLnBlZXJsaW5rLnYxLlNlc3'
    'Npb25TdGF0ZVIFc3RhdGUSSQoSc2VsZWN0ZWRfdHJhbnNwb3J0GAQgASgOMhoucGVlcmxpbmsu'
    'djEuVHJhbnNwb3J0VHlwZVIRc2VsZWN0ZWRUcmFuc3BvcnQSWwoTY2FwYWJpbGl0eV9yZXNwb2'
    '5zZRgFIAEoCzIqLnBlZXJsaW5rLnYxLkNhcGFiaWxpdHlOZWdvdGlhdGlvblJlc3BvbnNlUhJj'
    'YXBhYmlsaXR5UmVzcG9uc2USLgoFZXJyb3IYBiABKAsyGC5wZWVybGluay52MS5FcnJvckRldG'
    'FpbFIFZXJyb3I=');

@$core.Deprecated('Use handshakeFrameDescriptor instead')
const HandshakeFrame$json = {
  '1': 'HandshakeFrame',
  '2': [
    {
      '1': 'phase',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.HandshakePhase',
      '10': 'phase'
    },
    {
      '1': 'protocol_version',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'protocolVersion'
    },
    {
      '1': 'min_supported_version',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolVersion',
      '10': 'minSupportedVersion'
    },
    {
      '1': 'connection_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ConnectionId',
      '10': 'connectionId'
    },
    {
      '1': 'session_id',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionId',
      '10': 'sessionId'
    },
    {
      '1': 'peer_identity',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'peerIdentity'
    },
    {
      '1': 'device_identity',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceIdentity',
      '10': 'deviceIdentity'
    },
    {'1': 'nonce', '3': 8, '4': 1, '5': 12, '10': 'nonce'},
    {'1': 'timestamp_utc_ms', '3': 9, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {'1': 'signature', '3': 10, '4': 1, '5': 12, '10': 'signature'},
    {
      '1': 'supported_transports',
      '3': 11,
      '4': 3,
      '5': 14,
      '6': '.peerlink.v1.TransportType',
      '10': 'supportedTransports'
    },
    {
      '1': 'selected_transport',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TransportType',
      '10': 'selectedTransport'
    },
    {
      '1': 'supported_features',
      '3': 13,
      '4': 3,
      '5': 9,
      '10': 'supportedFeatures'
    },
    {
      '1': 'error',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
  ],
};

/// Descriptor for `HandshakeFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List handshakeFrameDescriptor = $convert.base64Decode(
    'Cg5IYW5kc2hha2VGcmFtZRIxCgVwaGFzZRgBIAEoDjIbLnBlZXJsaW5rLnYxLkhhbmRzaGFrZV'
    'BoYXNlUgVwaGFzZRJHChBwcm90b2NvbF92ZXJzaW9uGAIgASgLMhwucGVlcmxpbmsudjEuUHJv'
    'dG9jb2xWZXJzaW9uUg9wcm90b2NvbFZlcnNpb24SUAoVbWluX3N1cHBvcnRlZF92ZXJzaW9uGA'
    'MgASgLMhwucGVlcmxpbmsudjEuUHJvdG9jb2xWZXJzaW9uUhNtaW5TdXBwb3J0ZWRWZXJzaW9u'
    'Ej4KDWNvbm5lY3Rpb25faWQYBCABKAsyGS5wZWVybGluay52MS5Db25uZWN0aW9uSWRSDGNvbm'
    '5lY3Rpb25JZBI1CgpzZXNzaW9uX2lkGAUgASgLMhYucGVlcmxpbmsudjEuU2Vzc2lvbklkUglz'
    'ZXNzaW9uSWQSPgoNcGVlcl9pZGVudGl0eRgGIAEoCzIZLnBlZXJsaW5rLnYxLlBlZXJJZGVudG'
    'l0eVIMcGVlcklkZW50aXR5EkQKD2RldmljZV9pZGVudGl0eRgHIAEoCzIbLnBlZXJsaW5rLnYx'
    'LkRldmljZUlkZW50aXR5Ug5kZXZpY2VJZGVudGl0eRIUCgVub25jZRgIIAEoDFIFbm9uY2USKA'
    'oQdGltZXN0YW1wX3V0Y19tcxgJIAEoA1IOdGltZXN0YW1wVXRjTXMSHAoJc2lnbmF0dXJlGAog'
    'ASgMUglzaWduYXR1cmUSTQoUc3VwcG9ydGVkX3RyYW5zcG9ydHMYCyADKA4yGi5wZWVybGluay'
    '52MS5UcmFuc3BvcnRUeXBlUhNzdXBwb3J0ZWRUcmFuc3BvcnRzEkkKEnNlbGVjdGVkX3RyYW5z'
    'cG9ydBgMIAEoDjIaLnBlZXJsaW5rLnYxLlRyYW5zcG9ydFR5cGVSEXNlbGVjdGVkVHJhbnNwb3'
    'J0Ei0KEnN1cHBvcnRlZF9mZWF0dXJlcxgNIAMoCVIRc3VwcG9ydGVkRmVhdHVyZXMSLgoFZXJy'
    'b3IYDiABKAsyGC5wZWVybGluay52MS5FcnJvckRldGFpbFIFZXJyb3I=');

@$core.Deprecated('Use keepalivePingDescriptor instead')
const KeepalivePing$json = {
  '1': 'KeepalivePing',
  '2': [
    {'1': 'ping_id', '3': 1, '4': 1, '5': 9, '10': 'pingId'},
    {'1': 'timestamp_utc_ms', '3': 2, '4': 1, '5': 3, '10': 'timestampUtcMs'},
  ],
};

/// Descriptor for `KeepalivePing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keepalivePingDescriptor = $convert.base64Decode(
    'Cg1LZWVwYWxpdmVQaW5nEhcKB3BpbmdfaWQYASABKAlSBnBpbmdJZBIoChB0aW1lc3RhbXBfdX'
    'RjX21zGAIgASgDUg50aW1lc3RhbXBVdGNNcw==');

@$core.Deprecated('Use keepalivePongDescriptor instead')
const KeepalivePong$json = {
  '1': 'KeepalivePong',
  '2': [
    {'1': 'ping_id', '3': 1, '4': 1, '5': 9, '10': 'pingId'},
    {
      '1': 'echo_timestamp_utc_ms',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'echoTimestampUtcMs'
    },
    {
      '1': 'responder_timestamp_utc_ms',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'responderTimestampUtcMs'
    },
  ],
};

/// Descriptor for `KeepalivePong`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keepalivePongDescriptor = $convert.base64Decode(
    'Cg1LZWVwYWxpdmVQb25nEhcKB3BpbmdfaWQYASABKAlSBnBpbmdJZBIxChVlY2hvX3RpbWVzdG'
    'FtcF91dGNfbXMYAiABKANSEmVjaG9UaW1lc3RhbXBVdGNNcxI7ChpyZXNwb25kZXJfdGltZXN0'
    'YW1wX3V0Y19tcxgDIAEoA1IXcmVzcG9uZGVyVGltZXN0YW1wVXRjTXM=');

@$core.Deprecated('Use sessionCloseFrameDescriptor instead')
const SessionCloseFrame$json = {
  '1': 'SessionCloseFrame',
  '2': [
    {
      '1': 'session_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionId',
      '10': 'sessionId'
    },
    {'1': 'reason_code', '3': 2, '4': 1, '5': 13, '10': 'reasonCode'},
    {'1': 'reason_message', '3': 3, '4': 1, '5': 9, '10': 'reasonMessage'},
  ],
};

/// Descriptor for `SessionCloseFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionCloseFrameDescriptor = $convert.base64Decode(
    'ChFTZXNzaW9uQ2xvc2VGcmFtZRI1CgpzZXNzaW9uX2lkGAEgASgLMhYucGVlcmxpbmsudjEuU2'
    'Vzc2lvbklkUglzZXNzaW9uSWQSHwoLcmVhc29uX2NvZGUYAiABKA1SCnJlYXNvbkNvZGUSJQoO'
    'cmVhc29uX21lc3NhZ2UYAyABKAlSDXJlYXNvbk1lc3NhZ2U=');

@$core.Deprecated('Use transportFrameDescriptor instead')
const TransportFrame$json = {
  '1': 'TransportFrame',
  '2': [
    {
      '1': 'handshake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.HandshakeFrame',
      '9': 0,
      '10': 'handshake'
    },
    {
      '1': 'ping',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.KeepalivePing',
      '9': 0,
      '10': 'ping'
    },
    {
      '1': 'pong',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.KeepalivePong',
      '9': 0,
      '10': 'pong'
    },
    {
      '1': 'close',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionCloseFrame',
      '9': 0,
      '10': 'close'
    },
    {'1': 'payload', '3': 5, '4': 1, '5': 12, '9': 0, '10': 'payload'},
  ],
  '8': [
    {'1': 'frame'},
  ],
};

/// Descriptor for `TransportFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transportFrameDescriptor = $convert.base64Decode(
    'Cg5UcmFuc3BvcnRGcmFtZRI7CgloYW5kc2hha2UYASABKAsyGy5wZWVybGluay52MS5IYW5kc2'
    'hha2VGcmFtZUgAUgloYW5kc2hha2USMAoEcGluZxgCIAEoCzIaLnBlZXJsaW5rLnYxLktlZXBh'
    'bGl2ZVBpbmdIAFIEcGluZxIwCgRwb25nGAMgASgLMhoucGVlcmxpbmsudjEuS2VlcGFsaXZlUG'
    '9uZ0gAUgRwb25nEjYKBWNsb3NlGAQgASgLMh4ucGVlcmxpbmsudjEuU2Vzc2lvbkNsb3NlRnJh'
    'bWVIAFIFY2xvc2USGgoHcGF5bG9hZBgFIAEoDEgAUgdwYXlsb2FkQgcKBWZyYW1l');
