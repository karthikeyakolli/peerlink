import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'app_settings_service.dart';
import 'device_trust_service.dart';
import 'file_staging_service.dart';
import 'operation_journal_service.dart';

class DropZoneEvent {
  final String dropZoneId;
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final String? targetPeerId;
  final bool autoDispatched;
  final DateTime timestamp;

  DropZoneEvent({
    required this.dropZoneId,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    this.targetPeerId,
    required this.autoDispatched,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SmartDropZoneConfig {
  final String id;
  final String folderPath;
  final String? targetPeerId;
  final bool autoDispatch;
  final bool enabled;

  const SmartDropZoneConfig({
    required this.id,
    required this.folderPath,
    this.targetPeerId,
    this.autoDispatch = false,
    this.enabled = true,
  });
}

/// Drop-Zone / Quick-Beam Watcher Daemon.
/// Monitors designated drop folder(s). Any deposited file is automatically
/// validated (Rule 8: filesystem truth), staged in FileStagingService,
/// and optionally dispatched to a configured paired peer without manual UI work.
class DropZoneService {
  DropZoneService._();
  static final DropZoneService instance = DropZoneService._();

  final List<SmartDropZoneConfig> _zones = [];
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  final Set<String> _processedFileSignatures = {};
  final StreamController<DropZoneEvent> _eventController =
      StreamController<DropZoneEvent>.broadcast();
  Timer? _pollingTimer;

  Stream<DropZoneEvent> get eventStream => _eventController.stream;
  List<SmartDropZoneConfig> get zones => List.unmodifiable(_zones);
  bool get isRunning => _watchers.isNotEmpty || (_pollingTimer != null && _pollingTimer!.isActive);

  void resetForTesting() {
    stopWatcher();
    _zones.clear();
    _processedFileSignatures.clear();
  }

  /// Adds or updates a monitored drop zone.
  void configureDropZone(SmartDropZoneConfig config) {
    _zones.removeWhere((z) => z.id == config.id);
    _zones.add(config);
    if (isRunning) {
      _restartWatchers();
    }
  }

  /// Removes a drop zone by id.
  void removeDropZone(String id) {
    _watchers[id]?.cancel();
    _watchers.remove(id);
    _zones.removeWhere((z) => z.id == id);
  }

  /// Starts monitoring all configured and enabled drop zones.
  void startWatcher() {
    stopWatcher();
    _restartWatchers();

    // Secondary periodic sweep every 30 seconds to catch OS dropped file events (Rule 8)
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sweepDropZones();
    });
  }

  /// Stops all active watchers and background sweep timers.
  void stopWatcher() {
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _restartWatchers() {
    for (final sub in _watchers.values) {
      sub.cancel();
    }
    _watchers.clear();

    for (final zone in _zones) {
      if (!zone.enabled) continue;
      final dir = Directory(zone.folderPath);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {
          continue;
        }
      }

      try {
        final watcher = dir.watch(events: FileSystemEvent.create | FileSystemEvent.modify).listen((event) {
          _handleFileSystemEvent(zone, event);
        });
        _watchers[zone.id] = watcher;
      } catch (_) {
        // OS filesystem watchers might not be supported on all environments; polling timer acts as fallback.
      }
    }
  }

  void _handleFileSystemEvent(SmartDropZoneConfig zone, FileSystemEvent event) {
    if (event.isDirectory) return;
    final file = File(event.path);
    _processFile(zone, file);
  }

  /// Scans all configured drop zones, checking actual filesystem state (Rule 8).
  Future<List<DropZoneEvent>> sweepDropZones() async {
    final events = <DropZoneEvent>[];
    for (final zone in _zones) {
      if (!zone.enabled) continue;
      final dir = Directory(zone.folderPath);
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(recursive: false);
        for (final entity in entities) {
          if (entity is File) {
            final ev = await _processFile(zone, entity);
            if (ev != null) {
              events.add(ev);
            }
          }
        }
      } catch (_) {}
    }
    return events;
  }

  Future<DropZoneEvent?> _processFile(SmartDropZoneConfig zone, File file) async {
    final fileName = file.uri.pathSegments.last;

    // Rule 10 & Safety: Ignore temporary transfer chunks and partial writes
    if (fileName.startsWith('.') ||
        fileName.endsWith('.part') ||
        fileName.endsWith('.tmp') ||
        fileName.endsWith('.download')) {
      return null;
    }

    if (!file.existsSync()) return null;

    int length = 0;
    try {
      length = file.lengthSync();
    } catch (_) {
      return null; // File might be open by another process for exclusive write
    }

    if (length <= 0) return null;

    // Build signature (path + length + modified) to prevent duplicate triggers
    DateTime modified;
    try {
      modified = file.lastModifiedSync();
    } catch (_) {
      modified = DateTime.now();
    }

    final signature = '${file.path}_${length}_${modified.millisecondsSinceEpoch}';
    if (_processedFileSignatures.contains(signature)) {
      return null;
    }
    _processedFileSignatures.add(signature);

    // 1. Automatically stage the file in FileStagingService
    FileStagingService.instance.addPaths([file.path]);

    // 2. Auto-dispatch if enabled and target peer is configured
    final shouldDispatch = zone.autoDispatch && zone.targetPeerId != null && zone.targetPeerId!.isNotEmpty;

    if (shouldDispatch) {
      OperationJournalService.instance.recordOperation(
        JournalOperation(
          operationId: 'drop_${DateTime.now().millisecondsSinceEpoch}',
          type: OperationType.send,
          state: JournalOperationState.created,
          stage: JournalStage.intent,
          peerId: zone.targetPeerId!,
          summary: 'Auto-Beam: $fileName to ${zone.targetPeerId}',
          totalBytes: length,
          bytesTransferred: 0,
          timestamp: DateTime.now(),
        ),
      );
    }

    final event = DropZoneEvent(
      dropZoneId: zone.id,
      filePath: file.path,
      fileName: fileName,
      fileSizeBytes: length,
      targetPeerId: zone.targetPeerId,
      autoDispatched: shouldDispatch,
    );

    if (!_eventController.isClosed) {
      _eventController.add(event);
    }

    return event;
  }
}
