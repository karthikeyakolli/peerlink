import 'dart:async';
import 'package:flutter/services.dart';
import '../core/file_staging_service.dart';

/// Bridges native Windows Desktop shell events (Explorer drag-and-drop WM_DROPFILES,
/// System Tray Quick-Send menu, and right-click "Send with PeerLink" CLI launch args)
/// directly into PeerLink's contextual sharing workflow.
class DesktopShellBridge {
  static const MethodChannel _channel = MethodChannel('org.peerlink/desktop_shell');

  static final DesktopShellBridge instance = DesktopShellBridge._();

  final StreamController<List<String>> _droppedFilesController =
      StreamController<List<String>>.broadcast();
  final StreamController<void> _trayQuickSendController =
      StreamController<void>.broadcast();

  final List<String> _pendingLaunchArgs = [];

  Stream<List<String>> get droppedFilesStream => _droppedFilesController.stream;
  Stream<void> get trayQuickSendStream => _trayQuickSendController.stream;

  DesktopShellBridge._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesDropped') {
        final raw = call.arguments;
        if (raw is List) {
          final paths = raw
              .map((e) => e?.toString().trim() ?? '')
              .where((p) => p.isNotEmpty)
              .toList();
          handleIncomingPaths(paths);
        }
      } else if (call.method == 'onTrayQuickSend') {
        _trayQuickSendController.add(null);
      }
      return null;
    });
  }

  /// Records file paths passed via Windows Explorer "Send with PeerLink" CLI args
  /// so MainNavigationShell can immediately open the Contextual Share Sheet on startup.
  void recordLaunchArgs(List<String> paths) {
    final valid = paths.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (valid.isEmpty) return;
    _pendingLaunchArgs
      ..clear()
      ..addAll(valid);
    FileStagingService.instance.addPaths(valid);
  }

  /// Consumes and clears any pending cold-start Explorer file arguments.
  List<String> consumeLaunchArgs() {
    if (_pendingLaunchArgs.isEmpty) return const [];
    final copy = List<String>.from(_pendingLaunchArgs);
    _pendingLaunchArgs.clear();
    return copy;
  }

  /// Stages dropped/shared desktop paths and triggers the Quick-Send share sheet.
  void handleIncomingPaths(List<String> paths) {
    final valid = paths.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (valid.isEmpty) return;
    FileStagingService.instance.addPaths(valid);
    _droppedFilesController.add(valid);
  }

  /// Triggers the tray Quick-Send event (used by native tray menu & tests).
  void triggerTrayQuickSend() {
    _trayQuickSendController.add(null);
  }
}
