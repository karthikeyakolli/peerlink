// This is a generated file - do not edit.
//
// Generated from peerlink/v1/backup.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'backup.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'backup.pbenum.dart';

class HistoricalVersionProto extends $pb.GeneratedMessage {
  factory HistoricalVersionProto({
    $core.String? objectId,
    $core.String? relativePath,
    $core.String? contentHash,
    $fixnum.Int64? sizeBytes,
    $fixnum.Int64? versionSequence,
    $fixnum.Int64? capturedAtUtcMs,
    $core.bool? isDeleted,
    $core.String? storageHash,
    $core.bool? isEncrypted,
    $core.bool? isProtected,
  }) {
    final result = HistoricalVersionProto._();
    if (objectId != null) result.objectId = objectId;
    if (relativePath != null) result.relativePath = relativePath;
    if (contentHash != null) result.contentHash = contentHash;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (versionSequence != null) result.versionSequence = versionSequence;
    if (capturedAtUtcMs != null) result.capturedAtUtcMs = capturedAtUtcMs;
    if (isDeleted != null) result.isDeleted = isDeleted;
    if (storageHash != null) result.storageHash = storageHash;
    if (isEncrypted != null) result.isEncrypted = isEncrypted;
    if (isProtected != null) result.isProtected = isProtected;
    return result;
  }

  HistoricalVersionProto._();

  factory HistoricalVersionProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HistoricalVersionProto()..mergeFromBuffer(data, registry);
  factory HistoricalVersionProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HistoricalVersionProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistoricalVersionProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: HistoricalVersionProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'objectId')
    ..aOS(2, _omitFieldNames ? '' : 'relativePath')
    ..aOS(3, _omitFieldNames ? '' : 'contentHash')
    ..aInt64(4, _omitFieldNames ? '' : 'sizeBytes')
    ..aInt64(5, _omitFieldNames ? '' : 'versionSequence')
    ..aInt64(6, _omitFieldNames ? '' : 'capturedAtUtcMs')
    ..aOB(7, _omitFieldNames ? '' : 'isDeleted')
    ..aOS(8, _omitFieldNames ? '' : 'storageHash')
    ..aOB(9, _omitFieldNames ? '' : 'isEncrypted')
    ..aOB(10, _omitFieldNames ? '' : 'isProtected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoricalVersionProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HistoricalVersionProto copyWith(
          void Function(HistoricalVersionProto) updates) =>
      super.copyWith((message) => updates(message as HistoricalVersionProto))
          as HistoricalVersionProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use HistoricalVersionProto() / HistoricalVersionProto.new instead')
  static HistoricalVersionProto create() => HistoricalVersionProto._();
  static $pb.GeneratedMessage $_createMessage() => HistoricalVersionProto._();
  @$core.override
  HistoricalVersionProto createEmptyInstance() => HistoricalVersionProto._();
  @$core.pragma('dart2js:noInline')
  static HistoricalVersionProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistoricalVersionProto>(
          HistoricalVersionProto.$_createMessage);
  static HistoricalVersionProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get objectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set objectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasObjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearObjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get relativePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set relativePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelativePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelativePath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get contentHash => $_getSZ(2);
  @$pb.TagNumber(3)
  set contentHash($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContentHash() => $_has(2);
  @$pb.TagNumber(3)
  void clearContentHash() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearSizeBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get versionSequence => $_getI64(4);
  @$pb.TagNumber(5)
  set versionSequence($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVersionSequence() => $_has(4);
  @$pb.TagNumber(5)
  void clearVersionSequence() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get capturedAtUtcMs => $_getI64(5);
  @$pb.TagNumber(6)
  set capturedAtUtcMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCapturedAtUtcMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearCapturedAtUtcMs() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isDeleted => $_getBF(6);
  @$pb.TagNumber(7)
  set isDeleted($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsDeleted() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsDeleted() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get storageHash => $_getSZ(7);
  @$pb.TagNumber(8)
  set storageHash($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStorageHash() => $_has(7);
  @$pb.TagNumber(8)
  void clearStorageHash() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isEncrypted => $_getBF(8);
  @$pb.TagNumber(9)
  set isEncrypted($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsEncrypted() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsEncrypted() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isProtected => $_getBF(9);
  @$pb.TagNumber(10)
  set isProtected($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsProtected() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsProtected() => $_clearField(10);
}

class BackupManifestProto extends $pb.GeneratedMessage {
  factory BackupManifestProto({
    $core.String? backupId,
    $core.String? jobId,
    BackupTypeProto? backupType,
    $fixnum.Int64? snapshotTimestampUtcMs,
    $core.String? parentBackupId,
    $fixnum.Int64? totalFiles,
    $fixnum.Int64? totalBytes,
    $core.bool? isBlind,
    $core.String? manifestDigest,
    $core.Iterable<HistoricalVersionProto>? items,
  }) {
    final result = BackupManifestProto._();
    if (backupId != null) result.backupId = backupId;
    if (jobId != null) result.jobId = jobId;
    if (backupType != null) result.backupType = backupType;
    if (snapshotTimestampUtcMs != null)
      result.snapshotTimestampUtcMs = snapshotTimestampUtcMs;
    if (parentBackupId != null) result.parentBackupId = parentBackupId;
    if (totalFiles != null) result.totalFiles = totalFiles;
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (isBlind != null) result.isBlind = isBlind;
    if (manifestDigest != null) result.manifestDigest = manifestDigest;
    if (items != null) result.items.addAll(items);
    return result;
  }

  BackupManifestProto._();

  factory BackupManifestProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupManifestProto()..mergeFromBuffer(data, registry);
  factory BackupManifestProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupManifestProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupManifestProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: BackupManifestProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'backupId')
    ..aOS(2, _omitFieldNames ? '' : 'jobId')
    ..aE<BackupTypeProto>(3, _omitFieldNames ? '' : 'backupType',
        enumValues: BackupTypeProto.values)
    ..aInt64(4, _omitFieldNames ? '' : 'snapshotTimestampUtcMs')
    ..aOS(5, _omitFieldNames ? '' : 'parentBackupId')
    ..aInt64(6, _omitFieldNames ? '' : 'totalFiles')
    ..aInt64(7, _omitFieldNames ? '' : 'totalBytes')
    ..aOB(8, _omitFieldNames ? '' : 'isBlind')
    ..aOS(9, _omitFieldNames ? '' : 'manifestDigest')
    ..pPM<HistoricalVersionProto>(10, _omitFieldNames ? '' : 'items',
        subBuilder: HistoricalVersionProto.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupManifestProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupManifestProto copyWith(void Function(BackupManifestProto) updates) =>
      super.copyWith((message) => updates(message as BackupManifestProto))
          as BackupManifestProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use BackupManifestProto() / BackupManifestProto.new instead')
  static BackupManifestProto create() => BackupManifestProto._();
  static $pb.GeneratedMessage $_createMessage() => BackupManifestProto._();
  @$core.override
  BackupManifestProto createEmptyInstance() => BackupManifestProto._();
  @$core.pragma('dart2js:noInline')
  static BackupManifestProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupManifestProto>(
          BackupManifestProto.$_createMessage);
  static BackupManifestProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set backupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackupId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get jobId => $_getSZ(1);
  @$pb.TagNumber(2)
  set jobId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJobId() => $_has(1);
  @$pb.TagNumber(2)
  void clearJobId() => $_clearField(2);

  @$pb.TagNumber(3)
  BackupTypeProto get backupType => $_getN(2);
  @$pb.TagNumber(3)
  set backupType(BackupTypeProto value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBackupType() => $_has(2);
  @$pb.TagNumber(3)
  void clearBackupType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get snapshotTimestampUtcMs => $_getI64(3);
  @$pb.TagNumber(4)
  set snapshotTimestampUtcMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSnapshotTimestampUtcMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearSnapshotTimestampUtcMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get parentBackupId => $_getSZ(4);
  @$pb.TagNumber(5)
  set parentBackupId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParentBackupId() => $_has(4);
  @$pb.TagNumber(5)
  void clearParentBackupId() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get totalFiles => $_getI64(5);
  @$pb.TagNumber(6)
  set totalFiles($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTotalFiles() => $_has(5);
  @$pb.TagNumber(6)
  void clearTotalFiles() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get totalBytes => $_getI64(6);
  @$pb.TagNumber(7)
  set totalBytes($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalBytes() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalBytes() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isBlind => $_getBF(7);
  @$pb.TagNumber(8)
  set isBlind($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsBlind() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsBlind() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get manifestDigest => $_getSZ(8);
  @$pb.TagNumber(9)
  set manifestDigest($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasManifestDigest() => $_has(8);
  @$pb.TagNumber(9)
  void clearManifestDigest() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<HistoricalVersionProto> get items => $_getList(9);
}

class RestorePlanProto extends $pb.GeneratedMessage {
  factory RestorePlanProto({
    $core.String? backupId,
    $core.String? targetDirectory,
    RestoreConflictPolicyProto? conflictPolicy,
    $core.Iterable<$core.String>? selectedPaths,
  }) {
    final result = RestorePlanProto._();
    if (backupId != null) result.backupId = backupId;
    if (targetDirectory != null) result.targetDirectory = targetDirectory;
    if (conflictPolicy != null) result.conflictPolicy = conflictPolicy;
    if (selectedPaths != null) result.selectedPaths.addAll(selectedPaths);
    return result;
  }

  RestorePlanProto._();

  factory RestorePlanProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestorePlanProto()..mergeFromBuffer(data, registry);
  factory RestorePlanProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestorePlanProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestorePlanProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RestorePlanProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'backupId')
    ..aOS(2, _omitFieldNames ? '' : 'targetDirectory')
    ..aE<RestoreConflictPolicyProto>(3, _omitFieldNames ? '' : 'conflictPolicy',
        enumValues: RestoreConflictPolicyProto.values)
    ..pPS(4, _omitFieldNames ? '' : 'selectedPaths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestorePlanProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestorePlanProto copyWith(void Function(RestorePlanProto) updates) =>
      super.copyWith((message) => updates(message as RestorePlanProto))
          as RestorePlanProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RestorePlanProto() / RestorePlanProto.new instead')
  static RestorePlanProto create() => RestorePlanProto._();
  static $pb.GeneratedMessage $_createMessage() => RestorePlanProto._();
  @$core.override
  RestorePlanProto createEmptyInstance() => RestorePlanProto._();
  @$core.pragma('dart2js:noInline')
  static RestorePlanProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RestorePlanProto>(
          RestorePlanProto.$_createMessage);
  static RestorePlanProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set backupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackupId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetDirectory => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetDirectory($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetDirectory() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetDirectory() => $_clearField(2);

  @$pb.TagNumber(3)
  RestoreConflictPolicyProto get conflictPolicy => $_getN(2);
  @$pb.TagNumber(3)
  set conflictPolicy(RestoreConflictPolicyProto value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConflictPolicy() => $_has(2);
  @$pb.TagNumber(3)
  void clearConflictPolicy() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get selectedPaths => $_getList(3);
}

class RestoreResultProto extends $pb.GeneratedMessage {
  factory RestoreResultProto({
    $core.String? restoreId,
    $core.String? backupId,
    $core.bool? success,
    $fixnum.Int64? restoredFilesCount,
    $fixnum.Int64? restoredBytes,
    $fixnum.Int64? createdVersionsCount,
    $core.String? errorMessage,
  }) {
    final result = RestoreResultProto._();
    if (restoreId != null) result.restoreId = restoreId;
    if (backupId != null) result.backupId = backupId;
    if (success != null) result.success = success;
    if (restoredFilesCount != null)
      result.restoredFilesCount = restoredFilesCount;
    if (restoredBytes != null) result.restoredBytes = restoredBytes;
    if (createdVersionsCount != null)
      result.createdVersionsCount = createdVersionsCount;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  RestoreResultProto._();

  factory RestoreResultProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreResultProto()..mergeFromBuffer(data, registry);
  factory RestoreResultProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreResultProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreResultProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'peerlink.v1'),
      createEmptyInstance: RestoreResultProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'restoreId')
    ..aOS(2, _omitFieldNames ? '' : 'backupId')
    ..aOB(3, _omitFieldNames ? '' : 'success')
    ..aInt64(4, _omitFieldNames ? '' : 'restoredFilesCount')
    ..aInt64(5, _omitFieldNames ? '' : 'restoredBytes')
    ..aInt64(6, _omitFieldNames ? '' : 'createdVersionsCount')
    ..aOS(7, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreResultProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreResultProto copyWith(void Function(RestoreResultProto) updates) =>
      super.copyWith((message) => updates(message as RestoreResultProto))
          as RestoreResultProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RestoreResultProto() / RestoreResultProto.new instead')
  static RestoreResultProto create() => RestoreResultProto._();
  static $pb.GeneratedMessage $_createMessage() => RestoreResultProto._();
  @$core.override
  RestoreResultProto createEmptyInstance() => RestoreResultProto._();
  @$core.pragma('dart2js:noInline')
  static RestoreResultProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreResultProto>(
          RestoreResultProto.$_createMessage);
  static RestoreResultProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get restoreId => $_getSZ(0);
  @$pb.TagNumber(1)
  set restoreId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRestoreId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRestoreId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get backupId => $_getSZ(1);
  @$pb.TagNumber(2)
  set backupId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBackupId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBackupId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get success => $_getBF(2);
  @$pb.TagNumber(3)
  set success($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSuccess() => $_has(2);
  @$pb.TagNumber(3)
  void clearSuccess() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get restoredFilesCount => $_getI64(3);
  @$pb.TagNumber(4)
  set restoredFilesCount($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestoredFilesCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestoredFilesCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get restoredBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set restoredBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRestoredBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearRestoredBytes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdVersionsCount => $_getI64(5);
  @$pb.TagNumber(6)
  set createdVersionsCount($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedVersionsCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedVersionsCount() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get errorMessage => $_getSZ(6);
  @$pb.TagNumber(7)
  set errorMessage($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasErrorMessage() => $_has(6);
  @$pb.TagNumber(7)
  void clearErrorMessage() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
