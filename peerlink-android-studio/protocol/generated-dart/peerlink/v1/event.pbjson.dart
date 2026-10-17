// This is a generated file - do not edit.
//
// Generated from peerlink/v1/event.proto.

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

@$core.Deprecated('Use peerLinkEventDescriptor instead')
const PeerLinkEvent$json = {
  '1': 'PeerLinkEvent',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {
      '1': 'header',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolHeader',
      '10': 'header'
    },
    {
      '1': 'session_event',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.SessionDescriptor',
      '9': 0,
      '10': 'sessionEvent'
    },
    {
      '1': 'capability_event',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CapabilityNegotiationResponse',
      '9': 0,
      '10': 'capabilityEvent'
    },
    {
      '1': 'operation_event',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationRecord',
      '9': 0,
      '10': 'operationEvent'
    },
    {
      '1': 'error_event',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '9': 0,
      '10': 'errorEvent'
    },
    {
      '1': 'peer_event',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '9': 0,
      '10': 'peerEvent'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `PeerLinkEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerLinkEventDescriptor = $convert.base64Decode(
    'Cg1QZWVyTGlua0V2ZW50EhkKCGV2ZW50X2lkGAEgASgJUgdldmVudElkEjMKBmhlYWRlchgCIA'
    'EoCzIbLnBlZXJsaW5rLnYxLlByb3RvY29sSGVhZGVyUgZoZWFkZXISRQoNc2Vzc2lvbl9ldmVu'
    'dBgDIAEoCzIeLnBlZXJsaW5rLnYxLlNlc3Npb25EZXNjcmlwdG9ySABSDHNlc3Npb25FdmVudB'
    'JXChBjYXBhYmlsaXR5X2V2ZW50GAQgASgLMioucGVlcmxpbmsudjEuQ2FwYWJpbGl0eU5lZ290'
    'aWF0aW9uUmVzcG9uc2VIAFIPY2FwYWJpbGl0eUV2ZW50EkcKD29wZXJhdGlvbl9ldmVudBgFIA'
    'EoCzIcLnBlZXJsaW5rLnYxLk9wZXJhdGlvblJlY29yZEgAUg5vcGVyYXRpb25FdmVudBI7Cgtl'
    'cnJvcl9ldmVudBgGIAEoCzIYLnBlZXJsaW5rLnYxLkVycm9yRGV0YWlsSABSCmVycm9yRXZlbn'
    'QSOgoKcGVlcl9ldmVudBgHIAEoCzIZLnBlZXJsaW5rLnYxLlBlZXJJZGVudGl0eUgAUglwZWVy'
    'RXZlbnRCCQoHcGF5bG9hZA==');
