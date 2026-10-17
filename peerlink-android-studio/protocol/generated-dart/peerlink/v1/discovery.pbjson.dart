// This is a generated file - do not edit.
//
// Generated from peerlink/v1/discovery.proto.

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

@$core.Deprecated('Use discoveryEventTypeDescriptor instead')
const DiscoveryEventType$json = {
  '1': 'DiscoveryEventType',
  '2': [
    {'1': 'DISCOVERY_EVENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'DISCOVERY_EVENT_TYPE_PEER_FOUND', '2': 1},
    {'1': 'DISCOVERY_EVENT_TYPE_PEER_LOST', '2': 2},
    {'1': 'DISCOVERY_EVENT_TYPE_PEER_UPDATED', '2': 3},
  ],
};

/// Descriptor for `DiscoveryEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List discoveryEventTypeDescriptor = $convert.base64Decode(
    'ChJEaXNjb3ZlcnlFdmVudFR5cGUSJAogRElTQ09WRVJZX0VWRU5UX1RZUEVfVU5TUEVDSUZJRU'
    'QQABIjCh9ESVNDT1ZFUllfRVZFTlRfVFlQRV9QRUVSX0ZPVU5EEAESIgoeRElTQ09WRVJZX0VW'
    'RU5UX1RZUEVfUEVFUl9MT1NUEAISJQohRElTQ09WRVJZX0VWRU5UX1RZUEVfUEVFUl9VUERBVE'
    'VEEAM=');

@$core.Deprecated('Use discoveredPeerDescriptor instead')
const DiscoveredPeer$json = {
  '1': 'DiscoveredPeer',
  '2': [
    {
      '1': 'peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'peerId'
    },
    {'1': 'socket_addresses', '3': 2, '4': 3, '5': 9, '10': 'socketAddresses'},
    {
      '1': 'capabilities',
      '3': 3,
      '4': 3,
      '5': 14,
      '6': '.peerlink.v1.FeatureCapability',
      '10': 'capabilities'
    },
    {'1': 'display_name', '3': 4, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'last_seen_utc_ms', '3': 5, '4': 1, '5': 3, '10': 'lastSeenUtcMs'},
  ],
};

/// Descriptor for `DiscoveredPeer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discoveredPeerDescriptor = $convert.base64Decode(
    'Cg5EaXNjb3ZlcmVkUGVlchIsCgdwZWVyX2lkGAEgASgLMhMucGVlcmxpbmsudjEuUGVlcklkUg'
    'ZwZWVySWQSKQoQc29ja2V0X2FkZHJlc3NlcxgCIAMoCVIPc29ja2V0QWRkcmVzc2VzEkIKDGNh'
    'cGFiaWxpdGllcxgDIAMoDjIeLnBlZXJsaW5rLnYxLkZlYXR1cmVDYXBhYmlsaXR5UgxjYXBhYm'
    'lsaXRpZXMSIQoMZGlzcGxheV9uYW1lGAQgASgJUgtkaXNwbGF5TmFtZRInChBsYXN0X3NlZW5f'
    'dXRjX21zGAUgASgDUg1sYXN0U2VlblV0Y01z');

@$core.Deprecated('Use discoveryEventDescriptor instead')
const DiscoveryEvent$json = {
  '1': 'DiscoveryEvent',
  '2': [
    {
      '1': 'event_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.DiscoveryEventType',
      '10': 'eventType'
    },
    {
      '1': 'peer',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DiscoveredPeer',
      '10': 'peer'
    },
    {'1': 'timestamp_utc_ms', '3': 3, '4': 1, '5': 3, '10': 'timestampUtcMs'},
  ],
};

/// Descriptor for `DiscoveryEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discoveryEventDescriptor = $convert.base64Decode(
    'Cg5EaXNjb3ZlcnlFdmVudBI+CgpldmVudF90eXBlGAEgASgOMh8ucGVlcmxpbmsudjEuRGlzY2'
    '92ZXJ5RXZlbnRUeXBlUglldmVudFR5cGUSLwoEcGVlchgCIAEoCzIbLnBlZXJsaW5rLnYxLkRp'
    'c2NvdmVyZWRQZWVyUgRwZWVyEigKEHRpbWVzdGFtcF91dGNfbXMYAyABKANSDnRpbWVzdGFtcF'
    'V0Y01z');
