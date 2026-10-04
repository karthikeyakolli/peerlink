# Phase 01 Verification Report: Flutter ↔ Java Local Node Proof

**Project:** PeerLink (Native Cross-Platform P2P Platform)  
**Phase:** 01 — Flutter ↔ Java Local Node Proof  
**Date:** 2026-10-02  
**Engineer:** Lead Implementation Engineer  
**Status:** **PHASE 01 STATUS: PASS**

---

## 1. Executive Summary

Phase 01 objective has been successfully achieved and proven against real running processes:
```text
Desktop Flutter UI  <--- authenticated local IPC (gRPC / Protobuf) --->  Java Local Node Daemon
```
The architecture is proven without implementing premature product features (no file transfer, sync, backup, AI, or malware scanning).

### Key Architectural Invariants Proven:
1. **Separation of Authoritative State:** Flutter UI never directly accesses internal Java classes, SQLite storage objects, or cryptographic keys. All interactions pass through the strictly typed Protobuf IPC boundary (`DesktopLocalNodeService`).
2. **Localhost is NOT Trusted:** The Java Local Node enforces token-based authentication via gRPC interceptor (`LocalTokenAuthInterceptor`). Local processes attempting to invoke protected endpoints without valid credentials are immediately rejected with `UNAUTHENTICATED`.
3. **Strict Protocol & Version Compatibility Negotiation:** The IPC handshake strictly evaluates client vs. node API versions. Compatible minor versions (`0.1.x`) are admitted; incompatible major/minor versions are cleanly rejected with explicit error diagnostics without crashing either process.
4. **Resilience Across Node Restarts (Zero UI Rebuild Required):** The Flutter gRPC client automatically detects connection drops, transitions UI to reconnecting state, and re-establishes authenticated session and event streaming when the Java Local Node restarts, requiring zero Flutter application restarts or rebuilds.
5. **Real-time Server-Streaming Events:** The Java node emits real-time heartbeat and lifecycle events via server-streaming gRPC, tracked live in the Flutter UI.

---

## 2. Environment & Tooling Versions

| Component | Version / Identifier | Path / Details |
| :--- | :--- | :--- |
| **Operating System** | Windows 10 Pro 64-bit (10.0.19045) | Host Environment |
| **Java JDK** | OpenJDK 21.0.6 (Zulu 21.40+17-CA, 64-bit) | `C:\Users\WIN_10\.jdk\zulu-21.40.17-ca-jdk21.0.6-win_x64` |
| **Apache Maven** | 3.9.9 | `D:\tools\apache-maven-3.9.9\bin\mvn.cmd` |
| **Protocol Buffers** | libprotoc 29.3 | `D:\tools\bin\protoc.exe` |
| **gRPC Java Plugin** | 1.69.0 | `D:\tools\bin\protoc-gen-grpc-java.exe` |
| **Dart SDK** | 3.13.5 | `D:\tools\flutter\bin\cache\dart-sdk\bin\dart.exe` |
| **Flutter SDK** | 3.47.6 (channel stable) | `D:\tools\flutter\bin\flutter.bat` |
| **SQLite Engine** | SQLite JDBC 3.47.2.0 (WAL mode enabled) | Local Node SQLite state store |

---

## 3. Implemented Components

### 3.1. Protobuf Service & Message Contracts (`protocol/proto/peerlink/v1/ipc.proto`)
- `DesktopLocalNodeService`:
  - `Authenticate(AuthenticateIpcRequest) returns (AuthenticateIpcResponse)`: Handshake validating token and negotiating version compatibility.
  - `GetStatus(GetNodeStatusRequest) returns (GetNodeStatusResponse)`: Retrieves node execution status, uptime, memory, capabilities, peer ID, port, and subscriber count.
  - `SubscribeEvents(NodeEventSubscriptionRequest) returns (stream NodeEvent)`: Server-streaming real-time heartbeats, lifecycle notifications, and operational events.
  - `Restart(RestartNodeRequest) returns (RestartNodeResponse)`: Controlled node restart over IPC.
  - `Stop(StopNodeRequest) returns (StopNodeResponse)`: Graceful daemon shutdown.

### 3.2. Java Desktop Local Node Daemon (`desktop-node`)
- **`DesktopNodeDaemon`**: Lifecycle manager supporting `start()`, `stop()`, `restart()`, `isHealthy()`, and CLI arguments (`--port`, `--data-dir`).
- **`DesktopLocalNodeServiceImpl`**: Thread-safe gRPC service implementation with background scheduled heartbeat broadcaster (1Hz), version compatibility validator, and subscriber lifecycle management.
- **`LocalTokenAuthInterceptor`**: Enforces localhost security invariant. Protected RPCs without `x-peerlink-auth-token` header are rejected with `Status.UNAUTHENTICATED`.
- **`NodeConfiguration`**: Generates and persists high-entropy development IPC authentication tokens (`ipc_auth.token`) in the local node runtime directory.

### 3.3. Flutter gRPC Client & Live UI (`apps/peerlink-app`)
- **`NodeIpcClient`**: Robust asynchronous Dart client with reactive state stream (`IpcConnectionStatus`), automatic reconnection with backoff, token-authenticated metadata propagation, and server-streaming event listener.
- **`LocalNodeCard`**: Interactive UI component embedded in `HomeScreen` displaying real-time connection status chip, Peer ID, API version, live streaming heartbeat counter, node memory/uptime, and interactive controls (Connect, Disconnect, Query Status, Restart Node, Simulate Incompatible Version).

---

## 4. Verification Evidence & Exact Commands

### 4.1. Automated Live End-to-End Proof (`scripts/verify-phase-01.py`)

This script spawns the Java Local Node as an external process on port 54325, generates a dynamic token, runs the Dart client test suite against the live node, tests security rejection, version incompatibility rejection, streaming heartbeats, and triggers node restart with client auto-reconnect.

**Command:**
```powershell
python scripts/verify-phase-01.py
```

**Output:**
```text
=== STARTING PEERLINK PHASE 01 LIVE VERIFICATION ===
Repository Root: C:\Users\WIN_10\.gemini\antigravity\scratch\New folder\PeerLink
Node IPC Port:   54325
Data Directory:  C:\Users\WIN_10\AppData\Local\Temp\peerlink_phase01_juap8kzz

[Step A] Installing Java modules locally...
Java modules installed successfully.

[Step B] Starting Java Desktop Local Node daemon...
Waiting for Local Node IPC server to listen on port 54325...
Node is up and listening on 127.0.0.1:54325
Retrieved active development IPC auth token: B0SOP8Db***

[Step C] Running Flutter/Dart live proof client...
--- DART CLIENT OUTPUT ---
=== PEERLINK PHASE 01 LIVE INTEGRATION PROOF ===
Target Node: 127.0.0.1:54325

[Step 1] Testing Incompatible Protocol Version (v2.0.0)...
PASS: Incompatible version rejected cleanly (Incompatible client version: 2.0.0-incompatible. Requires 0.1.0)

[Step 2] Testing Invalid Local Auth Token...
PASS: Invalid token rejected cleanly (Invalid local IPC auth token)

[Step 3] Connecting with Valid Credentials (v0.1.0)...
PASS: Authenticated successfully. Peer ID: peer_2c60009f, Node Version: 0.1.0

[Step 4] Requesting Node Status via authenticated IPC...
PASS: Node Status: NODE_EXECUTION_STATUS_RUNNING, Uptime: 9s, Memory: 19MB

[Step 5] Awaiting Server-Streamed Heartbeats...
PASS: Received 2 streaming heartbeats (Last seq: 1)

[Step 6] Testing Client Disconnect...
PASS: Disconnected cleanly

[Step 7] Reconnecting to Node...
PASS: Reconnected successfully

[Step 8] Triggering Node Restart via IPC and testing Reconnect...
Restart request accepted. Waiting for Node to restart and client to auto-reconnect...
PASS: Node restarted successfully; Flutter client reconnected without application rebuild!

=== ALL PHASE 01 INTEGRATION CHECKS PASSED ===

Dart Client Exit Code: 0

[Step D] Shutting down Java Desktop Node daemon...

==============================================
PHASE 01 VERIFICATION RESULT: PASS
==============================================
```

### 4.2. Java Module JUnit 5 Tests

**Command:**
```powershell
mvn clean test -B
```

**Results:**
- `org.peerlink.core.CoreDomainInvariantsTest`: 6/6 PASSED
- `org.peerlink.desktop.DesktopNodeDaemonTest`: 8/8 PASSED
  - `testNodeLifecycleStartHealthyStopRestart()`: PASSED
  - `testAuthenticationWithValidTokenSucceeds()`: PASSED
  - `testAuthenticationWithIncompatibleVersionIsRejected()`: PASSED
  - `testAuthenticationWithInvalidTokenFails()`: PASSED
  - `testLocalhostCallWithoutTokenIsRejected()`: PASSED
  - `testAuthenticatedCallWithHeaderSucceeds()`: PASSED
  - `testEventStreamingHeartbeat()`: PASSED
  - `testReconnectionAcrossNodeRestart()`: PASSED
- **Total Java Tests:** 14/14 PASSED, 0 failures, 0 errors.

### 4.3. Flutter Static Analysis & Unit/Widget Tests

**Commands:**
```powershell
flutter analyze --fatal-infos
flutter test
```

**Results:**
```text
Analyzing peerlink-app...
No issues found! (ran in 29.4s)

00:07 +5: All tests passed!
```
- Tests executed:
  - `test/node_ipc_test.dart` (Authentication, Invalid token, Incompatible version, Streaming heartbeats): 4/4 PASSED
  - `test/widget_test.dart` (Shell navigation + LocalNodeCard rendering): 1/1 PASSED
- Total Flutter Tests: 5/5 PASSED.

### 4.4. Dependency Boundary Scanner

**Command:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-deps.ps1
```

**Output:**
```text
Verifying PeerLink architectural boundaries and forbidden dependencies...
PASS: No forbidden dependencies or boundary violations detected.
```

---

## 5. Failures Encountered & Fixes Made

| Issue Encountered | Root Cause | Fix Applied |
| :--- | :--- | :--- |
| **Submodule resolution in standalone `exec:java`** | Running `exec:java` in `desktop-node` without local Maven repository installation failed to find `peerlink-core:0.1.0-SNAPSHOT`. | Installed all modules locally via `mvn install -DskipTests -B` before launching standalone daemon process. |
| **Protobuf 64-bit integer type incompatibility in Dart** | Dart `test/node_ipc_test.dart` assigned native Dart `int` to protobuf `int64` fields. | Used `package:fixnum/fixnum.dart` `fixnum.Int64(...)` for all `int64` timestamp, sequence, and memory fields. |
| **Premature StreamController close during widget disposal** | Asynchronous `disconnect()` in `NodeIpcClient` attempted to broadcast state after `dispose()` closed the controller. | Added `!_stateController.isClosed` guard in `_updateState` and cancelled subscriptions and timers before closing. |
| **Flutter BoxDecoration parameter type mismatch** | `BoxDecoration(border: ...)` received a `BorderSide` instance instead of `Border.all(...)`. | Converted border parameter to `Border.all(color: statusColor, width: 1)` in `local_node_card.dart`. |

---

## 6. Pass Gate Assessment

| Pass Gate Requirement | Verified Status | Evidence |
| :--- | :--- | :--- |
| **Flutter communicates with Java Local Node via defined contract** | **PASS** | `live_node_proof.dart` executed full IPC handshake, status query, and streaming event subscription against `DesktopNodeDaemon`. |
| **Node restart does not require application rebuild** | **PASS** | `restartNode()` triggered daemon reboot; Flutter client automatically detected drop, reconnected, and resumed queries with zero app restart. |
| **No direct Flutter access to internal Java objects** | **PASS** | Strictly enforced process isolation over gRPC loopback; zero Java imports or shared memory bindings in Flutter. |
| **Localhost is not automatically trusted** | **PASS** | Calls lacking valid token rejected with `UNAUTHENTICATED`. |
| **Incompatible protocol version rejected cleanly** | **PASS** | Handshake with `v2.0.0` rejected with `isCompatible=false` and descriptive error. |

---

### **PHASE 01 STATUS: PASS**

**Explanation:**  
The desktop IPC architectural boundary between the Flutter desktop UI and the Java Local Node has been proven end-to-end. Authenticated loopback connection, status inspection, server-streaming heartbeats, lifecycle management (start, healthy, stop, restart), automatic reconnection, and strict protocol version negotiation operate cleanly and deterministically.
