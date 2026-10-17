import 'dart:async';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';
import 'app_constants.dart';
import 'protocol/peerlink/v1/common.pb.dart';
import 'protocol/peerlink/v1/ipc.pbgrpc.dart';
import 'protocol/peerlink/v1/transfer.pb.dart';

enum IpcConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  incompatibleVersion,
  reconnecting,
  error,
}

class IpcConnectionState {
  final IpcConnectionStatus status;
  final String? errorMessage;
  final String? peerId;
  final String? nodeVersion;
  final bool isCompatible;
  final int activeHeartbeatCount;
  final NodeHeartbeat? lastHeartbeat;
  final GetNodeStatusResponse? lastStatus;

  const IpcConnectionState({
    required this.status,
    this.errorMessage,
    this.peerId,
    this.nodeVersion,
    this.isCompatible = true,
    this.activeHeartbeatCount = 0,
    this.lastHeartbeat,
    this.lastStatus,
  });

  IpcConnectionState copyWith({
    IpcConnectionStatus? status,
    String? errorMessage,
    String? peerId,
    String? nodeVersion,
    bool? isCompatible,
    int? activeHeartbeatCount,
    NodeHeartbeat? lastHeartbeat,
    GetNodeStatusResponse? lastStatus,
  }) {
    return IpcConnectionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      peerId: peerId ?? this.peerId,
      nodeVersion: nodeVersion ?? this.nodeVersion,
      isCompatible: isCompatible ?? this.isCompatible,
      activeHeartbeatCount: activeHeartbeatCount ?? this.activeHeartbeatCount,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      lastStatus: lastStatus ?? this.lastStatus,
    );
  }
}

/// Client communicating with the authoritative Desktop Local Node daemon over authenticated localhost gRPC.
/// Invariant: Flutter UI is NOT authoritative. All transfer truth, trust decisions, and operations belong to the node.
class NodeIpcClient {
  static final NodeIpcClient _instance = NodeIpcClient();
  static NodeIpcClient get instance => _instance;

  ClientChannel? _channel;
  DesktopLocalNodeServiceClient? _stub;
  String? _sessionToken;
  String? _cachedHost;
  int? _cachedPort;
  String? _cachedToken;
  String? _cachedClientVersion;

  StreamSubscription<NodeEvent>? _eventSubscription;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;

  final _stateController = StreamController<IpcConnectionState>.broadcast();
  final _transferProgressController =
      StreamController<TransferProgress>.broadcast();
  IpcConnectionState _currentState =
      const IpcConnectionState(status: IpcConnectionStatus.disconnected);

  IpcConnectionState get currentState => _currentState;
  Stream<IpcConnectionState> get stateStream => _stateController.stream;
  Stream<TransferProgress> get transferProgressStream =>
      _transferProgressController.stream;

  bool get isAuthenticated =>
      _currentState.status == IpcConnectionStatus.connected;
  String? get sessionToken => _sessionToken;

  void _updateState(IpcConnectionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Future<bool> connectAndAuthenticate({
    String host = AppConstants.defaultIpcHost,
    int port = AppConstants.defaultIpcPort,
    required String localAuthToken,
    String clientVersion = AppConstants.appVersion,
    int clientPid = 0,
  }) async {
    _manualDisconnect = false;
    _cachedHost = host;
    _cachedPort = port;
    _cachedToken = localAuthToken;
    _cachedClientVersion = clientVersion;

    _updateState(_currentState.copyWith(
      status: IpcConnectionStatus.connecting,
      errorMessage: null,
    ));

    try {
      await _channel?.shutdown();
      _channel = ClientChannel(
        host,
        port: port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
      _stub = DesktopLocalNodeServiceClient(_channel!);

      _updateState(
          _currentState.copyWith(status: IpcConnectionStatus.authenticating));

      final authRequest = AuthenticateIpcRequest()
        ..authToken = localAuthToken
        ..clientPid = fixnum.Int64(clientPid)
        ..clientVersion = clientVersion;

      final authResponse = await _stub!.authenticate(
        authRequest,
        options: CallOptions(timeout: const Duration(seconds: 5)),
      );

      if (!authResponse.isCompatible) {
        _updateState(_currentState.copyWith(
          status: IpcConnectionStatus.incompatibleVersion,
          isCompatible: false,
          nodeVersion: authResponse.nodeVersion,
          errorMessage: authResponse.errorMessage.isNotEmpty
              ? authResponse.errorMessage
              : 'Incompatible client version: $clientVersion vs node ${authResponse.nodeVersion}',
        ));
        return false;
      }

      if (!authResponse.authenticated) {
        _updateState(_currentState.copyWith(
          status: IpcConnectionStatus.error,
          isCompatible: true,
          errorMessage: authResponse.errorMessage.isNotEmpty
              ? authResponse.errorMessage
              : 'Local IPC authentication failed (invalid token)',
        ));
        return false;
      }

      _sessionToken = authResponse.sessionToken;
      final peerId = authResponse.localPeerId.value;

      _updateState(_currentState.copyWith(
        status: IpcConnectionStatus.connected,
        peerId: peerId,
        nodeVersion: authResponse.nodeVersion,
        isCompatible: true,
        errorMessage: null,
      ));

      // 1. Initial status query
      await getStatus();

      // 2. Start server-streaming event subscription
      _startEventSubscription();

      return true;
    } catch (e) {
      _updateState(_currentState.copyWith(
        status: IpcConnectionStatus.error,
        errorMessage: 'Connection failed: $e',
      ));
      _scheduleReconnect();
      return false;
    }
  }

  void _startEventSubscription() {
    _eventSubscription?.cancel();
    if (_stub == null || _sessionToken == null) return;

    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
    );

    try {
      final stream = _stub!.subscribeEvents(
        NodeEventSubscriptionRequest()..sessionToken = _sessionToken!,
        options: options,
      );

      _eventSubscription = stream.listen(
        (event) {
          if (event.hasHeartbeat()) {
            _updateState(_currentState.copyWith(
              activeHeartbeatCount: _currentState.activeHeartbeatCount + 1,
              lastHeartbeat: event.heartbeat,
            ));
          }
          if (event.hasTransferProgress()) {
            if (!_transferProgressController.isClosed) {
              _transferProgressController.add(event.transferProgress);
            }
          }
        },
        onError: (error) {
          if (!_manualDisconnect) {
            _updateState(_currentState.copyWith(
              status: IpcConnectionStatus.reconnecting,
              errorMessage: 'Event stream disconnected: $error',
            ));
            _scheduleReconnect();
          }
        },
        onDone: () {
          if (!_manualDisconnect) {
            _updateState(_currentState.copyWith(
              status: IpcConnectionStatus.reconnecting,
              errorMessage: 'Node closed event stream.',
            ));
            _scheduleReconnect();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  Future<GetNodeStatusResponse?> getStatus() async {
    if (_stub == null || _sessionToken == null) return null;
    try {
      final options = CallOptions(
        metadata: {'x-peerlink-auth-token': _sessionToken!},
        timeout: const Duration(seconds: 4),
      );
      final response = await _stub!.getStatus(
        GetNodeStatusRequest()..sessionToken = _sessionToken!,
        options: options,
      );
      _updateState(_currentState.copyWith(lastStatus: response));
      return response;
    } catch (e) {
      if (!_manualDisconnect) {
        _scheduleReconnect();
      }
      return null;
    }
  }

  Future<bool> restartNode({int delayMs = 100}) async {
    if (_stub == null || _sessionToken == null) return false;
    try {
      final options = CallOptions(
        metadata: {'x-peerlink-auth-token': _sessionToken!},
        timeout: const Duration(seconds: 4),
      );
      final response = await _stub!.restart(
        RestartNodeRequest()
          ..sessionToken = _sessionToken!
          ..delayMs = delayMs,
        options: options,
      );
      if (response.accepted) {
        _updateState(_currentState.copyWith(
          status: IpcConnectionStatus.reconnecting,
          errorMessage: 'Node restart initiated...',
        ));
        _scheduleReconnect();
        return true;
      }
      return false;
    } catch (e) {
      _scheduleReconnect();
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect ||
        _currentState.status == IpcConnectionStatus.incompatibleVersion) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (_manualDisconnect) return;
      if (_cachedHost != null && _cachedPort != null && _cachedToken != null) {
        await connectAndAuthenticate(
          host: _cachedHost!,
          port: _cachedPort!,
          localAuthToken: _cachedToken!,
          clientVersion: _cachedClientVersion ?? AppConstants.appVersion,
        );
      }
    });
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _channel?.shutdown();
    _channel = null;
    _stub = null;
    _sessionToken = null;
    _updateState(
        const IpcConnectionState(status: IpcConnectionStatus.disconnected));
  }

  // Transfer Operations

  Future<InitiateSendResponse> initiateSend({
    required String targetPeerId,
    required List<String> sourcePaths,
    String destinationDirectory = '',
    DuplicateDestinationPolicy duplicatePolicy =
        DuplicateDestinationPolicy.DUPLICATE_DESTINATION_POLICY_FAIL_IF_EXISTS,
  }) async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 15),
    );
    final req = InitiateSendRequest()
      ..sessionToken = _sessionToken!
      ..targetPeerId = (PeerId()..value = targetPeerId)
      ..sourcePaths.addAll(sourcePaths)
      ..destinationFolder = destinationDirectory
      ..duplicatePolicy = duplicatePolicy;
    return await _stub!.initiateSend(req, options: options);
  }

  Future<CancelTransferResponse> cancelTransfer(String transferId,
      {String reason = 'User cancelled'}) async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 10),
    );
    final req = CancelTransferRequest()
      ..sessionToken = _sessionToken!
      ..transferId = transferId
      ..reason = reason;
    return await _stub!.cancelTransfer(req, options: options);
  }

  Future<PauseTransferResponse> pauseTransfer(String transferId,
      {String reason = 'User paused'}) async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 10),
    );
    final req = PauseTransferRequest()
      ..sessionToken = _sessionToken!
      ..transferId = transferId
      ..reason = reason;
    return await _stub!.pauseTransfer(req, options: options);
  }

  Future<ResumeTransferResponse> resumeTransfer(String transferId) async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 10),
    );
    final req = ResumeTransferRequest()
      ..sessionToken = _sessionToken!
      ..transferId = transferId;
    return await _stub!.resumeTransfer(req, options: options);
  }

  Future<GetTransferResponse> getTransfer(String transferId) async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 5),
    );
    final req = GetTransferRequest()
      ..sessionToken = _sessionToken!
      ..transferId = transferId;
    return await _stub!.getTransfer(req, options: options);
  }

  Future<ListTransfersResponse> listTransfers() async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 5),
    );
    final req = ListTransfersRequest()..sessionToken = _sessionToken!;
    return await _stub!.listTransfers(req, options: options);
  }

  Future<RevealInFolderResponse> revealInFolder(String path) async {
    if (_stub == null || _sessionToken == null) {
      throw StateError('Local Node IPC not connected or authenticated');
    }
    final options = CallOptions(
      metadata: {'x-peerlink-auth-token': _sessionToken!},
      timeout: const Duration(seconds: 5),
    );
    final req = RevealInFolderRequest()
      ..sessionToken = _sessionToken!
      ..fileOrFolderPath = path;
    return await _stub!.revealInFolder(req, options: options);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _transferProgressController.close();
  }
}
