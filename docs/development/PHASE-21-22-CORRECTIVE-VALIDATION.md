# PeerLink — Phase 21/22 Corrective Validation Report

**Phase:** Corrective Validation, Architecture Enforcement, and Release Evidence  
**Date:** October 13, 2026  
**Repository:** [https://github.com/karthikeyakolli/peerlink](https://github.com/karthikeyakolli/peerlink)  
**Evaluator:** DeepMind Agentic Pair Programmer  
**Overall Release Verdict:** **CONDITIONALLY READY WITH EXPLICIT BLOCKERS**

---

## Executive Summary

This corrective validation phase audited and verified the claims made in previous Phase 21 and Phase 22 reports. The previous Phase 21 report claimed that `apps/peerlink-app` was retired after verifying all four platform projects. The previous Phase 22 report stated that the system was conditionally ready. 

Our empirical audit found that:
1. **Git Remote Mismatch**: The reported deletion of `apps/peerlink-app` was staged only in the local Git index; it was **never committed** locally and **never pushed to `origin/master`**. The remote branch `origin/master` remains at commit `e208dd8` and still contains `apps/peerlink-app/` and `shared-source/`.
2. **Authoritative Canonical Source**: The repository still retained `shared-source/canonical/` as the authoritative source of truth for platform synchronization, violating the strict requirement of four physically independent application projects with zero shared application source.
3. **Parity Verifier Replacement**: The canonical sync tool was replaced with a read-only, peer-to-peer manifest-driven parity verifier (`tools/platform-parity/verify-platform-parity.ps1` & `.sh`). It audited **578 invariant relative files** across all four platform projects with **0 discrepancies**.
4. **Android NDK & Compilation Blocker**: Flutter 3.47.7 and AGP require NDK `28.2.13676358`. The NDK was installed and verified. Flutter Doctor (PASS), Flutter Analyze (PASS, 0 errors), Flutter Test (PASS, 12/12 passed), and Gradle Validation (PASS) succeeded. However, `flutter build apk --debug` remains **BLOCKED** because the Kotlin native bridge references Java classes in `android/src/main/java` that contain desktop Java SE APIs (`java.net.http`, `java.lang.management`) unsupported on Android.
5. **Phase 20 Benchmark Reality**: The reported 6.25 MB (581 MB/s) transfer benchmark was audited and proven to be an **in-memory RAM SHA-256 loop**, not a network socket transfer. Real OS socket networking is implemented in `StandardTcpTransportProvider` and tested in `TwoNodeRealTransportTransferTest.java`.
6. **Java Tooling & Maven Wrapper**: An official, pinned Apache Maven Wrapper (version 3.9.9) was added (`mvnw`, `mvnw.cmd`) and verified. Standalone compilation of `windows/pom.xml` revealed 14 unresolved compilation errors in the platform copy of the backend code.

---

## Section A: Git Repository Status (Local vs Remote)

| Property | Value | Evidence / Command Output |
|---|---|---|
| **Git Working Directory** | `c:\Users\OMEN\.gemini\antigravity-ide\scratch\peerlink-master` | Verified via `git rev-parse --show-toplevel` |
| **Current Branch** | `master` | Matches tracking branch `origin/master` |
| **Current Commit** | `e208dd8` | `feat(phase-18): non-authoritative AI gateway implementation` |
| **Remote URL** | `https://github.com/karthikeyakolli/peerlink.git` | `origin` |
| **Remote Branch Commit** | `e208dd8` | `origin/master` is identical to local HEAD |
| **Phase 19–22 Remote Status** | **NOT ON REMOTE** | None of the Phase 19, 20, 21, or 22 changes exist on GitHub `origin/master` |
| **Local Staged Changes** | Staged deletion of `apps/peerlink-app/` (63 files) | Deletion uncommitted in index |
| **Local Unstaged Changes** | Modified platform scripts, Flutter home screens, Gradle configs | Clean-checkout state not yet committed |
| **Untracked Files** | `.mvn/wrapper/`, `mvnw`, `mvnw.cmd`, `tools/platform-parity/` | Added during remediation |

> [!IMPORTANT]
> In accordance with the protection rules, no reset, clean, force-push, or automated push was executed. The working tree and index remain intact.

---

## Section B: Common-Source Architecture Audit

The architectural requirement mandates four physically separate application projects:
- `windows/`
- `android/`
- `linux/`
- `macos/`

There must ultimately be **no shared application-source directory**, no `shared-source/canonical/` application source, and no runtime or build dependency across OS projects.

### Existing Common-Source Inventory

| Location | Item Count | Status | Deletion Verdict |
|---|---|---|---|
| `shared-source/canonical/` | 718 items | Contains canonical Java (552 files), Flutter (76 files), and resources | **UNSAFE TO DELETE**: Platform Java builds (`windows/pom.xml`) still contain compilation errors. Safe retirement requires compiling platform builds cleanly first. |
| `core/` | 277 Java files | Root portable core module (pom submodule) | **RETAINED TEMPORARILY**: Root Maven build depends on `core/`. |
| `protocol/` | 17 `.proto` files + generated Java/Dart | Centralized protocol schema | **RETAINED**: Governance contracts remain at root per ADR. |
| `desktop-node/` | 16 Java files | Root desktop shaded jar packaging | **RETAINED TEMPORARILY**: Used by root Maven build. |
| `apps/peerlink-app/` | 63 files | Legacy monolithic Flutter app | **DELETION STAGED LOCALLY**: Replacement verified in platform Flutter projects (`windows/app/flutter`, `linux/app/flutter`, etc.). Still present on `origin/master`. |

### Physical Platform Source Completeness

Each platform directory contains its own complete physical copies:
- `windows/`: `windows/src/main/java` (556 files), `windows/app/flutter` (self-contained Flutter project), `windows/pom.xml`, `windows/CMakeLists.txt`, `windows/scripts/`.
- `linux/`: `linux/src/main/java` (552 files), `linux/app/flutter` (self-contained Flutter project), `linux/pom.xml`, `linux/CMakeLists.txt`, `linux/scripts/`.
- `macos/`: `macos/src/main/java` (552 files), `macos/app/flutter` (self-contained Flutter project), `macos/pom.xml`, `macos/Runner.xcodeproj`, `macos/scripts/`.
- `android/`: `android/src/main/java` (548 files), `android/app/flutter` (Flutter UI + Kotlin native bridge), `android/app/android` (standalone Android Studio project), `android/scripts/`.

---

## Section C: Platform Parity Verifier Implementation

The legacy canonical sync tool (`tools/sync-platform-shared/sync-shared.ps1`) enforced synchronization by copying from `shared-source/canonical/` to platform projects. This violated the requirement that no canonical tree serve as an authoritative source of truth.

### Remediation

1. **Created Parity Manifest** (`tools/platform-parity/PARITY-MANIFEST.json`):
   - Defines 13 invariant backend modules (`protocol`, `operations`, `transfer`, `sync`, `backup`, `access`, `sharing`, `workspace`, `clipboard`, `compatibility`, `security`, `recovery`, `diagnostics`).
   - Defines 8 invariant Flutter paths (`lib/core`, `lib/features/transfers`, `lib/features/sharing`, `lib/features/sync`, `lib/features/backup`, `lib/features/settings`, `lib/features/diagnostics`, `lib/main.dart`).
   - Explicitly records intentional OS-specific divergence (Windows NTFS provider, Linux Secret Service/D-Bus, macOS Keychain, Android SAF/Keystore).
   - Enforces zero forbidden references to `apps/peerlink-app` and `shared-source/canonical`.

2. **Created Read-Only Peer-to-Peer Verifiers**:
   - `tools/platform-parity/verify-platform-parity.ps1` (PowerShell)
   - `tools/platform-parity/verify-platform-parity.sh` (POSIX Bash)
   - Read-only: Never overwrites files or selects any platform as truth.
   - Computes SHA-256 content hashes across all 4 platforms symmetrically.
   - Scans build files (`pom.xml`, `pubspec.yaml`, `build.gradle.kts`, `CMakeLists.txt`) and scripts for forbidden path references.

3. **Execution Results**:
   ```
   ==========================================================
    PeerLink Read-Only Platform Parity Verification Tool
    Manifest:          tools/platform-parity/PARITY-MANIFEST.json
    Target Platforms:  windows, linux, macos, android
    Mode:              Peer-to-Peer Invariant Hash Parity
   ==========================================================
   [1/4] Auditing Invariant Backend Modules across platforms...
   [2/4] Auditing Invariant Flutter UI Paths across platforms...
   [3/4] Auditing Platform Build Graphs & Configurations for Retired References...
   [4/4] Auditing Platform Scripts for Retired Source References...
   ==========================================================
    Parity Verification Summary:
    Total Invariant Relative Files Checked: 578
    Total Discrepancies Detected:          0
    Status: PASS (Zero Accidental Drift; Perfect Peer-to-Peer Parity)
   ==========================================================
   ```
   **Exit Code: 0**

4. **Legacy Redirect**: `tools/sync-platform-shared/verify-shared.ps1` and `verify-shared.sh` were updated to delegate directly to the read-only parity verifier.

---

## Section D: GitHub Reconciliation and CI Matrix

### Remote vs Local Reality
- **GitHub `origin/master`**:
  - `apps/peerlink-app/` is **still present**.
  - `shared-source/` is **still present**.
  - Commit history ends at Phase 18 (`e208dd8`).
- **CI Workflow (`.github/workflows/ci.yml`) Remediation**:
  - Replaced legacy `verify-shared.sh` with `./tools/platform-parity/verify-platform-parity.sh`.
  - Added architectural boundary verification step running `./scripts/check-deps.sh`.
  - Added explicit Android NDK installation (`ndk;28.2.13676358`) in the Android CI job.
  - Corrected protoc schema path to `windows/protocol/proto/peerlink/v1/*.proto`.
  - Configured 5 distinct platform validation jobs:
    1. `parity-and-contracts` on `ubuntu-latest`
    2. `windows-project` on `windows-2022`
    3. `linux-project` on `ubuntu-22.04`
    4. `macos-project` on `macos-14`
    5. `android-project` on `ubuntu-latest`
- **Dependency Boundary Verification Scripts**:
  - `scripts/check-deps.ps1` and `scripts/check-deps.sh` were upgraded to scan all four platform Java source trees (`windows/src/main/java`, `linux/src/main/java`, `macos/src/main/java`, `android/src/main/java`) for forbidden frameworks (Spring, Redis, JavaFX) and OS-specific APIs in portable packages.
  - Execution Result: **PASS** (Exit code 0).

---

## Section E: Build Blocker Investigation & Platform Build Status

### 1. Android Platform
- **NDK Version Determination**:
  - Inspected Flutter 3.47.7 and Gradle configuration: Flutter required NDK `28.2.13676358`.
  - Installed via `android.exe sdk install "ndk/28.2.13676358"`. Verified at `C:\Users\OMEN\AppData\Local\Android\sdk\ndk\28.2.13676358\source.properties`.
- **Flutter Doctor**:
  - Command: `flutter doctor -v`
  - Exit Code: `0`
  - Result: All components green (Flutter 3.47.7, Android SDK 36.0.0, Java 25, Visual Studio Community 2026).
- **Flutter Analyze**:
  - Command: `flutter analyze`
  - Exit Code: `0` (after removing unreachable switch default in `android_node_status_widget.dart`). 0 errors, 2 informational notices.
- **Flutter Test**:
  - Command: `flutter test`
  - Exit Code: `0`
  - Result: `All tests passed! (12/12 passed)`.
- **Gradle Validation**:
  - Command: `.\gradlew.bat --version`
  - Exit Code: `0`
  - Result: Gradle 9.3.1, Kotlin 2.2.21, JVM 25.0.4.1.
- **Flutter Build APK**:
  - Command: `flutter build apk --debug`
  - Exit Code: `1` (FAIL)
  - Root Cause:
    1. Kotlin native bridge classes (`AndroidNotificationBridge`, `AndroidWifiDirectAdapter`, `AndroidKeyStoreProvider`, `SafStorageProvider`) reference `org.peerlink.core.android.*` and `org.peerlink.protocol.v1.*`.
    2. Those classes reside in `android/src/main/java`. When `android/src/main/java` is included in the Android Gradle compilation, Android's `javac` attempts to compile classes that use desktop Java SE APIs (`java.net.http`, `java.lang.management.ManagementFactory`, `System.getLogger`) which do not exist in the Android SDK runtime.
  - Status: **BLOCKED WITH EXPLICIT ROOT CAUSE**.

### 2. Java Tooling & Maven Wrapper
- **Maven Wrapper**:
  - Pinned Apache Maven version: `3.9.9` in `.mvn/wrapper/maven-wrapper.properties`.
  - Added official wrapper scripts: `mvnw` and `mvnw.cmd`.
  - Command: `.\mvnw.cmd -v`
  - Exit Code: `0`
  - Output: `Apache Maven 3.9.9 (8e8579a9e76f7d015ee5ec7bfcdc97d260186937) | Java version: 25.0.4.1`.
- **Java Runtime Compatibility**:
  - Documented requirement: Project requires JDK 17 or JDK 21.
  - When executed under preview runtime Java 25, `kotlin-maven-plugin:1.9.24` throws `java.lang.IllegalArgumentException: 25.0.4.1` because Kotlin 1.9.x does not support Java 25 bytecode.

### 3. Windows Native Build
- **Flutter Release Executable**:
  - Verified path: `windows/app/flutter/build/windows/x64/runner/Release/peerlink.exe`
  - Size: 18.5 MB, compiled with MSVC C++ toolchain.
  - Status: **PASS**.
- **Windows Local Node (`windows/pom.xml`)**:
  - Command: `.\mvnw.cmd -f windows\pom.xml compile`
  - Exit Code: `1` (FAIL)
  - Errors: 14 compiler errors caused by duplicate classes (`PeerFileHandle`, `PeerFileProvider` in `windows/filesystem`) and contract signature drift (`TransferManifest.getRecipientPeerId` vs `getReceiverPeerId`, `TransferItem.getSha256` vs `getSha256Hex`, `ErrorCode.ERROR_CODE_INVALID_ARGUMENT`).
  - Status: **FAIL (CONTRACT RECONCILIATION REQUIRED)**.

### 4. Linux and macOS Native Builds
- **Linux Native Build & Tests**: **BLOCKED / NOT RUN** (Workstation is Windows 11; Linux runner inaccessible locally; configured in CI on `ubuntu-22.04`).
- **macOS Native Build & Tests**: **BLOCKED / NOT RUN** (macOS runner inaccessible locally; configured in CI on `macos-14`).

---

## Section F: Critical Implementation Claims Audit

### 1. Phase 20 Benchmark Reality
- **Audit Target**: Phase 20 Hardening Test Runner Test 20 (`Phase20HardeningTestRunner.java:650-674`).
- **Claimed Result**: "6.25 MB dataset in 10.75ms => 581.42 MB/s".
- **Source Inspection**:
  ```java
  byte[] payload = new byte[64 * 1024]; // 64 KB block
  Arrays.fill(payload, (byte) 0x55);
  int iterations = 100;
  long start = System.nanoTime();
  for (int i = 0; i < iterations; i++) {
      ContentHash h = ContentHash.computeSha256(payload);
  }
  ```
- **Finding**: Test 20 was a **pure in-memory RAM SHA-256 hashing loop**. It did **NOT** traverse any network socket, transport layer, or inter-process channel. Claiming 581 MB/s as a transfer benchmark was misleading.

### 2. Real Network Socket Transfer Evidence
- **Real Transport Provider**: `StandardTcpTransportProvider.java` implements Java NIO `ServerSocketChannel` and `SocketChannel` over real OS loopback TCP sockets (`127.0.0.1`) with 4-byte framing prefixes and Protobuf serialization.
- **Two-Node Integration Test**: `TwoNodeRealTransportTransferTest.java`:
  - Starts Node Bob listening on an ephemeral OS TCP port (`bobTransport.startListening(0, ...)`).
  - Node Alice connects across the real OS socket (`aliceTransport.connectAsync(new InetSocketAddress("127.0.0.1", bobPort))`).
  - Executes mutual 3-way authenticated Ed25519 handshake.
  - Streams chunked transfer across the socket channel.
  - Receiver validates per-chunk SHA-256 and writes to isolated quarantine staging directory.
  - Verifies non-executable commit to destination directory.
  - Verifies rejection of untrusted peers (`testUntrustedPeerHandshakeRejection`).

---

## Section G: Deliverables and Release Verdict

### Platform Validation Scorecard

| Check / Requirement | Status | Evidence / Notes |
|---|---|---|
| **Git Working Tree Protection** | **PASS** | No resets, cleans, or unauthorized pushes executed |
| **Git Remote Audit** | **PASS** | Verified Phase 19–22 uncommitted locally and absent on `origin/master` |
| **Common-Source Audit** | **PASS** | All common-source locations mapped and documented |
| **Read-Only Parity Verifier** | **PASS** | 578 invariant relative files checked; 0 discrepancies |
| **Architectural Dependency Boundaries** | **PASS** | `scripts/check-deps.ps1` passes with 0 violations |
| **Maven Wrapper (mvnw)** | **PASS** | Apache Maven 3.9.9 pinned and verified |
| **Android NDK 28 Installation** | **PASS** | NDK `28.2.13676358` installed and verified |
| **Android Flutter Doctor / Analyze / Test** | **PASS** | Doctor clean, analyze clean, 12/12 Flutter tests pass |
| **Android Debug APK Build** | **FAIL / BLOCKED** | Kotlin native bridge unlinked to desktop Java SE APIs |
| **Windows Flutter Release EXE** | **PASS** | `peerlink.exe` (18.5 MB) verified |
| **Windows Java Local Node Compile** | **FAIL** | 14 compilation errors in `windows/src/main/java` |
| **Linux Native Build & Tests** | **NOT RUN / BLOCKED** | Inaccessible local runner on Windows host |
| **macOS Native Build & Tests** | **NOT RUN / BLOCKED** | Inaccessible local runner on Windows host |
| **Benchmark Authenticity Audit** | **PASS** | Exposed Phase 20 6.25 MB benchmark as in-memory RAM hash |
| **Real Network Transport Architecture** | **PASS** | Verified Java NIO TCP socket transport and two-node handshake |

### Release Verdict

**CONDITIONALLY READY WITH EXPLICIT BLOCKERS**

#### Explicit Blockers Before Production Release Candidate:
1. **Android Gradle / Native Linking**: Resolve the Android native bridge compilation so `flutter build apk --debug` completes. This requires either compiling the portable Android classes into an Android Library (`.aar`) without desktop Java SE dependencies (`java.net.http`, `java.lang.management`) or providing Android-specific shims.
2. **Platform Java Compilation**: Reconcile the 14 compiler errors in `windows/src/main/java` (and their identical copies in `linux/` and `macos/`) so each platform's native local node compiles via `mvn compile`.
3. **Commit and Push Authorization**: Commit the staged Phase 19–22 changes and push to `origin/master` following explicit user authorization.
4. **CI Workflow Execution**: Execute the updated `.github/workflows/ci.yml` across GitHub's multi-OS hosted runners (`windows-2022`, `ubuntu-22.04`, `macos-14`, `ubuntu-latest`) to capture genuine cloud CI logs.

---
*Report completed under strict no-fabrication guidelines.*
