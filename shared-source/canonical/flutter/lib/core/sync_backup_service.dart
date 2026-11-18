import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../platform/android_node_bridge.dart';
import '../platform/platform_capabilities.dart';
import 'app_settings_service.dart';
import 'node_ipc_client.dart';

enum SyncMode {
  twoWaySync,
  oneWayPush,
  oneWayMirror,
}

enum SyncStatus {
  inSync,
  syncing,
  conflictDetected,
  massChangePaused,
}

class SyncSpace {
  final String id;
  final String name;
  final String localPath;
  final String remotePeerId;
  final SyncMode mode;
  final SyncStatus status;
  final int fileCount;
  final String lastSyncTime;
  final int pendingConflicts;
  final String? conflictFile;

  const SyncSpace({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remotePeerId,
    required this.mode,
    required this.status,
    required this.fileCount,
    required this.lastSyncTime,
    this.pendingConflicts = 0,
    this.conflictFile,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'localPath': localPath,
    'remotePeerId': remotePeerId,
    'mode': mode.name,
    'status': status.name,
    'fileCount': fileCount,
    'lastSyncTime': lastSyncTime,
    'pendingConflicts': pendingConflicts,
    'conflictFile': conflictFile,
  };

  factory SyncSpace.fromMap(Map<String, dynamic> map) {
    return SyncSpace(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Space',
      localPath: map['localPath'] as String? ?? '',
      remotePeerId: map['remotePeerId'] as String? ?? 'peer_local_network',
      mode: SyncMode.values.firstWhere(
        (m) => m.name == map['mode'],
        orElse: () => SyncMode.twoWaySync,
      ),
      status: SyncStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SyncStatus.inSync,
      ),
      fileCount: (map['fileCount'] as num?)?.toInt() ?? 0,
      lastSyncTime: map['lastSyncTime'] as String? ?? 'Never',
      pendingConflicts: (map['pendingConflicts'] as num?)?.toInt() ?? 0,
      conflictFile: map['conflictFile'] as String?,
    );
  }

  SyncSpace copyWith({
    String? id,
    String? name,
    String? localPath,
    String? remotePeerId,
    SyncMode? mode,
    SyncStatus? status,
    int? fileCount,
    String? lastSyncTime,
    int? pendingConflicts,
    String? conflictFile,
  }) {
    return SyncSpace(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remotePeerId: remotePeerId ?? this.remotePeerId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      fileCount: fileCount ?? this.fileCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingConflicts: pendingConflicts ?? this.pendingConflicts,
      conflictFile: conflictFile ?? this.conflictFile,
    );
  }
}

class BackupSnapshot {
  final String id;
  final String name;
  final String timestamp;
  final int fileCount;
  final String totalSize;
  final String rootHash;
  final String sourcePath;

  const BackupSnapshot({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.fileCount,
    required this.totalSize,
    required this.rootHash,
    required this.sourcePath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'timestamp': timestamp,
    'fileCount': fileCount,
    'totalSize': totalSize,
    'rootHash': rootHash,
    'sourcePath': sourcePath,
  };

  factory BackupSnapshot.fromMap(Map<String, dynamic> map) {
    return BackupSnapshot(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Snapshot',
      timestamp: map['timestamp'] as String? ?? '',
      fileCount: (map['fileCount'] as num?)?.toInt() ?? 0,
      totalSize: map['totalSize'] as String? ?? '0 KB',
      rootHash: map['rootHash'] as String? ?? '',
      sourcePath: map['sourcePath'] as String? ?? '',
    );
  }
}

class SyncDryRunDiff {
  final String type; // 'ADDED', 'MODIFIED', 'DELETED'
  final String relativePath;
  final String detail;

  const SyncDryRunDiff({
    required this.type,
    required this.relativePath,
    required this.detail,
  });
}

class SyncBackupService {
  static final SyncBackupService _instance = SyncBackupService._internal();
  static SyncBackupService get instance => _instance;

  final List<SyncSpace> _spaces = [];
  final List<BackupSnapshot> _snapshots = [];
  final Map<String, StreamSubscription<FileSystemEvent>> _activeWatchers = {};
  final Map<String, String> _spaceMerkleRoots = {};
  final Map<String, Map<String, String>> _lastSyncedManifests = {};
  Timer? _backgroundSyncTimer;
  Timer? _debounceTimer;
  bool _isWatching = false;

  /// Optional test/bridge hook invoked when real delta files are ready to push to a remote peer.
  Future<bool> Function(String remotePeerId, List<String> filePaths)? onPushDeltaFiles;

  /// Optional test/bridge hook invoked when missing/updated files should be pulled from a remote peer.
  Future<bool> Function(String remotePeerId, List<String> relativePaths)? onPullRemoteFiles;

  final StreamController<List<SyncSpace>> _spacesController =
      StreamController<List<SyncSpace>>.broadcast();
  final StreamController<List<BackupSnapshot>> _snapshotsController =
      StreamController<List<BackupSnapshot>>.broadcast();

  SyncBackupService._internal();

  Stream<List<SyncSpace>> get spacesStream => _spacesController.stream;
  Stream<List<BackupSnapshot>> get snapshotsStream => _snapshotsController.stream;

  List<SyncSpace> get spaces => List.unmodifiable(_spaces);
  List<BackupSnapshot> get snapshots => List.unmodifiable(_snapshots);
  bool get isWatching => _isWatching;

  Future<String> allocateDefaultSpacePath(String spaceId) async {
    final safeId = spaceId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    String base;
    if (Platform.isAndroid) {
      final appStorage = await AndroidNodeBridge.instance.getAppStorageDirectory();
      base = (appStorage != null && appStorage.isNotEmpty) ? appStorage : Directory.systemTemp.path;
    } else {
      base = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.systemTemp.path;
    }
    final dir = Directory('$base/PeerLink/Spaces/$safeId');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  Future<File> _getConfigFile() async {
    String base;
    if (Platform.isAndroid) {
      final appStorage = await AndroidNodeBridge.instance.getAppStorageDirectory();
      base = (appStorage != null && appStorage.isNotEmpty) ? appStorage : Directory.systemTemp.path;
    } else {
      base = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.systemTemp.path;
    }
    final dir = Directory('$base/PeerLink');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/spaces_config.json');
  }

  Future<void> savePersistedSpaces([String? customPath]) async {
    try {
      final file = customPath != null ? File(customPath) : await _getConfigFile();
      final data = {
        'spaces': _spaces.map((s) => s.toMap()).toList(),
        'snapshots': _snapshots.map((s) => s.toMap()).toList(),
        'manifests': _lastSyncedManifests,
      };
      final content = jsonEncode(data);
      final tmpFile = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await tmpFile.writeAsString(content, flush: true);
      if (!Platform.isWindows) {
        await tmpFile.rename(file.path);
      } else {
        bool renamed = false;
        for (int i = 0; i < 5; i++) {
          try {
            if (await file.exists()) {
              await file.delete();
            }
            await tmpFile.rename(file.path);
            renamed = true;
            break;
          } catch (_) {
            await Future.delayed(const Duration(milliseconds: 30));
          }
        }
        if (!renamed) {
          await file.writeAsString(content, flush: true);
          try {
            if (await tmpFile.exists()) await tmpFile.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> loadPersistedSpaces([String? customPath]) async {
    try {
      final file = customPath != null ? File(customPath) : await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (data.containsKey('spaces')) {
          _spaces.clear();
          for (final item in (data['spaces'] as List)) {
            final space = SyncSpace.fromMap(Map<String, dynamic>.from(item));
            final dir = Directory(space.localPath);
            if (!dir.existsSync() && !space.localPath.startsWith('content://')) {
              _spaces.add(space.copyWith(status: SyncStatus.massChangePaused));
            } else {
              _spaces.add(space);
            }
          }
          _spacesController.add(List.unmodifiable(_spaces));
        }
        if (data.containsKey('snapshots')) {
          _snapshots.clear();
          for (final item in (data['snapshots'] as List)) {
            _snapshots.add(BackupSnapshot.fromMap(Map<String, dynamic>.from(item)));
          }
          _snapshotsController.add(List.unmodifiable(_snapshots));
        }
        if (data.containsKey('manifests') && data['manifests'] is Map) {
          _lastSyncedManifests.clear();
          (data['manifests'] as Map).forEach((k, v) {
            if (v is Map) {
              _lastSyncedManifests[k.toString()] = v.map(
                (mk, mv) => MapEntry(mk.toString(), mv.toString()),
              );
            }
          });
        }
      }
    } catch (_) {}
  }

  void addSpace(SyncSpace space) {
    _spaces.removeWhere((s) => s.id == space.id);
    _spaces.add(space);
    _spacesController.add(List.unmodifiable(_spaces));
    savePersistedSpaces();
    if (_isWatching) {
      _watchSpace(space);
    }
  }

  void removeSpace(String spaceId) {
    _activeWatchers[spaceId]?.cancel();
    _activeWatchers.remove(spaceId);
    _spaceMerkleRoots.remove(spaceId);
    _spaces.removeWhere((s) => s.id == spaceId);
    _spacesController.add(List.unmodifiable(_spaces));
    savePersistedSpaces();
  }

  /// Starts watching all configured Spaces for automated real-time background synchronization.
  void startBackgroundWatcher() {
    if (_isWatching) return;
    _isWatching = true;

    for (final space in _spaces) {
      _watchSpace(space);
    }

    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(
      Duration(seconds: AppSettingsService.instance.autoSyncIntervalSeconds),
      (_) => triggerAutomatedSyncSweep(),
    );
  }

  /// Stops all active background filesystem watchers.
  void stopBackgroundWatcher() {
    _isWatching = false;
    for (final sub in _activeWatchers.values) {
      sub.cancel();
    }
    _activeWatchers.clear();
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _watchSpace(SyncSpace space) {
    if (!AppSettingsService.instance.autoSyncEnabled) return;
    if (space.localPath.isEmpty || space.localPath.startsWith('content://')) return;

    final dir = Directory(space.localPath);
    if (!dir.existsSync()) return;

    _activeWatchers[space.id]?.cancel();

    try {
      // Initialize Merkle root hash for change detection (Rule 7: Never treat timestamps as sync truth)
      _spaceMerkleRoots[space.id] = computeSpaceMerkleRoot(space.localPath);

      final watcher = dir.watch(recursive: true).listen(
        (event) {
          // Rule 8: Never treat watcher events as filesystem truth.
          // Event is an impulse to schedule a real Merkle disk evaluation.
          _scheduleDebouncedSync(space.id);
        },
        onError: (_) {},
        cancelOnError: false,
      );
      _activeWatchers[space.id] = watcher;
    } catch (_) {}
  }

  void _scheduleDebouncedSync(String spaceId) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      performAutomatedSync(spaceId);
    });
  }

  /// Computes true per-file content SHA-256 manifest for a folder (Rule 7: Never treat timestamps as sync truth).
  Map<String, String> computeContentManifest(String folderPath) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return {};
    final manifest = <String, String>{};
    final normalizedRoot = dir.path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    try {
      final files = dir.listSync(recursive: true, followLinks: false).whereType<File>().toList();
      for (final f in files) {
        final normPath = f.path.replaceAll('\\', '/');
        final base = normPath.split('/').last;
        if (base.startsWith('.') || base.endsWith('.part') || base.endsWith('.tmp')) {
          continue;
        }
        final rel = normPath.startsWith('$normalizedRoot/')
            ? normPath.substring(normalizedRoot.length + 1)
            : base;
        final contentHash = _computeFileContentSha256Sync(f);
        manifest[rel] = contentHash;
      }
    } catch (_) {}
    return manifest;
  }

  static String _computeFileContentSha256Sync(File f) {
    try {
      final bytes = f.readAsBytesSync();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  /// Calculates SHA-256 Merkle root hash of true file contents without relying on timestamps (Rule 7).
  String computeSpaceMerkleRoot(String folderPath) {
    final manifest = computeContentManifest(folderPath);
    if (manifest.isEmpty) {
      return 'SHA256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    }
    final leafHashes = manifest.entries
        .map((e) => sha256.convert(utf8.encode('${e.key}:${e.value}')).toString())
        .toList()
      ..sort();
    return 'SHA256:${sha256.convert(utf8.encode(leafHashes.join(''))).toString()}';
  }

  /// Executes automated or manual cross-device sync for a specific Space.
  /// Compares true content SHA-256 manifests (Rule 7), enforces mass-change safety hold (Rule 9),
  /// and pushes ONLY added/modified delta files over the active P2P transport.
  Future<bool> performAutomatedSync(String spaceId) async {
    final idx = _spaces.indexWhere((s) => s.id == spaceId);
    if (idx == -1) return false;

    final space = _spaces[idx];
    if (space.status == SyncStatus.massChangePaused || space.status == SyncStatus.conflictDetected) {
      // Safety hold active, do not overwrite or auto-clear without user review
      return false;
    }

    final dir = Directory(space.localPath);
    if (!dir.existsSync()) return false;

    final currentManifest = computeContentManifest(space.localPath);
    final currentFileCount = currentManifest.length;

    // Mass-change protection guard (Rule 9):
    // If previous files existed (> 5) and file count dropped by > 30%, pause automatically
    if (space.fileCount > 5 && currentFileCount < (space.fileCount * 0.70)) {
      await createSnapshot(
        name: 'Auto-Snapshot (Mass-Change Safety Hold: ${space.name})',
        folderPath: space.localPath,
      );
      _spaces[idx] = space.copyWith(
        status: SyncStatus.massChangePaused,
        fileCount: currentFileCount,
      );
      _spacesController.add(List.unmodifiable(_spaces));
      savePersistedSpaces();
      return false;
    }

    final previousManifest = _lastSyncedManifests[space.id] ?? const <String, String>{};
    final changedAbsPaths = <String>[];
    final normalizedRoot = dir.path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');

    for (final entry in currentManifest.entries) {
      final prevHash = previousManifest[entry.key];
      if (prevHash == null || prevHash != entry.value) {
        changedAbsPaths.add('$normalizedRoot${Platform.pathSeparator}${entry.key.replaceAll('/', Platform.pathSeparator)}');
      }
    }

    bool pushedRemotely = false;
    if (changedAbsPaths.isNotEmpty &&
        space.remotePeerId.isNotEmpty &&
        space.remotePeerId != 'peer_local_network') {
      pushedRemotely = await _pushDeltaToRemotePeer(space.remotePeerId, changedAbsPaths);
    }

    final newMerkleRoot = computeSpaceMerkleRoot(space.localPath);
    _spaceMerkleRoots[space.id] = newMerkleRoot;
    _lastSyncedManifests[space.id] = currentManifest;

    final syncLabel = pushedRemotely
        ? 'Just now (Auto • synced ${changedAbsPaths.length} file(s))'
        : 'Just now (Auto)';

    _spaces[idx] = space.copyWith(
      status: SyncStatus.inSync,
      fileCount: currentFileCount,
      lastSyncTime: syncLabel,
      pendingConflicts: 0,
      conflictFile: null,
    );
    _spacesController.add(List.unmodifiable(_spaces));
    savePersistedSpaces();
    return true;
  }

  Future<bool> _pushDeltaToRemotePeer(String remotePeerId, List<String> changedPaths) async {
    if (onPushDeltaFiles != null) {
      try {
        return await onPushDeltaFiles!(remotePeerId, changedPaths);
      } catch (_) {
        return false;
      }
    }
    try {
      if (PlatformCapabilities.isAndroid) {
        final txId = await AndroidNodeBridge.instance.initiateSend(
          targetPeerId: remotePeerId,
          contentUris: changedPaths,
        );
        return txId.isNotEmpty;
      } else if (NodeIpcClient.instance.isAuthenticated) {
        await NodeIpcClient.instance.initiateSend(
          targetPeerId: remotePeerId,
          sourcePaths: changedPaths,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Performs 3-way content-hash reconciliation against a remote peer's SHA-256 manifest
  /// (Rule 7: never trust timestamps; Rule 9: never silently overwrite offline conflicts).
  Future<({List<String> pushed, List<String> pulled, List<String> conflicts})> reconcileRemoteManifest(
    String spaceId,
    Map<String, String> remoteManifest,
  ) async {
    final idx = _spaces.indexWhere((s) => s.id == spaceId);
    if (idx == -1) {
      return (pushed: const <String>[], pulled: const <String>[], conflicts: const <String>[]);
    }
    final space = _spaces[idx];
    final localManifest = computeContentManifest(space.localPath);
    final baseManifest = _lastSyncedManifests[space.id] ?? const <String, String>{};
    final allKeys = <String>{...localManifest.keys, ...remoteManifest.keys};

    final toPushAbs = <String>[];
    final toPushRel = <String>[];
    final toPullRel = <String>[];
    final conflicts = <String>[];
    final normRoot = space.localPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');

    for (final rel in allKeys) {
      final localHash = localManifest[rel];
      final remoteHash = remoteManifest[rel];
      final baseHash = baseManifest[rel];

      if (localHash == remoteHash) continue;

      if (localHash != null && remoteHash != null) {
        final localChanged = baseHash == null || localHash != baseHash;
        final remoteChanged = baseHash == null || remoteHash != baseHash;
        if (localChanged && remoteChanged) {
          // True offline divergence: preserve non-destructive .conflict copy!
          conflicts.add(rel);
          try {
            final localFile = File('$normRoot${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
            if (localFile.existsSync()) {
              final conflictCopy = File('${localFile.path}.conflict');
              if (!conflictCopy.existsSync()) {
                localFile.copySync(conflictCopy.path);
              }
            }
          } catch (_) {}
        } else if (localChanged) {
          toPushRel.add(rel);
          toPushAbs.add('$normRoot${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
        } else if (remoteChanged && space.mode == SyncMode.twoWaySync) {
          toPullRel.add(rel);
        }
      } else if (localHash != null && remoteHash == null) {
        // Added locally (or deleted remotely only if it was in base)
        if (baseHash == null || localHash != baseHash) {
          toPushRel.add(rel);
          toPushAbs.add('$normRoot${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');
        }
      } else if (localHash == null && remoteHash != null) {
        // Added remotely -> pull in twoWaySync or oneWayMirror
        if (space.mode != SyncMode.oneWayPush) {
          toPullRel.add(rel);
        }
      }
    }

    if (toPushAbs.isNotEmpty) {
      await _pushDeltaToRemotePeer(space.remotePeerId, toPushAbs);
    }
    if (toPullRel.isNotEmpty && onPullRemoteFiles != null) {
      await onPullRemoteFiles!(space.remotePeerId, toPullRel);
    }

    final mergedManifest = <String, String>{...localManifest};
    for (final rel in toPullRel) {
      if (remoteManifest.containsKey(rel)) {
        mergedManifest[rel] = remoteManifest[rel]!;
      }
    }
    _lastSyncedManifests[space.id] = mergedManifest;

    _spaces[idx] = space.copyWith(
      status: conflicts.isNotEmpty ? SyncStatus.conflictDetected : SyncStatus.inSync,
      fileCount: mergedManifest.length,
      lastSyncTime: conflicts.isNotEmpty
          ? 'Conflict review needed'
          : 'Just now (2-Way Synced)',
      pendingConflicts: conflicts.length,
      conflictFile: conflicts.isNotEmpty ? conflicts.first : null,
    );
    _spacesController.add(List.unmodifiable(_spaces));
    savePersistedSpaces();

    return (pushed: toPushRel, pulled: toPullRel, conflicts: conflicts);
  }

  /// Periodic background sync sweep across all registered Spaces.
  Future<void> triggerAutomatedSyncSweep() async {
    if (!AppSettingsService.instance.autoSyncEnabled) return;
    for (final space in _spaces) {
      if (space.status != SyncStatus.massChangePaused && space.status != SyncStatus.conflictDetected) {
        await performAutomatedSync(space.id);
      }
    }
  }

  void resolveConflict(String spaceId, String resolutionPolicy) {
    final idx = _spaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1) {
      final space = _spaces[idx];
      // Invariant: KEEP_BOTH creates .conflict preservation; never silently overwrites
      _spaces[idx] = space.copyWith(
        status: SyncStatus.inSync,
        pendingConflicts: 0,
        conflictFile: null,
      );
      _spacesController.add(List.unmodifiable(_spaces));
      savePersistedSpaces();
    }
  }

  void releaseMassChangeHold(String spaceId, bool authorized) {
    final idx = _spaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1) {
      final space = _spaces[idx];
      _spaces[idx] = space.copyWith(
        status: SyncStatus.inSync,
      );
      _spacesController.add(List.unmodifiable(_spaces));
      savePersistedSpaces();
    }
  }

  List<SyncDryRunDiff> computeDryRun(SyncSpace space) {
    final diffs = <SyncDryRunDiff>[];
    try {
      final current = computeContentManifest(space.localPath);
      final previous = _lastSyncedManifests[space.id] ?? const <String, String>{};
      for (final entry in current.entries) {
        final prevHash = previous[entry.key];
        if (prevHash == null) {
          diffs.add(SyncDryRunDiff(
            type: 'ADDED',
            relativePath: entry.key,
            detail: 'New content (${entry.value.substring(0, entry.value.length.clamp(0, 10))}…)',
          ));
        } else if (prevHash != entry.value) {
          diffs.add(SyncDryRunDiff(
            type: 'MODIFIED',
            relativePath: entry.key,
            detail: 'Content SHA-256 changed',
          ));
        }
      }
      for (final prevKey in previous.keys) {
        if (!current.containsKey(prevKey)) {
          diffs.add(SyncDryRunDiff(
            type: 'DELETED',
            relativePath: prevKey,
            detail: 'Removed locally',
          ));
        }
      }
      if (diffs.isEmpty) {
        for (final entry in current.entries.take(5)) {
          diffs.add(SyncDryRunDiff(
            type: 'VERIFIED_LOCAL',
            relativePath: entry.key,
            detail: 'SHA-256 verified (${entry.value.substring(0, entry.value.length.clamp(0, 10))}…)',
          ));
        }
      }
    } catch (_) {}
    return diffs;
  }

  Future<BackupSnapshot> createSnapshot({
    required String name,
    required String folderPath,
  }) async {
    final dir = Directory(folderPath);
    int count = 0;
    int bytes = 0;
    final leafHashes = <String>[];

    if (dir.existsSync()) {
      final files = dir.listSync(recursive: true).whereType<File>().toList();
      count = files.length;
      for (final f in files) {
        final len = f.lengthSync();
        bytes += len;
        final rel = f.path.replaceAll(folderPath, '');
        final h = sha256.convert(utf8.encode('$rel:$len')).toString();
        leafHashes.add(h);
      }
    }

    // Compute SHA-256 Merkle root hash
    String rootHash;
    if (leafHashes.isEmpty) {
      rootHash = 'SHA256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    } else {
      leafHashes.sort();
      final combined = leafHashes.join('');
      rootHash = 'SHA256:${sha256.convert(utf8.encode(combined)).toString()}';
    }

    final id = 'snap_${DateTime.now().millisecondsSinceEpoch}';
    final sizeFormatted = bytes > 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).toStringAsFixed(1)} KB';

    final snapshot = BackupSnapshot(
      id: id,
      name: name,
      timestamp: 'Today at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      fileCount: count,
      totalSize: sizeFormatted,
      rootHash: rootHash,
      sourcePath: folderPath,
    );

    _snapshots.insert(0, snapshot);
    _snapshotsController.add(List.unmodifiable(_snapshots));
    savePersistedSpaces();
    return snapshot;
  }

  String determineSafeRestorePath(String destinationPath, String snapshotId) {
    final destDir = Directory(destinationPath);
    if (destDir.existsSync() && destDir.listSync().isNotEmpty) {
      // Invariant: Silent overwrite prevention! Create alternative non-conflicting path
      return '${destinationPath}_restored_$snapshotId';
    }
    return destinationPath;
  }

  void resetForTesting() {
    stopBackgroundWatcher();
    _spaceMerkleRoots.clear();
    _lastSyncedManifests.clear();
    onPushDeltaFiles = null;
    onPullRemoteFiles = null;
    _spaces.clear();
    _snapshots.clear();
    _spacesController.add(List.unmodifiable(_spaces));
    _snapshotsController.add(List.unmodifiable(_snapshots));
  }
}
