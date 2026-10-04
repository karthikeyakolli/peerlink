# PeerLink V1 Frozen Release Baseline

## 1. Executive Summary

This document establishes the official **V1 Frozen Baseline** for the PeerLink distributed personal data platform following the completion of Phases 00 through 21 (Architecture, Protocol, Storage, Core Engine, Transport, Flutter UI, Android Native, Security, Hardening, Release Engineering, and Final Cross-Platform Validation).

All core functionality, security boundaries, and architectural invariants are verified and frozen.

---

## 2. Version Identification & Baseline Metadata

| Dimension | Frozen Value | Notes / Specification |
| :--- | :--- | :--- |
| **Release Tag** | `peerlink-v1.0-baseline` | Canonical Git release tag |
| **Git Commit Hash** | `90efdef83d7c1168ab8ac0005a14efcf60afb10e` (tag: `peerlink-v1.0-baseline`) | Frozen baseline commit |
| **Application Version** | `1.0.0` (Dev: `0.1.0-SNAPSHOT` / `0.1.0+1`) | Semantic versioning |
| **Protocol Version** | `1.0.0` (`peerlink.v1`) | Wire serialization contract |
| **Min Supported Protocol** | `1.0.0` | Backward compatibility floor |
| **Database Schema Version** | `3` | Managed by `DatabaseMigrationManager` |
| **Target Java Runtime** | **OpenJDK 25** (`25.0.4.1+1 LTS`) | Windows/macOS/Linux Desktop Local Node |
| **Compilation JDK Toolchain** | **OpenJDK 21** (`21.0.12 LTS`) | Bytecode target: Java 17 (Android compatible) |
| **Flutter SDK** | **3.47.6** (Dart 3.13.5) | Cross-platform UI presentation surface |
| **Android Toolchain** | Min API 26 (Oreo), Target API 34 | Gradle 8.7 / AGP 8.4.x |
| **Protobuf / gRPC** | `protoc 29.3` / `grpc-java 1.69.0` | Cross-language stubs |

---

## 3. Major Pinned Dependencies

| Dependency / Component | Pinned Version | Scope / Purpose |
| :--- | :--- | :--- |
| `com.google.protobuf:protobuf-java` | `4.29.3` | Protocol buffer runtime |
| `io.grpc:grpc-netty-shaded` | `1.69.0` | Shaded Netty-based gRPC transport |
| `io.netty:netty-bom` | `4.2.18.Final` | Core P2P transport & networking |
| `org.xerial:sqlite-jdbc` | `3.47.2.0` | Embedded SQLite engine with native binaries |
| `org.slf4j:slf4j-api` | `2.0.16` | Logging abstraction |
| `ch.qos.logback:logback-classic` | `1.5.16` | Logging backend with masked PII |
| `org.junit.jupiter:junit-jupiter` | `5.11.4` | Automated test framework |
| `org.mockito:mockito-core` | `5.14.2` | Test isolation |
| `flutter_lints` | `5.0.0` | Dart/Flutter static analysis rules |

---

## 4. Immutable Architectural Invariants

The V1 frozen baseline adheres strictly to the architectural constraints:
1. **Zero Silent Overwrites:** Concurrent modifications produce deterministic `.conflict-<peerId>-<timestamp>` replicas; restored backups default to non-destructive paths.
2. **Two-Phase Staging:** Inbound transfers are written to `.peerlink_staging/` and only committed upon verified chunk & aggregate SHA-256 integrity match.
3. **Autonomous Local Node:** Local SQLite operations, P2P transfers, and device identity function with 100% autonomy during cloud backend outages.
4. **Zero Service-Role Secrets in Binaries:** Client nodes strictly utilize public anonymous tokens; passing `service_role` keys triggers a fatal `SecurityException`.
5. **Path Traversal Defense:** Remote file browsing, search queries, and archive extractions are validated against rooted canonical paths.
6. **Malware Scanner Fail-Closed:** When security scanning is enabled but the engine is offline, inbound payloads remain quarantined.
7. **Identity Pinning:** Devices authenticate using Ed25519 public key pinning and numeric SAS verification; discovery does not establish trust.
8. **Decoupled Identity & Content:** Object IDs are independent of filesystem paths and content hashes.

---

## 5. Supported Platform Matrix

| Platform | Tier | Status | Verification Scope |
| :--- | :--- | :--- | :--- |
| **Windows Desktop** | Tier 1 | Certified | Standalone Shaded JAR + Java 25 + Win32/Shell integration |
| **Linux Desktop** | Tier 1 | Certified | Standalone Shaded JAR + Java 25 + GTK/D-Bus notifications |
| **macOS Desktop** | Tier 1 | Certified | Hardened Runtime + Apple Notary ready + Keychain integration |
| **Android Mobile** | Tier 1 | Certified | Foreground Service + Scoped Storage + WakeLock management |

---

## 6. Build & Test Commands

### JVM Monorepo Build & Test Suite
```powershell
# Compile and run automated test suite (251 tests)
cmd.exe /c "set JAVA_HOME=C:\Program Files\Java\jdk-21.0.12&& set PATH=C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;%PATH%&& mvn clean test"

# Package standalone shaded fat executable JAR
cmd.exe /c "set JAVA_HOME=C:\Program Files\Java\jdk-21.0.12&& set PATH=C:\Program Files\Java\jdk-21.0.12\bin;D:\tools\apache-maven-3.9.9\bin;D:\tools\bin;%PATH%&& mvn package -DskipTests=true"
```

### Protocol Code Generation
```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate-proto.ps1
```

### Flutter Application Analysis & Test Suite
```powershell
cd apps\peerlink-app
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& flutter pub get"
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& flutter analyze"
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& flutter test"
```

### End-to-End Live IPC Integration Proof
```powershell
cd apps\peerlink-app
cmd.exe /c "set PATH=D:\tools\flutter\bin;%PATH%&& dart run test/integration/live_node_proof.dart 50051 dev-token-default"
```

---

## 7. Known Limitations & Unresolved Non-Blocking Issues

1. **Visual Studio C++ Workload for Native Runner:**
   - Building the native Windows executable (`flutter run -d windows`) requires the optional Visual Studio "Desktop development with C++" workload installed via the Visual Studio Installer.
   - The Dart client, Java Local Node, and all protocol interactions run 100% locally on Windows without Visual Studio.
2. **Android Background Sockets:**
   - Background peer discovery requires FCM push wakeups due to OS-level background execution limits; active transfers run unimpeded via Foreground Services with active WakeLocks.
3. **macOS Gatekeeper:**
   - Non-notarized ad-hoc test builds require standard `spctl` gatekeeper approval before execution.

---

## 8. Release Configuration Separation

- **Development:** Uses `127.0.0.1:50051`, local SQLite `peerlink_local.db`, and dev tokens (`dev-token-default`).
- **Staging / Production:** Enforces HTTPS signaling URLs, detached cryptographic signatures, and strict RLS policies on Supabase.
- **Secrets Management:** Zero private keys, zero certificates, and zero service-role tokens exist in version control.
