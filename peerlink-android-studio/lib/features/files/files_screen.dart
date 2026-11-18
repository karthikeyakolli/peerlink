import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_settings_service.dart';
import '../../core/node_ipc_client.dart';
import '../../core/operation_journal_service.dart';
import '../../core/protocol/peerlink/v1/transfer.pb.dart';
import '../../core/protocol/peerlink/v1/error.pb.dart';
import 'package:fixnum/fixnum.dart';
import '../../core/device_trust_service.dart';
import '../../core/pairing_invitation.dart';
import '../../design_system/components/radar_sonar_view.dart';
import '../../design_system/components/qr_pairing_sheet.dart';
import '../../design_system/components/glass_container.dart';
import '../../design_system/components/interactive_glass_card.dart';
import '../../design_system/components/ephemeral_policy_modal.dart';
import '../../design_system/components/burn_viewer_modal.dart';
import '../../design_system/components/desktop_dropzone.dart';
import '../../platform/windows_file_dialog.dart';
import '../../platform/android_node_bridge.dart';
import '../../platform/platform_capabilities.dart';
import '../../design_system/components/media_category_sheet.dart';
import '../../core/transfer/transfer_progress_model.dart' show TransferProgressModel;
import '../../core/file_staging_service.dart';
import '../../design_system/components/quick_text_share_modal.dart';
import '../../core/error_message_simplifier.dart';
import '../../design_system/components/app_sharing_sheet.dart';
import '../../design_system/components/web_beam_modal.dart';
import '../../design_system/components/local_hotspot_modal.dart';
import '../../core/feedback_sound_service.dart';
import 'received_vault_view.dart';
import 'remote_scoped_browser_sheet.dart';

class SelectedFileInfo {
  final String path;
  final String name;
  final int sizeBytes;
  final bool isDirectory;
  final int fileCount;
  bool selected;

  SelectedFileInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.isDirectory,
    this.fileCount = 0,
    this.selected = true,
  });

  String get formattedSize {
    if (isDirectory) {
      if (fileCount == 0 && sizeBytes == 0) return 'Folder';
      final sizeStr = _formatBytes(sizeBytes);
      return fileCount == 1 ? '1 file ($sizeStr)' : '$fileCount files ($sizeStr)';
    }
    return _formatBytes(sizeBytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class FilesScreen extends StatefulWidget {
  final String? initialTargetPeer;
  final int initialTabIndex;

  const FilesScreen({
    super.key,
    this.initialTargetPeer,
    this.initialTabIndex = 0,
  });

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final NodeIpcClient _client = NodeIpcClient.instance;

  final TextEditingController _targetPeerController = TextEditingController(
    text: PlatformCapabilities.isAndroid ? '' : 'peer-desktop-b',
  );
  final TextEditingController _sourcePathsController = TextEditingController();
  final TextEditingController _destinationDirController =
      TextEditingController();
  DuplicateDestinationPolicy _duplicatePolicy =
      DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS;

  bool _isSending = false;
  String? _statusBanner;
  String? _refreshError;
  StreamSubscription<TransferProgress>? _progressSub;
  StreamSubscription<dynamic>? _androidBridgeSub;
  StreamSubscription<dynamic>? _incomingIntentSub;
  final Map<String, TransferProgress> _transfers = {};
  final Map<String, TransferProgressModel> _activeProgressModels = {};
  DateTime _lastProgressUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  EphemeralPolicy _currentPolicy = EphemeralPolicy.permanent;

  final List<SelectedFileInfo> _selectedFiles = [];
  String? _localAndroidPeerId;
  String? _localAndroidFingerprint;

  Future<void> _resolveAndroidIdentity() async {
    if (PlatformCapabilities.isAndroid) {
      final pid = await AndroidNodeBridge.instance.getLocalPeerId();
      final fp = await AndroidNodeBridge.instance.getFingerprint();
      if (mounted) {
        setState(() {
          if (pid != null && pid.isNotEmpty) _localAndroidPeerId = pid;
          if (fp != null && fp.isNotEmpty) _localAndroidFingerprint = fp;
        });
      }
    }
  }

  void _addPaths(List<String> paths) {
    for (final p in paths) {
      if (p.trim().isEmpty) continue;
      final cleanPath = p.trim();
      final f = File(cleanPath);
      final d = Directory(cleanPath);
      String name = cleanPath.split(RegExp(r'[\\/]')).last;
      name = Uri.decodeComponent(name);
      if (name.contains(':')) {
        name = name.split(':').last;
      }

      int size = 0;
      bool isDir = false;
      int fileCount = 0;
      try {
        if (f.existsSync()) {
          size = f.lengthSync();
          isDir = false;
        } else if (d.existsSync()) {
          isDir = true;
          int count = 0;
          for (final entity in d.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              size += entity.lengthSync();
              count++;
            }
          }
          fileCount = count;
        }
      } catch (_) {}

      if (size == 0 && cleanPath.startsWith('content://')) {
        size = 1024 * 1024;
      }

      if (!_selectedFiles.any((item) => item.path == cleanPath)) {
        _selectedFiles.add(SelectedFileInfo(
          path: cleanPath,
          name: name.isEmpty ? cleanPath : name,
          sizeBytes: size,
          isDirectory: isDir,
          fileCount: fileCount,
        ));
      }
    }
    FileStagingService.instance.addPaths(paths);
    _syncController();
  }

  void _syncController() {
    _sourcePathsController.text = _selectedFiles
        .where((f) => f.selected)
        .map((f) => f.path)
        .join('\n');
  }

  Future<void> _pickFiles() async {
    if (PlatformCapabilities.isAndroid) {
      try {
        final uris = await AndroidNodeBridge.instance.pickContentUris();
        if (uris.isNotEmpty && mounted) {
          setState(() {
            _addPaths(uris);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File picker failed: $e')),
          );
        }
      }
    } else {
      final paths = await WindowsFileDialog.pickFiles();
      if (paths.isNotEmpty && mounted) {
        setState(() {
          _addPaths(paths);
        });
      }
    }
  }

  Future<void> _pickSafFile() async {
    try {
      final uris = await AndroidNodeBridge.instance.pickContentUris();
      if (uris.isNotEmpty && mounted) {
        setState(() {
          _addPaths(uris);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SAF picker failed: $e')),
        );
      }
    }
  }

  Future<void> _pickFolder() async {
    if (PlatformCapabilities.isAndroid) {
      try {
        final folder = await AndroidNodeBridge.instance.pickDirectoryUri();
        if (folder != null && folder.isNotEmpty && mounted) {
          setState(() {
            _addPaths([folder]);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder picker failed: $e')),
          );
        }
      }
    } else {
      final folder = await WindowsFileDialog.pickDirectory();
      if (folder != null && mounted) {
        setState(() {
          _addPaths([folder]);
        });
      }
    }
  }

  void _clearSelectedFiles() {
    FileStagingService.instance.clear();
    setState(() {
      _selectedFiles.clear();
      _sourcePathsController.clear();
    });
  }

  void _openMediaCategorySheet() {
    final selectionItems = _selectedFiles.map((f) => MediaItemInfo(
      pathOrUri: f.path,
      name: f.name,
      sizeBytes: f.sizeBytes,
      category: _categoryForFileName(f.name),
    )).toList();

    MediaCategorySheet.show(
      context: context,
      currentSelection: selectionItems,
      onItemRemoved: (item) {
        FileStagingService.instance.removePath(item.pathOrUri);
        setState(() {
          _selectedFiles.removeWhere((f) => f.path == item.pathOrUri);
          _syncController();
        });
      },
      onClearAll: _clearSelectedFiles,
      onCategorySelected: (cat) async {
        String categoryKey = 'all';
        switch (cat) {
          case MediaCategory.photos:
            categoryKey = 'photos';
            break;
          case MediaCategory.videos:
            categoryKey = 'videos';
            break;
          case MediaCategory.audio:
            categoryKey = 'audio';
            break;
          case MediaCategory.documents:
            categoryKey = 'documents';
            break;
          case MediaCategory.archives:
            categoryKey = 'archives';
            break;
          case MediaCategory.allFiles:
            categoryKey = 'all';
            break;
        }
        final uris = await AndroidNodeBridge.instance.pickContentUris(category: categoryKey);
        if (uris.isNotEmpty && mounted) {
          setState(() {
            _addPaths(uris);
          });
        }
      },
    );
  }

  MediaCategory _categoryForFileName(String name) {
    final ext = name.toLowerCase().split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'].contains(ext)) {
      return MediaCategory.photos;
    }
    if (['mp4', 'mkv', 'webm', 'mov', 'avi', '3gp'].contains(ext)) {
      return MediaCategory.videos;
    }
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(ext)) {
      return MediaCategory.audio;
    }
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(ext)) {
      return MediaCategory.documents;
    }
    if (['zip', 'tar', 'gz', '7z', 'rar', 'bz2'].contains(ext)) {
      return MediaCategory.archives;
    }
    return MediaCategory.allFiles;
  }

  Future<void> _handlePasteToSend(BuildContext context) async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipData?.text?.trim();
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }

    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim().replaceAll('"', '')).where((l) => l.isNotEmpty).toList();
    final existingPaths = lines.where((l) => File(l).existsSync() || Directory(l).existsSync()).toList();

    if (existingPaths.isNotEmpty) {
      setState(() {
        _addPaths(existingPaths);
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${existingPaths.length} item(s) pasted from clipboard!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } else {
      if (context.mounted) {
        QuickTextShareModal.show(context, initialText: text);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveAndroidIdentity();
    if (widget.initialTargetPeer != null && widget.initialTargetPeer!.isNotEmpty) {
      _targetPeerController.text = widget.initialTargetPeer!;
    } else if (DeviceTrustService.instance.selectedSendTarget != null) {
      _targetPeerController.text = DeviceTrustService.instance.selectedSendTarget!;
      DeviceTrustService.instance.clearSelectedSendTarget();
    } else if (DeviceTrustService.instance.devices.isNotEmpty) {
      _targetPeerController.text = DeviceTrustService.instance.devices.first.id;
    }
    // Restore persistent staged draft files
    if (FileStagingService.instance.isNotEmpty && _selectedFiles.isEmpty) {
      for (final staged in FileStagingService.instance.stagedFiles) {
        _selectedFiles.add(SelectedFileInfo(
          path: staged.path,
          name: staged.name,
          sizeBytes: staged.sizeBytes,
          isDirectory: staged.isDirectory,
          fileCount: staged.fileCount,
          selected: staged.selected,
        ));
      }
      _syncController();
    }
    _refreshTransfers();
    _progressSub = _client.transferProgressStream.listen((progress) {
      if (mounted) {
        _transfers[progress.transferId] = progress;
        final now = DateTime.now();
        if (now.difference(_lastProgressUiUpdate).inMilliseconds >= 120 ||
            progress.state == TransferState.TRANSFER_STATE_COMPLETED ||
            progress.state == TransferState.TRANSFER_STATE_FAILED ||
            progress.state == TransferState.TRANSFER_STATE_CANCELLED) {
          _lastProgressUiUpdate = now;
          setState(() {});
        }
        // Invariant: Unknown or uncertain transfer events trigger reconciliation
        if (progress.state == TransferState.TRANSFER_STATE_UNSPECIFIED ||
            progress.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN) {
          OperationJournalService.instance.runDiagnosticsAndReconcile(progress.transferId);
        }
      }
    });

    _incomingIntentSub = AndroidNodeBridge.instance.incomingTransferIntentStream.listen((intentData) {
      if (!mounted) return;
      final transferId = intentData['transferId'] as String? ?? '';
      final peerId = intentData['peerId'] as String? ?? '';
      final peerName = intentData['peerName'] as String? ?? peerId;
      _showIncomingOfferDialog(
        transferId: transferId,
        senderPeer: peerName.isNotEmpty ? peerName : peerId,
        fileName: 'Incoming Shared Files',
        totalBytes: 0,
        itemCount: 1,
      );
    });

    _androidBridgeSub = AndroidNodeBridge.instance.events.listen((event) {
      if (!mounted) return;
      final type = event['type'] as String?;
      if (type == 'transferStarted') {
        final transferId = event['transferId'] as String? ?? '';
        final remotePeer = event['remotePeer'] as String? ?? '';
        final fileName = event['fileName'] as String? ?? '';
        final total = (event['totalBytes'] as num?)?.toInt() ?? -1;
        setState(() {
          _activeProgressModels[transferId] = TransferProgressModel(
            transferId: transferId,
            remotePeerId: remotePeer,
            initialTotalBytes: total,
            initialFileName: fileName,
          );
          _transfers[transferId] = TransferProgress(
            transferId: transferId,
            state: TransferState.TRANSFER_STATE_TRANSFERRING,
            transferredBytes: Int64(0),
            totalBytes: total > 0 ? Int64(total) : Int64(0),
            currentFile: fileName,
            totalItems: 1,
          );
        });
        OperationJournalService.instance.recordOperation(
          JournalOperation(
            operationId: transferId,
            type: OperationType.send,
            state: JournalOperationState.executing,
            stage: JournalStage.execute,
            peerId: remotePeer,
            summary: fileName.isNotEmpty ? fileName : 'Transfer $transferId',
            bytesTransferred: 0,
            totalBytes: total > 0 ? total : 0,
            timestamp: DateTime.now(),
          ),
        );
      } else if (type == 'transferProgress') {
        final transferId = event['transferId'] as String? ?? '';
        final percent = (event['percent'] as num?)?.toInt() ?? 0;
        final transferred = (event['transferredBytes'] as num?)?.toInt() ?? 0;
        final total = (event['totalBytes'] as num?)?.toInt() ?? 0;
        final model = _activeProgressModels[transferId];
        if (model != null) {
          model.recordProgress(transferredBytes: transferred, totalBytes: total);
        }
        OperationJournalService.instance.updateProgress(transferId, transferred, total);
        final existing = _transfers[transferId];
        final speedBps = model?.smoothedRateBytesPerSec != null
            ? Int64(model!.smoothedRateBytesPerSec!.toInt())
            : Int64(0);
        _transfers[transferId] = TransferProgress(
          transferId: transferId,
          state: TransferState.TRANSFER_STATE_TRANSFERRING,
          transferredBytes: Int64(transferred),
          totalBytes: total > 0 ? Int64(total) : (existing?.totalBytes ?? Int64(0)),
          currentFile: existing?.currentFile ?? (model?.currentFileName ?? ''),
          speedBps: speedBps,
          totalItems: 1,
        );
        final now = DateTime.now();
        if (now.difference(_lastProgressUiUpdate).inMilliseconds >= 120 || percent >= 100) {
          _lastProgressUiUpdate = now;
          setState(() {
            if (model != null && model.smoothedRateBytesPerSec != null) {
              _statusBanner =
                  'Transferring $transferId: ${model.formattedProgress} • ${model.formattedRate} • ${model.formattedEta}';
            } else {
              _statusBanner =
                  'Transferring $transferId: $percent% (${(transferred / 1024).toStringAsFixed(1)} / ${(total / 1024).toStringAsFixed(1)} KB)';
            }
          });
        }
      } else if (type == 'transferCompleted') {
        final transferId = event['transferId'] as String? ?? '';
        final success = event['success'] == true;
        final errorMessage = event['errorMessage'] as String? ?? '';
        final model = _activeProgressModels[transferId];
        if (model != null) {
          model.recordProgress(
            transferredBytes: model.totalBytes > 0 ? model.totalBytes : 0,
          );
        }
        final isCancelled = !success && errorMessage.toLowerCase().contains('cancel');
        final existing = _transfers[transferId];
        final finalBytes = (model != null && model.totalBytes > 0)
            ? Int64(model.totalBytes)
            : (existing?.totalBytes ?? Int64(0));
        _transfers[transferId] = TransferProgress(
          transferId: transferId,
          state: success
              ? TransferState.TRANSFER_STATE_COMPLETED
              : (isCancelled ? TransferState.TRANSFER_STATE_CANCELLED : TransferState.TRANSFER_STATE_FAILED),
          transferredBytes: success ? finalBytes : (existing?.transferredBytes ?? Int64(0)),
          totalBytes: finalBytes,
          currentFile: existing?.currentFile ?? (model?.currentFileName ?? ''),
          error: (!success && errorMessage.isNotEmpty)
              ? ErrorDetail(
                  humanSummary: isCancelled ? 'Transfer cancelled' : 'Transfer failed',
                  humanExplanation: errorMessage,
                )
              : null,
          totalItems: 1,
        );
        OperationJournalService.instance.updateState(
          transferId,
          success
              ? JournalOperationState.committed
              : (isCancelled ? JournalOperationState.cancelled : JournalOperationState.failed),
          note: success ? null : errorMessage,
        );
        if (success) {
          OperationJournalService.instance.updateStage(transferId, JournalStage.finalize);
        }
        _lastProgressUiUpdate = DateTime.now();
        setState(() {
          if (success) {
            _statusBanner = 'Transfer completed successfully!';
            FeedbackSoundService.instance.playTransferComplete();
          } else {
            final simplified = ErrorMessageSimplifier.simplify(
              errorMessage,
              transferId: transferId,
              targetPeer: _targetPeerController.text.trim(),
            );
            _statusBanner = isCancelled
                ? 'Transfer cancelled.'
                : 'Transfer failed: ${simplified.oneLineMessage}';
            if (!isCancelled) {
              FeedbackSoundService.instance.playTransferFailed();
            }
          }
        });
        if (!success && !isCancelled) {
          _showTransferFailureDialog(
            transferId: transferId,
            errorMessage: errorMessage,
          );
        }
      } else if (type == 'incomingTransferOffer') {
        final transferId = event['transferId'] as String? ?? '';
        final senderPeer = event['senderPeer'] as String? ?? '';
        final fileName = event['fileName'] as String? ?? 'file';
        final totalBytes = (event['totalBytes'] as num?)?.toInt() ?? 0;
        final itemCount = (event['itemCount'] as num?)?.toInt() ?? 1;

        OperationJournalService.instance.recordOperation(
          JournalOperation(
            operationId: transferId,
            type: OperationType.receive,
            state: JournalOperationState.waiting,
            stage: JournalStage.intent,
            peerId: senderPeer,
            summary: fileName,
            bytesTransferred: 0,
            totalBytes: totalBytes,
            timestamp: DateTime.now(),
          ),
        );

        final isTrusted = DeviceTrustService.instance.isTrusted(senderPeer);
        if (isTrusted && AppSettingsService.instance.autoAcceptFromTrusted) {
          OperationJournalService.instance.updateState(
            transferId,
            JournalOperationState.executing,
          );
          OperationJournalService.instance.updateStage(
            transferId,
            JournalStage.execute,
          );
          AndroidNodeBridge.instance.respondIncomingTransfer(
            transferId: transferId,
            accept: true,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-accepted "$fileName" from trusted device $senderPeer'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } else {
          _showIncomingOfferDialog(
            transferId: transferId,
            senderPeer: senderPeer,
            fileName: fileName,
            totalBytes: totalBytes,
            itemCount: itemCount,
          );
        }
      }
    });
  }

  void _showTransferFailureDialog({
    required String transferId,
    required String errorMessage,
  }) {
    if (!mounted) return;
    final simplified = ErrorMessageSimplifier.simplify(
      errorMessage,
      transferId: transferId,
      targetPeer: _targetPeerController.text.trim(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: simplified.iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(simplified.icon, color: simplified.iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                simplified.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                simplified.oneLineMessage,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                simplified.suggestedAction,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (simplified.technicalDetails != null &&
                  simplified.technicalDetails!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Theme(
                  data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Technical details',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: SelectableText(
                          simplified.technicalDetails!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          if (simplified.canHotspotFallback)
            FilledButton.tonalIcon(
              key: const Key('hotspot_fallback_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF10B981),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                LocalHotspotModal.show(context);
              },
              icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
              label: const Text('Direct Hotspot'),
            ),
          if (simplified.canPair)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openRadarPicker();
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
              label: const Text('Pair Device'),
            )
          else if (simplified.isRetryable)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _initiateSend();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Transfer'),
            ),
        ],
      ),
    );
  }

  void _showIncomingOfferDialog({
    required String transferId,
    required String senderPeer,
    required String fileName,
    required int totalBytes,
    required int itemCount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.blueAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text('Incoming File Transfer', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: $senderPeer',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                'File: $fileName${itemCount > 1 ? ' (and ${itemCount - 1} other files)' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
              Text('Size: ${(totalBytes / 1024).toStringAsFixed(1)} KB'),
              const SizedBox(height: 12),
              const Text('Do you want to accept this transfer and save to your received folder?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              OperationJournalService.instance.updateState(
                transferId,
                JournalOperationState.cancelled,
                note: 'Declined by recipient',
              );
              AndroidNodeBridge.instance.respondIncomingTransfer(
                transferId: transferId,
                accept: false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Declined transfer $transferId')),
              );
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              OperationJournalService.instance.updateState(
                transferId,
                JournalOperationState.executing,
              );
              OperationJournalService.instance.updateStage(
                transferId,
                JournalStage.execute,
              );
              AndroidNodeBridge.instance.respondIncomingTransfer(
                transferId: transferId,
                accept: true,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Accepted transfer $transferId')),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _androidBridgeSub?.cancel();
    _incomingIntentSub?.cancel();
    _targetPeerController.dispose();
    _sourcePathsController.dispose();
    _destinationDirController.dispose();
    super.dispose();
  }

  Future<void> _refreshTransfers() async {
    setState(() => _refreshError = null);
    if (!_client.isAuthenticated) return;
    try {
      final res = await _client.listTransfers();
      if (mounted) {
        setState(() {
          for (final t in res.transfers) {
            _transfers[t.transferId] = t;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _refreshError = 'Error refreshing transfer list: $e';
        });
      }
    }
  }

  Future<void> _initiateSend() async {
    final rawPaths = _sourcePathsController.text.trim();
    if (rawPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter at least one file or folder path to send.')),
      );
      return;
    }

    var targetPeer = _targetPeerController.text.trim();
    if (targetPeer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a target peer ID.')),
      );
      return;
    }

    // Auto-detect JSON pairing invitation pasted directly into target peer field
    if (targetPeer.startsWith('{') && targetPeer.contains('"peerId"')) {
      try {
        final invitation = PairingInvitation.parse(targetPeer);
        targetPeer = invitation.peerId;
        _targetPeerController.text = targetPeer;

        String? hintHost;
        int hintPort = 8765;
        if (invitation.connectionHints.isNotEmpty) {
          final hint = invitation.connectionHints.first;
          if (hint.contains(':')) {
            final parts = hint.split(':');
            hintHost = parts[0];
            hintPort = int.tryParse(parts[1]) ?? 8765;
          } else {
            hintHost = hint;
          }
        }

        DeviceTrustService.instance.pairDevice(
          PairedDevice(
            id: invitation.peerId,
            name: invitation.name.isNotEmpty ? invitation.name : invitation.peerId,
            deviceType: 'device',
            fingerprint: invitation.fingerprint,
            trustLevel: DeviceTrustLevel.trustedPeer,
            isOnline: true,
            lastSeen: 'Active now',
          ),
          host: hintHost,
          port: hintPort,
        );

        if (PlatformCapabilities.isAndroid) {
          await AndroidNodeBridge.instance.addTrustedPeer(
            peerId: invitation.peerId,
            fingerprint: invitation.fingerprint,
            host: hintHost,
            port: hintPort,
            name: invitation.name,
          );
        }
      } catch (_) {}
    }

    final paths = rawPaths
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    setState(() {
      _isSending = true;
      _statusBanner = null;
    });

    if (Platform.isAndroid) {
      try {
        await AndroidNodeBridge.instance.requestPermissions(['notifications', 'nearby']);
      } catch (_) {}
    }

    if (Platform.isAndroid || paths.any((p) => p.startsWith('content://'))) {
      try {
        final transferId = await AndroidNodeBridge.instance.initiateSend(
          targetPeerId: targetPeer,
          contentUris: paths,
        );
        if (mounted) {
          if (transferId.isNotEmpty) {
            DeviceTrustService.instance.recordSendRecipient(targetPeer);
            setState(() {
              _statusBanner = 'Transfer initiated: $transferId';
              _sourcePathsController.clear();
              _selectedFiles.clear();
            });
            _refreshTransfers();
          } else {
            setState(() {
              _statusBanner = 'Initiation rejected by target peer: $targetPeer';
            });
          }
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusBanner = 'Android Send error: $e';
          });
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
    }

    if (!_client.isAuthenticated) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _statusBanner =
              'Local Node daemon is disconnected. Please start the node to transfer files.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Local Node daemon is disconnected. Transfer cannot be initiated.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    try {
      final res = await _client.initiateSend(
        targetPeerId: targetPeer,
        sourcePaths: paths,
        destinationDirectory: _destinationDirController.text.trim(),
        duplicatePolicy: _duplicatePolicy,
      );

      if (mounted) {
        if (res.accepted) {
          DeviceTrustService.instance.recordSendRecipient(targetPeer);
          setState(() {
            _statusBanner = 'Transfer initiated: ${res.transferId}';
            _sourcePathsController.clear();
            _selectedFiles.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Transfer initiated successfully! ID: ${res.transferId}'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          _refreshTransfers();
        } else {
          final simplified = ErrorMessageSimplifier.simplify(
            res.errorMessage,
            targetPeer: targetPeer,
          );
          setState(() {
            _statusBanner = 'Send rejected: ${simplified.oneLineMessage}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(simplified.oneLineMessage),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final simplified = ErrorMessageSimplifier.simplify(e.toString());
        setState(() {
          _statusBanner = 'Transfer Error: ${simplified.oneLineMessage}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(simplified.oneLineMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _cancelTransfer(String transferId) async {
    if (PlatformCapabilities.isAndroid || !_client.isAuthenticated) {
      if (mounted) {
        setState(() {
          final existing = _transfers[transferId];
          if (existing != null) {
            existing.state = TransferState.TRANSFER_STATE_CANCELLED;
          }
        });
        OperationJournalService.instance.updateState(
          transferId,
          JournalOperationState.cancelled,
          note: 'Cancelled by user',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer $transferId cancelled')),
        );
      }
      return;
    }
    try {
      final res = await _client.cancelTransfer(transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Transfer cancellation requested: ${res.message}'
                : 'Failed to cancel: ${res.message}'),
          ),
        );
        _refreshTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling transfer: $e')),
        );
      }
    }
  }

  Future<void> _pauseTransfer(String transferId) async {
    try {
      final res = await _client.pauseTransfer(transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Transfer paused: ${res.message}'
                : 'Failed to pause: ${res.message}'),
          ),
        );
        _refreshTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pausing transfer: $e')),
        );
      }
    }
  }

  Future<void> _resumeTransfer(String transferId) async {
    try {
      final res = await _client.resumeTransfer(transferId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.accepted
                ? 'Transfer resumed: ${res.message}'
                : 'Failed to resume: ${res.message}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _refreshTransfers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming transfer: $e')),
        );
      }
    }
  }

  Future<void> _revealInFolder(String path) async {
    try {
      final res = await _client.revealInFolder(path);
      if (mounted) {
        if (!res.opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to reveal file: ${res.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error revealing in folder: $e')),
        );
      }
    }
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isAndroid) {
        await AndroidNodeBridge.instance.openFile(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  String _formatBytes(dynamic bytes) {
    final b = bytes is int
        ? bytes
        : (bytes is num ? bytes.toInt() : (bytes?.toInt() ?? 0));
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Color _getStateColor(TransferState state) {
    switch (state) {
      case TransferState.TRANSFER_STATE_COMPLETED:
        return Colors.green;
      case TransferState.TRANSFER_STATE_TRANSFERRING:
      case TransferState.TRANSFER_STATE_COMMITTING:
      case TransferState.TRANSFER_STATE_VERIFYING:
        return Colors.blue;
      case TransferState.TRANSFER_STATE_PAUSED:
        return Colors.amber.shade800;
      case TransferState.TRANSFER_STATE_PREPARING:
      case TransferState.TRANSFER_STATE_CONNECTING:
      case TransferState.TRANSFER_STATE_RECEIVED:
        return Colors.orange;
      case TransferState.TRANSFER_STATE_CANCELLED:
        return Colors.grey;
      case TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN:
        return Colors.deepPurple;
      case TransferState.TRANSFER_STATE_FAILED:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedTransfers = _transfers.values.toList().reversed.toList();

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('Share & Transfers'),
          actions: [
            IconButton(
              icon: const Icon(Icons.radar_rounded),
              tooltip: 'Receive / Waiting Mode',
              onPressed: () => _showReceiveModal(context),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'Web Share Portal',
              onPressed: () {
                final selectedPaths = _selectedFiles
                    .where((f) => f.selected)
                    .map((f) => f.path)
                    .toList();
                final stagedPaths = FileStagingService.instance.stagedFiles
                    .where((f) => f.selected)
                    .map((f) => f.path)
                    .toList();
                WebBeamModal.showLive(
                  context,
                  initialPaths: selectedPaths.isNotEmpty ? selectedPaths : stagedPaths,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Transfers',
              onPressed: _refreshTransfers,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.send_rounded), text: 'SEND'),
              Tab(icon: Icon(Icons.folder_special_rounded), text: 'FILE MANAGER'),
              Tab(icon: Icon(Icons.folder_shared_rounded), text: 'BROWSE PEER'),
              Tab(icon: Icon(Icons.history_rounded), text: 'ACTIVE & HISTORY'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_refreshError != null)
              Container(
                color: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _refreshError!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _refreshTransfers,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSendTab(theme),
                  const ReceivedVaultView(),
                  _buildBrowsePeerTab(theme),
                  _buildHistoryTab(theme, sortedTransfers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final devices = DeviceTrustService.instance.devices;
    final localFingerprint = DeviceTrustService.instance.getLocalFingerprint(
      _localAndroidPeerId ?? _client.currentState.peerId ?? 'peer_local',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting to Receive',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Your device is visible to senders on local network',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<DiscoveredPeer>>(
                  stream: AndroidNodeBridge.instance.discoveredPeersStream,
                  initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                  builder: (context, snapshot) {
                    final livePeers = snapshot.data ?? [];
                    final List<RadarPeerInfo> peerInfos;
                    if (PlatformCapabilities.isAndroid) {
                      peerInfos = livePeers.map((p) {
                        final isTrusted = DeviceTrustService.instance.devices
                            .any((d) => d.id == p.peerId);
                        return RadarPeerInfo(
                          id: p.peerId,
                          name: p.name.isNotEmpty ? p.name : p.peerId,
                          deviceType: p.technology.contains('WIFI_DIRECT') ? 'phone' : 'desktop',
                          isTrusted: isTrusted,
                          ip: p.host,
                          technology: p.technology,
                          routeCount: p.routes.isNotEmpty ? p.routes.length : 1,
                        );
                      }).toList();
                    } else {
                      peerInfos = devices.map((d) => RadarPeerInfo(
                        id: d.id,
                        name: d.name,
                        deviceType: d.deviceType,
                        isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
                        ip: '127.0.0.1',
                        technology: 'Configured',
                        routeCount: 1,
                      )).toList();
                    }

                    return RadarSonarView(
                      localDeviceName: PlatformCapabilities.isAndroid ? 'Android Peer' : 'Desktop PC',
                      discoveredPeers: peerInfos,
                      onAddManualEndpoint: (ip, port, name) async {
                        final peerId = 'manual_${ip.replaceAll('.', '_')}';
                        final effectiveName = name.isNotEmpty ? name : 'Manual Endpoint ($ip)';
                        DeviceTrustService.instance.pairDevice(
                          PairedDevice(
                            id: peerId,
                            name: effectiveName,
                            deviceType: 'Manual',
                            fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                            trustLevel: DeviceTrustLevel.trustedPeer,
                            isOnline: true,
                            lastSeen: 'Direct IP Route ($ip:$port)',
                          ),
                        );
                        if (PlatformCapabilities.isAndroid) {
                          await AndroidNodeBridge.instance.addManualPeer(
                            peerId: peerId,
                            name: effectiveName,
                            host: ip,
                            port: port,
                          );
                          await AndroidNodeBridge.instance.addTrustedPeer(
                            peerId: peerId,
                            fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                            name: effectiveName,
                            host: ip,
                            port: port,
                          );
                        }
                      },
                      onPeerSelected: (peer) {
                        Navigator.pop(ctx);
                        setState(() {
                          _targetPeerController.text = peer.id;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connected with ${peer.name}'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                      onQrScanPressed: () {
                        QrPairingSheet.show(
                          context,
                          deviceName: PlatformCapabilities.isAndroid ? 'Android Peer' : 'Desktop PC',
                          peerId: _localAndroidPeerId ?? _client.currentState.peerId ?? 'peer_local',
                          fingerprint: _localAndroidFingerprint ?? localFingerprint,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRadarPicker() {
    final selectedFiles =
        _selectedFiles.where((f) => f.selected).toList();
    if (selectedFiles.isEmpty && _sourcePathsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one file to send.')),
      );
      return;
    }

    if (selectedFiles.isNotEmpty) {
      _sourcePathsController.text =
          selectedFiles.map((f) => f.path).join('\n');
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select Destination Device',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Tap a nearby peer to send the selected batch directly',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<DiscoveredPeer>>(
                  stream: AndroidNodeBridge.instance.discoveredPeersStream,
                  initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                  builder: (context, snapshot) {
                    final livePeers = snapshot.data ?? [];
                    final List<RadarPeerInfo> peerInfos;
                    if (Platform.isAndroid) {
                      peerInfos = livePeers.map((p) {
                        final isTrusted = DeviceTrustService.instance.devices
                            .any((d) => d.id == p.peerId);
                        return RadarPeerInfo(
                          id: p.peerId,
                          name: p.name.isNotEmpty ? p.name : p.peerId,
                          deviceType: p.technology.contains('WIFI_DIRECT') ? 'phone' : 'desktop',
                          isTrusted: isTrusted,
                          ip: p.host,
                          technology: p.technology,
                          routeCount: p.routes.isNotEmpty ? p.routes.length : 1,
                        );
                      }).toList();
                    } else {
                      peerInfos = DeviceTrustService.instance.devices.map((d) => RadarPeerInfo(
                        id: d.id,
                        name: d.name,
                        deviceType: d.deviceType,
                        isTrusted: d.trustLevel == DeviceTrustLevel.trustedPeer,
                        ip: '127.0.0.1',
                        technology: 'Configured',
                        routeCount: 1,
                      )).toList();
                    }

                    return RadarSonarView(
                      localDeviceName: Platform.isAndroid ? 'Android Peer' : 'This PC',
                      discoveredPeers: peerInfos,
                      onAddManualEndpoint: (ip, port, name) async {
                        final peerId = 'manual_${ip.replaceAll('.', '_')}';
                        final effectiveName = name.isNotEmpty ? name : 'Manual Endpoint ($ip)';
                        DeviceTrustService.instance.pairDevice(
                          PairedDevice(
                            id: peerId,
                            name: effectiveName,
                            deviceType: 'Manual',
                            fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                            trustLevel: DeviceTrustLevel.trustedPeer,
                            isOnline: true,
                            lastSeen: 'Direct IP Route ($ip:$port)',
                          ),
                        );
                        await AndroidNodeBridge.instance.addManualPeer(
                          peerId: peerId,
                          name: effectiveName,
                          host: ip,
                          port: port,
                        );
                        await AndroidNodeBridge.instance.addTrustedPeer(
                          peerId: peerId,
                          fingerprint: DeviceTrustService.instance.getLocalFingerprint(peerId),
                          name: effectiveName,
                          host: ip,
                          port: port,
                        );
                      },
                      onPeerSelected: (peer) {
                        Navigator.pop(ctx);
                        setState(() {
                          _targetPeerController.text = peer.id;
                        });
                        if (_selectedFiles.any((f) => f.selected)) {
                          _initiateSend();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Target set to ${peer.name}. Choose files to send!'),
                              backgroundColor: const Color(0xFF2563EB),
                            ),
                          );
                        }
                      },
                      onQrScanPressed: () {
                        Navigator.pop(ctx);
                        QrPairingSheet.show(
                          context,
                          deviceName: Platform.isAndroid ? 'Android Peer' : 'This PC',
                          peerId: _localAndroidPeerId ?? _client.currentState.peerId ?? 'peer_node_local',
                          fingerprint: _localAndroidFingerprint ?? 'ed25519:peerlink...node',
                          onQrScanned: (payload) {
                            String scannedId = payload;
                            try {
                              final invitation = PairingInvitation.parse(payload);
                              scannedId = invitation.peerId;
                            } catch (_) {}
                            setState(() {
                              _targetPeerController.text = scannedId;
                            });
                            _initiateSend();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInFlightCard(ThemeData theme, bool isDark, TransferProgress t) {
    final totalBytes = t.totalBytes.toInt();
    final transferredBytes = t.transferredBytes.toInt();
    final double? progress = totalBytes > 0
        ? (transferredBytes / totalBytes).clamp(0.0, 1.0)
        : null;
    final percent = progress != null ? (progress * 100).toInt() : 0;
    final model = _activeProgressModels[t.transferId];
    final rateStr = model?.formattedRate ??
        (t.speedBps > 0
            ? '${(t.speedBps.toInt() / (1024 * 1024)).toStringAsFixed(1)} MB/s'
            : '');
    final etaStr = model?.formattedEta ?? '';
    final fileName = t.currentFile.isNotEmpty
        ? t.currentFile.split(RegExp(r'[\\/]')).last
        : 'In-Flight Transfer';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      t.transferId.length > 16
                          ? '${t.transferId.substring(0, 16)}...'
                          : t.transferId,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (ctx) => TextButton.icon(
                  onPressed: () {
                    DefaultTabController.of(ctx).animateTo(1);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('History', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatBytes(transferredBytes)} / ${_formatBytes(totalBytes)} ($percent%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (rateStr.isNotEmpty || etaStr.isNotEmpty)
                Text(
                  [if (rateStr.isNotEmpty) rateStr, if (etaStr.isNotEmpty) etaStr].join(' • '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _cancelTransfer(t.transferId),
              icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
              label: const Text(
                'Cancel Transfer',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    final selectedCount =
        _selectedFiles.where((f) => f.selected).length;
    final selectedBytes = _selectedFiles
        .where((f) => f.selected)
        .fold<int>(0, (sum, f) => sum + f.sizeBytes);

    return DesktopDropzone(
      onFilesDropped: (dropped) {
        setState(() {
          _addPaths(dropped);
        });
      },
      child: Column(
        children: [
          // Status Banner (Initiation results, rejection, disconnection)
          if (_statusBanner != null)
            Container(
              width: double.infinity,
              color: _statusBanner!.contains('initiated')
                  ? const Color(0xFF10B981)
                  : (_statusBanner!.contains('rejected') ||
                          _statusBanner!.contains('disconnected') ||
                          _statusBanner!.contains('Error')
                      ? Colors.red.shade800
                      : Colors.blue.shade800),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _statusBanner!.contains('initiated')
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusBanner!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16),
                    onPressed: () => setState(() => _statusBanner = null),
                  ),
                ],
              ),
            ),

          // Real File Action Bar (Responsive across Desktop & Android)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Primary Action: Add Files
                FilledButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.file_open_rounded, size: 16),
                  label: const Text('Add Files...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                // Complementary Action: Folder
                OutlinedButton.icon(
                  onPressed: _pickFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('Add Folder...', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                // Complementary Action: Categories
                OutlinedButton.icon(
                  onPressed: _openMediaCategorySheet,
                  icon: const Icon(Icons.category_rounded, size: 16),
                  label: const Text('Categories...', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                // Android SAF Document Selector
                OutlinedButton.icon(
                  onPressed: _pickSafFile,
                  icon: const Icon(Icons.document_scanner_outlined, size: 16),
                  label: const Text('Pick SAF File', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                // Quick Text / Link
                OutlinedButton.icon(
                  onPressed: () => QuickTextShareModal.show(context),
                  icon: const Icon(Icons.short_text_rounded, size: 16),
                  label: const Text('Text / Link...', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                // Paste from Clipboard
                OutlinedButton.icon(
                  onPressed: () => _handlePasteToSend(context),
                  icon: const Icon(Icons.paste_rounded, size: 16),
                  label: const Text('Paste', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (_selectedFiles.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearSelectedFiles,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                  ),
              ],
            ),
          ),

          // Discovered Recipients Quick-Send Shelf (Feature A: 2-tap sharing)
          StreamBuilder<List<PairedDevice>>(
            stream: DeviceTrustService.instance.devicesStream,
            initialData: DeviceTrustService.instance.devices,
            builder: (context, pairedSnapshot) {
              return StreamBuilder<List<DiscoveredPeer>>(
                stream: AndroidNodeBridge.instance.discoveredPeersStream,
                initialData: AndroidNodeBridge.instance.activeDiscoveredPeers,
                builder: (context, snapshot) {
                  final paired = pairedSnapshot.data ?? DeviceTrustService.instance.devices;
                  final discovered = snapshot.data ?? [];

                  // Combine paired and discovered without duplicates
                  final allRecipients = <Map<String, dynamic>>[];
                  final seenIds = <String>{};

                  for (final d in paired) {
                    seenIds.add(d.id);
                    allRecipients.add({
                      'id': d.id,
                      'name': d.name,
                      'isPaired': true,
                      'isPhone': d.deviceType.toLowerCase().contains('phone'),
                    });
                  }

                  for (final p in discovered) {
                    if (!seenIds.contains(p.peerId)) {
                      seenIds.add(p.peerId);
                      allRecipients.add({
                        'id': p.peerId,
                        'name': p.name.isNotEmpty ? p.name : p.peerId,
                        'isPaired': false,
                        'isPhone': p.technology.contains('WIFI_DIRECT'),
                      });
                    }
                  }

                  if (allRecipients.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Select Recipient (${allRecipients.length} available)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _openRadarPicker,
                              child: Text(
                                '+ Pair New (QR)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: allRecipients.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final item = allRecipients[index];
                              final id = item['id'] as String;
                              final name = item['name'] as String;
                              final isPaired = item['isPaired'] as bool;
                              final isPhone = item['isPhone'] as bool;
                              final isSelected = _targetPeerController.text == id;

                              return FilterChip(
                                selected: isSelected,
                                selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                checkmarkColor: const Color(0xFF2563EB),
                                avatar: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: isPaired ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                                  child: Icon(
                                    isPhone ? Icons.phone_android_rounded : Icons.laptop_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                label: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF2563EB) : null,
                                  ),
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _targetPeerController.text = id;
                                  });
                                  if (_selectedFiles.any((f) => f.selected)) {
                                    _initiateSend();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Scrollable Media Selection List & Advanced Options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                // Active Recipient Status & Selector Bar (Mobile / Android)
                if (PlatformCapabilities.isAndroid)
                  Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _targetPeerController.text.isNotEmpty
                            ? Icons.verified_user_rounded
                            : Icons.person_search_rounded,
                        size: 18,
                        color: _targetPeerController.text.isNotEmpty
                            ? const Color(0xFF10B981)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _targetPeerController.text.isNotEmpty
                              ? 'Target Peer: ${_targetPeerController.text}'
                              : 'No recipient selected (Choose below or tap Radar)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _targetPeerController.text.isNotEmpty
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _targetPeerController.text.isNotEmpty
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_targetPeerController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          tooltip: 'Clear Target Peer',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _targetPeerController.clear();
                            });
                          },
                        ),
                      TextButton.icon(
                        onPressed: _openRadarPicker,
                        icon: const Icon(Icons.radar_rounded, size: 14),
                        label: Text(
                          _targetPeerController.text.isNotEmpty ? 'Change' : 'Select',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Active In-Flight Transfers Section (Real-Time Progress)
                ..._transfers.values
                    .where((t) => t.state == TransferState.TRANSFER_STATE_TRANSFERRING)
                    .map((t) => _buildInFlightCard(theme, isDark, t)),
                if (_selectedFiles.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                          : const Color(0xFFF1F5F9),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.drive_folder_upload_rounded,
                          size: 48,
                          color: const Color(0xFF2563EB).withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No files selected yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          PlatformCapabilities.isAndroid
                              ? 'Tap "Add Files...", "Pick SAF File", or "Categories..." above to choose files to send.'
                              : 'Drag & drop files from Windows File Explorer here, or click "Add Files..." above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._selectedFiles.map((file) {
                    final isSelected = file.selected;
                    final fileColor = file.isDirectory ? Colors.amber : const Color(0xFF2563EB);
                    return InteractiveGlassCard(
                      glowColor: null, // Minimal, clean, non-glowing
                      isSelected: isSelected,
                      borderRadius: BorderRadius.circular(18),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onTap: () {
                        setState(() {
                          file.selected = !isSelected;
                          _syncController();
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: fileColor.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              file.isDirectory
                                  ? Icons.folder_rounded
                                  : Icons.insert_drive_file_rounded,
                              color: fileColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  file.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (val) {
                              setState(() {
                                file.selected = val ?? false;
                                _syncController();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Remove file',
                            onPressed: () {
                              FileStagingService.instance.removePath(file.path);
                              setState(() {
                                _selectedFiles.remove(file);
                                _syncController();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 12),

                // Collapsible Advanced Manual Form (Preserves developer / script controls)
                ExpansionTile(
                  title: const Text(
                    'Advanced Manual Paths & Policy',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  leading: const Icon(Icons.tune_rounded, size: 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _targetPeerController,
                            decoration: const InputDecoration(
                              labelText: 'Target Peer ID',
                              hintText: 'e.g. peer_alice or node-uuid',
                              prefixIcon: Icon(Icons.person_pin_circle_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _sourcePathsController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Source Paths (File or Folder)',
                              hintText: 'Enter absolute file or folder paths',
                              prefixIcon: Icon(Icons.source_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _destinationDirController,
                            decoration: const InputDecoration(
                              labelText: 'Destination Directory (Optional)',
                              hintText: 'Leave empty for node default',
                              prefixIcon: Icon(Icons.folder_open_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<DuplicateDestinationPolicy>(
                            initialValue: _duplicatePolicy,
                            decoration: const InputDecoration(
                              labelText: 'Duplicate Policy',
                              prefixIcon: Icon(Icons.file_copy_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: DuplicateDestinationPolicy
                                    .DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
                                child: Text('FAIL_IF_EXISTS (Error if file exists)'),
                              ),
                              DropdownMenuItem(
                                value: DuplicateDestinationPolicy
                                    .DUPLICATE_DESTINATION_POLICY_OVERWRITE,
                                child: Text('OVERWRITE (Replace existing file)'),
                              ),
                              DropdownMenuItem(
                                value: DuplicateDestinationPolicy
                                    .DUPLICATE_DESTINATION_POLICY_RENAME_WITH_SUFFIX,
                                child: Text('RENAME_WITH_SUFFIX (Save as (1))'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _duplicatePolicy = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _isSending ? null : _initiateSend,
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('SEND TO EXACT PEER ID'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Sticky Bottom Batch Action Pill (AirDrop / Quick Share inspired)
        if (selectedCount > 0)
          AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            offset: Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0,
            child: GlassContainer(
              glowColor: null, // Minimal, clean, zero-glow
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 380;
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCompact ? '$selectedCount items' : '$selectedCount item(s) selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatBytes(selectedBytes),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final policy = await EphemeralPolicyModal.show(
                            context,
                            initialPolicy: _currentPolicy,
                          );
                          if (policy != null) {
                            setState(() => _currentPolicy = policy);
                          }
                        },
                        icon: Icon(
                          Icons.local_fire_department_rounded,
                          color: _currentPolicy.isEphemeral
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        tooltip: _currentPolicy.isEphemeral
                            ? 'Ephemeral Mode Active (${_currentPolicy.burnAfterRead ? "1-View" : "${_currentPolicy.ttlSeconds}s TTL"})'
                            : 'Configure Burn-After-Read Ephemeral Policy',
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: selectedCount > 0
                            ? (_targetPeerController.text.isNotEmpty
                                ? _initiateSend
                                : _openRadarPicker)
                            : null,
                        icon: Icon(
                          _currentPolicy.isEphemeral
                              ? Icons.local_fire_department_rounded
                              : (_targetPeerController.text.isNotEmpty
                                  ? Icons.send_rounded
                                  : Icons.radar_rounded),
                          size: 16,
                        ),
                        label: Text(
                          isCompact
                              ? (_currentPolicy.isEphemeral ? 'Burn' : (_targetPeerController.text.isNotEmpty ? 'Send' : 'Radar'))
                              : (_currentPolicy.isEphemeral ? 'Burn Beam' : (_targetPeerController.text.isNotEmpty ? 'Send to Recipient' : 'Send via Radar')),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _currentPolicy.isEphemeral
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF2563EB),
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 12 : 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildHistoryTab(ThemeData theme, List<TransferProgress> transfers) {
    final journalOps = OperationJournalService.instance.operations;

    final activeJournalOps = journalOps.where((op) => !op.isTerminal).toList();
    final historyJournalOps = journalOps.where((op) => op.isTerminal).toList();

    final activeTransfers = transfers.where((t) =>
        t.state == TransferState.TRANSFER_STATE_TRANSFERRING ||
        t.state == TransferState.TRANSFER_STATE_COMMITTING ||
        t.state == TransferState.TRANSFER_STATE_VERIFYING ||
        t.state == TransferState.TRANSFER_STATE_PREPARING ||
        t.state == TransferState.TRANSFER_STATE_CONNECTING).toList();

    final historyTransfers = transfers.where((t) =>
        t.state == TransferState.TRANSFER_STATE_COMPLETED ||
        t.state == TransferState.TRANSFER_STATE_FAILED ||
        t.state == TransferState.TRANSFER_STATE_CANCELLED ||
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN).toList();

    final hasActive = activeTransfers.isNotEmpty || activeJournalOps.isNotEmpty;
    final hasHistory = historyTransfers.isNotEmpty || historyJournalOps.isNotEmpty;

    if (!hasActive && !hasHistory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horizontal_circle_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No Transfers Recorded Yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            const Text(
                'Transfers initiated or received by the Local Node will appear here.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (hasActive) ...[
          Text(
            'ACTIVE IN-FLIGHT TRANSFERS (${activeTransfers.length + activeJournalOps.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 10),
          ...activeTransfers.map((t) => _buildTransferCard(theme, t)),
          ...activeJournalOps.map((op) => _buildJournalOperationCard(theme, op)),
          const SizedBox(height: 16),
        ],
        if (hasHistory) ...[
          Text(
            'TRANSFER JOURNAL & HISTORY (${historyTransfers.length + historyJournalOps.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          ...historyTransfers.map((t) => _buildTransferCard(theme, t)),
          ...historyJournalOps.map((op) => _buildJournalOperationCard(theme, op)),
        ],
      ],
    );
  }

  Widget _buildJournalOperationCard(ThemeData theme, JournalOperation op) {
    Color stateColor;
    String stateLabel;
    switch (op.state) {
      case JournalOperationState.committed:
        stateColor = const Color(0xFF10B981);
        stateLabel = 'COMMITTED';
        break;
      case JournalOperationState.executing:
        stateColor = const Color(0xFF2563EB);
        stateLabel = 'EXECUTING';
        break;
      case JournalOperationState.waiting:
        stateColor = Colors.orange;
        stateLabel = 'WAITING';
        break;
      case JournalOperationState.verifying:
        stateColor = const Color(0xFF8B5CF6);
        stateLabel = 'VERIFYING';
        break;
      case JournalOperationState.failed:
        stateColor = const Color(0xFFEF4444);
        stateLabel = 'FAILED';
        break;
      case JournalOperationState.cancelled:
        stateColor = Colors.grey;
        stateLabel = 'CANCELLED';
        break;
      case JournalOperationState.outcomeUnknown:
        stateColor = Colors.deepPurple;
        stateLabel = 'UNCERTAIN';
        break;
      default:
        stateColor = Colors.blue;
        stateLabel = op.state.name.toUpperCase();
    }

    final fraction = op.totalBytes > 0
        ? (op.bytesTransferred / op.totalBytes).clamp(0.0, 1.0)
        : 0.0;

    return InteractiveGlassCard(
      glowColor: stateColor,
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  op.summary,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: stateColor),
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Peer: ${op.peerId} • ID: ${op.operationId} • Stage: ${op.stage.name.toUpperCase()}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: op.isTerminal ? (op.state == JournalOperationState.committed ? 1.0 : fraction) : fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(stateColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatBytes(op.bytesTransferred)} / ${_formatBytes(op.totalBytes)} (${(fraction * 100).toStringAsFixed(1)}%)',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(ThemeData theme, TransferProgress t) {
    final totalBytes = t.totalBytes.toInt();
    final transferredBytes = t.transferredBytes.toInt();
    final fraction =
        totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
    final stateColor = _getStateColor(t.state);

    final isTerminated = t.state == TransferState.TRANSFER_STATE_COMPLETED ||
        t.state == TransferState.TRANSFER_STATE_FAILED ||
        t.state == TransferState.TRANSFER_STATE_CANCELLED ||
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN;

    final isCompleted = t.state == TransferState.TRANSFER_STATE_COMPLETED;
    final isPaused = t.state == TransferState.TRANSFER_STATE_PAUSED;
    final isOutcomeUnknown =
        t.state == TransferState.TRANSFER_STATE_OUTCOME_UNKNOWN;

    return InteractiveGlassCard(
      glowColor: stateColor,
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(20.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.transferId,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label:
                      'Transfer state is ${t.state.name.replaceFirst("TRANSFER_STATE_", "")}',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stateColor),
                    ),
                    child: Text(
                      t.state.name.replaceFirst('TRANSFER_STATE_', ''),
                      style: TextStyle(
                        color: stateColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (t.totalItems > 0)
              _buildDetailRow(Icons.layers_rounded, 'Items:',
                  '${t.currentItemIndex + 1} / ${t.totalItems}'),
            if (t.currentFile.isNotEmpty)
              _buildDetailRow(
                  Icons.description_rounded, 'Current File:', t.currentFile),
            if (t.destinationPath.isNotEmpty)
              _buildDetailRow(Icons.folder_special_rounded, 'Destination:',
                  t.destinationPath),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isTerminated ? (isCompleted ? 1.0 : fraction) : fraction,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final model = _activeProgressModels[t.transferId];
                final displayRate = (model != null && model.smoothedRateBytesPerSec != null)
                    ? model.formattedRate
                    : _formatSpeed(t.speedBps.toDouble());
                final displayEta = (model != null && model.estimatedRemainingTime != null)
                    ? ' • ${model.formattedEta}'
                    : '';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatBytes(transferredBytes)} / ${_formatBytes(totalBytes)} (${(fraction * 100).toStringAsFixed(1)}%)',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      isTerminated
                          ? (isCompleted
                              ? 'Verified SHA-256 ✓'
                              : (isOutcomeUnknown
                                  ? 'Outcome Unconfirmed'
                                  : 'Terminated'))
                          : (isPaused
                              ? 'Paused'
                              : '$displayRate$displayEta'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? Colors.green
                            : (isPaused ? Colors.amber.shade900 : null),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (isOutcomeUnknown) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.help_outline_rounded,
                        color: Colors.deepPurple.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outcome Unconfirmed (Network Interruption)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Data was staged remotely, but the final confirmation was interrupted. Do NOT re-send blindly to avoid duplicate copies. Verify remote destination or click "Reconcile Status" below.',
                            style: TextStyle(
                                color: Colors.deepPurple.shade900,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (t.hasError()) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.error.humanSummary.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: Colors.red.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.error.humanSummary,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (t.error.humanExplanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Why: ${t.error.humanExplanation}',
                        style:
                            TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ],
                    if (t.error.suggestedRecoveryAction.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Action: ${t.error.suggestedRecoveryAction}',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPaused) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _resumeTransfer(t.transferId),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Resume'),
                  ),
                  const SizedBox(width: 8),
                ] else if (!isTerminated) ...[
                  OutlinedButton.icon(
                    onPressed: () => _pauseTransfer(t.transferId),
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pause'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade900),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isTerminated && !isPaused)
                  OutlinedButton.icon(
                    onPressed: () => _cancelTransfer(t.transferId),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                if (isOutcomeUnknown) ...[
                  FilledButton.tonalIcon(
                    onPressed: _refreshTransfers,
                    icon: const Icon(Icons.sync_problem_rounded, size: 18),
                    label: const Text('Reconcile Status'),
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      BurnViewerModal.show(
                        context,
                        fileName: t.currentFile.isNotEmpty
                            ? t.currentFile.split(RegExp(r'[\\/]')).last
                            : 'Document.pdf',
                        fileSize: _formatBytes(t.transferredBytes),
                        previewContent:
                            'CONFIDENTIAL ENCRYPTED RECORD\nSHA-256 Verified Payload: 8f4a...e12b\nZero-Trust Ephemeral Beam Content\nAuto-shredded upon viewer closure.',
                        policy: EphemeralPolicy.singleView,
                        onShred: () {
                          setState(() {
                            _transfers.remove(t.transferId);
                          });
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    label: const Text('Burn Viewer'),
                  ),
                ],
                if (isCompleted && t.destinationPath.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openFile(t.destinationPath),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open File'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _revealInFolder(t.destinationPath),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Reveal in Folder'),
                  ),
                ],
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowsePeerTab(ThemeData theme) {
    return StreamBuilder<List<PairedDevice>>(
      stream: DeviceTrustService.instance.devicesStream,
      initialData: DeviceTrustService.instance.devices,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // ACCESS Mode Explanation Glass Container
            GlassContainer(
              glowColor: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(18),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_shared_rounded,
                        color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remote Scoped Explorer (ACCESS Mode)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Browse and download shared files directly from your paired devices without transferring entire folders. Completely private and sandboxed.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Devices Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Online & Paired Peers (${devices.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (devices.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.devices_rounded, size: 40, color: theme.disabledColor),
                    const SizedBox(height: 12),
                    const Text(
                      'No Paired Devices',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pair your phone, laptop, or desktop in the Devices tab to browse its shared folders here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              ...devices.map((dev) {
                final isGuest = dev.trustLevel == DeviceTrustLevel.temporaryGuest;
                final glow = isGuest ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

                return InteractiveGlassCard(
                  glowColor: glow,
                  margin: const EdgeInsets.only(bottom: 10),
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: glow.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          dev.deviceType.toLowerCase().contains('phone')
                              ? Icons.smartphone_rounded
                              : Icons.laptop_rounded,
                          color: glow,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    dev.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: glow.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    dev.isOnline ? 'Online' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: glow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${dev.id}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: dev.isOnline
                            ? () => RemoteScopedBrowserSheet.show(context, dev)
                            : null,
                        icon: const Icon(Icons.folder_shared_rounded, size: 15),
                        label: const Text('Browse Files'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
