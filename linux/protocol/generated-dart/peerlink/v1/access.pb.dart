// This is a generated file - do not edit.
//
// Generated from peerlink/v1/access.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'access.pbenum.dart';
import 'common.pb.dart' as $0;
import 'error.pb.dart' as $1;
import 'object_reference.pbenum.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'access.pbenum.dart';

/// Remote Object Reference returned during Browse, Search, or Metadata queries
class RemoteObjectReference extends $pb.GeneratedMessage {
  factory RemoteObjectReference({
    $0.ObjectId? objectId,
    $core.String? relativePath,
    $core.String? displayName,
    $2.ObjectType? objectType,
    $fixnum.Int64? byteSize,
    $core.String? mimeType,
    $fixnum.Int64? modifiedTimeUtcMs,
    $core.String? contentHashSha256,
    $core.bool? isSymlink,
    $core.bool? isExecutable,
    $core.bool? isPreviewable,
    $core.bool? isHidden,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? attributes,
  }) {
    final result = RemoteObjectReference._();
    if (objectId != null) result.objectId = objectId;
    if (relativePath != null) result.relativePath = relativePath;
    if (displayName != null) result.displayName = displayName;
    if (objectType != null) result.objectType = objectType;
    if (byteSize != null) result.byteSize = byteSize;
    if (mimeType != null) result.mimeType = mimeType;
    if (modifiedTimeUtcMs != null) result.modifiedTimeUtcMs = modifiedTimeUtcMs;
    if (contentHashSha256 != null) result.contentHashSha256 = contentHashSha256;
    if (isSymlink != null) result.isSymlink = isSymlink;
    if (isExecutable != null) result.isExecutable = isExecutable;
    if (isPreviewable != null) result.isPreviewable = isPreviewable;
    if (isHidden != null) result.isHidden = isHidden;
    if (attributes != null) result.attributes.addEntries(attributes);
    return result;
  }

  RemoteObjectReference._();

  factory RemoteObjectReference.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoteObjectReference()..mergeFromBuffer(data, registry);
  factory RemoteObjectReference.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoteObjectReference()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoteObjectReference',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RemoteObjectReference.$_createMessage)
    ..aOM<$0.ObjectId>(1, _omitFieldNames ? '' : 'objectId',
        subBuilder: $0.ObjectId.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'relativePath')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..aE<$2.ObjectType>(4, _omitFieldNames ? '' : 'objectType',
        enumValues: $2.ObjectType.values)
    ..aInt64(5, _omitFieldNames ? '' : 'byteSize')
    ..aOS(6, _omitFieldNames ? '' : 'mimeType')
    ..aInt64(7, _omitFieldNames ? '' : 'modifiedTimeUtcMs')
    ..aOS(8, _omitFieldNames ? '' : 'contentHashSha256')
    ..aOB(9, _omitFieldNames ? '' : 'isSymlink')
    ..aOB(10, _omitFieldNames ? '' : 'isExecutable')
    ..aOB(11, _omitFieldNames ? '' : 'isPreviewable')
    ..aOB(12, _omitFieldNames ? '' : 'isHidden')
    ..m<$core.String, $core.String>(13, _omitFieldNames ? '' : 'attributes',
        entryClassName: 'RemoteObjectReference.AttributesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('peerlink.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteObjectReference clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoteObjectReference copyWith(
          void Function(RemoteObjectReference) updates) =>
      super.copyWith((message) => updates(message as RemoteObjectReference))
          as RemoteObjectReference;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoteObjectReference() / RemoteObjectReference.new instead')
  static RemoteObjectReference create() => RemoteObjectReference._();
  static $pb.GeneratedMessage $_createMessage() => RemoteObjectReference._();
  @$core.override
  RemoteObjectReference createEmptyInstance() => RemoteObjectReference._();
  @$core.pragma('dart2js:noInline')
  static RemoteObjectReference getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoteObjectReference>(
          RemoteObjectReference.$_createMessage);
  static RemoteObjectReference? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ObjectId get objectId => $_getN(0);
  @$pb.TagNumber(1)
  set objectId($0.ObjectId value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ObjectId ensureObjectId() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get relativePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set relativePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelativePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelativePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $2.ObjectType get objectType => $_getN(3);
  @$pb.TagNumber(4)
  set objectType($2.ObjectType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasObjectType() => $_has(3);
  @$pb.TagNumber(4)
  void clearObjectType() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get byteSize => $_getI64(4);
  @$pb.TagNumber(5)
  set byteSize($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasByteSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearByteSize() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get mimeType => $_getSZ(5);
  @$pb.TagNumber(6)
  set mimeType($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMimeType() => $_has(5);
  @$pb.TagNumber(6)
  void clearMimeType() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get modifiedTimeUtcMs => $_getI64(6);
  @$pb.TagNumber(7)
  set modifiedTimeUtcMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasModifiedTimeUtcMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearModifiedTimeUtcMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get contentHashSha256 => $_getSZ(7);
  @$pb.TagNumber(8)
  set contentHashSha256($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasContentHashSha256() => $_has(7);
  @$pb.TagNumber(8)
  void clearContentHashSha256() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isSymlink => $_getBF(8);
  @$pb.TagNumber(9)
  set isSymlink($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsSymlink() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsSymlink() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isExecutable => $_getBF(9);
  @$pb.TagNumber(10)
  set isExecutable($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsExecutable() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsExecutable() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get isPreviewable => $_getBF(10);
  @$pb.TagNumber(11)
  set isPreviewable($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIsPreviewable() => $_has(10);
  @$pb.TagNumber(11)
  void clearIsPreviewable() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get isHidden => $_getBF(11);
  @$pb.TagNumber(12)
  set isHidden($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIsHidden() => $_has(11);
  @$pb.TagNumber(12)
  void clearIsHidden() => $_clearField(12);

  @$pb.TagNumber(13)
  $pb.PbMap<$core.String, $core.String> get attributes => $_getMap(12);
}

/// Archive entry descriptor for safe inspection without disk extraction
class ArchiveEntryDescriptor extends $pb.GeneratedMessage {
  factory ArchiveEntryDescriptor({
    $core.String? entryPath,
    $fixnum.Int64? uncompressedSizeBytes,
    $fixnum.Int64? compressedSizeBytes,
    $core.bool? isDirectory,
    $fixnum.Int64? modifiedTimeUtcMs,
    $core.bool? isSafe,
    $core.String? warning,
  }) {
    final result = ArchiveEntryDescriptor._();
    if (entryPath != null) result.entryPath = entryPath;
    if (uncompressedSizeBytes != null)
      result.uncompressedSizeBytes = uncompressedSizeBytes;
    if (compressedSizeBytes != null)
      result.compressedSizeBytes = compressedSizeBytes;
    if (isDirectory != null) result.isDirectory = isDirectory;
    if (modifiedTimeUtcMs != null) result.modifiedTimeUtcMs = modifiedTimeUtcMs;
    if (isSafe != null) result.isSafe = isSafe;
    if (warning != null) result.warning = warning;
    return result;
  }

  ArchiveEntryDescriptor._();

  factory ArchiveEntryDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveEntryDescriptor()..mergeFromBuffer(data, registry);
  factory ArchiveEntryDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveEntryDescriptor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArchiveEntryDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: ArchiveEntryDescriptor.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'entryPath')
    ..aInt64(2, _omitFieldNames ? '' : 'uncompressedSizeBytes')
    ..aInt64(3, _omitFieldNames ? '' : 'compressedSizeBytes')
    ..aOB(4, _omitFieldNames ? '' : 'isDirectory')
    ..aInt64(5, _omitFieldNames ? '' : 'modifiedTimeUtcMs')
    ..aOB(6, _omitFieldNames ? '' : 'isSafe')
    ..aOS(7, _omitFieldNames ? '' : 'warning')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveEntryDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveEntryDescriptor copyWith(
          void Function(ArchiveEntryDescriptor) updates) =>
      super.copyWith((message) => updates(message as ArchiveEntryDescriptor))
          as ArchiveEntryDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ArchiveEntryDescriptor() / ArchiveEntryDescriptor.new instead')
  static ArchiveEntryDescriptor create() => ArchiveEntryDescriptor._();
  static $pb.GeneratedMessage $_createMessage() => ArchiveEntryDescriptor._();
  @$core.override
  ArchiveEntryDescriptor createEmptyInstance() => ArchiveEntryDescriptor._();
  @$core.pragma('dart2js:noInline')
  static ArchiveEntryDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArchiveEntryDescriptor>(
          ArchiveEntryDescriptor.$_createMessage);
  static ArchiveEntryDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get entryPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set entryPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEntryPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearEntryPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get uncompressedSizeBytes => $_getI64(1);
  @$pb.TagNumber(2)
  set uncompressedSizeBytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUncompressedSizeBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearUncompressedSizeBytes() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get compressedSizeBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set compressedSizeBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCompressedSizeBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearCompressedSizeBytes() => $_clearField(3);

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

  @$pb.TagNumber(6)
  $core.bool get isSafe => $_getBF(5);
  @$pb.TagNumber(6)
  set isSafe($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsSafe() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsSafe() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get warning => $_getSZ(6);
  @$pb.TagNumber(7)
  set warning($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasWarning() => $_has(6);
  @$pb.TagNumber(7)
  void clearWarning() => $_clearField(7);
}

/// Access Request sent from client to remote peer
class AccessRequest extends $pb.GeneratedMessage {
  factory AccessRequest({
    $0.ProtocolHeader? header,
    $core.String? requestId,
    $0.PeerId? requesterPeerId,
    $0.PeerId? targetPeerId,
    AccessRequestType? requestType,
    $core.String? shareId,
    $core.String? relativePath,
    $core.String? searchQuery,
    $core.int? maxResults,
    $core.int? maxDepth,
    $fixnum.Int64? timeoutMs,
    $core.String? paginationCursor,
    $core.String? authorizationToken,
    $core.bool? previewThumbnailOnly,
    $core.int? previewMaxBytes,
    $fixnum.Int64? clientTimestampUtcMs,
  }) {
    final result = AccessRequest._();
    if (header != null) result.header = header;
    if (requestId != null) result.requestId = requestId;
    if (requesterPeerId != null) result.requesterPeerId = requesterPeerId;
    if (targetPeerId != null) result.targetPeerId = targetPeerId;
    if (requestType != null) result.requestType = requestType;
    if (shareId != null) result.shareId = shareId;
    if (relativePath != null) result.relativePath = relativePath;
    if (searchQuery != null) result.searchQuery = searchQuery;
    if (maxResults != null) result.maxResults = maxResults;
    if (maxDepth != null) result.maxDepth = maxDepth;
    if (timeoutMs != null) result.timeoutMs = timeoutMs;
    if (paginationCursor != null) result.paginationCursor = paginationCursor;
    if (authorizationToken != null)
      result.authorizationToken = authorizationToken;
    if (previewThumbnailOnly != null)
      result.previewThumbnailOnly = previewThumbnailOnly;
    if (previewMaxBytes != null) result.previewMaxBytes = previewMaxBytes;
    if (clientTimestampUtcMs != null)
      result.clientTimestampUtcMs = clientTimestampUtcMs;
    return result;
  }

  AccessRequest._();

  factory AccessRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessRequest()..mergeFromBuffer(data, registry);
  factory AccessRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccessRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AccessRequest.$_createMessage)
    ..aOM<$0.ProtocolHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOM<$0.PeerId>(3, _omitFieldNames ? '' : 'requesterPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aOM<$0.PeerId>(4, _omitFieldNames ? '' : 'targetPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..aE<AccessRequestType>(5, _omitFieldNames ? '' : 'requestType',
        enumValues: AccessRequestType.values)
    ..aOS(6, _omitFieldNames ? '' : 'shareId')
    ..aOS(7, _omitFieldNames ? '' : 'relativePath')
    ..aOS(8, _omitFieldNames ? '' : 'searchQuery')
    ..aI(9, _omitFieldNames ? '' : 'maxResults')
    ..aI(10, _omitFieldNames ? '' : 'maxDepth')
    ..aInt64(11, _omitFieldNames ? '' : 'timeoutMs')
    ..aOS(12, _omitFieldNames ? '' : 'paginationCursor')
    ..aOS(13, _omitFieldNames ? '' : 'authorizationToken')
    ..aOB(14, _omitFieldNames ? '' : 'previewThumbnailOnly')
    ..aI(15, _omitFieldNames ? '' : 'previewMaxBytes')
    ..aInt64(16, _omitFieldNames ? '' : 'clientTimestampUtcMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessRequest copyWith(void Function(AccessRequest) updates) =>
      super.copyWith((message) => updates(message as AccessRequest))
          as AccessRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AccessRequest() / AccessRequest.new instead')
  static AccessRequest create() => AccessRequest._();
  static $pb.GeneratedMessage $_createMessage() => AccessRequest._();
  @$core.override
  AccessRequest createEmptyInstance() => AccessRequest._();
  @$core.pragma('dart2js:noInline')
  static AccessRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AccessRequest>(
          AccessRequest.$_createMessage);
  static AccessRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ProtocolHeader get header => $_getN(0);
  @$pb.TagNumber(1)
  set header($0.ProtocolHeader value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHeader() => $_has(0);
  @$pb.TagNumber(1)
  void clearHeader() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ProtocolHeader ensureHeader() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.PeerId get requesterPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPeerId($0.PeerId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRequesterPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PeerId ensureRequesterPeerId() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.PeerId get targetPeerId => $_getN(3);
  @$pb.TagNumber(4)
  set targetPeerId($0.PeerId value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTargetPeerId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTargetPeerId() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.PeerId ensureTargetPeerId() => $_ensure(3);

  @$pb.TagNumber(5)
  AccessRequestType get requestType => $_getN(4);
  @$pb.TagNumber(5)
  set requestType(AccessRequestType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRequestType() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get shareId => $_getSZ(5);
  @$pb.TagNumber(6)
  set shareId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasShareId() => $_has(5);
  @$pb.TagNumber(6)
  void clearShareId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get relativePath => $_getSZ(6);
  @$pb.TagNumber(7)
  set relativePath($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRelativePath() => $_has(6);
  @$pb.TagNumber(7)
  void clearRelativePath() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get searchQuery => $_getSZ(7);
  @$pb.TagNumber(8)
  set searchQuery($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSearchQuery() => $_has(7);
  @$pb.TagNumber(8)
  void clearSearchQuery() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get maxResults => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxResults($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxResults() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxResults() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get maxDepth => $_getIZ(9);
  @$pb.TagNumber(10)
  set maxDepth($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMaxDepth() => $_has(9);
  @$pb.TagNumber(10)
  void clearMaxDepth() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get timeoutMs => $_getI64(10);
  @$pb.TagNumber(11)
  set timeoutMs($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTimeoutMs() => $_has(10);
  @$pb.TagNumber(11)
  void clearTimeoutMs() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get paginationCursor => $_getSZ(11);
  @$pb.TagNumber(12)
  set paginationCursor($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasPaginationCursor() => $_has(11);
  @$pb.TagNumber(12)
  void clearPaginationCursor() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get authorizationToken => $_getSZ(12);
  @$pb.TagNumber(13)
  set authorizationToken($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAuthorizationToken() => $_has(12);
  @$pb.TagNumber(13)
  void clearAuthorizationToken() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get previewThumbnailOnly => $_getBF(13);
  @$pb.TagNumber(14)
  set previewThumbnailOnly($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasPreviewThumbnailOnly() => $_has(13);
  @$pb.TagNumber(14)
  void clearPreviewThumbnailOnly() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get previewMaxBytes => $_getIZ(14);
  @$pb.TagNumber(15)
  set previewMaxBytes($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasPreviewMaxBytes() => $_has(14);
  @$pb.TagNumber(15)
  void clearPreviewMaxBytes() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get clientTimestampUtcMs => $_getI64(15);
  @$pb.TagNumber(16)
  set clientTimestampUtcMs($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasClientTimestampUtcMs() => $_has(15);
  @$pb.TagNumber(16)
  void clearClientTimestampUtcMs() => $_clearField(16);
}

/// Access Response returned from remote peer
class AccessResponse extends $pb.GeneratedMessage {
  factory AccessResponse({
    $0.ProtocolHeader? header,
    $core.String? requestId,
    $core.bool? success,
    $core.Iterable<RemoteObjectReference>? items,
    $core.String? nextPaginationCursor,
    $core.bool? hasMore,
    $core.int? totalMatching,
    $core.List<$core.int>? previewData,
    $core.String? previewMimeType,
    $core.Iterable<ArchiveEntryDescriptor>? archiveEntries,
    $1.ErrorDetail? error,
    $fixnum.Int64? executionTimeMs,
  }) {
    final result = AccessResponse._();
    if (header != null) result.header = header;
    if (requestId != null) result.requestId = requestId;
    if (success != null) result.success = success;
    if (items != null) result.items.addAll(items);
    if (nextPaginationCursor != null)
      result.nextPaginationCursor = nextPaginationCursor;
    if (hasMore != null) result.hasMore = hasMore;
    if (totalMatching != null) result.totalMatching = totalMatching;
    if (previewData != null) result.previewData = previewData;
    if (previewMimeType != null) result.previewMimeType = previewMimeType;
    if (archiveEntries != null) result.archiveEntries.addAll(archiveEntries);
    if (error != null) result.error = error;
    if (executionTimeMs != null) result.executionTimeMs = executionTimeMs;
    return result;
  }

  AccessResponse._();

  factory AccessResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessResponse()..mergeFromBuffer(data, registry);
  factory AccessResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccessResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AccessResponse.$_createMessage)
    ..aOM<$0.ProtocolHeader>(1, _omitFieldNames ? '' : 'header',
        subBuilder: $0.ProtocolHeader.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOB(3, _omitFieldNames ? '' : 'success')
    ..pPM<RemoteObjectReference>(4, _omitFieldNames ? '' : 'items',
        subBuilder: RemoteObjectReference.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'nextPaginationCursor')
    ..aOB(6, _omitFieldNames ? '' : 'hasMore')
    ..aI(7, _omitFieldNames ? '' : 'totalMatching')
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'previewData', $pb.PbFieldType.OY)
    ..aOS(9, _omitFieldNames ? '' : 'previewMimeType')
    ..pPM<ArchiveEntryDescriptor>(10, _omitFieldNames ? '' : 'archiveEntries',
        subBuilder: ArchiveEntryDescriptor.$_createMessage)
    ..aOM<$1.ErrorDetail>(11, _omitFieldNames ? '' : 'error',
        subBuilder: $1.ErrorDetail.$_createMessage)
    ..aInt64(12, _omitFieldNames ? '' : 'executionTimeMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessResponse copyWith(void Function(AccessResponse) updates) =>
      super.copyWith((message) => updates(message as AccessResponse))
          as AccessResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AccessResponse() / AccessResponse.new instead')
  static AccessResponse create() => AccessResponse._();
  static $pb.GeneratedMessage $_createMessage() => AccessResponse._();
  @$core.override
  AccessResponse createEmptyInstance() => AccessResponse._();
  @$core.pragma('dart2js:noInline')
  static AccessResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AccessResponse>(
          AccessResponse.$_createMessage);
  static AccessResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ProtocolHeader get header => $_getN(0);
  @$pb.TagNumber(1)
  set header($0.ProtocolHeader value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHeader() => $_has(0);
  @$pb.TagNumber(1)
  void clearHeader() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ProtocolHeader ensureHeader() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get success => $_getBF(2);
  @$pb.TagNumber(3)
  set success($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSuccess() => $_has(2);
  @$pb.TagNumber(3)
  void clearSuccess() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<RemoteObjectReference> get items => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get nextPaginationCursor => $_getSZ(4);
  @$pb.TagNumber(5)
  set nextPaginationCursor($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNextPaginationCursor() => $_has(4);
  @$pb.TagNumber(5)
  void clearNextPaginationCursor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get hasMore => $_getBF(5);
  @$pb.TagNumber(6)
  set hasMore($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHasMore() => $_has(5);
  @$pb.TagNumber(6)
  void clearHasMore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get totalMatching => $_getIZ(6);
  @$pb.TagNumber(7)
  set totalMatching($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalMatching() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalMatching() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get previewData => $_getN(7);
  @$pb.TagNumber(8)
  set previewData($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPreviewData() => $_has(7);
  @$pb.TagNumber(8)
  void clearPreviewData() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get previewMimeType => $_getSZ(8);
  @$pb.TagNumber(9)
  set previewMimeType($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasPreviewMimeType() => $_has(8);
  @$pb.TagNumber(9)
  void clearPreviewMimeType() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<ArchiveEntryDescriptor> get archiveEntries => $_getList(9);

  @$pb.TagNumber(11)
  $1.ErrorDetail get error => $_getN(10);
  @$pb.TagNumber(11)
  set error($1.ErrorDetail value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasError() => $_has(10);
  @$pb.TagNumber(11)
  void clearError() => $_clearField(11);
  @$pb.TagNumber(11)
  $1.ErrorDetail ensureError() => $_ensure(10);

  @$pb.TagNumber(12)
  $fixnum.Int64 get executionTimeMs => $_getI64(11);
  @$pb.TagNumber(12)
  set executionTimeMs($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasExecutionTimeMs() => $_has(11);
  @$pb.TagNumber(12)
  void clearExecutionTimeMs() => $_clearField(12);
}

/// Request to cancel an ongoing access operation
class AccessCancelRequest extends $pb.GeneratedMessage {
  factory AccessCancelRequest({
    $core.String? requestId,
    $core.String? reason,
    $0.PeerId? requesterPeerId,
  }) {
    final result = AccessCancelRequest._();
    if (requestId != null) result.requestId = requestId;
    if (reason != null) result.reason = reason;
    if (requesterPeerId != null) result.requesterPeerId = requesterPeerId;
    return result;
  }

  AccessCancelRequest._();

  factory AccessCancelRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessCancelRequest()..mergeFromBuffer(data, registry);
  factory AccessCancelRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessCancelRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccessCancelRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AccessCancelRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aOM<$0.PeerId>(3, _omitFieldNames ? '' : 'requesterPeerId',
        subBuilder: $0.PeerId.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessCancelRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessCancelRequest copyWith(void Function(AccessCancelRequest) updates) =>
      super.copyWith((message) => updates(message as AccessCancelRequest))
          as AccessCancelRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use AccessCancelRequest() / AccessCancelRequest.new instead')
  static AccessCancelRequest create() => AccessCancelRequest._();
  static $pb.GeneratedMessage $_createMessage() => AccessCancelRequest._();
  @$core.override
  AccessCancelRequest createEmptyInstance() => AccessCancelRequest._();
  @$core.pragma('dart2js:noInline')
  static AccessCancelRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccessCancelRequest>(
          AccessCancelRequest.$_createMessage);
  static AccessCancelRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.PeerId get requesterPeerId => $_getN(2);
  @$pb.TagNumber(3)
  set requesterPeerId($0.PeerId value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRequesterPeerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequesterPeerId() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.PeerId ensureRequesterPeerId() => $_ensure(2);
}

/// Response acknowledging cancellation
class AccessCancelResponse extends $pb.GeneratedMessage {
  factory AccessCancelResponse({
    $core.String? requestId,
    $core.bool? cancelled,
    $core.String? message,
  }) {
    final result = AccessCancelResponse._();
    if (requestId != null) result.requestId = requestId;
    if (cancelled != null) result.cancelled = cancelled;
    if (message != null) result.message = message;
    return result;
  }

  AccessCancelResponse._();

  factory AccessCancelResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessCancelResponse()..mergeFromBuffer(data, registry);
  factory AccessCancelResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessCancelResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccessCancelResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AccessCancelResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOB(2, _omitFieldNames ? '' : 'cancelled')
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessCancelResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessCancelResponse copyWith(void Function(AccessCancelResponse) updates) =>
      super.copyWith((message) => updates(message as AccessCancelResponse))
          as AccessCancelResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AccessCancelResponse() / AccessCancelResponse.new instead')
  static AccessCancelResponse create() => AccessCancelResponse._();
  static $pb.GeneratedMessage $_createMessage() => AccessCancelResponse._();
  @$core.override
  AccessCancelResponse createEmptyInstance() => AccessCancelResponse._();
  @$core.pragma('dart2js:noInline')
  static AccessCancelResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccessCancelResponse>(
          AccessCancelResponse.$_createMessage);
  static AccessCancelResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get cancelled => $_getBF(1);
  @$pb.TagNumber(2)
  set cancelled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCancelled() => $_has(1);
  @$pb.TagNumber(2)
  void clearCancelled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);
}

enum AccessWireMessage_Payload {
  request,
  response,
  cancelRequest,
  cancelResponse,
  notSet
}

/// Wire carrier wrapper for remote access protocol messages
class AccessWireMessage extends $pb.GeneratedMessage {
  factory AccessWireMessage({
    AccessRequest? request,
    AccessResponse? response,
    AccessCancelRequest? cancelRequest,
    AccessCancelResponse? cancelResponse,
  }) {
    final result = AccessWireMessage._();
    if (request != null) result.request = request;
    if (response != null) result.response = response;
    if (cancelRequest != null) result.cancelRequest = cancelRequest;
    if (cancelResponse != null) result.cancelResponse = cancelResponse;
    return result;
  }

  AccessWireMessage._();

  factory AccessWireMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessWireMessage()..mergeFromBuffer(data, registry);
  factory AccessWireMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AccessWireMessage()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AccessWireMessage_Payload>
      _AccessWireMessage_PayloadByTag = {
    1: AccessWireMessage_Payload.request,
    2: AccessWireMessage_Payload.response,
    3: AccessWireMessage_Payload.cancelRequest,
    4: AccessWireMessage_Payload.cancelResponse,
    0: AccessWireMessage_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccessWireMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: AccessWireMessage.$_createMessage)
    ..oo(0, [1, 2, 3, 4])
    ..aOM<AccessRequest>(1, _omitFieldNames ? '' : 'request',
        subBuilder: AccessRequest.$_createMessage)
    ..aOM<AccessResponse>(2, _omitFieldNames ? '' : 'response',
        subBuilder: AccessResponse.$_createMessage)
    ..aOM<AccessCancelRequest>(3, _omitFieldNames ? '' : 'cancelRequest',
        subBuilder: AccessCancelRequest.$_createMessage)
    ..aOM<AccessCancelResponse>(4, _omitFieldNames ? '' : 'cancelResponse',
        subBuilder: AccessCancelResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessWireMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccessWireMessage copyWith(void Function(AccessWireMessage) updates) =>
      super.copyWith((message) => updates(message as AccessWireMessage))
          as AccessWireMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AccessWireMessage() / AccessWireMessage.new instead')
  static AccessWireMessage create() => AccessWireMessage._();
  static $pb.GeneratedMessage $_createMessage() => AccessWireMessage._();
  @$core.override
  AccessWireMessage createEmptyInstance() => AccessWireMessage._();
  @$core.pragma('dart2js:noInline')
  static AccessWireMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AccessWireMessage>(
          AccessWireMessage.$_createMessage);
  static AccessWireMessage? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  AccessWireMessage_Payload whichPayload() =>
      _AccessWireMessage_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  AccessRequest get request => $_getN(0);
  @$pb.TagNumber(1)
  set request(AccessRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRequest() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequest() => $_clearField(1);
  @$pb.TagNumber(1)
  AccessRequest ensureRequest() => $_ensure(0);

  @$pb.TagNumber(2)
  AccessResponse get response => $_getN(1);
  @$pb.TagNumber(2)
  set response(AccessResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  AccessResponse ensureResponse() => $_ensure(1);

  @$pb.TagNumber(3)
  AccessCancelRequest get cancelRequest => $_getN(2);
  @$pb.TagNumber(3)
  set cancelRequest(AccessCancelRequest value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCancelRequest() => $_has(2);
  @$pb.TagNumber(3)
  void clearCancelRequest() => $_clearField(3);
  @$pb.TagNumber(3)
  AccessCancelRequest ensureCancelRequest() => $_ensure(2);

  @$pb.TagNumber(4)
  AccessCancelResponse get cancelResponse => $_getN(3);
  @$pb.TagNumber(4)
  set cancelResponse(AccessCancelResponse value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCancelResponse() => $_has(3);
  @$pb.TagNumber(4)
  void clearCancelResponse() => $_clearField(4);
  @$pb.TagNumber(4)
  AccessCancelResponse ensureCancelResponse() => $_ensure(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
