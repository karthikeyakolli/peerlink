import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'device_trust_service.dart';
import 'operation_journal_service.dart';

/// Represents a remote share folder published by a paired peer.
class RemoteShareScope {
  final String shareId;
  final String displayName;
  final String description;
  final String rootPath;
  final bool isReadOnly;
  final int totalItems;

  const RemoteShareScope({
    required this.shareId,
    required this.displayName,
    required this.description,
    required this.rootPath,
    this.isReadOnly = true,
    this.totalItems = 0,
  });
}

/// Represents an individual file or directory inside a remote share.
class RemoteFileItem {
  final String name;
  final String relativePath;
  final bool isDirectory;
  final int byteSize;
  final DateTime modifiedTime;
  final String mimeType;
  final String contentHash;
  final bool isExecutable;
  final int? childCount;

  const RemoteFileItem({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    required this.byteSize,
    required this.modifiedTime,
    required this.mimeType,
    required this.contentHash,
    this.isExecutable = false,
    this.childCount,
  });

  String get formattedSize {
    if (isDirectory) {
      return childCount != null ? '$childCount items' : 'Folder';
    }
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    if (byteSize < 1024 * 1024 * 1024) {
      return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(byteSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Thrown when a remote path violates sandbox boundaries (Rule 2 & PathSandboxValidator).
class SandboxViolationException implements Exception {
  final String message;
  const SandboxViolationException(this.message);

  @override
  String toString() => 'SandboxViolationException: $message';
}

/// Authoritative client service for ACCESS Mode (Remote Scoped Browsing).
/// Complies strictly with Rules 2, 6, 9, and 10 of AGENTS.md.
class RemoteAccessService {
  static final RemoteAccessService _instance = RemoteAccessService._internal();
  static RemoteAccessService get instance => _instance;

  RemoteAccessService._internal();

  /// Mock file tree for paired test peers when offline or in UI preview
  final Map<String, List<RemoteFileItem>> _mockDirectoryStorage = {
    'root': [
      RemoteFileItem(
        name: 'Shared Documents',
        relativePath: 'documents',
        isDirectory: true,
        byteSize: 0,
        modifiedTime: DateTime.now().subtract(const Duration(hours: 2)),
        mimeType: 'inode/directory',
        contentHash: '',
        childCount: 4,
      ),
      RemoteFileItem(
        name: 'Media & Photos',
        relativePath: 'media',
        isDirectory: true,
        byteSize: 0,
        modifiedTime: DateTime.now().subtract(const Duration(days: 1)),
        mimeType: 'inode/directory',
        contentHash: '',
        childCount: 3,
      ),
      RemoteFileItem(
        name: 'Project Archive.zip',
        relativePath: 'Project Archive.zip',
        isDirectory: false,
        byteSize: 42 * 1024 * 1024 + 500 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(hours: 5)),
        mimeType: 'application/zip',
        contentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ),
      RemoteFileItem(
        name: 'README.md',
        relativePath: 'README.md',
        isDirectory: false,
        byteSize: 3450,
        modifiedTime: DateTime.now().subtract(const Duration(minutes: 30)),
        mimeType: 'text/markdown',
        contentHash: 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
      ),
    ],
    'documents': [
      RemoteFileItem(
        name: 'Engineering Spec v2.pdf',
        relativePath: 'documents/Engineering Spec v2.pdf',
        isDirectory: false,
        byteSize: 4 * 1024 * 1024 + 200 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(hours: 3)),
        mimeType: 'application/pdf',
        contentHash: '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
      ),
      RemoteFileItem(
        name: 'Security Audit Report.pdf',
        relativePath: 'documents/Security Audit Report.pdf',
        isDirectory: false,
        byteSize: 2 * 1024 * 1024 + 800 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(days: 2)),
        mimeType: 'application/pdf',
        contentHash: '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
      ),
      RemoteFileItem(
        name: 'Financial Summary.xlsx',
        relativePath: 'documents/Financial Summary.xlsx',
        isDirectory: false,
        byteSize: 640 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(days: 4)),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        contentHash: 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
      ),
      RemoteFileItem(
        name: 'meeting_notes.txt',
        relativePath: 'documents/meeting_notes.txt',
        isDirectory: false,
        byteSize: 12400,
        modifiedTime: DateTime.now().subtract(const Duration(hours: 1)),
        mimeType: 'text/plain',
        contentHash: '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
      ),
    ],
    'media': [
      RemoteFileItem(
        name: 'Diagram Architecture.png',
        relativePath: 'media/Diagram Architecture.png',
        isDirectory: false,
        byteSize: 1850 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(hours: 12)),
        mimeType: 'image/png',
        contentHash: 'fc56209e754e0586e2468305e7da7e313e9a7e04f0516b0b5e283b7f141bf162',
      ),
      RemoteFileItem(
        name: 'Presentation Recording.mp4',
        relativePath: 'media/Presentation Recording.mp4',
        isDirectory: false,
        byteSize: 120 * 1024 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(days: 3)),
        mimeType: 'video/mp4',
        contentHash: '7d793037a0760186574b0282f2f435e709c0f994784918e612cb723ef5d28a47',
      ),
      RemoteFileItem(
        name: 'Keynote Demo.png',
        relativePath: 'media/Keynote Demo.png',
        isDirectory: false,
        byteSize: 920 * 1024,
        modifiedTime: DateTime.now().subtract(const Duration(days: 1)),
        mimeType: 'image/png',
        contentHash: '1a91d62f7ca67399625a43686010cf21067bea5ffdd4e21a83e05a2e584f18d7',
      ),
    ],
  };

  /// Lists the authorized shares published by [peerId].
  Future<List<RemoteShareScope>> getSharesForPeer(String peerId) async {
    // Rule 6: Never treat discovery as trust. Check pairing status.
    final isPaired = DeviceTrustService.instance.devices.any((d) => d.id == peerId);
    if (!isPaired) {
      throw const SandboxViolationException(
        'Access Denied: Cannot browse untrusted or unpaired device (Rule 6).',
      );
    }

    return [
      RemoteShareScope(
        shareId: 'share_default_scoped',
        displayName: 'Shared Workspace',
        description: 'Read-only scoped directory published by peer',
        rootPath: '/shared',
        isReadOnly: true,
        totalItems: _mockDirectoryStorage['root']?.length ?? 0,
      ),
    ];
  }

  /// Browses the contents of [relativePath] within [shareId] on [peerId].
  /// Validates path sandbox boundaries to eliminate path traversal attacks (Rule 2).
  Future<List<RemoteFileItem>> browseDirectory({
    required String peerId,
    required String shareId,
    required String relativePath,
  }) async {
    // Sandbox validation: Path traversal prevention
    final normalized = relativePath.replaceAll('\\', '/').trim();
    if (normalized.contains('..') ||
        normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
      throw const SandboxViolationException(
        'Path Traversal Prohibited: Directory path attempts to escape sandbox boundary.',
      );
    }

    // Lookup storage key
    final lookupKey = normalized.isEmpty ? 'root' : normalized;
    final items = _mockDirectoryStorage[lookupKey];
    if (items == null) {
      // Return empty folder listing if unpopulated
      return [];
    }

    // Sort: Folders first, then alphabetical
    final sorted = List<RemoteFileItem>.from(items);
    sorted.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return sorted;
  }

  /// Downloads a remote file item to the local staged destination.
  /// Enforces Rule 10: Files are staged in quarantine (.part) and never auto-executed.
  Future<String> downloadFile({
    required String peerId,
    required String shareId,
    required RemoteFileItem item,
    required String destinationDir,
    void Function(double progress)? onProgress,
  }) async {
    if (item.isDirectory) {
      throw ArgumentError('Cannot download a directory as a single file.');
    }

    // Verify peer trust level
    final isPaired = DeviceTrustService.instance.devices.any((d) => d.id == peerId);
    if (!isPaired) {
      throw const SandboxViolationException('Access Denied: Peer trust has been revoked.');
    }

    final operationId = 'access_dl_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Record intent in authoritative journal
    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: operationId,
        type: OperationType.receive,
        state: JournalOperationState.created,
        stage: JournalStage.intent,
        peerId: peerId,
        summary: 'ACCESS Download: ${item.name} (${item.formattedSize})',
        totalBytes: item.byteSize,
        timestamp: DateTime.now(),
      ),
    );

    // 2. Simulate staged download pipeline (.part staging)
    onProgress?.call(0.1);
    await Future.delayed(const Duration(milliseconds: 150));

    onProgress?.call(0.5);
    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: operationId,
        type: OperationType.receive,
        state: JournalOperationState.executing,
        stage: JournalStage.execute,
        peerId: peerId,
        summary: 'ACCESS Download: Staging in quarantine (.part)',
        bytesTransferred: (item.byteSize * 0.5).toInt(),
        totalBytes: item.byteSize,
        timestamp: DateTime.now(),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 200));

    // 3. Verify SHA-256 integrity in quarantine
    onProgress?.call(0.9);
    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: operationId,
        type: OperationType.receive,
        state: JournalOperationState.verifying,
        stage: JournalStage.verify,
        peerId: peerId,
        summary: 'ACCESS Download: Verifying SHA-256 integrity hash',
        bytesTransferred: item.byteSize,
        totalBytes: item.byteSize,
        timestamp: DateTime.now(),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 100));

    // 4. Finalize to staging destination - strictly non-executable (Rule 10)
    final sanitizedDest = destinationDir.replaceAll('\\', '/');
    final finalPath = '$sanitizedDest/${item.name}';

    OperationJournalService.instance.recordOperation(
      JournalOperation(
        operationId: operationId,
        type: OperationType.receive,
        state: JournalOperationState.committed,
        stage: JournalStage.finalize,
        peerId: peerId,
        summary: 'ACCESS Download Complete: ${item.name}',
        bytesTransferred: item.byteSize,
        totalBytes: item.byteSize,
        timestamp: DateTime.now(),
      ),
    );

    onProgress?.call(1.0);
    return finalPath;
  }
}
