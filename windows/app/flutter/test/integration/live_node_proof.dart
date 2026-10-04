import 'dart:async';
import 'dart:io';
import 'package:peerlink/core/node_ipc_client.dart';
import 'package:peerlink/core/protocol/peerlink/v1/ipc.pbgrpc.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run live_node_proof.dart <port> <token>');
    exit(1);
  }

  final port = int.parse(args[0]);
  final token = args[1];

  stdout.writeln('=== PEERLINK PHASE 01 LIVE INTEGRATION PROOF ===');
  stdout.writeln('Target Node: 127.0.0.1:$port');

  final client = NodeIpcClient();

  try {
    // 1. Authenticate with Incompatible Version
    stdout.writeln('\n[Step 1] Testing Incompatible Protocol Version (v2.0.0)...');
    final incompResult = await client.connectAndAuthenticate(
      port: port,
      localAuthToken: token,
      clientVersion: '2.0.0-incompatible',
    );
    if (incompResult) {
      stderr.writeln('FAIL: Incompatible version was incorrectly accepted!');
      exit(10);
    }
    if (client.currentState.status != IpcConnectionStatus.incompatibleVersion) {
      stderr.writeln('FAIL: Expected incompatibleVersion status, got ${client.currentState.status}');
      exit(11);
    }
    stdout.writeln('PASS: Incompatible version rejected cleanly (${client.currentState.errorMessage})');
    await client.disconnect();

    // 2. Authenticate with Invalid Token
    stdout.writeln('\n[Step 2] Testing Invalid Local Auth Token...');
    final badTokenResult = await client.connectAndAuthenticate(
      port: port,
      localAuthToken: 'tampered-bogus-token',
      clientVersion: '0.1.0',
    );
    if (badTokenResult) {
      stderr.writeln('FAIL: Invalid token was accepted!');
      exit(12);
    }
    stdout.writeln('PASS: Invalid token rejected cleanly (${client.currentState.errorMessage})');
    await client.disconnect();

    // 3. Connect and Authenticate with Valid Token
    stdout.writeln('\n[Step 3] Connecting with Valid Credentials (v0.1.0)...');
    final authSuccess = await client.connectAndAuthenticate(
      port: port,
      localAuthToken: token,
      clientVersion: '0.1.0',
    );
    if (!authSuccess) {
      stderr.writeln('FAIL: Valid authentication failed: ${client.currentState.errorMessage}');
      exit(13);
    }
    stdout.writeln('PASS: Authenticated successfully. Peer ID: ${client.currentState.peerId}, Node Version: ${client.currentState.nodeVersion}');

    // 4. Query Node Status
    stdout.writeln('\n[Step 4] Requesting Node Status via authenticated IPC...');
    final status = await client.getStatus();
    if (status == null || status.status != NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING) {
      stderr.writeln('FAIL: Node status query returned null or not running');
      exit(14);
    }
    stdout.writeln('PASS: Node Status: ${status.status}, Uptime: ${status.uptimeSeconds}s, Memory: ${status.memoryUsedBytes ~/ (1024 * 1024)}MB');

    // 5. Receive Server-Streamed Events
    stdout.writeln('\n[Step 5] Awaiting Server-Streamed Heartbeats...');
    // Wait for at least 2 heartbeats
    for (int i = 0; i < 25; i++) {
      if (client.currentState.activeHeartbeatCount >= 2) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (client.currentState.activeHeartbeatCount < 2) {
      stderr.writeln('FAIL: Did not receive expected server-streamed heartbeats (received ${client.currentState.activeHeartbeatCount})');
      exit(15);
    }
    stdout.writeln('PASS: Received ${client.currentState.activeHeartbeatCount} streaming heartbeats (Last seq: ${client.currentState.lastHeartbeat?.sequenceNumber})');

    // 6. Test Disconnect
    stdout.writeln('\n[Step 6] Testing Client Disconnect...');
    await client.disconnect();
    if (client.isAuthenticated) {
      stderr.writeln('FAIL: Client still reports authenticated after disconnect');
      exit(16);
    }
    stdout.writeln('PASS: Disconnected cleanly');

    // 7. Reconnect
    stdout.writeln('\n[Step 7] Reconnecting to Node...');
    final reconnected = await client.connectAndAuthenticate(
      port: port,
      localAuthToken: token,
      clientVersion: '0.1.0',
    );
    if (!reconnected) {
      stderr.writeln('FAIL: Reconnection failed');
      exit(17);
    }
    stdout.writeln('PASS: Reconnected successfully');

    // 8. Test Restart Node via IPC & Auto-Reconnect
    stdout.writeln('\n[Step 8] Triggering Node Restart via IPC and testing Reconnect...');
    final restartAccepted = await client.restartNode(delayMs: 200);
    if (!restartAccepted) {
      stderr.writeln('FAIL: Restart request was not accepted by Node');
      exit(18);
    }
    stdout.writeln('Restart request accepted. Waiting for Node to restart and client to auto-reconnect...');

    // Wait for auto-reconnect
    bool postRestartHealthy = false;
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (client.isAuthenticated) {
        final postStatus = await client.getStatus();
        if (postStatus != null && postStatus.status == NodeExecutionStatus.NODE_EXECUTION_STATUS_RUNNING) {
          postRestartHealthy = true;
          break;
        }
      }
    }

    if (!postRestartHealthy) {
      stderr.writeln('FAIL: Client failed to reconnect to Node after restart');
      exit(19);
    }
    stdout.writeln('PASS: Node restarted successfully; Flutter client reconnected without application rebuild!');

    await client.disconnect();
    stdout.writeln('\n=== ALL PHASE 01 INTEGRATION CHECKS PASSED ===');
    exit(0);
  } catch (e, st) {
    stderr.writeln('UNEXPECTED EXCEPTION: $e\n$st');
    exit(99);
  } finally {
    client.dispose();
  }
}
