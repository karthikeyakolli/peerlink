// This is a generated file - do not edit.
//
// Generated from peerlink/v1/transfer.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class TransferState extends $pb.ProtobufEnum {
  static const TransferState TRANSFER_STATE_UNSPECIFIED =
      TransferState._(0, _omitEnumNames ? '' : 'TRANSFER_STATE_UNSPECIFIED');
  static const TransferState TRANSFER_STATE_PREPARING =
      TransferState._(1, _omitEnumNames ? '' : 'TRANSFER_STATE_PREPARING');
  static const TransferState TRANSFER_STATE_CONNECTING =
      TransferState._(2, _omitEnumNames ? '' : 'TRANSFER_STATE_CONNECTING');
  static const TransferState TRANSFER_STATE_TRANSFERRING =
      TransferState._(3, _omitEnumNames ? '' : 'TRANSFER_STATE_TRANSFERRING');
  static const TransferState TRANSFER_STATE_RECEIVED =
      TransferState._(4, _omitEnumNames ? '' : 'TRANSFER_STATE_RECEIVED');
  static const TransferState TRANSFER_STATE_VERIFYING =
      TransferState._(5, _omitEnumNames ? '' : 'TRANSFER_STATE_VERIFYING');
  static const TransferState TRANSFER_STATE_COMMITTING =
      TransferState._(6, _omitEnumNames ? '' : 'TRANSFER_STATE_COMMITTING');
  static const TransferState TRANSFER_STATE_COMPLETED =
      TransferState._(7, _omitEnumNames ? '' : 'TRANSFER_STATE_COMPLETED');
  static const TransferState TRANSFER_STATE_FAILED =
      TransferState._(8, _omitEnumNames ? '' : 'TRANSFER_STATE_FAILED');
  static const TransferState TRANSFER_STATE_CANCELLED =
      TransferState._(9, _omitEnumNames ? '' : 'TRANSFER_STATE_CANCELLED');
  static const TransferState TRANSFER_STATE_OUTCOME_UNKNOWN = TransferState._(
      10, _omitEnumNames ? '' : 'TRANSFER_STATE_OUTCOME_UNKNOWN');
  static const TransferState TRANSFER_STATE_PAUSED =
      TransferState._(11, _omitEnumNames ? '' : 'TRANSFER_STATE_PAUSED');

  static const $core.List<TransferState> values = <TransferState>[
    TRANSFER_STATE_UNSPECIFIED,
    TRANSFER_STATE_PREPARING,
    TRANSFER_STATE_CONNECTING,
    TRANSFER_STATE_TRANSFERRING,
    TRANSFER_STATE_RECEIVED,
    TRANSFER_STATE_VERIFYING,
    TRANSFER_STATE_COMMITTING,
    TRANSFER_STATE_COMPLETED,
    TRANSFER_STATE_FAILED,
    TRANSFER_STATE_CANCELLED,
    TRANSFER_STATE_OUTCOME_UNKNOWN,
    TRANSFER_STATE_PAUSED,
  ];

  static final $core.List<TransferState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
  static TransferState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TransferState._(super.value, super.name);
}

class ChunkStatus extends $pb.ProtobufEnum {
  static const ChunkStatus CHUNK_STATUS_UNSPECIFIED =
      ChunkStatus._(0, _omitEnumNames ? '' : 'CHUNK_STATUS_UNSPECIFIED');
  static const ChunkStatus CHUNK_STATUS_PENDING =
      ChunkStatus._(1, _omitEnumNames ? '' : 'CHUNK_STATUS_PENDING');
  static const ChunkStatus CHUNK_STATUS_IN_FLIGHT =
      ChunkStatus._(2, _omitEnumNames ? '' : 'CHUNK_STATUS_IN_FLIGHT');
  static const ChunkStatus CHUNK_STATUS_ACKED =
      ChunkStatus._(3, _omitEnumNames ? '' : 'CHUNK_STATUS_ACKED');
  static const ChunkStatus CHUNK_STATUS_FAILED =
      ChunkStatus._(4, _omitEnumNames ? '' : 'CHUNK_STATUS_FAILED');

  static const $core.List<ChunkStatus> values = <ChunkStatus>[
    CHUNK_STATUS_UNSPECIFIED,
    CHUNK_STATUS_PENDING,
    CHUNK_STATUS_IN_FLIGHT,
    CHUNK_STATUS_ACKED,
    CHUNK_STATUS_FAILED,
  ];

  static final $core.List<ChunkStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ChunkStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChunkStatus._(super.value, super.name);
}

class DuplicateDestinationPolicy extends $pb.ProtobufEnum {
  static const DuplicateDestinationPolicy
      DUPLICATE_DESTINATION_POLICY_UNSPECIFIED = DuplicateDestinationPolicy._(
          0, _omitEnumNames ? '' : 'DUPLICATE_DESTINATION_POLICY_UNSPECIFIED');
  static const DuplicateDestinationPolicy
      DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS =
      DuplicateDestinationPolicy._(1,
          _omitEnumNames ? '' : 'DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS');
  static const DuplicateDestinationPolicy
      DUPLICATE_DESTINATION_POLICY_OVERWRITE = DuplicateDestinationPolicy._(
          2, _omitEnumNames ? '' : 'DUPLICATE_DESTINATION_POLICY_OVERWRITE');
  static const DuplicateDestinationPolicy
      DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX =
      DuplicateDestinationPolicy._(
          3,
          _omitEnumNames
              ? ''
              : 'DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX');

  static const $core.List<DuplicateDestinationPolicy> values =
      <DuplicateDestinationPolicy>[
    DUPLICATE_DESTINATION_POLICY_UNSPECIFIED,
    DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
    DUPLICATE_DESTINATION_POLICY_OVERWRITE,
    DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX,
  ];

  static final $core.List<DuplicateDestinationPolicy?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static DuplicateDestinationPolicy? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DuplicateDestinationPolicy._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
