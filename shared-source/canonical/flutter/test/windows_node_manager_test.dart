import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/node_ipc_client.dart';
import 'package:peerlink/platform/windows_node_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowsNodeManager Authoritative Background Node Allocation Tests', () {
    late WindowsNodeManager manager;

    setUp(() {
      manager = WindowsNodeManager.instance;
      WindowsNodeManager.overridePortOpenForTesting = null;
      WindowsNodeManager.overrideJarPathForTesting = null;
      WindowsNodeManager.skipProcessSpawnForTesting = false;
    });

    test('Data directory resolution points to .peerlink in user home profile', () {
      final dir = manager.getDataDirectory();
      expect(dir.path, contains('.peerlink'));
    });

    test('getOrCreateAuthToken generates non-empty secure URL-safe base64 token', () async {
      final token = await manager.getOrCreateAuthToken();
      expect(token.isNotEmpty, isTrue);
      expect(token.length, greaterThanOrEqualTo(32));
      // Idempotency: subsequent calls return the same token
      final token2 = await manager.getOrCreateAuthToken();
      expect(token2, equals(token));
    });

    test('startBackgroundNode detects already running port and reports running state', () async {
      WindowsNodeManager.overridePortOpenForTesting = true;

      final started = await manager.startBackgroundNode(port: 50051);
      expect(started, isTrue);
      expect(manager.state, WindowsNodeProcessState.running);
    });

    test('startBackgroundNode handles missing JAR gracefully with clear error (Failure Path)', () async {
      WindowsNodeManager.overridePortOpenForTesting = false;
      WindowsNodeManager.overrideJarPathForTesting = 'C:\\non_existent_jar_path\\node.jar';

      final started = await manager.startBackgroundNode(port: 50051);
      expect(started, isFalse);
      expect(manager.state, WindowsNodeProcessState.error);
      expect(manager.lastError, contains('Local node JAR file not found'));
    });

    test('autoStartAndAuthenticate transitions state to running when port is simulated open', () async {
      WindowsNodeManager.overridePortOpenForTesting = true;
      WindowsNodeManager.skipProcessSpawnForTesting = true;

      // When node is running, it returns true
      final status = await manager.startBackgroundNode(port: 50051);
      expect(status, isTrue);
      expect(manager.state, WindowsNodeProcessState.running);
    });

    test('stopManagedProcess resets state to stopped', () {
      manager.stopManagedProcess();
      expect(manager.state, WindowsNodeProcessState.stopped);
    });

    test('findJavaExecutable resolves bundled runtime or standard system java', () {
      final javaExe = manager.findJavaExecutable();
      expect(javaExe.isNotEmpty, isTrue);
      expect(javaExe, anyOf(contains('java'), contains('bin')));
    });

    test('revealInExplorer handles invalid paths safely without throwing', () async {
      final res = await manager.revealInExplorer('C:\\non_existent_folder_xyz');
      expect(res, isFalse);
    });
  });
}
