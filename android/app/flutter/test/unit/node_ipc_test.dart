import 'dart:async';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:peerlink/core/node_ipc_client.dart';
import 'package:peerlink/core/protocol/peerlink/v1/common.pb.dart';
import 'package:peerlink/core/protocol/peerlink/v1/ipc.pbgrpc.dart';

class MockDesktopLocalNodeService extends DesktopLocalNodeServiceBase {
  final String validToken = 'valid-secret-token';
  final String nodeVersion = '0.1.0';
  final StreamController<NodeEvent> _eventController =
      StreamController<NodeEvent>.broadcast();

  @override
  Future<AuthenticateIpcResponse> authenticate(
      ServiceCall call, AuthenticateIpcRequest request) async {
    if (!request.clientVersion.startsWith('0.1.')) {
      return AuthenticateIpcResponse()
        ..authenticated = false
        ..isCompatible = false
        ..nodeVersion = nodeVersion
        ..errorMessage =
            'Incompatible client version: ${request.clientVersion}';
    }

    if (request.authToken != validToken) {
      return AuthenticateIpcResponse()
        ..authenticated = false
        ..isCompatible = true
        ..nodeVersion = nodeVersion
        ..errorMessage = 'Invalid local IPC auth token';
    }

    return AuthenticateIpcResponse()
      ..authenticated = true
      ..isCompatible = true
      ..sessionToken = validToken
      ..nodeVersion = nodeVersion
      ..localPeerId = (PeerId()..value = 'peer_mock_test');
  }

  @override
  Future<GetNodeStatusResponse> getStatus(
      ServiceCall call, GetNodeStatusRequest request) async {
    return GetNodeStatusResponse()
      ..status = NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING
      ..peerId = (PeerId()..value = 'peer_mock_test')
      ..listenPort = 50051
      ..nodeVersion = nodeVersion
      ..uptimeSeconds = fixnum.Int64(42)
      ..memoryUsedBytes = fixnum.Int64(10485760);
  }

  @override
  Stream<NodeEvent> subscribeEvents(
      ServiceCall call, NodeEventSubscriptionRequest request) {
    Timer.run(() => emitHeartbeat(0));
    return _eventController.stream;
  }

  void emitHeartbeat(int seq) {
    _eventController.add(
      NodeEvent()
        ..timestampUtcMs = fixnum.Int64(DateTime.now().millisecondsSinceEpoch)
        ..heartbeat = (NodeHeartbeat()
          ..timestampUtcMs = fixnum.Int64(DateTime.now().millisecondsSinceEpoch)
          ..status = NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING
          ..sequenceNumber = fixnum.Int64(seq)
          ..uptimeSeconds = fixnum.Int64(42)
          ..memoryUsedBytes = fixnum.Int64(10485760)),
    );
  }

  @override
  Future<RestartNodeResponse> restart(
      ServiceCall call, RestartNodeRequest request) async {
    return RestartNodeResponse()
      ..accepted = true
      ..message = 'Restart initiated';
  }

  @override
  Future<StopNodeResponse> stop(
      ServiceCall call, StopNodeRequest request) async {
    return StopNodeResponse()
      ..accepted = true
      ..message = 'Stop initiated';
  }

  @override
  Future<InitiateSendResponse> initiateSend(
      ServiceCall call, InitiateSendRequest request) async {
    return InitiateSendResponse()
      ..accepted = true
      ..transferId = 'tx_mock_123';
  }

  @override
  Future<CancelTransferResponse> cancelTransfer(
      ServiceCall call, CancelTransferRequest request) async {
    return CancelTransferResponse()
      ..accepted = true
      ..message = 'Cancelled mock transfer';
  }

  @override
  Future<GetTransferResponse> getTransfer(
      ServiceCall call, GetTransferRequest request) async {
    return GetTransferResponse()..found = true;
  }

  @override
  Future<ListTransfersResponse> listTransfers(
      ServiceCall call, ListTransfersRequest request) async {
    return ListTransfersResponse();
  }

  @override
  Future<PauseTransferResponse> pauseTransfer(
      ServiceCall call, PauseTransferRequest request) async {
    return PauseTransferResponse()
      ..accepted = true
      ..message = 'Transfer paused';
  }

  @override
  Future<ResumeTransferResponse> resumeTransfer(
      ServiceCall call, ResumeTransferRequest request) async {
    return ResumeTransferResponse()
      ..accepted = true
      ..message = 'Transfer resumed';
  }

  @override
  Future<SetBandwidthLimitResponse> setBandwidthLimit(
      ServiceCall call, SetBandwidthLimitRequest request) async {
    return SetBandwidthLimitResponse()
      ..accepted = true
      ..currentLimitBps = request.maxBytesPerSec;
  }

  @override
  Future<RevealInFolderResponse> revealInFolder(
      ServiceCall call, RevealInFolderRequest request) async {
    return RevealInFolderResponse()..opened = true;
  }
}

void main() {
  late Server server;
  late MockDesktopLocalNodeService mockService;
  const testPort = 54322;

  setUpAll(() async {
    mockService = MockDesktopLocalNodeService();
    server = Server.create(services: [mockService]);
    await server.serve(port: testPort);
  });

  tearDownAll(() async {
    await server.shutdown();
  });

  test('NodeIpcClient connects, authenticates, and retrieves node status',
      () async {
    final client = NodeIpcClient();

    final success = await client.connectAndAuthenticate(
      port: testPort,
      localAuthToken: 'valid-secret-token',
      clientVersion: '0.1.0',
    );

    expect(success, isTrue);
    expect(client.isAuthenticated, isTrue);
    expect(client.currentState.status, equals(IpcConnectionStatus.connected));
    expect(client.currentState.peerId, equals('peer_mock_test'));
    expect(client.currentState.nodeVersion, equals('0.1.0'));

    final status = await client.getStatus();
    expect(status, isNotNull);
    expect(status!.status,
        equals(NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING));
    expect(status.uptimeSeconds, equals(fixnum.Int64(42)));

    await client.disconnect();
    expect(client.isAuthenticated, isFalse);
    expect(
        client.currentState.status, equals(IpcConnectionStatus.disconnected));
  });

  test('NodeIpcClient cleanly rejects invalid auth token', () async {
    final client = NodeIpcClient();

    final success = await client.connectAndAuthenticate(
      port: testPort,
      localAuthToken: 'wrong-tampered-token',
      clientVersion: '0.1.0',
    );

    expect(success, isFalse);
    expect(client.isAuthenticated, isFalse);
    expect(client.currentState.status, equals(IpcConnectionStatus.error));
    expect(client.currentState.errorMessage,
        contains('Invalid local IPC auth token'));

    await client.disconnect();
  });

  test('NodeIpcClient cleanly rejects incompatible client version', () async {
    final client = NodeIpcClient();

    final success = await client.connectAndAuthenticate(
      port: testPort,
      localAuthToken: 'valid-secret-token',
      clientVersion: '2.0.0-incompatible',
    );

    expect(success, isFalse);
    expect(client.isAuthenticated, isFalse);
    expect(client.currentState.status,
        equals(IpcConnectionStatus.incompatibleVersion));
    expect(client.currentState.isCompatible, isFalse);
    expect(client.currentState.errorMessage,
        contains('Incompatible client version'));

    await client.disconnect();
  });

  test('NodeIpcClient receives server-streamed heartbeats', () async {
    final client = NodeIpcClient();

    await client.connectAndAuthenticate(
      port: testPort,
      localAuthToken: 'valid-secret-token',
      clientVersion: '0.1.0',
    );

    // Wait for stream subscription to establish
    await Future.delayed(const Duration(milliseconds: 150));

    // Emit two mock heartbeats
    mockService.emitHeartbeat(1);
    mockService.emitHeartbeat(2);

    await Future.delayed(const Duration(milliseconds: 150));

    expect(client.currentState.activeHeartbeatCount, greaterThanOrEqualTo(2));
    expect(client.currentState.lastHeartbeat?.sequenceNumber,
        equals(fixnum.Int64(2)));

    await client.disconnect();
  });
}
