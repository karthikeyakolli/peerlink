import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/node_watchdog_service.dart';

void main() {
  late Directory tempStagingDir;

  setUp(() {
    tempStagingDir = Directory.systemTemp.createTempSync('peerlink_watchdog_staging_test_');
    NodeWatchdogService.instance.resetForTesting();
  });

  tearDown(() {
    NodeWatchdogService.instance.stopWatchdog();
    try {
      tempStagingDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('NodeWatchdogService Unit Tests (Phase 16 Self-Healing & Diagnostics)', () {
    test('Starts and stops watchdog timer', () {
      final watchdog = NodeWatchdogService.instance;
      expect(watchdog.isRunning, isFalse);

      watchdog.startWatchdog(interval: const Duration(seconds: 1));
      expect(watchdog.isRunning, isTrue);

      watchdog.stopWatchdog();
      expect(watchdog.isRunning, isFalse);
    });

    test('Reports healthy when database integrity is clean and memory is normal', () async {
      final watchdog = NodeWatchdogService.instance;
      watchdog.dbIntegrityChecker = () => true;
      watchdog.memoryUsedProvider = () => 50 * 1024 * 1024;
      watchdog.memoryMaxProvider = () => 512 * 1024 * 1024;

      final report = await watchdog.inspectAndHeal();

      expect(report.healthy, isTrue);
      expect(report.dbIntegrityOk, isTrue);
      expect(report.restartLoopInhibited, isFalse);
      expect(report.warnings, isEmpty);
    });

    test('Warns when database reports corruption', () async {
      final watchdog = NodeWatchdogService.instance;
      watchdog.dbIntegrityChecker = () => false;

      final report = await watchdog.inspectAndHeal();

      expect(report.healthy, isFalse);
      expect(report.dbIntegrityOk, isFalse);
      expect(report.warnings.any((w) => w.contains('Database reported corruption')), isTrue);
    });

    test('Warns when memory pressure exceeds 90%', () async {
      final watchdog = NodeWatchdogService.instance;
      watchdog.memoryUsedProvider = () => 480 * 1024 * 1024; // 480 MB
      watchdog.memoryMaxProvider = () => 500 * 1024 * 1024;  // 500 MB (96%)

      final report = await watchdog.inspectAndHeal();

      expect(report.healthy, isFalse);
      expect(report.warnings.any((w) => w.contains('Memory pressure critical')), isTrue);
    });

    test('Scavenges stale temporary and partial files older than stale age', () async {
      final watchdog = NodeWatchdogService.instance;
      watchdog.stagingDirectoryOverride = tempStagingDir.path;

      // Create a stale temporary file
      final staleFile = File('${tempStagingDir.path}/interrupted_stream.part');
      staleFile.writeAsStringSync('stale chunk data');

      // Set modification time to 3 hours ago
      final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
      staleFile.setLastModifiedSync(threeHoursAgo);

      // Create a recent temporary file (should not be deleted)
      final recentFile = File('${tempStagingDir.path}/active_stream.part');
      recentFile.writeAsStringSync('fresh chunk data');

      final report = await watchdog.inspectAndHeal();

      expect(report.cleanedStaleFiles, equals(1));
      expect(staleFile.existsSync(), isFalse);
      expect(recentFile.existsSync(), isTrue);
    });

    test('Crash-loop protector engages after excessive restarts within rolling window', () {
      final watchdog = NodeWatchdogService.instance;

      expect(watchdog.recordRestartAndCheckInhibition(), isFalse); // Restart 1
      expect(watchdog.recordRestartAndCheckInhibition(), isFalse); // Restart 2
      expect(watchdog.recordRestartAndCheckInhibition(), isFalse); // Restart 3
      expect(watchdog.recordRestartAndCheckInhibition(), isTrue);  // Restart 4 -> Engages crash-loop guard!
    });

    test('Exports privacy-safe diagnostics bundle', () {
      final bundle = NodeWatchdogService.instance.exportPrivacySafeDiagnostics();

      expect(bundle['nodeVersion'], equals('1.0.0-rc1'));
      expect(bundle['privacyScrubbed'], isTrue);
      expect(bundle.containsKey('restartsInWindow'), isTrue);
      expect(bundle.containsKey('activeOperations'), isTrue);
    });
  });
}
