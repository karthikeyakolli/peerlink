// This is a generated file - do not edit.
//
// Generated from peerlink/v1/object_reference.proto.

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

@$core.Deprecated('Use objectTypeDescriptor instead')
const ObjectType$json = {
  '1': 'ObjectType',
  '2': [
    {'1': 'OBJECT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'OBJECT_TYPE_FILE', '2': 1},
    {'1': 'OBJECT_TYPE_DIRECTORY', '2': 2},
    {'1': 'OBJECT_TYPE_COLLECTION', '2': 3},
    {'1': 'OBJECT_TYPE_TOMBSTONE', '2': 4},
  ],
};

/// Descriptor for `ObjectType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List objectTypeDescriptor = $convert.base64Decode(
    'CgpPYmplY3RUeXBlEhsKF09CSkVDVF9UWVBFX1VOU1BFQ0lGSUVEEAASFAoQT0JKRUNUX1RZUE'
    'VfRklMRRABEhkKFU9CSkVDVF9UWVBFX0RJUkVDVE9SWRACEhoKFk9CSkVDVF9UWVBFX0NPTExF'
    'Q1RJT04QAxIZChVPQkpFQ1RfVFlQRV9UT01CU1RPTkUQBA==');

@$core.Deprecated('Use objectReferenceDescriptor instead')
const ObjectReference$json = {
  '1': 'ObjectReference',
  '2': [
    {
      '1': 'object_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ObjectId',
      '10': 'objectId'
    },
    {
      '1': 'content_hash',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.ContentHash',
      '10': 'contentHash'
    },
    {
      '1': 'version_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.VersionId',
      '10': 'versionId'
    },
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
    {'1': 'logical_name', '3': 7, '4': 1, '5': 9, '10': 'logicalName'},
    {
      '1': 'causal_clock',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CausalClock',
      '10': 'causalClock'
    },
    {
      '1': 'client_modified_hint_utc_ms',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'clientModifiedHintUtcMs'
    },
    {'1': 'is_tombstone', '3': 10, '4': 1, '5': 8, '10': 'isTombstone'},
    {
      '1': 'metadata',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.ObjectReference.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [ObjectReference_MetadataEntry$json],
};

@$core.Deprecated('Use objectReferenceDescriptor instead')
const ObjectReference_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ObjectReference`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List objectReferenceDescriptor = $convert.base64Decode(
    'Cg9PYmplY3RSZWZlcmVuY2USMgoJb2JqZWN0X2lkGAEgASgLMhUucGVlcmxpbmsudjEuT2JqZW'
    'N0SWRSCG9iamVjdElkEjsKDGNvbnRlbnRfaGFzaBgCIAEoCzIYLnBlZXJsaW5rLnYxLkNvbnRl'
    'bnRIYXNoUgtjb250ZW50SGFzaBI1Cgp2ZXJzaW9uX2lkGAMgASgLMhYucGVlcmxpbmsudjEuVm'
    'Vyc2lvbklkUgl2ZXJzaW9uSWQSOAoLb2JqZWN0X3R5cGUYBCABKA4yFy5wZWVybGluay52MS5P'
    'YmplY3RUeXBlUgpvYmplY3RUeXBlEhsKCWJ5dGVfc2l6ZRgFIAEoA1IIYnl0ZVNpemUSGwoJbW'
    'ltZV90eXBlGAYgASgJUghtaW1lVHlwZRIhCgxsb2dpY2FsX25hbWUYByABKAlSC2xvZ2ljYWxO'
    'YW1lEjsKDGNhdXNhbF9jbG9jaxgIIAEoCzIYLnBlZXJsaW5rLnYxLkNhdXNhbENsb2NrUgtjYX'
    'VzYWxDbG9jaxI8ChtjbGllbnRfbW9kaWZpZWRfaGludF91dGNfbXMYCSABKANSF2NsaWVudE1v'
    'ZGlmaWVkSGludFV0Y01zEiEKDGlzX3RvbWJzdG9uZRgKIAEoCFILaXNUb21ic3RvbmUSRgoIbW'
    'V0YWRhdGEYCyADKAsyKi5wZWVybGluay52MS5PYmplY3RSZWZlcmVuY2UuTWV0YWRhdGFFbnRy'
    'eVIIbWV0YWRhdGEaOwoNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZR'
    'gCIAEoCVIFdmFsdWU6AjgB');
