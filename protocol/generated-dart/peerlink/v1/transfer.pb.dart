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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $0;
import 'error.pb.dart' as $1;
import 'transfer.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'transfer.pbenum.dart';

class TransferItem extends $pb.GeneratedMessage {
  factory TransferItem({
    $core.String? relativePath,
    $fixnum.Int64? fileSizeBytes,
    $core.String? sha256Hex,
    $core.bool? isDirectory,
    $fixnum.Int64? modifiedTimeUtcMs,
  }) {
    final result = TransferItem._();
    if (relativePath != null) result.relativePath = relativePath;
    if (fileSizeBytes != null) result.fileSizeBytes = fileSizeBytes;
    if (sha256Hex != null) result.sha256Hex = sha256Hex;
    if (isDirectory != null) result.isDirectory = isDirectory;
    if (modifiedTimeUtcMs != null) result.modifiedTimeUtcMs = modifiedTimeUtcMs;
    return result;
  }

  TransferItem._();

  factory TransferItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferItem()..mergeFromBuffer(data, registry);
  factory TransferItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'relativePath')
    ..aInt64(2, _omitFieldNames ? '' : 'fileSizeBytes')
    ..aOS(3, _omitFieldNames ? '' : 'sha256Hex')
    ..aOB(4, _omitFieldNames ? '' : 'isDirectory')
    ..aInt64(5, _omitFieldNames ? '' : 'modifiedTimeUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferItem copyWith(void Function(TransferItem) updates) =>
      super.copyWith((message) => updates(message as TransferItem))
          as TransferItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferItem() / TransferItem.new instead')
  static TransferItem create() => TransferItem._();
  static $pb.GeneratedMessage $_createMessage() => TransferItem._();
  @$core.override
  TransferItem createEmptyInstance() => TransferItem._();
  @$core.pragma('dart2js:noInline')
  static TransferItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferItem>(
          TransferItem.$_createMessage);
  static TransferItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get relativePath => $_getSZ(0);
  @$pb.TagNumber(1)
  set relativePath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelativePath() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelativePath() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get fileSizeBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set fileSizeBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileSizeBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileSizeBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sha256Hex => $_getSZ(2);
  @$pb.TagNumber(3)
  set sha256Hex($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSha256Hex() => $_has(2);
  @$pb.TagNumber(3)
  void clearSha256Hex() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isDirectory => $_getBF(3);
  @$pb.TagNumber(4)
  set isDirectory($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsDirectory() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsDirectory() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get modifiedTimeUtcMs => $_getI64(4);
  @$pb.TagNumber(5)
  set modifiedTimeUtcMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasModifiedTimeUtcMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearModifiedTimeUtcMs() => $_clearField(5);
}

class TransferManifest extends $pb.GeneratedMessage {
  factory TransferManifest({
    $core.String? transferId,
    $0.OperationId? operationId,
    $core.Iterable<TransferItem>? items,
    $fixnum.Int64? totalBytes,
    $core.int? chunkSizeBytes,
    $0.PeerId? senderPeerId,
    $0.PeerId? receiverPeerId,
    $core.String? displayName,
    DuplicateDestinationPolicy? duplicatePolicy,
    $core.String? targetDirectory,
  }) {
    final result = TransferManifest._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (items != null) result.items.addAll(items);
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (chunkSizeBytes != null) result.chunkSizeBytes = chunkSizeBytes;
    if (senderPeerId != null) result.senderPeerId = senderPeerId;
    if (receiverPeerId != null) result.receiverPeerId = receiverPeerId;
    if (displayName != null) result.displayName = displayName;
    if (duplicatePolicy != null) result.duplicatePolicy = duplicatePolicy;
    if (targetDirectory != null) result.targetDirectory = targetDirectory;
    return result;
  }

  TransferManifest._();

  factory TransferManifest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferManifest()..mergeFromBuffer(data, registry);
  factory TransferManifest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferManifest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferManifest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferManifest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..pPM<TransferItem>(3, _omitFieldNames ? '' : 'items',
        subBuilder: TransferItem.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'totalBytes')
    ..aI(5, _omitFieldNames ? '' : 'chunkSizeBytes')
    ..aOM<$0.PeerId>(6, _omitFieldNames ? '' : 'senderPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.PeerId>(7, _omitFieldNames ? '' : 'receiverPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'displayName')
    ..aE<DuplicateDestinationPolicy>(
        9, _omitFieldNames ? '' : 'duplicatePolicy',
        enumValues: DuplicateDestinationPolicy.values)
    ..aOS(10, _omitFieldNames ? '' : 'targetDirectory')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferManifest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferManifest copyWith(void Function(TransferManifest) updates) =>
      super.copyWith((message) => updates(message as TransferManifest))
          as TransferManifest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferManifest() / TransferManifest.new instead')
  static TransferManifest create() => TransferManifest._();
  static $pb.GeneratedMessage $_createMessage() => TransferManifest._();
  @$core.override
  TransferManifest createEmptyInstance() => TransferManifest._();
  @$core.pragma('dart2js:noInline')
  static TransferManifest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferManifest>(
          TransferManifest.$_createMessage);
  static TransferManifest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<TransferItem> get items => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get totalBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set totalBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get chunkSizeBytes => $_getIZ(4);
  @$pb.TagNumber(5)
  set chunkSizeBytes($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChunkSizeBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearChunkSizeBytes() => $_clearField(5);

  @$pb.TagNumber(6)
  $0.PeerId get senderPeerId => $_getN(5);
  @$pb.TagNumber(6)
  set senderPeerId($0.PeerId value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSenderPeerId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderPeerId() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.PeerId ensureSenderPeerId() => $_ensure(5);

  @$pb.TagNumber(7)
  $0.PeerId get receiverPeerId => $_getN(6);
  @$pb.TagNumber(7)
  set receiverPeerId($0.PeerId value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReceiverPeerId() => $_has(6);
  @$pb.TagNumber(7)
  void clearReceiverPeerId() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.PeerId ensureReceiverPeerId() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get displayName => $_getSZ(7);
  @$pb.TagNumber(8)
  set displayName($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDisplayName() => $_has(7);
  @$pb.TagNumber(8)
  void clearDisplayName() => $_clearField(8);

  @$pb.TagNumber(9)
  DuplicateDestinationPolicy get duplicatePolicy => $_getN(8);
  @$pb.TagNumber(9)
  set duplicatePolicy(DuplicateDestinationPolicy value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasDuplicatePolicy() => $_has(8);
  @$pb.TagNumber(9)
  void clearDuplicatePolicy() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get targetDirectory => $_getSZ(9);
  @$pb.TagNumber(10)
  set targetDirectory($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTargetDirectory() => $_has(9);
  @$pb.TagNumber(10)
  void clearTargetDirectory() => $_clearField(10);
}

class TransferOffer extends $pb.GeneratedMessage {
  factory TransferOffer({
    TransferManifest? manifest,
    $fixnum.Int64? timestampUtcMs,
  }) {
    final result = TransferOffer._();
    if (manifest != null) result.manifest = manifest;
    if (timestampUtcMs != null) result.timestampUtcMs = timestampUtcMs;
    return result;
  }

  TransferOffer._();

  factory TransferOffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferOffer()..mergeFromBuffer(data, registry);
  factory TransferOffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferOffer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferOffer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferOffer.$_createMessage)
    ..aOM<TransferManifest>(1, _omitFieldNames ? '' : 'manifest',
        subBuilder: TransferManifest.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'timestampUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferOffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferOffer copyWith(void Function(TransferOffer) updates) =>
      super.copyWith((message) => updates(message as TransferOffer))
          as TransferOffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferOffer() / TransferOffer.new instead')
  static TransferOffer create() => TransferOffer._();
  static $pb.GeneratedMessage $_createMessage() => TransferOffer._();
  @$core.override
  TransferOffer createEmptyInstance() => TransferOffer._();
  @$core.pragma('dart2js:noInline')
  static TransferOffer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferOffer>(
          TransferOffer.$_createMessage);
  static TransferOffer? _defaultInstance;

  @$pb.TagNumber(1)
  TransferManifest get manifest => $_getN(0);
  @$pb.TagNumber(1)
  set manifest(TransferManifest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasManifest() => $_has(0);
  @$pb.TagNumber(1)
  void clearManifest() => $_clearField(1);
  @$pb.TagNumber(1)
  TransferManifest ensureManifest() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get timestampUtcMs => $_getI64(1);
  @$pb.TagNumber(2)
  set timestampUtcMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTimestampUtcMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearTimestampUtcMs() => $_clearField(2);
}

class TransferResponse extends $pb.GeneratedMessage {
  factory TransferResponse({
    $core.String? transferId,
    $core.bool? accepted,
    $core.String? rejectionReason,
    $1.ErrorDetail? error,
  }) {
    final result = TransferResponse._();
    if (transferId != null) result.transferId = transferId;
    if (accepted != null) result.accepted = accepted;
    if (rejectionReason != null) result.rejectionReason = rejectionReason;
    if (error != null) result.error = error;
    return result;
  }

  TransferResponse._();

  factory TransferResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferResponse()..mergeFromBuffer(data, registry);
  factory TransferResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOB(2, _omitFieldNames ? '' : 'accepted')
    ..aOS(3, _omitFieldNames ? '' : 'rejectionReason')
    ..aOM<$1.ErrorDetail>(4, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferResponse copyWith(void Function(TransferResponse) updates) =>
      super.copyWith((message) => updates(message as TransferResponse))
          as TransferResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferResponse() / TransferResponse.new instead')
  static TransferResponse create() => TransferResponse._();
  static $pb.GeneratedMessage $_createMessage() => TransferResponse._();
  @$core.override
  TransferResponse createEmptyInstance() => TransferResponse._();
  @$core.pragma('dart2js:noInline')
  static TransferResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferResponse>(
          TransferResponse.$_createMessage);
  static TransferResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get accepted => $_getBF(1);
  @$pb.TagNumber(2)
  set accepted($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccepted() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccepted() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get rejectionReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set rejectionReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRejectionReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearRejectionReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.ErrorDetail get error => $_getN(3);
  @$pb.TagNumber(4)
  set error($1.ErrorDetail value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.ErrorDetail ensureError() => $_ensure(3);
}

class TransferChunk extends $pb.GeneratedMessage {
  factory TransferChunk({
    $core.String? transferId,
    $core.int? itemIndex,
    $fixnum.Int64? chunkIndex,
    $fixnum.Int64? offsetBytes,
    $core.List<$core.int>? data,
    $core.bool? isLastChunk,
    $core.String? chunkSha256,
  }) {
    final result = TransferChunk._();
    if (transferId != null) result.transferId = transferId;
    if (itemIndex != null) result.itemIndex = itemIndex;
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    if (offsetBytes != null) result.offsetBytes = offsetBytes;
    if (data != null) result.data = data;
    if (isLastChunk != null) result.isLastChunk = isLastChunk;
    if (chunkSha256 != null) result.chunkSha256 = chunkSha256;
    return result;
  }

  TransferChunk._();

  factory TransferChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferChunk()..mergeFromBuffer(data, registry);
  factory TransferChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferChunk()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferChunk.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aI(2, _omitFieldNames ? '' : 'itemIndex')
    ..aInt64(3, _omitFieldNames ? '' : 'chunkIndex')
    ..aInt64(4, _omitFieldNames ? '' : 'offsetBytes')
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOB(6, _omitFieldNames ? '' : 'isLastChunk')
    ..aOS(7, _omitFieldNames ? '' : 'chunkSha256')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferChunk copyWith(void Function(TransferChunk) updates) =>
      super.copyWith((message) => updates(message as TransferChunk))
          as TransferChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferChunk() / TransferChunk.new instead')
  static TransferChunk create() => TransferChunk._();
  static $pb.GeneratedMessage $_createMessage() => TransferChunk._();
  @$core.override
  TransferChunk createEmptyInstance() => TransferChunk._();
  @$core.pragma('dart2js:noInline')
  static TransferChunk getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferChunk>(
          TransferChunk.$_createMessage);
  static TransferChunk? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get itemIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set itemIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get chunkIndex => $_getI64(2);
  @$pb.TagNumber(3)
  set chunkIndex($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChunkIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearChunkIndex() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get offsetBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set offsetBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOffsetBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearOffsetBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get data => $_getN(4);
  @$pb.TagNumber(5)
  set data($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasData() => $_has(4);
  @$pb.TagNumber(5)
  void clearData() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isLastChunk => $_getBF(5);
  @$pb.TagNumber(6)
  set isLastChunk($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsLastChunk() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsLastChunk() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get chunkSha256 => $_getSZ(6);
  @$pb.TagNumber(7)
  set chunkSha256($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasChunkSha256() => $_has(6);
  @$pb.TagNumber(7)
  void clearChunkSha256() => $_clearField(7);
}

class TransferChunkAck extends $pb.GeneratedMessage {
  factory TransferChunkAck({
    $core.String? transferId,
    $core.int? itemIndex,
    $fixnum.Int64? chunkIndex,
    $fixnum.Int64? bytesReceived,
    $core.bool? success,
    $core.String? errorMessage,
    $core.bool? retryRequested,
  }) {
    final result = TransferChunkAck._();
    if (transferId != null) result.transferId = transferId;
    if (itemIndex != null) result.itemIndex = itemIndex;
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    if (bytesReceived != null) result.bytesReceived = bytesReceived;
    if (success != null) result.success = success;
    if (errorMessage != null) result.errorMessage = errorMessage;
    if (retryRequested != null) result.retryRequested = retryRequested;
    return result;
  }

  TransferChunkAck._();

  factory TransferChunkAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferChunkAck()..mergeFromBuffer(data, registry);
  factory TransferChunkAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferChunkAck()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferChunkAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferChunkAck.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aI(2, _omitFieldNames ? '' : 'itemIndex')
    ..aInt64(3, _omitFieldNames ? '' : 'chunkIndex')
    ..aInt64(4, _omitFieldNames ? '' : 'bytesReceived')
    ..aOB(5, _omitFieldNames ? '' : 'success')
    ..aOS(6, _omitFieldNames ? '' : 'errorMessage')
    ..aOB(7, _omitFieldNames ? '' : 'retryRequested')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferChunkAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferChunkAck copyWith(void Function(TransferChunkAck) updates) =>
      super.copyWith((message) => updates(message as TransferChunkAck))
          as TransferChunkAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferChunkAck() / TransferChunkAck.new instead')
  static TransferChunkAck create() => TransferChunkAck._();
  static $pb.GeneratedMessage $_createMessage() => TransferChunkAck._();
  @$core.override
  TransferChunkAck createEmptyInstance() => TransferChunkAck._();
  @$core.pragma('dart2js:noInline')
  static TransferChunkAck getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferChunkAck>(
          TransferChunkAck.$_createMessage);
  static TransferChunkAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get itemIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set itemIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get chunkIndex => $_getI64(2);
  @$pb.TagNumber(3)
  set chunkIndex($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChunkIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearChunkIndex() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get bytesReceived => $_getI64(3);
  @$pb.TagNumber(4)
  set bytesReceived($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBytesReceived() => $_has(3);
  @$pb.TagNumber(4)
  void clearBytesReceived() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get success => $_getBF(4);
  @$pb.TagNumber(5)
  set success($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSuccess() => $_has(4);
  @$pb.TagNumber(5)
  void clearSuccess() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get errorMessage => $_getSZ(5);
  @$pb.TagNumber(6)
  set errorMessage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasErrorMessage() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorMessage() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get retryRequested => $_getBF(6);
  @$pb.TagNumber(7)
  set retryRequested($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRetryRequested() => $_has(6);
  @$pb.TagNumber(7)
  void clearRetryRequested() => $_clearField(7);
}

class TransferVerifyResult extends $pb.GeneratedMessage {
  factory TransferVerifyResult({
    $core.String? transferId,
    $core.int? itemIndex,
    $core.bool? verified,
    $core.String? computedSha256,
    $core.String? expectedSha256,
    $core.String? details,
  }) {
    final result = TransferVerifyResult._();
    if (transferId != null) result.transferId = transferId;
    if (itemIndex != null) result.itemIndex = itemIndex;
    if (verified != null) result.verified = verified;
    if (computedSha256 != null) result.computedSha256 = computedSha256;
    if (expectedSha256 != null) result.expectedSha256 = expectedSha256;
    if (details != null) result.details = details;
    return result;
  }

  TransferVerifyResult._();

  factory TransferVerifyResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferVerifyResult()..mergeFromBuffer(data, registry);
  factory TransferVerifyResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferVerifyResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferVerifyResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferVerifyResult.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aI(2, _omitFieldNames ? '' : 'itemIndex')
    ..aOB(3, _omitFieldNames ? '' : 'verified')
    ..aOS(4, _omitFieldNames ? '' : 'computedSha256')
    ..aOS(5, _omitFieldNames ? '' : 'expectedSha256')
    ..aOS(6, _omitFieldNames ? '' : 'details')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferVerifyResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferVerifyResult copyWith(void Function(TransferVerifyResult) updates) =>
      super.copyWith((message) => updates(message as TransferVerifyResult))
          as TransferVerifyResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferVerifyResult() / TransferVerifyResult.new instead')
  static TransferVerifyResult create() => TransferVerifyResult._();
  static $pb.GeneratedMessage $_createMessage() => TransferVerifyResult._();
  @$core.override
  TransferVerifyResult createEmptyInstance() => TransferVerifyResult._();
  @$core.pragma('dart2js:noInline')
  static TransferVerifyResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferVerifyResult>(
          TransferVerifyResult.$_createMessage);
  static TransferVerifyResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get itemIndex => $_getIZ(1);
  @$pb.TagNumber(2)
  set itemIndex($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemIndex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get verified => $_getBF(2);
  @$pb.TagNumber(3)
  set verified($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVerified() => $_has(2);
  @$pb.TagNumber(3)
  void clearVerified() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get computedSha256 => $_getSZ(3);
  @$pb.TagNumber(4)
  set computedSha256($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasComputedSha256() => $_has(3);
  @$pb.TagNumber(4)
  void clearComputedSha256() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get expectedSha256 => $_getSZ(4);
  @$pb.TagNumber(5)
  set expectedSha256($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExpectedSha256() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpectedSha256() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get details => $_getSZ(5);
  @$pb.TagNumber(6)
  set details($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDetails() => $_has(5);
  @$pb.TagNumber(6)
  void clearDetails() => $_clearField(6);
}

class TransferCommitSignal extends $pb.GeneratedMessage {
  factory TransferCommitSignal({
    $core.String? transferId,
    $core.bool? commitConfirmed,
  }) {
    final result = TransferCommitSignal._();
    if (transferId != null) result.transferId = transferId;
    if (commitConfirmed != null) result.commitConfirmed = commitConfirmed;
    return result;
  }

  TransferCommitSignal._();

  factory TransferCommitSignal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferCommitSignal()..mergeFromBuffer(data, registry);
  factory TransferCommitSignal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferCommitSignal()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferCommitSignal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferCommitSignal.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOB(2, _omitFieldNames ? '' : 'commitConfirmed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferCommitSignal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferCommitSignal copyWith(void Function(TransferCommitSignal) updates) =>
      super.copyWith((message) => updates(message as TransferCommitSignal))
          as TransferCommitSignal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferCommitSignal() / TransferCommitSignal.new instead')
  static TransferCommitSignal create() => TransferCommitSignal._();
  static $pb.GeneratedMessage $_createMessage() => TransferCommitSignal._();
  @$core.override
  TransferCommitSignal createEmptyInstance() => TransferCommitSignal._();
  @$core.pragma('dart2js:noInline')
  static TransferCommitSignal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferCommitSignal>(
          TransferCommitSignal.$_createMessage);
  static TransferCommitSignal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get commitConfirmed => $_getBF(1);
  @$pb.TagNumber(2)
  set commitConfirmed($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommitConfirmed() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommitConfirmed() => $_clearField(2);
}

class TransferCompletedReceipt extends $pb.GeneratedMessage {
  factory TransferCompletedReceipt({
    $core.String? transferId,
    $0.OperationId? operationId,
    $fixnum.Int64? completionTimestampUtcMs,
    $fixnum.Int64? totalBytesTransferred,
    $core.bool? success,
    $core.String? finalDestinationPath,
    $core.String? errorMessage,
  }) {
    final result = TransferCompletedReceipt._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (completionTimestampUtcMs != null)
      result.completionTimestampUtcMs = completionTimestampUtcMs;
    if (totalBytesTransferred != null)
      result.totalBytesTransferred = totalBytesTransferred;
    if (success != null) result.success = success;
    if (finalDestinationPath != null)
      result.finalDestinationPath = finalDestinationPath;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  TransferCompletedReceipt._();

  factory TransferCompletedReceipt.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferCompletedReceipt()..mergeFromBuffer(data, registry);
  factory TransferCompletedReceipt.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferCompletedReceipt()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferCompletedReceipt',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferCompletedReceipt.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'completionTimestampUtcMs')
    ..aInt64(4, _omitFieldNames ? '' : 'totalBytesTransferred')
    ..aOB(5, _omitFieldNames ? '' : 'success')
    ..aOS(6, _omitFieldNames ? '' : 'finalDestinationPath')
    ..aOS(7, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferCompletedReceipt clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferCompletedReceipt copyWith(
          void Function(TransferCompletedReceipt) updates) =>
      super.copyWith((message) => updates(message as TransferCompletedReceipt))
          as TransferCompletedReceipt;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferCompletedReceipt() / TransferCompletedReceipt.new instead')
  static TransferCompletedReceipt create() => TransferCompletedReceipt._();
  static $pb.GeneratedMessage $_createMessage() => TransferCompletedReceipt._();
  @$core.override
  TransferCompletedReceipt createEmptyInstance() =>
      TransferCompletedReceipt._();
  @$core.pragma('dart2js:noInline')
  static TransferCompletedReceipt getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferCompletedReceipt>(
          TransferCompletedReceipt.$_createMessage);
  static TransferCompletedReceipt? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get completionTimestampUtcMs => $_getI64(2);
  @$pb.TagNumber(3)
  set completionTimestampUtcMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCompletionTimestampUtcMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearCompletionTimestampUtcMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get totalBytesTransferred => $_getI64(3);
  @$pb.TagNumber(4)
  set totalBytesTransferred($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalBytesTransferred() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalBytesTransferred() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get success => $_getBF(4);
  @$pb.TagNumber(5)
  set success($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSuccess() => $_has(4);
  @$pb.TagNumber(5)
  void clearSuccess() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get finalDestinationPath => $_getSZ(5);
  @$pb.TagNumber(6)
  set finalDestinationPath($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFinalDestinationPath() => $_has(5);
  @$pb.TagNumber(6)
  void clearFinalDestinationPath() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get errorMessage => $_getSZ(6);
  @$pb.TagNumber(7)
  set errorMessage($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasErrorMessage() => $_has(6);
  @$pb.TagNumber(7)
  void clearErrorMessage() => $_clearField(7);
}

class TransferCancelRequest extends $pb.GeneratedMessage {
  factory TransferCancelRequest({
    $core.String? transferId,
    $core.String? reason,
  }) {
    final result = TransferCancelRequest._();
    if (transferId != null) result.transferId = transferId;
    if (reason != null) result.reason = reason;
    return result;
  }

  TransferCancelRequest._();

  factory TransferCancelRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferCancelRequest()..mergeFromBuffer(data, registry);
  factory TransferCancelRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferCancelRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferCancelRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferCancelRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferCancelRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferCancelRequest copyWith(
          void Function(TransferCancelRequest) updates) =>
      super.copyWith((message) => updates(message as TransferCancelRequest))
          as TransferCancelRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferCancelRequest() / TransferCancelRequest.new instead')
  static TransferCancelRequest create() => TransferCancelRequest._();
  static $pb.GeneratedMessage $_createMessage() => TransferCancelRequest._();
  @$core.override
  TransferCancelRequest createEmptyInstance() => TransferCancelRequest._();
  @$core.pragma('dart2js:noInline')
  static TransferCancelRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferCancelRequest>(
          TransferCancelRequest.$_createMessage);
  static TransferCancelRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class TransferPauseRequest extends $pb.GeneratedMessage {
  factory TransferPauseRequest({
    $core.String? transferId,
    $core.String? reason,
  }) {
    final result = TransferPauseRequest._();
    if (transferId != null) result.transferId = transferId;
    if (reason != null) result.reason = reason;
    return result;
  }

  TransferPauseRequest._();

  factory TransferPauseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferPauseRequest()..mergeFromBuffer(data, registry);
  factory TransferPauseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferPauseRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferPauseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferPauseRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferPauseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferPauseRequest copyWith(void Function(TransferPauseRequest) updates) =>
      super.copyWith((message) => updates(message as TransferPauseRequest))
          as TransferPauseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferPauseRequest() / TransferPauseRequest.new instead')
  static TransferPauseRequest create() => TransferPauseRequest._();
  static $pb.GeneratedMessage $_createMessage() => TransferPauseRequest._();
  @$core.override
  TransferPauseRequest createEmptyInstance() => TransferPauseRequest._();
  @$core.pragma('dart2js:noInline')
  static TransferPauseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferPauseRequest>(
          TransferPauseRequest.$_createMessage);
  static TransferPauseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class TransferPauseResponse extends $pb.GeneratedMessage {
  factory TransferPauseResponse({
    $core.String? transferId,
    $core.bool? acknowledged,
  }) {
    final result = TransferPauseResponse._();
    if (transferId != null) result.transferId = transferId;
    if (acknowledged != null) result.acknowledged = acknowledged;
    return result;
  }

  TransferPauseResponse._();

  factory TransferPauseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferPauseResponse()..mergeFromBuffer(data, registry);
  factory TransferPauseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferPauseResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferPauseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferPauseResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOB(2, _omitFieldNames ? '' : 'acknowledged')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferPauseResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferPauseResponse copyWith(
          void Function(TransferPauseResponse) updates) =>
      super.copyWith((message) => updates(message as TransferPauseResponse))
          as TransferPauseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferPauseResponse() / TransferPauseResponse.new instead')
  static TransferPauseResponse create() => TransferPauseResponse._();
  static $pb.GeneratedMessage $_createMessage() => TransferPauseResponse._();
  @$core.override
  TransferPauseResponse createEmptyInstance() => TransferPauseResponse._();
  @$core.pragma('dart2js:noInline')
  static TransferPauseResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferPauseResponse>(
          TransferPauseResponse.$_createMessage);
  static TransferPauseResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get acknowledged => $_getBF(1);
  @$pb.TagNumber(2)
  set acknowledged($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAcknowledged() => $_has(1);
  @$pb.TagNumber(2)
  void clearAcknowledged() => $_clearField(2);
}

class TransferResumeOffer extends $pb.GeneratedMessage {
  factory TransferResumeOffer({
    $core.String? transferId,
    $0.OperationId? operationId,
    TransferManifest? manifest,
    $fixnum.Int64? resumeTimestampUtcMs,
  }) {
    final result = TransferResumeOffer._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (manifest != null) result.manifest = manifest;
    if (resumeTimestampUtcMs != null)
      result.resumeTimestampUtcMs = resumeTimestampUtcMs;
    return result;
  }

  TransferResumeOffer._();

  factory TransferResumeOffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferResumeOffer()..mergeFromBuffer(data, registry);
  factory TransferResumeOffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferResumeOffer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferResumeOffer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferResumeOffer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..aOM<TransferManifest>(3, _omitFieldNames ? '' : 'manifest',
        subBuilder: TransferManifest.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'resumeTimestampUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferResumeOffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferResumeOffer copyWith(void Function(TransferResumeOffer) updates) =>
      super.copyWith((message) => updates(message as TransferResumeOffer))
          as TransferResumeOffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use TransferResumeOffer() / TransferResumeOffer.new instead')
  static TransferResumeOffer create() => TransferResumeOffer._();
  static $pb.GeneratedMessage $_createMessage() => TransferResumeOffer._();
  @$core.override
  TransferResumeOffer createEmptyInstance() => TransferResumeOffer._();
  @$core.pragma('dart2js:noInline')
  static TransferResumeOffer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferResumeOffer>(
          TransferResumeOffer.$_createMessage);
  static TransferResumeOffer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);

  @$pb.TagNumber(3)
  TransferManifest get manifest => $_getN(2);
  @$pb.TagNumber(3)
  set manifest(TransferManifest value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasManifest() => $_has(2);
  @$pb.TagNumber(3)
  void clearManifest() => $_clearField(3);
  @$pb.TagNumber(3)
  TransferManifest ensureManifest() => $_ensure(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get resumeTimestampUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set resumeTimestampUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResumeTimestampUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearResumeTimestampUtcMs() => $_clearField(4);
}

class TransferResumeState extends $pb.GeneratedMessage {
  factory TransferResumeState({
    $core.String? transferId,
    $0.OperationId? operationId,
    $core.Iterable<$fixnum.Int64>? ackedChunkIndices,
    $fixnum.Int64? bytesAlreadyStaged,
    TransferState? currentState,
    $core.bool? canResume,
    $core.String? message,
  }) {
    final result = TransferResumeState._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (ackedChunkIndices != null)
      result.ackedChunkIndices.addAll(ackedChunkIndices);
    if (bytesAlreadyStaged != null)
      result.bytesAlreadyStaged = bytesAlreadyStaged;
    if (currentState != null) result.currentState = currentState;
    if (canResume != null) result.canResume = canResume;
    if (message != null) result.message = message;
    return result;
  }

  TransferResumeState._();

  factory TransferResumeState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferResumeState()..mergeFromBuffer(data, registry);
  factory TransferResumeState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferResumeState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferResumeState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferResumeState.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..p<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'ackedChunkIndices', $pb.PbFieldType.K6)
    ..aInt64(4, _omitFieldNames ? '' : 'bytesAlreadyStaged')
    ..aE<TransferState>(5, _omitFieldNames ? '' : 'currentState',
        enumValues: TransferState.values)
    ..aOB(6, _omitFieldNames ? '' : 'canResume')
    ..aOS(7, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferResumeState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferResumeState copyWith(void Function(TransferResumeState) updates) =>
      super.copyWith((message) => updates(message as TransferResumeState))
          as TransferResumeState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use TransferResumeState() / TransferResumeState.new instead')
  static TransferResumeState create() => TransferResumeState._();
  static $pb.GeneratedMessage $_createMessage() => TransferResumeState._();
  @$core.override
  TransferResumeState createEmptyInstance() => TransferResumeState._();
  @$core.pragma('dart2js:noInline')
  static TransferResumeState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferResumeState>(
          TransferResumeState.$_createMessage);
  static TransferResumeState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<$fixnum.Int64> get ackedChunkIndices => $_getList(2);

  @$pb.TagNumber(4)
  $fixnum.Int64 get bytesAlreadyStaged => $_getI64(3);
  @$pb.TagNumber(4)
  set bytesAlreadyStaged($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBytesAlreadyStaged() => $_has(3);
  @$pb.TagNumber(4)
  void clearBytesAlreadyStaged() => $_clearField(4);

  @$pb.TagNumber(5)
  TransferState get currentState => $_getN(4);
  @$pb.TagNumber(5)
  set currentState(TransferState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrentState() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrentState() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get canResume => $_getBF(5);
  @$pb.TagNumber(6)
  set canResume($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCanResume() => $_has(5);
  @$pb.TagNumber(6)
  void clearCanResume() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get message => $_getSZ(6);
  @$pb.TagNumber(7)
  set message($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMessage() => $_has(6);
  @$pb.TagNumber(7)
  void clearMessage() => $_clearField(7);
}

class TransferOperationStatusQuery extends $pb.GeneratedMessage {
  factory TransferOperationStatusQuery({
    $core.String? transferId,
    $0.OperationId? operationId,
  }) {
    final result = TransferOperationStatusQuery._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    return result;
  }

  TransferOperationStatusQuery._();

  factory TransferOperationStatusQuery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferOperationStatusQuery()..mergeFromBuffer(data, registry);
  factory TransferOperationStatusQuery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferOperationStatusQuery()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferOperationStatusQuery',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferOperationStatusQuery.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferOperationStatusQuery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferOperationStatusQuery copyWith(
          void Function(TransferOperationStatusQuery) updates) =>
      super.copyWith(
              (message) => updates(message as TransferOperationStatusQuery))
          as TransferOperationStatusQuery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferOperationStatusQuery() / TransferOperationStatusQuery.new instead')
  static TransferOperationStatusQuery create() =>
      TransferOperationStatusQuery._();
  static $pb.GeneratedMessage $_createMessage() =>
      TransferOperationStatusQuery._();
  @$core.override
  TransferOperationStatusQuery createEmptyInstance() =>
      TransferOperationStatusQuery._();
  @$core.pragma('dart2js:noInline')
  static TransferOperationStatusQuery getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferOperationStatusQuery>(
          TransferOperationStatusQuery.$_createMessage);
  static TransferOperationStatusQuery? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);
}

class TransferOperationStatusResponse extends $pb.GeneratedMessage {
  factory TransferOperationStatusResponse({
    $core.String? transferId,
    $0.OperationId? operationId,
    TransferState? state,
    $core.bool? isCommitted,
    TransferCompletedReceipt? receipt,
    $core.String? errorMessage,
  }) {
    final result = TransferOperationStatusResponse._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (state != null) result.state = state;
    if (isCommitted != null) result.isCommitted = isCommitted;
    if (receipt != null) result.receipt = receipt;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  TransferOperationStatusResponse._();

  factory TransferOperationStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferOperationStatusResponse()..mergeFromBuffer(data, registry);
  factory TransferOperationStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferOperationStatusResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferOperationStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferOperationStatusResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..aE<TransferState>(3, _omitFieldNames ? '' : 'state',
        enumValues: TransferState.values)
    ..aOB(4, _omitFieldNames ? '' : 'isCommitted')
    ..aOM<TransferCompletedReceipt>(5, _omitFieldNames ? '' : 'receipt',
        subBuilder: TransferCompletedReceipt.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferOperationStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferOperationStatusResponse copyWith(
          void Function(TransferOperationStatusResponse) updates) =>
      super.copyWith(
              (message) => updates(message as TransferOperationStatusResponse))
          as TransferOperationStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransferOperationStatusResponse() / TransferOperationStatusResponse.new instead')
  static TransferOperationStatusResponse create() =>
      TransferOperationStatusResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      TransferOperationStatusResponse._();
  @$core.override
  TransferOperationStatusResponse createEmptyInstance() =>
      TransferOperationStatusResponse._();
  @$core.pragma('dart2js:noInline')
  static TransferOperationStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferOperationStatusResponse>(
          TransferOperationStatusResponse.$_createMessage);
  static TransferOperationStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);

  @$pb.TagNumber(3)
  TransferState get state => $_getN(2);
  @$pb.TagNumber(3)
  set state(TransferState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isCommitted => $_getBF(3);
  @$pb.TagNumber(4)
  set isCommitted($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsCommitted() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsCommitted() => $_clearField(4);

  @$pb.TagNumber(5)
  TransferCompletedReceipt get receipt => $_getN(4);
  @$pb.TagNumber(5)
  set receipt(TransferCompletedReceipt value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasReceipt() => $_has(4);
  @$pb.TagNumber(5)
  void clearReceipt() => $_clearField(5);
  @$pb.TagNumber(5)
  TransferCompletedReceipt ensureReceipt() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get errorMessage => $_getSZ(5);
  @$pb.TagNumber(6)
  set errorMessage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasErrorMessage() => $_has(5);
  @$pb.TagNumber(6)
  void clearErrorMessage() => $_clearField(6);
}

enum TransferWireMessage_Payload {
  offer,
  response,
  chunk,
  ack,
  verify,
  commit,
  receipt,
  cancel,
  pause,
  pauseResponse,
  resumeOffer,
  resumeState,
  statusQuery,
  statusResponse,
  notSet
}

class TransferWireMessage extends $pb.GeneratedMessage {
  factory TransferWireMessage({
    TransferOffer? offer,
    TransferResponse? response,
    TransferChunk? chunk,
    TransferChunkAck? ack,
    TransferVerifyResult? verify,
    TransferCommitSignal? commit,
    TransferCompletedReceipt? receipt,
    TransferCancelRequest? cancel,
    TransferPauseRequest? pause,
    TransferPauseResponse? pauseResponse,
    TransferResumeOffer? resumeOffer,
    TransferResumeState? resumeState,
    TransferOperationStatusQuery? statusQuery,
    TransferOperationStatusResponse? statusResponse,
  }) {
    final result = TransferWireMessage._();
    if (offer != null) result.offer = offer;
    if (response != null) result.response = response;
    if (chunk != null) result.chunk = chunk;
    if (ack != null) result.ack = ack;
    if (verify != null) result.verify = verify;
    if (commit != null) result.commit = commit;
    if (receipt != null) result.receipt = receipt;
    if (cancel != null) result.cancel = cancel;
    if (pause != null) result.pause = pause;
    if (pauseResponse != null) result.pauseResponse = pauseResponse;
    if (resumeOffer != null) result.resumeOffer = resumeOffer;
    if (resumeState != null) result.resumeState = resumeState;
    if (statusQuery != null) result.statusQuery = statusQuery;
    if (statusResponse != null) result.statusResponse = statusResponse;
    return result;
  }

  TransferWireMessage._();

  factory TransferWireMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferWireMessage()..mergeFromBuffer(data, registry);
  factory TransferWireMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferWireMessage()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TransferWireMessage_Payload>
      _TransferWireMessage_PayloadByTag = {
    1: TransferWireMessage_Payload.offer,
    2: TransferWireMessage_Payload.response,
    3: TransferWireMessage_Payload.chunk,
    4: TransferWireMessage_Payload.ack,
    5: TransferWireMessage_Payload.verify,
    6: TransferWireMessage_Payload.commit,
    7: TransferWireMessage_Payload.receipt,
    8: TransferWireMessage_Payload.cancel,
    9: TransferWireMessage_Payload.pause,
    10: TransferWireMessage_Payload.pauseResponse,
    11: TransferWireMessage_Payload.resumeOffer,
    12: TransferWireMessage_Payload.resumeState,
    13: TransferWireMessage_Payload.statusQuery,
    14: TransferWireMessage_Payload.statusResponse,
    0: TransferWireMessage_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferWireMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferWireMessage.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14])
    ..aOM<TransferOffer>(1, _omitFieldNames ? '' : 'offer',
        subBuilder: TransferOffer.$_createMessage)
    ..aOM<TransferResponse>(2, _omitFieldNames ? '' : 'response',
        subBuilder: TransferResponse.$_createMessage)
    ..aOM<TransferChunk>(3, _omitFieldNames ? '' : 'chunk',
        subBuilder: TransferChunk.$_createMessage)
    ..aOM<TransferChunkAck>(4, _omitFieldNames ? '' : 'ack',
        subBuilder: TransferChunkAck.$_createMessage)
    ..aOM<TransferVerifyResult>(5, _omitFieldNames ? '' : 'verify',
        subBuilder: TransferVerifyResult.$_createMessage)
    ..aOM<TransferCommitSignal>(6, _omitFieldNames ? '' : 'commit',
        subBuilder: TransferCommitSignal.$_createMessage)
    ..aOM<TransferCompletedReceipt>(7, _omitFieldNames ? '' : 'receipt',
        subBuilder: TransferCompletedReceipt.$_createMessage)
    ..aOM<TransferCancelRequest>(8, _omitFieldNames ? '' : 'cancel',
        subBuilder: TransferCancelRequest.$_createMessage)
    ..aOM<TransferPauseRequest>(9, _omitFieldNames ? '' : 'pause',
        subBuilder: TransferPauseRequest.$_createMessage)
    ..aOM<TransferPauseResponse>(10, _omitFieldNames ? '' : 'pauseResponse',
        subBuilder: TransferPauseResponse.$_createMessage)
    ..aOM<TransferResumeOffer>(11, _omitFieldNames ? '' : 'resumeOffer',
        subBuilder: TransferResumeOffer.$_createMessage)
    ..aOM<TransferResumeState>(12, _omitFieldNames ? '' : 'resumeState',
        subBuilder: TransferResumeState.$_createMessage)
    ..aOM<TransferOperationStatusQuery>(
        13, _omitFieldNames ? '' : 'statusQuery',
        subBuilder: TransferOperationStatusQuery.$_createMessage)
    ..aOM<TransferOperationStatusResponse>(
        14, _omitFieldNames ? '' : 'statusResponse',
        subBuilder: TransferOperationStatusResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferWireMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferWireMessage copyWith(void Function(TransferWireMessage) updates) =>
      super.copyWith((message) => updates(message as TransferWireMessage))
          as TransferWireMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use TransferWireMessage() / TransferWireMessage.new instead')
  static TransferWireMessage create() => TransferWireMessage._();
  static $pb.GeneratedMessage $_createMessage() => TransferWireMessage._();
  @$core.override
  TransferWireMessage createEmptyInstance() => TransferWireMessage._();
  @$core.pragma('dart2js:noInline')
  static TransferWireMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferWireMessage>(
          TransferWireMessage.$_createMessage);
  static TransferWireMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  TransferWireMessage_Payload whichPayload() =>
      _TransferWireMessage_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  TransferOffer get offer => $_getN(0);
  @$pb.TagNumber(1)
  set offer(TransferOffer value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOffer() => $_has(0);
  @$pb.TagNumber(1)
  void clearOffer() => $_clearField(1);
  @$pb.TagNumber(1)
  TransferOffer ensureOffer() => $_ensure(0);

  @$pb.TagNumber(2)
  TransferResponse get response => $_getN(1);
  @$pb.TagNumber(2)
  set response(TransferResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  TransferResponse ensureResponse() => $_ensure(1);

  @$pb.TagNumber(3)
  TransferChunk get chunk => $_getN(2);
  @$pb.TagNumber(3)
  set chunk(TransferChunk value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasChunk() => $_has(2);
  @$pb.TagNumber(3)
  void clearChunk() => $_clearField(3);
  @$pb.TagNumber(3)
  TransferChunk ensureChunk() => $_ensure(2);

  @$pb.TagNumber(4)
  TransferChunkAck get ack => $_getN(3);
  @$pb.TagNumber(4)
  set ack(TransferChunkAck value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAck() => $_has(3);
  @$pb.TagNumber(4)
  void clearAck() => $_clearField(4);
  @$pb.TagNumber(4)
  TransferChunkAck ensureAck() => $_ensure(3);

  @$pb.TagNumber(5)
  TransferVerifyResult get verify => $_getN(4);
  @$pb.TagNumber(5)
  set verify(TransferVerifyResult value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasVerify() => $_has(4);
  @$pb.TagNumber(5)
  void clearVerify() => $_clearField(5);
  @$pb.TagNumber(5)
  TransferVerifyResult ensureVerify() => $_ensure(4);

  @$pb.TagNumber(6)
  TransferCommitSignal get commit => $_getN(5);
  @$pb.TagNumber(6)
  set commit(TransferCommitSignal value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCommit() => $_has(5);
  @$pb.TagNumber(6)
  void clearCommit() => $_clearField(6);
  @$pb.TagNumber(6)
  TransferCommitSignal ensureCommit() => $_ensure(5);

  @$pb.TagNumber(7)
  TransferCompletedReceipt get receipt => $_getN(6);
  @$pb.TagNumber(7)
  set receipt(TransferCompletedReceipt value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReceipt() => $_has(6);
  @$pb.TagNumber(7)
  void clearReceipt() => $_clearField(7);
  @$pb.TagNumber(7)
  TransferCompletedReceipt ensureReceipt() => $_ensure(6);

  @$pb.TagNumber(8)
  TransferCancelRequest get cancel => $_getN(7);
  @$pb.TagNumber(8)
  set cancel(TransferCancelRequest value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCancel() => $_has(7);
  @$pb.TagNumber(8)
  void clearCancel() => $_clearField(8);
  @$pb.TagNumber(8)
  TransferCancelRequest ensureCancel() => $_ensure(7);

  @$pb.TagNumber(9)
  TransferPauseRequest get pause => $_getN(8);
  @$pb.TagNumber(9)
  set pause(TransferPauseRequest value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasPause() => $_has(8);
  @$pb.TagNumber(9)
  void clearPause() => $_clearField(9);
  @$pb.TagNumber(9)
  TransferPauseRequest ensurePause() => $_ensure(8);

  @$pb.TagNumber(10)
  TransferPauseResponse get pauseResponse => $_getN(9);
  @$pb.TagNumber(10)
  set pauseResponse(TransferPauseResponse value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPauseResponse() => $_has(9);
  @$pb.TagNumber(10)
  void clearPauseResponse() => $_clearField(10);
  @$pb.TagNumber(10)
  TransferPauseResponse ensurePauseResponse() => $_ensure(9);

  @$pb.TagNumber(11)
  TransferResumeOffer get resumeOffer => $_getN(10);
  @$pb.TagNumber(11)
  set resumeOffer(TransferResumeOffer value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasResumeOffer() => $_has(10);
  @$pb.TagNumber(11)
  void clearResumeOffer() => $_clearField(11);
  @$pb.TagNumber(11)
  TransferResumeOffer ensureResumeOffer() => $_ensure(10);

  @$pb.TagNumber(12)
  TransferResumeState get resumeState => $_getN(11);
  @$pb.TagNumber(12)
  set resumeState(TransferResumeState value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasResumeState() => $_has(11);
  @$pb.TagNumber(12)
  void clearResumeState() => $_clearField(12);
  @$pb.TagNumber(12)
  TransferResumeState ensureResumeState() => $_ensure(11);

  @$pb.TagNumber(13)
  TransferOperationStatusQuery get statusQuery => $_getN(12);
  @$pb.TagNumber(13)
  set statusQuery(TransferOperationStatusQuery value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasStatusQuery() => $_has(12);
  @$pb.TagNumber(13)
  void clearStatusQuery() => $_clearField(13);
  @$pb.TagNumber(13)
  TransferOperationStatusQuery ensureStatusQuery() => $_ensure(12);

  @$pb.TagNumber(14)
  TransferOperationStatusResponse get statusResponse => $_getN(13);
  @$pb.TagNumber(14)
  set statusResponse(TransferOperationStatusResponse value) =>
      $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasStatusResponse() => $_has(13);
  @$pb.TagNumber(14)
  void clearStatusResponse() => $_clearField(14);
  @$pb.TagNumber(14)
  TransferOperationStatusResponse ensureStatusResponse() => $_ensure(13);
}

class TransferDescriptor extends $pb.GeneratedMessage {
  factory TransferDescriptor({
    $core.String? transferId,
    $0.OperationId? operationId,
    $0.ObjectId? objectId,
    $0.PeerId? sourcePeer,
    $0.PeerId? destinationPeer,
    $core.String? displayName,
    $fixnum.Int64? totalBytes,
    $core.int? chunkSizeBytes,
    $0.ContentHash? expectedHash,
    $fixnum.Int64? createdAtUtcMs,
    $core.Iterable<TransferItem>? items,
    $core.String? localSourcePath,
    $core.String? destinationPath,
  }) {
    final result = TransferDescriptor._();
    if (transferId != null) result.transferId = transferId;
    if (operationId != null) result.operationId = operationId;
    if (objectId != null) result.objectId = objectId;
    if (sourcePeer != null) result.sourcePeer = sourcePeer;
    if (destinationPeer != null) result.destinationPeer = destinationPeer;
    if (displayName != null) result.displayName = displayName;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (chunkSizeBytes != null) result.chunkSizeBytes = chunkSizeBytes;
    if (expectedHash != null) result.expectedHash = expectedHash;
    if (createdAtUtcMs != null) result.createdAtUtcMs = createdAtUtcMs;
    if (items != null) result.items.addAll(items);
    if (localSourcePath != null) result.localSourcePath = localSourcePath;
    if (destinationPath != null) result.destinationPath = destinationPath;
    return result;
  }

  TransferDescriptor._();

  factory TransferDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferDescriptor()..mergeFromBuffer(data, registry);
  factory TransferDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferDescriptor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferDescriptor.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aOM<$0.OperationId>(2, _omitFieldNames ? '' : 'operationId',
        subBuilder: $0.OperationId.$_createMessage)
    ..aOM<$0.ObjectId>(3, _omitFieldNames ? '' : 'objectId',
        subBuilder: $0.ObjectId.$_createMessage)
    ..aOM<$0.PeerId>(4, _omitFieldNames ? '' : 'sourcePeer',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.PeerId>(5, _omitFieldNames ? '' : 'destinationPeer',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOS(6, _omitFieldNames ? '' : 'displayName')
    ..aInt64(7, _omitFieldNames ? '' : 'totalBytes')
    ..aI(8, _omitFieldNames ? '' : 'chunkSizeBytes')
    ..aOM<$0.ContentHash>(9, _omitFieldNames ? '' : 'expectedHash',
        subBuilder: $0.ContentHash.$_createMessage)
    ..aInt64(10, _omitFieldNames ? '' : 'createdAtUtcMs')
    ..pPM<TransferItem>(11, _omitFieldNames ? '' : 'items',
        subBuilder: TransferItem.$_createMessage)
    ..aOS(12, _omitFieldNames ? '' : 'localSourcePath')
    ..aOS(13, _omitFieldNames ? '' : 'destinationPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferDescriptor copyWith(void Function(TransferDescriptor) updates) =>
      super.copyWith((message) => updates(message as TransferDescriptor))
          as TransferDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferDescriptor() / TransferDescriptor.new instead')
  static TransferDescriptor create() => TransferDescriptor._();
  static $pb.GeneratedMessage $_createMessage() => TransferDescriptor._();
  @$core.override
  TransferDescriptor createEmptyInstance() => TransferDescriptor._();
  @$core.pragma('dart2js:noInline')
  static TransferDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransferDescriptor>(
          TransferDescriptor.$_createMessage);
  static TransferDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.OperationId get operationId => $_getN(1);
  @$pb.TagNumber(2)
  set operationId($0.OperationId value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperationId() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.OperationId ensureOperationId() => $_ensure(1);

  @$pb.TagNumber(3)
  $0.ObjectId get objectId => $_getN(2);
  @$pb.TagNumber(3)
  set objectId($0.ObjectId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasObjectId() => $_has(2);
  @$pb.TagNumber(3)
  void clearObjectId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.ObjectId ensureObjectId() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.PeerId get sourcePeer => $_getN(3);
  @$pb.TagNumber(4)
  set sourcePeer($0.PeerId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSourcePeer() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourcePeer() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.PeerId ensureSourcePeer() => $_ensure(3);

  @$pb.TagNumber(5)
  $0.PeerId get destinationPeer => $_getN(4);
  @$pb.TagNumber(5)
  set destinationPeer($0.PeerId value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDestinationPeer() => $_has(4);
  @$pb.TagNumber(5)
  void clearDestinationPeer() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.PeerId ensureDestinationPeer() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get displayName => $_getSZ(5);
  @$pb.TagNumber(6)
  set displayName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDisplayName() => $_has(5);
  @$pb.TagNumber(6)
  void clearDisplayName() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get totalBytes => $_getI64(6);
  @$pb.TagNumber(7)
  set totalBytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get chunkSizeBytes => $_getIZ(7);
  @$pb.TagNumber(8)
  set chunkSizeBytes($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasChunkSizeBytes() => $_has(7);
  @$pb.TagNumber(8)
  void clearChunkSizeBytes() => $_clearField(8);

  @$pb.TagNumber(9)
  $0.ContentHash get expectedHash => $_getN(8);
  @$pb.TagNumber(9)
  set expectedHash($0.ContentHash value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasExpectedHash() => $_has(8);
  @$pb.TagNumber(9)
  void clearExpectedHash() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.ContentHash ensureExpectedHash() => $_ensure(8);

  @$pb.TagNumber(10)
  $fixnum.Int64 get createdAtUtcMs => $_getI64(9);
  @$pb.TagNumber(10)
  set createdAtUtcMs($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCreatedAtUtcMs() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreatedAtUtcMs() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<TransferItem> get items => $_getList(10);

  @$pb.TagNumber(12)
  $core.String get localSourcePath => $_getSZ(11);
  @$pb.TagNumber(12)
  set localSourcePath($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasLocalSourcePath() => $_has(11);
  @$pb.TagNumber(12)
  void clearLocalSourcePath() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get destinationPath => $_getSZ(12);
  @$pb.TagNumber(13)
  set destinationPath($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasDestinationPath() => $_has(12);
  @$pb.TagNumber(13)
  void clearDestinationPath() => $_clearField(13);
}

class TransferProgress extends $pb.GeneratedMessage {
  factory TransferProgress({
    $core.String? transferId,
    $fixnum.Int64? transferredBytes,
    $fixnum.Int64? totalBytes,
    TransferState? state,
    $fixnum.Int64? speedBps,
    $1.ErrorDetail? error,
    $core.String? currentFile,
    $core.int? currentItemIndex,
    $core.int? totalItems,
    $core.String? destinationPath,
  }) {
    final result = TransferProgress._();
    if (transferId != null) result.transferId = transferId;
    if (transferredBytes != null) result.transferredBytes = transferredBytes;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (state != null) result.state = state;
    if (speedBps != null) result.speedBps = speedBps;
    if (error != null) result.error = error;
    if (currentFile != null) result.currentFile = currentFile;
    if (currentItemIndex != null) result.currentItemIndex = currentItemIndex;
    if (totalItems != null) result.totalItems = totalItems;
    if (destinationPath != null) result.destinationPath = destinationPath;
    return result;
  }

  TransferProgress._();

  factory TransferProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferProgress()..mergeFromBuffer(data, registry);
  factory TransferProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransferProgress()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransferProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: TransferProgress.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'transferId')
    ..aInt64(2, _omitFieldNames ? '' : 'transferredBytes')
    ..aInt64(3, _omitFieldNames ? '' : 'totalBytes')
    ..aE<TransferState>(4, _omitFieldNames ? '' : 'state',
        enumValues: TransferState.values)
    ..aInt64(5, _omitFieldNames ? '' : 'speedBps')
    ..aOM<$1.ErrorDetail>(6, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'currentFile')
    ..aI(8, _omitFieldNames ? '' : 'currentItemIndex')
    ..aI(9, _omitFieldNames ? '' : 'totalItems')
    ..aOS(10, _omitFieldNames ? '' : 'destinationPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransferProgress copyWith(void Function(TransferProgress) updates) =>
      super.copyWith((message) => updates(message as TransferProgress))
          as TransferProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransferProgress() / TransferProgress.new instead')
  static TransferProgress create() => TransferProgress._();
  static $pb.GeneratedMessage $_createMessage() => TransferProgress._();
  @$core.override
  TransferProgress createEmptyInstance() => TransferProgress._();
  @$core.pragma('dart2js:noInline')
  static TransferProgress getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferProgress>(
          TransferProgress.$_createMessage);
  static TransferProgress? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transferId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transferId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransferId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransferId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get transferredBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set transferredBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransferredBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransferredBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set totalBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  TransferState get state => $_getN(3);
  @$pb.TagNumber(4)
  set state(TransferState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasState() => $_has(3);
  @$pb.TagNumber(4)
  void clearState() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get speedBps => $_getI64(4);
  @$pb.TagNumber(5)
  set speedBps($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSpeedBps() => $_has(4);
  @$pb.TagNumber(5)
  void clearSpeedBps() => $_clearField(5);

  @$pb.TagNumber(6)
  $1.ErrorDetail get error => $_getN(5);
  @$pb.TagNumber(6)
  set error($1.ErrorDetail value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasError() => $_has(5);
  @$pb.TagNumber(6)
  void clearError() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.ErrorDetail ensureError() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.String get currentFile => $_getSZ(6);
  @$pb.TagNumber(7)
  set currentFile($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCurrentFile() => $_has(6);
  @$pb.TagNumber(7)
  void clearCurrentFile() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get currentItemIndex => $_getIZ(7);
  @$pb.TagNumber(8)
  set currentItemIndex($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCurrentItemIndex() => $_has(7);
  @$pb.TagNumber(8)
  void clearCurrentItemIndex() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get totalItems => $_getIZ(8);
  @$pb.TagNumber(9)
  set totalItems($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTotalItems() => $_has(8);
  @$pb.TagNumber(9)
  void clearTotalItems() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get destinationPath => $_getSZ(9);
  @$pb.TagNumber(10)
  set destinationPath($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDestinationPath() => $_has(9);
  @$pb.TagNumber(10)
  void clearDestinationPath() => $_clearField(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
