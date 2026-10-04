# PeerLink — Windows Local Development Setup & Run Guide

This guide describes how to build, run, and test the **PeerLink** distributed personal data platform on a local Windows development machine without changing the product architecture.

---

## 1. Architecture Overview

PeerLink operates as a local-first peer-to-peer system:
```text
Flutter / Dart (UI)
        ↕
Protobuf over Local gRPC IPC (127.0.0.1:50051)
        ↕
Java 25 Local Node Daemon
    ├── P2P Transport & ICE / QUIC / TLS
    ├── SQLite Storage & Migration Manager (peerlink_local.db)
    ├── Transfer & Staging Engine
    └── Non-Authoritative Cloud Sync (Supabase)
```

---

## 2. Prerequisites & Verified Toolchain

The following toolchain versions are verified on Windows 10/11 x64:

| Tool | Verified Version | Path on this Machine |
| :--- | :--- | :--- |
| **Java Runtime (Desktop Node)** | **OpenJDK 25** (25.0.4.1+1 LTS) | `C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot` |
| **Java JDK (Compiler Toolchain)**| **OpenJDK 21** (21.0.12 LTS) | `C:\Program Files\Java\jdk-21.0.12` |
| **Apache Maven** | **3.9.9** (or 3.9.6+) | `D:\tools\apache-maven-3.9.9\bin` |
| **Protobuf Compiler (protoc)** | **libprotoc 29.3** | `D:\tools\bin\protoc.exe` |
| **gRPC Java Plugin** | **protoc-gen-grpc-java 1.69.0** | `D:\tools\bin\protoc-gen-grpc-java.exe` |
| **Dart protoc Plugin** | **protoc-gen-dart** | `C:\Users\WIN_10\AppData\Local\Pub\Cache\bin\protoc-gen-dart.bat` |
| **Flutter SDK** | **3.47.6** (Dart 3.13.5) | `D:\tools\flutter` |
| **Git** | **2.55.0+** | System PATH |
| **Visual Studio (Desktop C++)** | VS 2022 C++ Tools *(Optional)* | Required only for native C++ runner (`flutter run -d windows`) |

---

## 3. Environment Setup & Diagnostics

Run the environment diagnostic script:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-environment.ps1
```
This checks all prerequisites and outputs their statuses.

---

## 4. Protobuf Generation

Protobuf definitions reside in `protocol/proto/peerlink/v1/*.proto`.
To compile protocol buffers for both Java (stubs) and Dart (Flutter):
```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-proto.ps1
```
Output directories:
- Java: `protocol/generated-java/org/peerlink/protocol/v1/`
- Dart: `apps/peerlink-app/lib/core/protocol/`

---

## 5. Building Java Core & Local Node

To build the JVM monorepo and run all 251 unit/integration tests:
```powershell
cmd.exe /c "set JAVA_HOME=C:\Program Files\Java\jdk-21.0.12&& set PATH=C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;%PATH%&& mvn clean test"
```

To produce the standalone shaded fat executable JAR:
```powershell
cmd.exe /c "set JAVA_HOME=C:\Program Files\Java\jdk-21.0.12&& set PATH=C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;%PATH%&& mvn package -DskipTests=true"
```
Artifact generated:
`desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar` (~39.2 MB).

---

## 6. Starting the Java Local Node on Java 25

Run the local node script:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-node.ps1 -Port 50051 -DataDir data\node1 -Token dev-token-default
```
Or directly via the Java 25 executable:
```powershell
& "C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot\bin\java.exe" -jar desktop-node\target\peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar --port 50051 --data-dir .\data\node1 --token dev-token-default
```

Logs will confirm:
```text
INFO  o.p.d.storage.LocalSqliteStorage - LocalSqliteStorage ready at .\data\node1\peerlink_local.db (schema v3)
INFO  o.p.d.runtime.DesktopNodeDaemon - Desktop Local Node IPC server listening on 127.0.0.1:50051
INFO  o.p.d.runtime.DesktopNodeDaemon - Desktop Node Daemon started. Press Ctrl+C to terminate.
```

---

## 7. Starting Flutter Desktop Application

### Flutter Tests & IPC Verification
```powershell
cd apps\peerlink-app
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& flutter test"
```

### Flutter Windows Desktop UI
If Visual Studio with the "Desktop development with C++" workload is installed:
```powershell
cd apps\peerlink-app
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& flutter run -d windows"
```

---

## 8. Single Recommended Developer Startup Command

To run environment checks, start the Java 25 Local Node, and perform a full live Flutter ↔ Local Node handshake verification:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-peerlink.ps1
```

---

## 9. Verification of Flutter ↔ Java Local Node Communication

To run the live end-to-end integration handshake against a running Local Node:
```powershell
cd apps\peerlink-app
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& dart run test/integration/live_node_proof.dart 50051 dev-token-default"
```
The test verifies:
1. `[PASS]` Incompatible version rejected (`2.0.0-incompatible` rejected)
2. `[PASS]` Invalid auth token rejected (`tampered-bogus-token` rejected)
3. `[PASS]` Valid authentication handshake (`v0.1.0` authenticated)
4. `[PASS]` Node status retrieved (`NODE_EXECUTION_STATUS_RUNNING`, Uptime, Memory)
5. `[PASS]` Server-streamed heartbeats received
6. `[PASS]` Clean disconnect
7. `[PASS]` Reconnection
8. `[PASS]` Remote node restart via IPC and auto-reconnection

---

## 10. Two-Instance Local Testing

To start two completely independent Local Nodes simultaneously on separate ports:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-two-nodes.ps1
```
This launches:
- **Node A:** Port `50051`, storage in `data/nodeA/peerlink_local.db`
- **Node B:** Port `50052`, storage in `data/nodeB/peerlink_local.db`
And validates IPC communication to both instances independently.

---

## 11. Troubleshooting & Resolved Errors

### Error 1: `kotlin-maven-plugin: java.lang.IllegalArgumentException: 25.0.4.1`
- **Root Cause:** Kotlin compiler plugin internally uses an IntelliJ version parser that does not recognize Java 25 version strings when Maven runs on Java 25.
- **Resolution:** As per Section 4 Java Version Policy, Maven compiles code targeting bytecode release 17 using JDK 21 toolchain (`C:\Program Files\Java\jdk-21.0.12`), and the compiled standalone shaded fat JAR runs directly on **Java 25** (`C:\Program Files\Microsoft\jdk-25.0.4.101-hotspot`).

### Error 2: `flutter : The term 'flutter' is not recognized`
- **Root Cause:** Flutter is installed in `D:\tools\flutter\bin` but not added to the Windows user/system environment PATH.
- **Resolution:** Added to execution wrappers via `D:\tools\flutter\bin`. To add permanently: add `D:\tools\flutter\bin` to system PATH.

### Error 3: `Unable to find suitable Visual Studio toolchain`
- **Root Cause:** Compiling the native Windows C++ executable (`flutter run -d windows`) requires Visual Studio "Desktop development with C++".
- **Resolution:** Install Visual Studio Community or Build Tools with the C++ workload. The Dart protocol client and Java Local Node run 100% locally without Visual Studio.
