import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../core/app_constants.dart';
import '../core/node_ipc_client.dart';

enum WindowsNodeProcessState {
  stopped,
  starting,
  running,
  error,
}

/// Authoritative manager for the Windows Desktop Local Node daemon.
/// Handles zero-configuration background process allocation, JAR discovery,
/// port liveness checking, and seamless local token authentication.
class WindowsNodeManager {
  static final WindowsNodeManager _instance = WindowsNodeManager._internal();
  static WindowsNodeManager get instance => _instance;

  WindowsNodeManager._internal();

  WindowsNodeProcessState _state = WindowsNodeProcessState.stopped;
  WindowsNodeProcessState get state => _state;

  Process? _nodeProcess;
  int? _nodePid;
  int? get nodePid => _nodePid;

  String? _authToken;
  String? get authToken => _authToken;

  int _port = AppConstants.defaultIpcPort;
  int get port => _port;

  String? _lastError;
  String? get lastError => _lastError;

  final StreamController<WindowsNodeProcessState> _stateController =
      StreamController<WindowsNodeProcessState>.broadcast();
  Stream<WindowsNodeProcessState> get stateStream => _stateController.stream;

  // Test hooks / overrides
  static bool? overridePortOpenForTesting;
  static String? overrideJarPathForTesting;
  static bool skipProcessSpawnForTesting = false;
  static bool get isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST');

  void _notifyState(WindowsNodeProcessState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Directory getDataDirectory() {
    final userHome = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final dir = Directory('$userHome\\.peerlink');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  Future<String> getOrCreateAuthToken() async {
    if (_authToken != null && _authToken!.isNotEmpty) {
      return _authToken!;
    }
    final dataDir = getDataDirectory();
    final tokenFile = File('${dataDir.path}\\ipc_auth.token');
    if (tokenFile.existsSync()) {
      try {
        final content = tokenFile.readAsStringSync().trim();
        if (content.isNotEmpty) {
          _authToken = content;
          return _authToken!;
        }
      } catch (_) {}
    }

    // Generate secure random 32-byte URL-safe token
    final rand = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    try {
      tokenFile.writeAsStringSync(token);
    } catch (_) {}
    _authToken = token;
    return _authToken!;
  }

  Future<bool> isPortOpen(int port, {Duration timeout = const Duration(milliseconds: 300)}) async {
    if (overridePortOpenForTesting != null) {
      return overridePortOpenForTesting!;
    }
    try {
      final socket = await Socket.connect(
        AppConstants.defaultIpcHost,
        port,
        timeout: timeout,
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  String findJavaExecutable() {
    try {
      final exeFile = File(Platform.resolvedExecutable);
      final exeDir = exeFile.parent;
      final bundledJava = File('${exeDir.parent.path}\\runtime\\bin\\java.exe');
      if (bundledJava.existsSync()) {
        return bundledJava.path;
      }
    } catch (_) {}
    final javaHome = Platform.environment['JAVA_HOME'];
    if (javaHome != null && javaHome.isNotEmpty) {
      final javaExe = File('$javaHome\\bin\\java.exe');
      if (javaExe.existsSync()) {
        return javaExe.path;
      }
    }
    return 'java';
  }

  File? findJarFile() {
    if (overrideJarPathForTesting != null) {
      if (overrideJarPathForTesting!.isEmpty) return null;
      final f = File(overrideJarPathForTesting!);
      return f.existsSync() ? f : null;
    }

    // Check environment variable
    final envJar = Platform.environment['PEERLINK_NODE_JAR'];
    if (envJar != null && envJar.isNotEmpty) {
      final f = File(envJar);
      if (f.existsSync()) return f;
    }

    final List<String> candidatePaths = [];

    // Packaged release layout: relative to resolved executable (peerlink.exe)
    try {
      final exeFile = File(Platform.resolvedExecutable);
      final exeDir = exeFile.parent;
      // If exe is in bin/peerlink.exe -> ../lib/peerlink-windows-node.jar
      candidatePaths.add('${exeDir.parent.path}\\lib\\peerlink-windows-node.jar');
      candidatePaths.add('${exeDir.parent.path}\\lib\\peerlink-windows-node-0.1.0-SNAPSHOT-all.jar');
      candidatePaths.add('${exeDir.path}\\lib\\peerlink-windows-node.jar');
      candidatePaths.add('${exeDir.path}\\peerlink-windows-node.jar');
    } catch (_) {}

    // Development / project working directory layout
    final currentPath = Directory.current.path;
    candidatePaths.addAll([
      '$currentPath\\windows\\dist\\peerlink-windows-1.0.0-rc1\\lib\\peerlink-windows-node.jar',
      '$currentPath\\windows\\target\\peerlink-windows-node-0.1.0-SNAPSHOT-all.jar',
      '$currentPath\\target\\peerlink-windows-node-0.1.0-SNAPSHOT-all.jar',
      '$currentPath\\..\\windows\\target\\peerlink-windows-node-0.1.0-SNAPSHOT-all.jar',
      '$currentPath\\..\\..\\windows\\target\\peerlink-windows-node-0.1.0-SNAPSHOT-all.jar',
    ]);

    for (final path in candidatePaths) {
      final f = File(path);
      if (f.existsSync()) {
        return f;
      }
    }
    return null;
  }

  Future<bool> startBackgroundNode({int port = AppConstants.defaultIpcPort}) async {
    _port = port;
    if (await isPortOpen(_port)) {
      _notifyState(WindowsNodeProcessState.running);
      return true;
    }

    if (skipProcessSpawnForTesting) {
      _notifyState(WindowsNodeProcessState.running);
      return true;
    }

    final token = await getOrCreateAuthToken();
    final jarFile = findJarFile();
    if (jarFile == null || !jarFile.existsSync()) {
      _lastError = 'Local node JAR file not found. Ensure peerlink-windows-node.jar is built or packaged.';
      _notifyState(WindowsNodeProcessState.error);
      return false;
    }

    _notifyState(WindowsNodeProcessState.starting);

    final javaExec = findJavaExecutable();
    final dataDir = getDataDirectory();

    try {
      final process = await Process.start(
        javaExec,
        [
          '-jar',
          jarFile.absolute.path,
          '--port',
          '$_port',
          '--data-dir',
          dataDir.absolute.path,
          '--token',
          token,
        ],
        mode: ProcessStartMode.detached,
      );

      _nodePid = process.pid;
      _nodeProcess = process;

      // Poll port until ready
      const maxAttempts = 25;
      for (int i = 0; i < maxAttempts; i++) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (await isPortOpen(_port)) {
          _notifyState(WindowsNodeProcessState.running);
          return true;
        }
      }

      _lastError = 'Background node process started (PID: $_nodePid), but IPC port $_port did not respond in time.';
      _notifyState(WindowsNodeProcessState.error);
      return false;
    } catch (e) {
      _lastError = 'Failed to allocate/spawn background Java node: $e';
      _notifyState(WindowsNodeProcessState.error);
      return false;
    }
  }

  Future<bool> autoStartAndAuthenticate({
    NodeIpcClient? client,
    int port = AppConstants.defaultIpcPort,
  }) async {
    _port = port;
    final targetClient = client ?? NodeIpcClient.instance;

    // Check if already authenticated
    if (targetClient.isAuthenticated) {
      _notifyState(WindowsNodeProcessState.running);
      return true;
    }

    // 1. Ensure node process is running
    bool running = await isPortOpen(_port);
    if (!running) {
      running = await startBackgroundNode(port: _port);
    } else {
      _notifyState(WindowsNodeProcessState.running);
    }

    // 2. Fetch the authoritative local auth token
    final token = await getOrCreateAuthToken();

    // 3. Connect and authenticate over loopback gRPC
    try {
      final success = await targetClient.connectAndAuthenticate(
        host: AppConstants.defaultIpcHost,
        port: _port,
        localAuthToken: token,
        clientVersion: AppConstants.appVersion,
        clientPid: pid,
      );
      if (success) {
        _notifyState(WindowsNodeProcessState.running);
      }
      return success;
    } catch (e) {
      _lastError = 'Auto-authentication failed: $e';
      return false;
    }
  }

  Future<bool> restartNode({
    NodeIpcClient? client,
    int port = AppConstants.defaultIpcPort,
  }) async {
    final targetClient = client ?? NodeIpcClient.instance;
    try {
      if (targetClient.isAuthenticated) {
        await targetClient.restartNode();
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1200));
    return autoStartAndAuthenticate(client: targetClient, port: port);
  }

  void stopManagedProcess() {
    if (_nodeProcess != null) {
      try {
        _nodeProcess!.kill();
      } catch (_) {}
      _nodeProcess = null;
    }
    _notifyState(WindowsNodeProcessState.stopped);
  }

  /// Native Win32 Shell integration: highlights a file or folder in Windows File Explorer.
  Future<bool> revealInExplorer(String path) async {
    if (!Platform.isWindows) return false;
    try {
      final file = File(path);
      if (file.existsSync()) {
        await Process.run('explorer.exe', ['/select,${file.path}']);
        return true;
      }
      final dir = Directory(path);
      if (dir.existsSync()) {
        await Process.run('explorer.exe', [dir.path]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Native Win32 Shell integration: registers "Send with PeerLink" Explorer context menu.
  Future<bool> registerContextMenu() async {
    if (!Platform.isWindows) return false;
    try {
      final exe = Platform.resolvedExecutable;
      final script = '''
\$exe = "$exe"
\$fileKey = "HKCU:\\Software\\Classes\\*\\shell\\PeerLink"
New-Item -Path \$fileKey -Force | Out-Null
Set-ItemProperty -Path \$fileKey -Name "(Default)" -Value "Send with PeerLink"
Set-ItemProperty -Path \$fileKey -Name "Icon" -Value "`"\$exe`",0"
\$fileCmd = "\$fileKey\\command"
New-Item -Path \$fileCmd -Force | Out-Null
Set-ItemProperty -Path \$fileCmd -Name "(Default)" -Value "`"\$exe`" `"%1`""

\$dirKey = "HKCU:\\Software\\Classes\\Directory\\shell\\PeerLink"
New-Item -Path \$dirKey -Force | Out-Null
Set-ItemProperty -Path \$dirKey -Name "(Default)" -Value "Send folder with PeerLink"
Set-ItemProperty -Path \$dirKey -Name "Icon" -Value "`"\$exe`",0"
\$dirCmd = "\$dirKey\\command"
New-Item -Path \$dirCmd -Force | Out-Null
Set-ItemProperty -Path \$dirCmd -Name "(Default)" -Value "`"\$exe`" `"%1`""
''';
      final res = await Process.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
