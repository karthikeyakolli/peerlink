// This is a generated file - do not edit.
//
// Generated from peerlink/v1/ipc.proto.

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

@$core.Deprecated('Use nodeExecutionStatusDescriptor instead')
const NodeExecutionStatus$json = {
  '1': 'NodeExecutionStatus',
  '2': [
    {'1': 'NODE_EXECUTION_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'NODE_EXECUTION_STATUS_STARTING', '2': 1},
    {'1': 'NODE_EXECUTION_STATUS_RUNNING', '2': 2},
    {'1': 'NODE_EXECUTION_STATUS_DEGRADED', '2': 3},
    {'1': 'NODE_EXECUTION_STATUS_STOPPING', '2': 4},
    {'1': 'NODE_EXECUTION_STATUS_STOPPED', '2': 5},
  ],
};

/// Descriptor for `NodeExecutionStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List nodeExecutionStatusDescriptor = $convert.base64Decode(
    'ChNOb2RlRXhlY3V0aW9uU3RhdHVzEiUKIU5PREVfRVhFQ1VUSU9OX1NUQVRVU19VTlNQRUNJRk'
    'lFRBAAEiIKHk5PREVfRVhFQ1VUSU9OX1NUQVRVU19TVEFSVElORxABEiEKHU5PREVfRVhFQ1VU'
    'SU9OX1NUQVRVU19SVU5OSU5HEAISIgoeTk9ERV9FWEVDVVRJT05fU1RBVFVTX0RFR1JBREVEEA'
    'MSIgoeTk9ERV9FWEVDVVRJT05fU1RBVFVTX1NUT1BQSU5HEAQSIQodTk9ERV9FWEVDVVRJT05f'
    'U1RBVFVTX1NUT1BQRUQQBQ==');

@$core.Deprecated('Use authenticateIpcRequestDescriptor instead')
const AuthenticateIpcRequest$json = {
  '1': 'AuthenticateIpcRequest',
  '2': [
    {'1': 'auth_token', '3': 1, '4': 1, '5': 9, '10': 'authToken'},
    {'1': 'client_pid', '3': 2, '4': 1, '5': 3, '10': 'clientPid'},
    {'1': 'client_version', '3': 3, '4': 1, '5': 9, '10': 'clientVersion'},
  ],
};

/// Descriptor for `AuthenticateIpcRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authenticateIpcRequestDescriptor = $convert.base64Decode(
    'ChZBdXRoZW50aWNhdGVJcGNSZXF1ZXN0Eh0KCmF1dGhfdG9rZW4YASABKAlSCWF1dGhUb2tlbh'
    'IdCgpjbGllbnRfcGlkGAIgASgDUgljbGllbnRQaWQSJQoOY2xpZW50X3ZlcnNpb24YAyABKAlS'
    'DWNsaWVudFZlcnNpb24=');

@$core.Deprecated('Use authenticateIpcResponseDescriptor instead')
const AuthenticateIpcResponse$json = {
  '1': 'AuthenticateIpcResponse',
  '2': [
    {'1': 'authenticated', '3': 1, '4': 1, '5': 8, '10': 'authenticated'},
    {'1': 'session_token', '3': 2, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'node_version', '3': 3, '4': 1, '5': 9, '10': 'nodeVersion'},
    {
      '1': 'local_peer_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'localPeerId'
    },
    {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
    {'1': 'is_compatible', '3': 6, '4': 1, '5': 8, '10': 'isCompatible'},
    {
      '1': 'min_compatible_version',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'minCompatibleVersion'
    },
  ],
};

/// Descriptor for `AuthenticateIpcResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authenticateIpcResponseDescriptor = $convert.base64Decode(
    'ChdBdXRoZW50aWNhdGVJcGNSZXNwb25zZRIkCg1hdXRoZW50aWNhdGVkGAEgASgIUg1hdXRoZW'
    '50aWNhdGVkEiMKDXNlc3Npb25fdG9rZW4YAiABKAlSDHNlc3Npb25Ub2tlbhIhCgxub2RlX3Zl'
    'cnNpb24YAyABKAlSC25vZGVWZXJzaW9uEjcKDWxvY2FsX3BlZXJfaWQYBCABKAsyEy5wZWVybG'
    'luay52MS5QZWVySWRSC2xvY2FsUGVlcklkEiMKDWVycm9yX21lc3NhZ2UYBSABKAlSDGVycm9y'
    'TWVzc2FnZRIjCg1pc19jb21wYXRpYmxlGAYgASgIUgxpc0NvbXBhdGlibGUSNAoWbWluX2NvbX'
    'BhdGlibGVfdmVyc2lvbhgHIAEoCVIUbWluQ29tcGF0aWJsZVZlcnNpb24=');

@$core.Deprecated('Use getNodeStatusRequestDescriptor instead')
const GetNodeStatusRequest$json = {
  '1': 'GetNodeStatusRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
  ],
};

/// Descriptor for `GetNodeStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNodeStatusRequestDescriptor = $convert.base64Decode(
    'ChRHZXROb2RlU3RhdHVzUmVxdWVzdBIjCg1zZXNzaW9uX3Rva2VuGAEgASgJUgxzZXNzaW9uVG'
    '9rZW4=');

@$core.Deprecated('Use getNodeStatusResponseDescriptor instead')
const GetNodeStatusResponse$json = {
  '1': 'GetNodeStatusResponse',
  '2': [
    {
      '1': 'status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.NodeExecutionStatus',
      '10': 'status'
    },
    {
      '1': 'peer_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'peerId'
    },
    {'1': 'listen_port', '3': 3, '4': 1, '5': 5, '10': 'listenPort'},
    {
      '1': 'supported_capabilities',
      '3': 4,
      '4': 3,
      '5': 14,
      '6': '.peerlink.v1.FeatureCapability',
      '10': 'supportedCapabilities'
    },
    {'1': 'uptime_seconds', '3': 5, '4': 1, '5': 3, '10': 'uptimeSeconds'},
    {'1': 'memory_used_bytes', '3': 6, '4': 1, '5': 3, '10': 'memoryUsedBytes'},
    {'1': 'node_version', '3': 7, '4': 1, '5': 9, '10': 'nodeVersion'},
    {
      '1': 'active_subscribers',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'activeSubscribers'
    },
  ],
};

/// Descriptor for `GetNodeStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNodeStatusResponseDescriptor = $convert.base64Decode(
    'ChVHZXROb2RlU3RhdHVzUmVzcG9uc2USOAoGc3RhdHVzGAEgASgOMiAucGVlcmxpbmsudjEuTm'
    '9kZUV4ZWN1dGlvblN0YXR1c1IGc3RhdHVzEiwKB3BlZXJfaWQYAiABKAsyEy5wZWVybGluay52'
    'MS5QZWVySWRSBnBlZXJJZBIfCgtsaXN0ZW5fcG9ydBgDIAEoBVIKbGlzdGVuUG9ydBJVChZzdX'
    'Bwb3J0ZWRfY2FwYWJpbGl0aWVzGAQgAygOMh4ucGVlcmxpbmsudjEuRmVhdHVyZUNhcGFiaWxp'
    'dHlSFXN1cHBvcnRlZENhcGFiaWxpdGllcxIlCg51cHRpbWVfc2Vjb25kcxgFIAEoA1INdXB0aW'
    '1lU2Vjb25kcxIqChFtZW1vcnlfdXNlZF9ieXRlcxgGIAEoA1IPbWVtb3J5VXNlZEJ5dGVzEiEK'
    'DG5vZGVfdmVyc2lvbhgHIAEoCVILbm9kZVZlcnNpb24SLQoSYWN0aXZlX3N1YnNjcmliZXJzGA'
    'ggASgFUhFhY3RpdmVTdWJzY3JpYmVycw==');

@$core.Deprecated('Use nodeEventSubscriptionRequestDescriptor instead')
const NodeEventSubscriptionRequest$json = {
  '1': 'NodeEventSubscriptionRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
  ],
};

/// Descriptor for `NodeEventSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeEventSubscriptionRequestDescriptor =
    $convert.base64Decode(
        'ChxOb2RlRXZlbnRTdWJzY3JpcHRpb25SZXF1ZXN0EiMKDXNlc3Npb25fdG9rZW4YASABKAlSDH'
        'Nlc3Npb25Ub2tlbg==');

@$core.Deprecated('Use nodeHeartbeatDescriptor instead')
const NodeHeartbeat$json = {
  '1': 'NodeHeartbeat',
  '2': [
    {'1': 'timestamp_utc_ms', '3': 1, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {
      '1': 'status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.NodeExecutionStatus',
      '10': 'status'
    },
    {'1': 'uptime_seconds', '3': 3, '4': 1, '5': 3, '10': 'uptimeSeconds'},
    {'1': 'memory_used_bytes', '3': 4, '4': 1, '5': 3, '10': 'memoryUsedBytes'},
    {'1': 'sequence_number', '3': 5, '4': 1, '5': 3, '10': 'sequenceNumber'},
  ],
};

/// Descriptor for `NodeHeartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeHeartbeatDescriptor = $convert.base64Decode(
    'Cg1Ob2RlSGVhcnRiZWF0EigKEHRpbWVzdGFtcF91dGNfbXMYASABKANSDnRpbWVzdGFtcFV0Y0'
    '1zEjgKBnN0YXR1cxgCIAEoDjIgLnBlZXJsaW5rLnYxLk5vZGVFeGVjdXRpb25TdGF0dXNSBnN0'
    'YXR1cxIlCg51cHRpbWVfc2Vjb25kcxgDIAEoA1INdXB0aW1lU2Vjb25kcxIqChFtZW1vcnlfdX'
    'NlZF9ieXRlcxgEIAEoA1IPbWVtb3J5VXNlZEJ5dGVzEicKD3NlcXVlbmNlX251bWJlchgFIAEo'
    'A1IOc2VxdWVuY2VOdW1iZXI=');

@$core.Deprecated('Use nodeEventDescriptor instead')
const NodeEvent$json = {
  '1': 'NodeEvent',
  '2': [
    {'1': 'timestamp_utc_ms', '3': 1, '4': 1, '5': 3, '10': 'timestampUtcMs'},
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.NodeHeartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'operation_update',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationRecord',
      '9': 0,
      '10': 'operationUpdate'
    },
    {
      '1': 'security_alert',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'securityAlert'
    },
    {
      '1': 'lifecycle_event',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'lifecycleEvent'
    },
    {
      '1': 'transfer_progress',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferProgress',
      '9': 0,
      '10': 'transferProgress'
    },
    {
      '1': 'transfer_receipt',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferCompletedReceipt',
      '9': 0,
      '10': 'transferReceipt'
    },
  ],
  '8': [
    {'1': 'event'},
  ],
};

/// Descriptor for `NodeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeEventDescriptor = $convert.base64Decode(
    'CglOb2RlRXZlbnQSKAoQdGltZXN0YW1wX3V0Y19tcxgBIAEoA1IOdGltZXN0YW1wVXRjTXMSOg'
    'oJaGVhcnRiZWF0GAIgASgLMhoucGVlcmxpbmsudjEuTm9kZUhlYXJ0YmVhdEgAUgloZWFydGJl'
    'YXQSSQoQb3BlcmF0aW9uX3VwZGF0ZRgDIAEoCzIcLnBlZXJsaW5rLnYxLk9wZXJhdGlvblJlY2'
    '9yZEgAUg9vcGVyYXRpb25VcGRhdGUSJwoOc2VjdXJpdHlfYWxlcnQYBCABKAlIAFINc2VjdXJp'
    'dHlBbGVydBIpCg9saWZlY3ljbGVfZXZlbnQYBSABKAlIAFIObGlmZWN5Y2xlRXZlbnQSTAoRdH'
    'JhbnNmZXJfcHJvZ3Jlc3MYBiABKAsyHS5wZWVybGluay52MS5UcmFuc2ZlclByb2dyZXNzSABS'
    'EHRyYW5zZmVyUHJvZ3Jlc3MSUgoQdHJhbnNmZXJfcmVjZWlwdBgHIAEoCzIlLnBlZXJsaW5rLn'
    'YxLlRyYW5zZmVyQ29tcGxldGVkUmVjZWlwdEgAUg90cmFuc2ZlclJlY2VpcHRCBwoFZXZlbnQ=');

@$core.Deprecated('Use restartNodeRequestDescriptor instead')
const RestartNodeRequest$json = {
  '1': 'RestartNodeRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'delay_ms', '3': 2, '4': 1, '5': 5, '10': 'delayMs'},
  ],
};

/// Descriptor for `RestartNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartNodeRequestDescriptor = $convert.base64Decode(
    'ChJSZXN0YXJ0Tm9kZVJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvblRva2'
    'VuEhkKCGRlbGF5X21zGAIgASgFUgdkZWxheU1z');

@$core.Deprecated('Use restartNodeResponseDescriptor instead')
const RestartNodeResponse$json = {
  '1': 'RestartNodeResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `RestartNodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartNodeResponseDescriptor = $convert.base64Decode(
    'ChNSZXN0YXJ0Tm9kZVJlc3BvbnNlEhoKCGFjY2VwdGVkGAEgASgIUghhY2NlcHRlZBIYCgdtZX'
    'NzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use stopNodeRequestDescriptor instead')
const StopNodeRequest$json = {
  '1': 'StopNodeRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
  ],
};

/// Descriptor for `StopNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopNodeRequestDescriptor = $convert.base64Decode(
    'Cg9TdG9wTm9kZVJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvblRva2Vu');

@$core.Deprecated('Use stopNodeResponseDescriptor instead')
const StopNodeResponse$json = {
  '1': 'StopNodeResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `StopNodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopNodeResponseDescriptor = $convert.base64Decode(
    'ChBTdG9wTm9kZVJlc3BvbnNlEhoKCGFjY2VwdGVkGAEgASgIUghhY2NlcHRlZBIYCgdtZXNzYW'
    'dlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use initiateSendRequestDescriptor instead')
const InitiateSendRequest$json = {
  '1': 'InitiateSendRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {
      '1': 'target_peer_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'targetPeerId'
    },
    {'1': 'source_paths', '3': 3, '4': 3, '5': 9, '10': 'sourcePaths'},
    {
      '1': 'destination_folder',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'destinationFolder'
    },
    {
      '1': 'duplicate_policy',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.DuplicateDestinationPolicy',
      '10': 'duplicatePolicy'
    },
    {'1': 'display_name', '3': 6, '4': 1, '5': 9, '10': 'displayName'},
  ],
};

/// Descriptor for `InitiateSendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List initiateSendRequestDescriptor = $convert.base64Decode(
    'ChNJbml0aWF0ZVNlbmRSZXF1ZXN0EiMKDXNlc3Npb25fdG9rZW4YASABKAlSDHNlc3Npb25Ub2'
    'tlbhI5Cg50YXJnZXRfcGVlcl9pZBgCIAEoCzITLnBlZXJsaW5rLnYxLlBlZXJJZFIMdGFyZ2V0'
    'UGVlcklkEiEKDHNvdXJjZV9wYXRocxgDIAMoCVILc291cmNlUGF0aHMSLQoSZGVzdGluYXRpb2'
    '5fZm9sZGVyGAQgASgJUhFkZXN0aW5hdGlvbkZvbGRlchJSChBkdXBsaWNhdGVfcG9saWN5GAUg'
    'ASgOMicucGVlcmxpbmsudjEuRHVwbGljYXRlRGVzdGluYXRpb25Qb2xpY3lSD2R1cGxpY2F0ZV'
    'BvbGljeRIhCgxkaXNwbGF5X25hbWUYBiABKAlSC2Rpc3BsYXlOYW1l');

@$core.Deprecated('Use initiateSendResponseDescriptor instead')
const InitiateSendResponse$json = {
  '1': 'InitiateSendResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'transfer_id', '3': 2, '4': 1, '5': 9, '10': 'transferId'},
    {
      '1': 'operation_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.OperationId',
      '10': 'operationId'
    },
    {'1': 'total_bytes', '3': 4, '4': 1, '5': 3, '10': 'totalBytes'},
    {'1': 'file_count', '3': 5, '4': 1, '5': 5, '10': 'fileCount'},
    {'1': 'error_message', '3': 6, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `InitiateSendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List initiateSendResponseDescriptor = $convert.base64Decode(
    'ChRJbml0aWF0ZVNlbmRSZXNwb25zZRIaCghhY2NlcHRlZBgBIAEoCFIIYWNjZXB0ZWQSHwoLdH'
    'JhbnNmZXJfaWQYAiABKAlSCnRyYW5zZmVySWQSOwoMb3BlcmF0aW9uX2lkGAMgASgLMhgucGVl'
    'cmxpbmsudjEuT3BlcmF0aW9uSWRSC29wZXJhdGlvbklkEh8KC3RvdGFsX2J5dGVzGAQgASgDUg'
    'p0b3RhbEJ5dGVzEh0KCmZpbGVfY291bnQYBSABKAVSCWZpbGVDb3VudBIjCg1lcnJvcl9tZXNz'
    'YWdlGAYgASgJUgxlcnJvck1lc3NhZ2U=');

@$core.Deprecated('Use cancelTransferRequestDescriptor instead')
const CancelTransferRequest$json = {
  '1': 'CancelTransferRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'transfer_id', '3': 2, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `CancelTransferRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelTransferRequestDescriptor = $convert.base64Decode(
    'ChVDYW5jZWxUcmFuc2ZlclJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvbl'
    'Rva2VuEh8KC3RyYW5zZmVyX2lkGAIgASgJUgp0cmFuc2ZlcklkEhYKBnJlYXNvbhgDIAEoCVIG'
    'cmVhc29u');

@$core.Deprecated('Use cancelTransferResponseDescriptor instead')
const CancelTransferResponse$json = {
  '1': 'CancelTransferResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `CancelTransferResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelTransferResponseDescriptor =
    $convert.base64Decode(
        'ChZDYW5jZWxUcmFuc2ZlclJlc3BvbnNlEhoKCGFjY2VwdGVkGAEgASgIUghhY2NlcHRlZBIYCg'
        'dtZXNzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use getTransferRequestDescriptor instead')
const GetTransferRequest$json = {
  '1': 'GetTransferRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'transfer_id', '3': 2, '4': 1, '5': 9, '10': 'transferId'},
  ],
};

/// Descriptor for `GetTransferRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTransferRequestDescriptor = $convert.base64Decode(
    'ChJHZXRUcmFuc2ZlclJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvblRva2'
    'VuEh8KC3RyYW5zZmVyX2lkGAIgASgJUgp0cmFuc2Zlcklk');

@$core.Deprecated('Use getTransferResponseDescriptor instead')
const GetTransferResponse$json = {
  '1': 'GetTransferResponse',
  '2': [
    {
      '1': 'transfer_descriptor',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferDescriptor',
      '10': 'transferDescriptor'
    },
    {
      '1': 'progress',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.TransferProgress',
      '10': 'progress'
    },
    {'1': 'found', '3': 3, '4': 1, '5': 8, '10': 'found'},
  ],
};

/// Descriptor for `GetTransferResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTransferResponseDescriptor = $convert.base64Decode(
    'ChNHZXRUcmFuc2ZlclJlc3BvbnNlElAKE3RyYW5zZmVyX2Rlc2NyaXB0b3IYASABKAsyHy5wZW'
    'VybGluay52MS5UcmFuc2ZlckRlc2NyaXB0b3JSEnRyYW5zZmVyRGVzY3JpcHRvchI5Cghwcm9n'
    'cmVzcxgCIAEoCzIdLnBlZXJsaW5rLnYxLlRyYW5zZmVyUHJvZ3Jlc3NSCHByb2dyZXNzEhQKBW'
    'ZvdW5kGAMgASgIUgVmb3VuZA==');

@$core.Deprecated('Use listTransfersRequestDescriptor instead')
const ListTransfersRequest$json = {
  '1': 'ListTransfersRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'active_only', '3': 2, '4': 1, '5': 8, '10': 'activeOnly'},
  ],
};

/// Descriptor for `ListTransfersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTransfersRequestDescriptor = $convert.base64Decode(
    'ChRMaXN0VHJhbnNmZXJzUmVxdWVzdBIjCg1zZXNzaW9uX3Rva2VuGAEgASgJUgxzZXNzaW9uVG'
    '9rZW4SHwoLYWN0aXZlX29ubHkYAiABKAhSCmFjdGl2ZU9ubHk=');

@$core.Deprecated('Use listTransfersResponseDescriptor instead')
const ListTransfersResponse$json = {
  '1': 'ListTransfersResponse',
  '2': [
    {
      '1': 'transfers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.TransferProgress',
      '10': 'transfers'
    },
  ],
};

/// Descriptor for `ListTransfersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTransfersResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0VHJhbnNmZXJzUmVzcG9uc2USOwoJdHJhbnNmZXJzGAEgAygLMh0ucGVlcmxpbmsudj'
    'EuVHJhbnNmZXJQcm9ncmVzc1IJdHJhbnNmZXJz');

@$core.Deprecated('Use revealInFolderRequestDescriptor instead')
const RevealInFolderRequest$json = {
  '1': 'RevealInFolderRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {
      '1': 'file_or_folder_path',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'fileOrFolderPath'
    },
  ],
};

/// Descriptor for `RevealInFolderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revealInFolderRequestDescriptor = $convert.base64Decode(
    'ChVSZXZlYWxJbkZvbGRlclJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvbl'
    'Rva2VuEi0KE2ZpbGVfb3JfZm9sZGVyX3BhdGgYAiABKAlSEGZpbGVPckZvbGRlclBhdGg=');

@$core.Deprecated('Use revealInFolderResponseDescriptor instead')
const RevealInFolderResponse$json = {
  '1': 'RevealInFolderResponse',
  '2': [
    {'1': 'opened', '3': 1, '4': 1, '5': 8, '10': 'opened'},
    {'1': 'error_message', '3': 2, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `RevealInFolderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revealInFolderResponseDescriptor =
    $convert.base64Decode(
        'ChZSZXZlYWxJbkZvbGRlclJlc3BvbnNlEhYKBm9wZW5lZBgBIAEoCFIGb3BlbmVkEiMKDWVycm'
        '9yX21lc3NhZ2UYAiABKAlSDGVycm9yTWVzc2FnZQ==');

@$core.Deprecated('Use pauseTransferRequestDescriptor instead')
const PauseTransferRequest$json = {
  '1': 'PauseTransferRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'transfer_id', '3': 2, '4': 1, '5': 9, '10': 'transferId'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PauseTransferRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pauseTransferRequestDescriptor = $convert.base64Decode(
    'ChRQYXVzZVRyYW5zZmVyUmVxdWVzdBIjCg1zZXNzaW9uX3Rva2VuGAEgASgJUgxzZXNzaW9uVG'
    '9rZW4SHwoLdHJhbnNmZXJfaWQYAiABKAlSCnRyYW5zZmVySWQSFgoGcmVhc29uGAMgASgJUgZy'
    'ZWFzb24=');

@$core.Deprecated('Use pauseTransferResponseDescriptor instead')
const PauseTransferResponse$json = {
  '1': 'PauseTransferResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `PauseTransferResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pauseTransferResponseDescriptor = $convert.base64Decode(
    'ChVQYXVzZVRyYW5zZmVyUmVzcG9uc2USGgoIYWNjZXB0ZWQYASABKAhSCGFjY2VwdGVkEhgKB2'
    '1lc3NhZ2UYAiABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use resumeTransferRequestDescriptor instead')
const ResumeTransferRequest$json = {
  '1': 'ResumeTransferRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'transfer_id', '3': 2, '4': 1, '5': 9, '10': 'transferId'},
  ],
};

/// Descriptor for `ResumeTransferRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resumeTransferRequestDescriptor = $convert.base64Decode(
    'ChVSZXN1bWVUcmFuc2ZlclJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvbl'
    'Rva2VuEh8KC3RyYW5zZmVyX2lkGAIgASgJUgp0cmFuc2Zlcklk');

@$core.Deprecated('Use resumeTransferResponseDescriptor instead')
const ResumeTransferResponse$json = {
  '1': 'ResumeTransferResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ResumeTransferResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resumeTransferResponseDescriptor =
    $convert.base64Decode(
        'ChZSZXN1bWVUcmFuc2ZlclJlc3BvbnNlEhoKCGFjY2VwdGVkGAEgASgIUghhY2NlcHRlZBIYCg'
        'dtZXNzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use setBandwidthLimitRequestDescriptor instead')
const SetBandwidthLimitRequest$json = {
  '1': 'SetBandwidthLimitRequest',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'max_bytes_per_sec', '3': 2, '4': 1, '5': 3, '10': 'maxBytesPerSec'},
  ],
};

/// Descriptor for `SetBandwidthLimitRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setBandwidthLimitRequestDescriptor =
    $convert.base64Decode(
        'ChhTZXRCYW5kd2lkdGhMaW1pdFJlcXVlc3QSIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2'
        'lvblRva2VuEikKEW1heF9ieXRlc19wZXJfc2VjGAIgASgDUg5tYXhCeXRlc1BlclNlYw==');

@$core.Deprecated('Use setBandwidthLimitResponseDescriptor instead')
const SetBandwidthLimitResponse$json = {
  '1': 'SetBandwidthLimitResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'current_limit_bps', '3': 2, '4': 1, '5': 3, '10': 'currentLimitBps'},
  ],
};

/// Descriptor for `SetBandwidthLimitResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setBandwidthLimitResponseDescriptor =
    $convert.base64Decode(
        'ChlTZXRCYW5kd2lkdGhMaW1pdFJlc3BvbnNlEhoKCGFjY2VwdGVkGAEgASgIUghhY2NlcHRlZB'
        'IqChFjdXJyZW50X2xpbWl0X2JwcxgCIAEoA1IPY3VycmVudExpbWl0QnBz');
