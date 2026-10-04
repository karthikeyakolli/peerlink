// This is a generated file - do not edit.
//
// Generated from peerlink/v1/identity.proto.

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

@$core.Deprecated('Use deviceTypeDescriptor instead')
const DeviceType$json = {
  '1': 'DeviceType',
  '2': [
    {'1': 'DEVICE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'DEVICE_TYPE_DESKTOP_WINDOWS', '2': 1},
    {'1': 'DEVICE_TYPE_DESKTOP_MACOS', '2': 2},
    {'1': 'DEVICE_TYPE_DESKTOP_LINUX', '2': 3},
    {'1': 'DEVICE_TYPE_MOBILE_ANDROID', '2': 4},
    {'1': 'DEVICE_TYPE_MOBILE_IOS', '2': 5},
    {'1': 'DEVICE_TYPE_HEADLESS_SERVER', '2': 6},
  ],
};

/// Descriptor for `DeviceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deviceTypeDescriptor = $convert.base64Decode(
    'CgpEZXZpY2VUeXBlEhsKF0RFVklDRV9UWVBFX1VOU1BFQ0lGSUVEEAASHwobREVWSUNFX1RZUE'
    'VfREVTS1RPUF9XSU5ET1dTEAESHQoZREVWSUNFX1RZUEVfREVTS1RPUF9NQUNPUxACEh0KGURF'
    'VklDRV9UWVBFX0RFU0tUT1BfTElOVVgQAxIeChpERVZJQ0VfVFlQRV9NT0JJTEVfQU5EUk9JRB'
    'AEEhoKFkRFVklDRV9UWVBFX01PQklMRV9JT1MQBRIfChtERVZJQ0VfVFlQRV9IRUFETEVTU19T'
    'RVJWRVIQBg==');

@$core.Deprecated('Use keyTypeDescriptor instead')
const KeyType$json = {
  '1': 'KeyType',
  '2': [
    {'1': 'KEY_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'KEY_TYPE_ED25519', '2': 1},
    {'1': 'KEY_TYPE_X25519', '2': 2},
  ],
};

/// Descriptor for `KeyType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List keyTypeDescriptor = $convert.base64Decode(
    'CgdLZXlUeXBlEhgKFEtFWV9UWVBFX1VOU1BFQ0lGSUVEEAASFAoQS0VZX1RZUEVfRUQyNTUxOR'
    'ABEhMKD0tFWV9UWVBFX1gyNTUxORAC');

@$core.Deprecated('Use trustLevelDescriptor instead')
const TrustLevel$json = {
  '1': 'TrustLevel',
  '2': [
    {'1': 'TRUST_LEVEL_UNSPECIFIED', '2': 0},
    {'1': 'TRUST_LEVEL_UNTRUSTED', '2': 1},
    {'1': 'TRUST_LEVEL_PAIRING_PENDING', '2': 2},
    {'1': 'TRUST_LEVEL_TRUSTED_PAIRED', '2': 3},
    {'1': 'TRUST_LEVEL_REVOKED', '2': 4},
    {'1': 'TRUST_LEVEL_BLOCKED', '2': 5},
  ],
};

/// Descriptor for `TrustLevel`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List trustLevelDescriptor = $convert.base64Decode(
    'CgpUcnVzdExldmVsEhsKF1RSVVNUX0xFVkVMX1VOU1BFQ0lGSUVEEAASGQoVVFJVU1RfTEVWRU'
    'xfVU5UUlVTVEVEEAESHwobVFJVU1RfTEVWRUxfUEFJUklOR19QRU5ESU5HEAISHgoaVFJVU1Rf'
    'TEVWRUxfVFJVU1RFRF9QQUlSRUQQAxIXChNUUlVTVF9MRVZFTF9SRVZPS0VEEAQSFwoTVFJVU1'
    'RfTEVWRUxfQkxPQ0tFRBAF');

@$core.Deprecated('Use cryptographicKeyDescriptor instead')
const CryptographicKey$json = {
  '1': 'CryptographicKey',
  '2': [
    {
      '1': 'key_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.KeyType',
      '10': 'keyType'
    },
    {'1': 'public_key_bytes', '3': 2, '4': 1, '5': 12, '10': 'publicKeyBytes'},
    {'1': 'key_id', '3': 3, '4': 1, '5': 9, '10': 'keyId'},
    {'1': 'created_at_utc_ms', '3': 4, '4': 1, '5': 3, '10': 'createdAtUtcMs'},
  ],
};

/// Descriptor for `CryptographicKey`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cryptographicKeyDescriptor = $convert.base64Decode(
    'ChBDcnlwdG9ncmFwaGljS2V5Ei8KCGtleV90eXBlGAEgASgOMhQucGVlcmxpbmsudjEuS2V5VH'
    'lwZVIHa2V5VHlwZRIoChBwdWJsaWNfa2V5X2J5dGVzGAIgASgMUg5wdWJsaWNLZXlCeXRlcxIV'
    'CgZrZXlfaWQYAyABKAlSBWtleUlkEikKEWNyZWF0ZWRfYXRfdXRjX21zGAQgASgDUg5jcmVhdG'
    'VkQXRVdGNNcw==');

@$core.Deprecated('Use accountBindingDescriptor instead')
const AccountBinding$json = {
  '1': 'AccountBinding',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'account_email', '3': 2, '4': 1, '5': 9, '10': 'accountEmail'},
    {'1': 'bound_at_utc_ms', '3': 3, '4': 1, '5': 3, '10': 'boundAtUtcMs'},
    {
      '1': 'ownership_proof_signature',
      '3': 4,
      '4': 1,
      '5': 12,
      '10': 'ownershipProofSignature'
    },
  ],
};

/// Descriptor for `AccountBinding`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountBindingDescriptor = $convert.base64Decode(
    'Cg5BY2NvdW50QmluZGluZxIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SWQSIwoNYWNjb3'
    'VudF9lbWFpbBgCIAEoCVIMYWNjb3VudEVtYWlsEiUKD2JvdW5kX2F0X3V0Y19tcxgDIAEoA1IM'
    'Ym91bmRBdFV0Y01zEjoKGW93bmVyc2hpcF9wcm9vZl9zaWduYXR1cmUYBCABKAxSF293bmVyc2'
    'hpcFByb29mU2lnbmF0dXJl');

@$core.Deprecated('Use deviceIdentityDescriptor instead')
const DeviceIdentity$json = {
  '1': 'DeviceIdentity',
  '2': [
    {
      '1': 'device_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceId',
      '10': 'deviceId'
    },
    {'1': 'device_name', '3': 2, '4': 1, '5': 9, '10': 'deviceName'},
    {
      '1': 'device_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.DeviceType',
      '10': 'deviceType'
    },
    {'1': 'os_version', '3': 4, '4': 1, '5': 9, '10': 'osVersion'},
    {'1': 'app_version', '3': 5, '4': 1, '5': 9, '10': 'appVersion'},
    {
      '1': 'identity_key',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CryptographicKey',
      '10': 'identityKey'
    },
    {
      '1': 'account_binding',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.AccountBinding',
      '10': 'accountBinding'
    },
    {
      '1': 'ownership_metadata',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.DeviceIdentity.OwnershipMetadataEntry',
      '10': 'ownershipMetadata'
    },
  ],
  '3': [DeviceIdentity_OwnershipMetadataEntry$json],
};

@$core.Deprecated('Use deviceIdentityDescriptor instead')
const DeviceIdentity_OwnershipMetadataEntry$json = {
  '1': 'OwnershipMetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DeviceIdentity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceIdentityDescriptor = $convert.base64Decode(
    'Cg5EZXZpY2VJZGVudGl0eRIyCglkZXZpY2VfaWQYASABKAsyFS5wZWVybGluay52MS5EZXZpY2'
    'VJZFIIZGV2aWNlSWQSHwoLZGV2aWNlX25hbWUYAiABKAlSCmRldmljZU5hbWUSOAoLZGV2aWNl'
    'X3R5cGUYAyABKA4yFy5wZWVybGluay52MS5EZXZpY2VUeXBlUgpkZXZpY2VUeXBlEh0KCm9zX3'
    'ZlcnNpb24YBCABKAlSCW9zVmVyc2lvbhIfCgthcHBfdmVyc2lvbhgFIAEoCVIKYXBwVmVyc2lv'
    'bhJACgxpZGVudGl0eV9rZXkYBiABKAsyHS5wZWVybGluay52MS5DcnlwdG9ncmFwaGljS2V5Ug'
    'tpZGVudGl0eUtleRJECg9hY2NvdW50X2JpbmRpbmcYByABKAsyGy5wZWVybGluay52MS5BY2Nv'
    'dW50QmluZGluZ1IOYWNjb3VudEJpbmRpbmcSYQoSb3duZXJzaGlwX21ldGFkYXRhGAggAygLMj'
    'IucGVlcmxpbmsudjEuRGV2aWNlSWRlbnRpdHkuT3duZXJzaGlwTWV0YWRhdGFFbnRyeVIRb3du'
    'ZXJzaGlwTWV0YWRhdGEaRAoWT3duZXJzaGlwTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2'
    'tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use peerIdentityDescriptor instead')
const PeerIdentity$json = {
  '1': 'PeerIdentity',
  '2': [
    {
      '1': 'peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'peerId'
    },
    {
      '1': 'device_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceId',
      '10': 'deviceId'
    },
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {
      '1': 'identity_key',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.CryptographicKey',
      '10': 'identityKey'
    },
    {'1': 'fingerprint_hex', '3': 5, '4': 1, '5': 9, '10': 'fingerprintHex'},
    {
      '1': 'trust_level',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.peerlink.v1.TrustLevel',
      '10': 'trustLevel'
    },
    {'1': 'paired_at_utc_ms', '3': 7, '4': 1, '5': 3, '10': 'pairedAtUtcMs'},
    {
      '1': 'account_binding',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.AccountBinding',
      '10': 'accountBinding'
    },
    {
      '1': 'metadata',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [PeerIdentity_MetadataEntry$json],
};

@$core.Deprecated('Use peerIdentityDescriptor instead')
const PeerIdentity_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `PeerIdentity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List peerIdentityDescriptor = $convert.base64Decode(
    'CgxQZWVySWRlbnRpdHkSLAoHcGVlcl9pZBgBIAEoCzITLnBlZXJsaW5rLnYxLlBlZXJJZFIGcG'
    'VlcklkEjIKCWRldmljZV9pZBgCIAEoCzIVLnBlZXJsaW5rLnYxLkRldmljZUlkUghkZXZpY2VJ'
    'ZBIhCgxkaXNwbGF5X25hbWUYAyABKAlSC2Rpc3BsYXlOYW1lEkAKDGlkZW50aXR5X2tleRgEIA'
    'EoCzIdLnBlZXJsaW5rLnYxLkNyeXB0b2dyYXBoaWNLZXlSC2lkZW50aXR5S2V5EicKD2Zpbmdl'
    'cnByaW50X2hleBgFIAEoCVIOZmluZ2VycHJpbnRIZXgSOAoLdHJ1c3RfbGV2ZWwYBiABKA4yFy'
    '5wZWVybGluay52MS5UcnVzdExldmVsUgp0cnVzdExldmVsEicKEHBhaXJlZF9hdF91dGNfbXMY'
    'ByABKANSDXBhaXJlZEF0VXRjTXMSRAoPYWNjb3VudF9iaW5kaW5nGAggASgLMhsucGVlcmxpbm'
    'sudjEuQWNjb3VudEJpbmRpbmdSDmFjY291bnRCaW5kaW5nEkMKCG1ldGFkYXRhGAkgAygLMicu'
    'cGVlcmxpbmsudjEuUGVlcklkZW50aXR5Lk1ldGFkYXRhRW50cnlSCG1ldGFkYXRhGjsKDU1ldG'
    'FkYXRhRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use revocationRecordDescriptor instead')
const RevocationRecord$json = {
  '1': 'RevocationRecord',
  '2': [
    {
      '1': 'revoked_peer_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'revokedPeerId'
    },
    {
      '1': 'revoked_by_peer_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'revokedByPeerId'
    },
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'revoked_at_utc_ms', '3': 4, '4': 1, '5': 3, '10': 'revokedAtUtcMs'},
    {
      '1': 'revocation_signature',
      '3': 5,
      '4': 1,
      '5': 12,
      '10': 'revocationSignature'
    },
  ],
};

/// Descriptor for `RevocationRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revocationRecordDescriptor = $convert.base64Decode(
    'ChBSZXZvY2F0aW9uUmVjb3JkEjsKD3Jldm9rZWRfcGVlcl9pZBgBIAEoCzITLnBlZXJsaW5rLn'
    'YxLlBlZXJJZFINcmV2b2tlZFBlZXJJZBJAChJyZXZva2VkX2J5X3BlZXJfaWQYAiABKAsyEy5w'
    'ZWVybGluay52MS5QZWVySWRSD3Jldm9rZWRCeVBlZXJJZBIWCgZyZWFzb24YAyABKAlSBnJlYX'
    'NvbhIpChFyZXZva2VkX2F0X3V0Y19tcxgEIAEoA1IOcmV2b2tlZEF0VXRjTXMSMQoUcmV2b2Nh'
    'dGlvbl9zaWduYXR1cmUYBSABKAxSE3Jldm9jYXRpb25TaWduYXR1cmU=');

@$core.Deprecated('Use deviceReplacementRecordDescriptor instead')
const DeviceReplacementRecord$json = {
  '1': 'DeviceReplacementRecord',
  '2': [
    {
      '1': 'old_device_id',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceId',
      '10': 'oldDeviceId'
    },
    {
      '1': 'new_device_id',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.DeviceId',
      '10': 'newDeviceId'
    },
    {
      '1': 'peer_id',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.peerlink.v1.PeerId',
      '10': 'peerId'
    },
    {
      '1': 'replacement_token',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'replacementToken'
    },
    {
      '1': 'replaced_at_utc_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'replacedAtUtcMs'
    },
    {
      '1': 'authorization_signature',
      '3': 6,
      '4': 1,
      '5': 12,
      '10': 'authorizationSignature'
    },
  ],
};

/// Descriptor for `DeviceReplacementRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceReplacementRecordDescriptor = $convert.base64Decode(
    'ChdEZXZpY2VSZXBsYWNlbWVudFJlY29yZBI5Cg1vbGRfZGV2aWNlX2lkGAEgASgLMhUucGVlcm'
    'xpbmsudjEuRGV2aWNlSWRSC29sZERldmljZUlkEjkKDW5ld19kZXZpY2VfaWQYAiABKAsyFS5w'
    'ZWVybGluay52MS5EZXZpY2VJZFILbmV3RGV2aWNlSWQSLAoHcGVlcl9pZBgDIAEoCzITLnBlZX'
    'JsaW5rLnYxLlBlZXJJZFIGcGVlcklkEisKEXJlcGxhY2VtZW50X3Rva2VuGAQgASgJUhByZXBs'
    'YWNlbWVudFRva2VuEisKEnJlcGxhY2VkX2F0X3V0Y19tcxgFIAEoA1IPcmVwbGFjZWRBdFV0Y0'
    '1zEjcKF2F1dGhvcml6YXRpb25fc2lnbmF0dXJlGAYgASgMUhZhdXRob3JpemF0aW9uU2lnbmF0'
    'dXJl');

@$core.Deprecated('Use trustStoreSnapshotDescriptor instead')
const TrustStoreSnapshot$json = {
  '1': 'TrustStoreSnapshot',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 5, '10': 'version'},
    {
      '1': 'snapshot_timestamp_utc_ms',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'snapshotTimestampUtcMs'
    },
    {
      '1': 'trusted_peers',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.PeerIdentity',
      '10': 'trustedPeers'
    },
    {
      '1': 'revocations',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.peerlink.v1.RevocationRecord',
      '10': 'revocations'
    },
    {
      '1': 'integrity_signature',
      '3': 5,
      '4': 1,
      '5': 12,
      '10': 'integritySignature'
    },
  ],
};

/// Descriptor for `TrustStoreSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trustStoreSnapshotDescriptor = $convert.base64Decode(
    'ChJUcnVzdFN0b3JlU25hcHNob3QSGAoHdmVyc2lvbhgBIAEoBVIHdmVyc2lvbhI5ChlzbmFwc2'
    'hvdF90aW1lc3RhbXBfdXRjX21zGAIgASgDUhZzbmFwc2hvdFRpbWVzdGFtcFV0Y01zEj4KDXRy'
    'dXN0ZWRfcGVlcnMYAyADKAsyGS5wZWVybGluay52MS5QZWVySWRlbnRpdHlSDHRydXN0ZWRQZW'
    'VycxI/CgtyZXZvY2F0aW9ucxgEIAMoCzIdLnBlZXJsaW5rLnYxLlJldm9jYXRpb25SZWNvcmRS'
    'C3Jldm9jYXRpb25zEi8KE2ludGVncml0eV9zaWduYXR1cmUYBSABKAxSEmludGVncml0eVNpZ2'
    '5hdHVyZQ==');
