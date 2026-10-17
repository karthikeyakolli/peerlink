// This is a generated file - do not edit.
//
// Generated from peerlink/v1/access.proto.

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

@$core.Deprecated('Use accessRequestTypeDescriptor instead')
const AccessRequestType$json = {
  '1': 'AccessRequestType',
  '2': [
    {'1': 'ACCESS_REQUEST_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ACCESS_REQUEST_TYPE_BROWSE', '2': 1},
    {'1': 'ACCESS_REQUEST_TYPE_METADATA', '2': 2},
    {'1': 'ACCESS_REQUEST_TYPE_SEARCH', '2': 3},
    {'1': 'ACCESS_REQUEST_TYPE_PREVIEW', '2': 4},
    {'1': 'ACCESS_REQUEST_TYPE_DOWNLOAD', '2': 5},
    {'1': 'ACCESS_REQUEST_TYPE_ARCHIVE_INSPECT', '2': 6},
  ],
};

/// Descriptor for `AccessRequestType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accessRequestTypeDescriptor = $convert.base64Decode(
    'ChFBY2Nlc3NSZXF1ZXN0VHlwZRIjCh9BQ0NFU1NfUkVRVUVTVF9UWVBFX1VOU1BFQ0lGSUVEEA'
    'ASHgoaQUNDRVNTX1JFUVVFU1RfVFlQRV9CUk9XU0UQARIgChxBQ0NFU1NfUkVRVUVTVF9UWVBF'
    'X01FVEFEQVRBEAISHgoaQUNDRVNTX1JFUVVFU1RfVFlQRV9TRUFSQ0gQAxIfChtBQ0NFU1NfUk'
    'VRVUVTVF9UWVBFX1BSRVZJRVcQBBIgChxBQ0NFU1NfUkVRVUVTVF9UWVBFX0RPV05MT0FEEAUS'
    'JwojQUNDRVNTX1JFUVVFU1RfVFlQRV9BUkNISVZFX0lOU1BFQ1QQBg==');

@$core.Deprecated('Use accessScopeDescriptor instead')
const AccessScope$json = {
  '1': 'AccessScope',
  '2': [
    {'1': 'ACCESS_SCOPE_UNSPECIFIED', '2': 0},
    {'1': 'ACCESS_SCOPE_READ_METADATA', '2': 1},
    {'1': 'ACCESS_SCOPE_BROWSE', '2': 2},
    {'1': 'ACCESS_SCOPE_SEARCH', '2': 3},
    {'1': 'ACCESS_SCOPE_PREVIEW', '2': 4},
    {'1': 'ACCESS_SCOPE_DOWNLOAD', '2': 5},
    {'1': 'ACCESS_SCOPE_FULL', '2': 6},
  ],
};

/// Descriptor for `AccessScope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accessScopeDescriptor = $convert.base64Decode(
    'CgtBY2Nlc3NTY29wZRIcChhBQ0NFU1NfU0NPUEVfVU5TUEVDSUZJRUQQABIeChpBQ0NFU1NfU0'
    'NPUEVfUkVBRF9NRVRBREFUQRABEhcKE0FDQ0VTU19TQ09QRV9CUk9XU0UQAhIXChNBQ0NFU1Nf'
    'U0NPUEVfU0VBUkNIEAMSGAoUQUNDRVNTX1NDT1BFX1BSRVZJRVcQBBIZChVBQ0NFU1NfU0NPUE'
    'VfRE9XTkxPQUQQBRIVChFBQ0NFU1NfU0NPUEVfRlVMTBAG');

@$core.Deprecated('Use remoteObjectReferenceDescriptor instead')
const RemoteObjectReference$json = {
  '1': 'RemoteObjectReference',
  '2': [
    {
      '1': 'object_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ObjectId',
      '10': 'objectId'
    },
    {'1': 'relative_path', '3': 2, '4': 1, '5': 9, '10': 'relativePath'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {
      '1': 'object_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.ObjectType',
      '10': 'objectType'
    },
    {'1': 'byte_size', '3': 5, '4': 1, '5': 3, '10': 'byteSize'},
    {'1': 'mime_type', '3': 6, '4': 1, '5': 9, '10': 'mimeType'},
    {
      '1': 'modified_time_utc_ms',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'modifiedTimeUtcMs'
    },
    {
      '1': 'content_hash_sha256',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'contentHashSha256'
    },
    {'1': 'is_symlink', '3': 9, '4': 1, '5': 8, '10': 'isSymlink'},
    {'1': 'is_executable', '3': 10, '4': 1, '5': 8, '10': 'isExecutable'},
    {'1': 'is_previewable', '3': 11, '4': 1, '5': 8, '10': 'isPreviewable'},
    {'1': 'is_hidden', '3': 12, '4': 1, '5': 8, '10': 'isHidden'},
    {
      '1': 'attributes',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.RemoteObjectReference.AttributesEntry',
      '10': 'attributes'
    },
  ],
  '3': [RemoteObjectReference_AttributesEntry$json],
};

@$core.Deprecated('Use remoteObjectReferenceDescriptor instead')
const RemoteObjectReference_AttributesEntry$json = {
  '1': 'AttributesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `RemoteObjectReference`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteObjectReferenceDescriptor = $convert.base64Decode(
    'ChVSZW1vdGVPYmplY3RSZWZlcmVuY2USMgoJb2JqZWN0X2lkGAEgASgLMhUucGVlcmxpbmsudj'
    'EuT2JqZWN0SWRSCG9iamVjdElkEiMKDXJlbGF0aXZlX3BhdGgYAiABKAlSDHJlbGF0aXZlUGF0'
    'aBIhCgxkaXNwbGF5X25hbWUYAyABKAlSC2Rpc3BsYXlOYW1lEjgKC29iamVjdF90eXBlGAQgAS'
    'gOMhcucGVlcmxpbmsudjEuT2JqZWN0VHlwZVIKb2JqZWN0VHlwZRIbCglieXRlX3NpemUYBSAB'
    'KANSCGJ5dGVTaXplEhsKCW1pbWVfdHlwZRgGIAEoCVIIbWltZVR5cGUSLwoUbW9kaWZpZWRfdG'
    'ltZV91dGNfbXMYByABKANSEW1vZGlmaWVkVGltZVV0Y01zEi4KE2NvbnRlbnRfaGFzaF9zaGEy'
    'NTYYCCABKAlSEWNvbnRlbnRIYXNoU2hhMjU2Eh0KCmlzX3N5bWxpbmsYCSABKAhSCWlzU3ltbG'
    'luaxIjCg1pc19leGVjdXRhYmxlGAogASgIUgxpc0V4ZWN1dGFibGUSJQoOaXNfcHJldmlld2Fi'
    'bGUYCyABKAhSDWlzUHJldmlld2FibGUSGwoJaXNfaGlkZGVuGAwgASgIUghpc0hpZGRlbhJSCg'
    'phdHRyaWJ1dGVzGA0gAygLMjIucGVlcmxpbmsudjEuUmVtb3RlT2JqZWN0UmVmZXJlbmNlLkF0'
    'dHJpYnV0ZXNFbnRyeVIKYXR0cmlidXRlcxo9Cg9BdHRyaWJ1dGVzRW50cnkSEAoDa2V5GAEgAS'
    'gJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use archiveEntryDescriptorDescriptor instead')
const ArchiveEntryDescriptor$json = {
  '1': 'ArchiveEntryDescriptor',
  '2': [
    {'1': 'entry_path', '3': 1, '4': 1, '5': 9, '10': 'entryPath'},
    {
      '1': 'uncompressed_size_bytes',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'uncompressedSizeBytes'
    },
    {
      '1': 'compressed_size_bytes',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'compressedSizeBytes'
    },
    {'1': 'is_directory', '3': 4, '4': 1, '5': 8, '10': 'isDirectory'},
    {
      '1': 'modified_time_utc_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'modifiedTimeUtcMs'
    },
    {'1': 'is_safe', '3': 6, '4': 1, '5': 8, '10': 'isSafe'},
    {'1': 'warning', '3': 7, '4': 1, '5': 9, '10': 'warning'},
  ],
};

/// Descriptor for `ArchiveEntryDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveEntryDescriptorDescriptor = $convert.base64Decode(
    'ChZBcmNoaXZlRW50cnlEZXNjcmlwdG9yEh0KCmVudHJ5X3BhdGgYASABKAlSCWVudHJ5UGF0aB'
    'I2Chd1bmNvbXByZXNzZWRfc2l6ZV9ieXRlcxgCIAEoA1IVdW5jb21wcmVzc2VkU2l6ZUJ5dGVz'
    'EjIKFWNvbXByZXNzZWRfc2l6ZV9ieXRlcxgDIAEoA1ITY29tcHJlc3NlZFNpemVCeXRlcxIhCg'
    'xpc19kaXJlY3RvcnkYBCABKAhSC2lzRGlyZWN0b3J5Ei8KFG1vZGlmaWVkX3RpbWVfdXRjX21z'
    'GAUgASgDUhFtb2RpZmllZFRpbWVVdGNNcxIXCgdpc19zYWZlGAYgASgIUgZpc1NhZmUSGAoHd2'
    'FybmluZxgHIAEoCVIHd2FybmluZw==');

@$core.Deprecated('Use accessRequestDescriptor instead')
const AccessRequest$json = {
  '1': 'AccessRequest',
  '2': [
    {
      '1': 'header',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolHeader',
      '10': 'header'
    },
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {
      '1': 'requester_peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'requesterPeerId'
    },
    {
      '1': 'target_peer_id',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'targetPeerId'
    },
    {
      '1': 'request_type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.AccessRequestType',
      '10': 'requestType'
    },
    {'1': 'share_id', '3': 6, '4': 1, '5': 9, '10': 'shareId'},
    {'1': 'relative_path', '3': 7, '4': 1, '5': 9, '10': 'relativePath'},
    {'1': 'search_query', '3': 8, '4': 1, '5': 9, '10': 'searchQuery'},
    {'1': 'max_results', '3': 9, '4': 1, '5': 5, '10': 'maxResults'},
    {'1': 'max_depth', '3': 10, '4': 1, '5': 5, '10': 'maxDepth'},
    {'1': 'timeout_ms', '3': 11, '4': 1, '5': 3, '10': 'timeoutMs'},
    {
      '1': 'pagination_cursor',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'paginationCursor'
    },
    {
      '1': 'authorization_token',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'authorizationToken'
    },
    {
      '1': 'preview_thumbnail_only',
      '3': 14,
      '4': 1,
      '5': 8,
      '10': 'previewThumbnailOnly'
    },
    {
      '1': 'preview_max_bytes',
      '3': 15,
      '4': 1,
      '5': 5,
      '10': 'previewMaxBytes'
    },
    {
      '1': 'client_timestamp_utc_ms',
      '3': 16,
      '4': 1,
      '5': 3,
      '10': 'clientTimestampUtcMs'
    },
  ],
};

/// Descriptor for `AccessRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessRequestDescriptor = $convert.base64Decode(
    'Cg1BY2Nlc3NSZXF1ZXN0EjMKBmhlYWRlchgBIAEoCzIbLnBlZXJsaW5rLnYxLlByb3RvY29sSG'
    'VhZGVyUgZoZWFkZXISHQoKcmVxdWVzdF9pZBgCIAEoCVIJcmVxdWVzdElkEj8KEXJlcXVlc3Rl'
    'cl9wZWVyX2lkGAMgASgLMhMucGVlcmxpbmsudjEuUGVlcklkUg9yZXF1ZXN0ZXJQZWVySWQSOQ'
    'oOdGFyZ2V0X3BlZXJfaWQYBCABKAsyEy5wZWVybGluay52MS5QZWVySWRSDHRhcmdldFBlZXJJ'
    'ZBJBCgxyZXF1ZXN0X3R5cGUYBSABKA4yHi5wZWVybGluay52MS5BY2Nlc3NSZXF1ZXN0VHlwZV'
    'ILcmVxdWVzdFR5cGUSGQoIc2hhcmVfaWQYBiABKAlSB3NoYXJlSWQSIwoNcmVsYXRpdmVfcGF0'
    'aBgHIAEoCVIMcmVsYXRpdmVQYXRoEiEKDHNlYXJjaF9xdWVyeRgIIAEoCVILc2VhcmNoUXVlcn'
    'kSHwoLbWF4X3Jlc3VsdHMYCSABKAVSCm1heFJlc3VsdHMSGwoJbWF4X2RlcHRoGAogASgFUght'
    'YXhEZXB0aBIdCgp0aW1lb3V0X21zGAsgASgDUgl0aW1lb3V0TXMSKwoRcGFnaW5hdGlvbl9jdX'
    'Jzb3IYDCABKAlSEHBhZ2luYXRpb25DdXJzb3ISLwoTYXV0aG9yaXphdGlvbl90b2tlbhgNIAEo'
    'CVISYXV0aG9yaXphdGlvblRva2VuEjQKFnByZXZpZXdfdGh1bWJuYWlsX29ubHkYDiABKAhSFH'
    'ByZXZpZXdUaHVtYm5haWxPbmx5EioKEXByZXZpZXdfbWF4X2J5dGVzGA8gASgFUg9wcmV2aWV3'
    'TWF4Qnl0ZXMSNQoXY2xpZW50X3RpbWVzdGFtcF91dGNfbXMYECABKANSFGNsaWVudFRpbWVzdG'
    'FtcFV0Y01z');

@$core.Deprecated('Use accessResponseDescriptor instead')
const AccessResponse$json = {
  '1': 'AccessResponse',
  '2': [
    {
      '1': 'header',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ProtocolHeader',
      '10': 'header'
    },
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'success', '3': 3, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'items',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.RemoteObjectReference',
      '10': 'items'
    },
    {
      '1': 'next_pagination_cursor',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'nextPaginationCursor'
    },
    {'1': 'has_more', '3': 6, '4': 1, '5': 8, '10': 'hasMore'},
    {'1': 'total_matching', '3': 7, '4': 1, '5': 5, '10': 'totalMatching'},
    {'1': 'preview_data', '3': 8, '4': 1, '5': 12, '10': 'previewData'},
    {'1': 'preview_mime_type', '3': 9, '4': 1, '5': 9, '10': 'previewMimeType'},
    {
      '1': 'archive_entries',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.ArchiveEntryDescriptor',
      '10': 'archiveEntries'
    },
    {
      '1': 'error',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ErrorDetail',
      '10': 'error'
    },
    {
      '1': 'execution_time_ms',
      '3': 12,
      '4': 1,
      '5': 3,
      '10': 'executionTimeMs'
    },
  ],
};

/// Descriptor for `AccessResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessResponseDescriptor = $convert.base64Decode(
    'Cg5BY2Nlc3NSZXNwb25zZRIzCgZoZWFkZXIYASABKAsyGy5wZWVybGluay52MS5Qcm90b2NvbE'
    'hlYWRlclIGaGVhZGVyEh0KCnJlcXVlc3RfaWQYAiABKAlSCXJlcXVlc3RJZBIYCgdzdWNjZXNz'
    'GAMgASgIUgdzdWNjZXNzEjgKBWl0ZW1zGAQgAygLMiIucGVlcmxpbmsudjEuUmVtb3RlT2JqZW'
    'N0UmVmZXJlbmNlUgVpdGVtcxI0ChZuZXh0X3BhZ2luYXRpb25fY3Vyc29yGAUgASgJUhRuZXh0'
    'UGFnaW5hdGlvbkN1cnNvchIZCghoYXNfbW9yZRgGIAEoCFIHaGFzTW9yZRIlCg50b3RhbF9tYX'
    'RjaGluZxgHIAEoBVINdG90YWxNYXRjaGluZxIhCgxwcmV2aWV3X2RhdGEYCCABKAxSC3ByZXZp'
    'ZXdEYXRhEioKEXByZXZpZXdfbWltZV90eXBlGAkgASgJUg9wcmV2aWV3TWltZVR5cGUSTAoPYX'
    'JjaGl2ZV9lbnRyaWVzGAogAygLMiMucGVlcmxpbmsudjEuQXJjaGl2ZUVudHJ5RGVzY3JpcHRv'
    'clIOYXJjaGl2ZUVudHJpZXMSLgoFZXJyb3IYCyABKAsyGC5wZWVybGluay52MS5FcnJvckRldG'
    'FpbFIFZXJyb3ISKgoRZXhlY3V0aW9uX3RpbWVfbXMYDCABKANSD2V4ZWN1dGlvblRpbWVNcw==');

@$core.Deprecated('Use accessCancelRequestDescriptor instead')
const AccessCancelRequest$json = {
  '1': 'AccessCancelRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {
      '1': 'requester_peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'requesterPeerId'
    },
  ],
};

/// Descriptor for `AccessCancelRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessCancelRequestDescriptor = $convert.base64Decode(
    'ChNBY2Nlc3NDYW5jZWxSZXF1ZXN0Eh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZBIWCg'
    'ZyZWFzb24YAiABKAlSBnJlYXNvbhI/ChFyZXF1ZXN0ZXJfcGVlcl9pZBgDIAEoCzITLnBlZXJs'
    'aW5rLnYxLlBlZXJJZFIPcmVxdWVzdGVyUGVlcklk');

@$core.Deprecated('Use accessCancelResponseDescriptor instead')
const AccessCancelResponse$json = {
  '1': 'AccessCancelResponse',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'cancelled', '3': 2, '4': 1, '5': 8, '10': 'cancelled'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `AccessCancelResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessCancelResponseDescriptor = $convert.base64Decode(
    'ChRBY2Nlc3NDYW5jZWxSZXNwb25zZRIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZXN0SWQSHA'
    'oJY2FuY2VsbGVkGAIgASgIUgljYW5jZWxsZWQSGAoHbWVzc2FnZRgDIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use accessWireMessageDescriptor instead')
const AccessWireMessage$json = {
  '1': 'AccessWireMessage',
  '2': [
    {
      '1': 'request',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.AccessRequest',
      '9': 0,
      '10': 'request'
    },
    {
      '1': 'response',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.AccessResponse',
      '9': 0,
      '10': 'response'
    },
    {
      '1': 'cancel_request',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.AccessCancelRequest',
      '9': 0,
      '10': 'cancelRequest'
    },
    {
      '1': 'cancel_response',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.AccessCancelResponse',
      '9': 0,
      '10': 'cancelResponse'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `AccessWireMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accessWireMessageDescriptor = $convert.base64Decode(
    'ChFBY2Nlc3NXaXJlTWVzc2FnZRI2CgdyZXF1ZXN0GAEgASgLMhoucGVlcmxpbmsudjEuQWNjZX'
    'NzUmVxdWVzdEgAUgdyZXF1ZXN0EjkKCHJlc3BvbnNlGAIgASgLMhsucGVlcmxpbmsudjEuQWNj'
    'ZXNzUmVzcG9uc2VIAFIIcmVzcG9uc2USSQoOY2FuY2VsX3JlcXVlc3QYAyABKAsyIC5wZWVybG'
    'luay52MS5BY2Nlc3NDYW5jZWxSZXF1ZXN0SABSDWNhbmNlbFJlcXVlc3QSTAoPY2FuY2VsX3Jl'
    'c3BvbnNlGAQgASgLMiEucGVlcmxpbmsudjEuQWNjZXNzQ2FuY2VsUmVzcG9uc2VIAFIOY2FuY2'
    'VsUmVzcG9uc2VCCQoHcGF5bG9hZA==');
