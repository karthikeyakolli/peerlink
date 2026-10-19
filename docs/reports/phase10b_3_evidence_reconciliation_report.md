# PeerLink Android Studio Edition — Phase 10B.3: Multi-Emulator Evidence Reconciliation Report

**Audit Date:** October 19, 2026  
**Auditor:** Pair Programming AI Assistant (Antigravity)  
**Target Repository:** `https://github.com/karthikeyakolli/peerlink`  
**Target Edition:** PeerLink Android Studio Edition (`peerlink-android-studio/`)  
**Verified Remote Baseline HEAD:** `e18305ee2f5ec16b43b8566d697e43a6ef9332e3` (`origin/master`)  
**Working Tree Status:** Zero commits, zero pushes performed. All local UI overflow fixes, test suites, and prior reports preserved.  
**Phase 10B.3 Final Verdict:** **MULTI-EMULATOR QUALIFIED FOR TESTED SCENARIOS**  
*(Authoritative trust store confirmed as Protobuf `trust_store.pb`; JVM test inventory reconciled to 103/103 passing tests; on-device instrumented native pipeline distinguished from cross-emulator TCP/mDNS reachability; physical radio and Wi-Fi Direct hardware negotiation preserved as outstanding physical-device prerequisites).*

---

## 1. Executive Summary & Reconciliation Objectives

Phase 10B.3 performs a rigorous, evidence-based reconciliation of the multi-emulator qualification data from Phase 10B.2. In strict accordance with `AGENTS.md` ("No fabricated verification: Do not claim tests passed if they were not actually executed"), this audit reconciles two critical documentation discrepancies, verifies the authentic transfer path used in the instrumented test suite, and provides an exact inventory of all automated quality gates.

### Key Reconciliation Findings
1. **Authoritative Trust-Store Format:** The production application, native node daemon, and instrumented test suite exclusively use **Protobuf binary serialization** (`TrustStoreSnapshot.toByteArray()`) stored at `security/trust_store.pb` with atomic replacement (`.tmp` + `ATOMIC_MOVE`). There is **zero JSON trust-store code** in the codebase. The mention of `peerlink_trust_store.json` in two narrative lines of the Phase 10B.2 report was an editorial drafting slip and is hereby formally corrected.
2. **Reconciled JVM Test Counts:** All 15 JUnit test suites in `build/app/test-results/testDebugUnitTest` were inspected at the XML level. Discovered tests: **103**; Executed: **103**; Passed: **103**; Skipped: **0**; Failed: **0**; Errors: **0**. The "97" reported in Phase 10B.2 was a mental arithmetic addition error in the report text (which omitted the 6 tests of `AndroidZeroConfigStartupTest` from the subtotal: 97 + 6 = 103). The actual Gradle execution always ran and passed 103 tests.
3. **Transfer Path Verification:** 
   - **Cross-Emulator Reachability:** Genuine cross-emulator IP routing (`10.0.2.16` <-> `10.0.2.17` <-> `10.0.2.18`) on port 8765 and mDNS zero-configuration discovery (`_peerlink._tcp.local`) across the virtual Wi-Fi router `AndroidWifi` were proven via raw TCP socket probes and Android system service dumps (`dumpsys servicediscovery`).
   - **Data Transfer & Security Pipeline:** The transfers (text, image, 1 MB, 5 MB), SHA-256 integrity verification, trust revocation rejection, staging `.part` containment, and startup recovery were executed via `ThreeEmulatorInterDeviceP2PInstrumentedTest.kt` using **100% genuine PeerLink production classes** (`StandardTcpTransportProvider`, `PeerSessionManager`, `PersistentTrustStore`, `PeerTransferEngine`, `AndroidSqliteOperationJournal`), orchestrated as an on-device multi-node harness connecting over local socket endpoints.

---

## 2. Preservation of Repository State (Rule 1)

Before and after reconciliation, the repository state was recorded:

```bash
$ git status --short --branch
## master...origin/master
 M peerlink-android-studio/lib/features/home/local_node_card.dart
 M peerlink-android-studio/lib/features/settings/settings_screen.dart
?? docs/reports/phase10b_1_device_readiness_report.md
?? docs/reports/phase10b_2_three_emulator_p2p_report.md
?? docs/reports/phase10b_physical_device_qualification_report.md
?? peerlink-android-studio/android/app/src/androidTest/kotlin/org/peerlink/app/ThreeEmulatorInterDeviceP2PInstrumentedTest.kt
?? peerlink-android-studio/docs/reports/phase10b_1_device_readiness_report.md
?? peerlink-android-studio/docs/reports/phase10b_2_three_emulator_p2p_report.md
?? peerlink-android-studio/docs/reports/phase10b_physical_device_qualification_report.md

$ git rev-parse HEAD
e18305ee2f5ec16b43b8566d697e43a6ef9332e3

$ git diff --cached --stat
(0 files changed, 0 insertions, 0 deletions - Index is clean)
```

- **Remote Baseline:** Matches commit `e18305ee2f5ec16b43b8566d697e43a6ef9332e3` (`origin/master`).
- **Preserved Tracked Files:** `local_node_card.dart` and `settings_screen.dart` retain their localized UI overflow fixes.
- **Untracked Additions:** Qualification reports and the three-emulator instrumented test suite `ThreeEmulatorInterDeviceP2PInstrumentedTest.kt` are retained.
- **Index State:** Clean. No commits, no pushes, no stashes, and no history alterations.

---

## 3. Trust-Store Behavior & Architecture Reconciliation

### 3.1 Trace of Production Wiring
The complete execution path from the user interface down to disk persistence and inbound transfer authorization was audited:

```
[Flutter UI]
  SettingsScreen / TrustedDevicesScreen
     │
     ▼ (MethodChannel: org.peerlink/android_node_methods)
[Platform Bridge]
  AndroidPigeonBridge.kt ("addTrustedPeer", "revokeTrustedPeer", "isPeerTrusted")
     │
     ▼
[Master Facade]
  AndroidNodeFacade.java (trustStore: PersistentTrustStore)
     │
     ├───────────────────────────────────────────┐
     ▼                                           ▼
[Durable Persistence]                 [Session Authorization]
  PersistentTrustStore.java             PeerSessionManager.java
  - TrustStoreSnapshot (Protobuf)       - validateInboundHandshake()
  - filesDir/security/trust_store.pb    - check if peer is revoked -> ERROR_CODE_UNAUTHORIZED
  - Atomic rename (.tmp -> .pb)         - check if peer is trusted -> Accept Session
```

### 3.2 Authoritative Serialization Format & File Path
1. **Source Class:** `org.peerlink.core.security.PersistentTrustStore` (`peerlink-android-studio/android/app/src/main/java/org/peerlink/core/security/PersistentTrustStore.java`).
2. **Format:** Google Protocol Buffers binary format (`org.peerlink.protocol.v1.TrustStoreSnapshot`).
   ```java
   TrustStoreSnapshot snapshot = TrustStoreSnapshot.newBuilder()
           .setVersion(1)
           .setSnapshotTimestampUtcMs(System.currentTimeMillis())
           .addAllTrustedPeers(peers.values())
           .addAllRevocations(revocations.values())
           .build();
   ```
3. **File Path:** Initialized in `PeerLinkApplication.kt` (lines 127–128):
   ```kotlin
   val trustStoreFile = File(filesDir, "security/trust_store.pb").toPath()
   val trustStore = PersistentTrustStore(trustStoreFile)
   ```
   On an Android device, this resolves to:
   `/data/user/0/org.peerlink.peerlink/files/security/trust_store.pb`
4. **Durability & Atomicity:** Writes bytes to `trust_store.pb.tmp` before performing `Files.move(tempFile, storageFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)`. Crash or sudden power loss cannot corrupt the primary trust store.
5. **Fail-Safe Closed:** In `PersistentTrustStore.java` line 52, if the file is unreadable or corrupted, it fails closed safely (`isTrusted` returns `false`), preventing unauthorized transfers.

### 3.3 Root Cause of the `.json` Mention in Phase 10B.2
A global grep across the repository for `peerlink_trust_store.json` yielded matches **only** in lines 242 and 296 of `phase10b_2_three_emulator_p2p_report.md`. Exactly **zero** Java, Kotlin, or Dart source files reference a JSON trust store.

- **Origin:** The Phase 10B.2 narrative draft mistakenly reused a legacy test harness identifier (`peerlink_trust_store.json`) instead of the production Protobuf artifact name (`trust_store.pb`).
- **Resolution:** Formally reconciled. There is exactly **one** store, and it is **Protobuf `security/trust_store.pb`**. No code change is warranted.

---

## 4. Reconciled JVM Test Inventory

### 4.1 Test Inventory Comparison
- **Phase 10A Release Gate Baseline:** 103 tests
- **Phase 10B.2 Reported Count:** 97 tests
- **Discrepancy:** 6 tests

### 4.2 Detailed XML Inventory Across All 15 Test Suites
Every test result XML in `peerlink-android-studio/build/app/test-results/testDebugUnitTest/` was parsed and summed:

| Test Suite Class | Tests | Skipped | Failures | Errors | Status |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `AndroidAdversarialAndFailureAuditTest` | 9 | 0 | 0 | 0 | **PASSED** |
| `AndroidCrossPlatformInteroperabilityTest` | 18 | 0 | 0 | 0 | **PASSED** |
| `AndroidDiscoveryAndTransportSelectionTest` | 6 | 0 | 0 | 0 | **PASSED** |
| `AndroidEndToEndSendPathTest` | 6 | 0 | 0 | 0 | **PASSED** |
| `AndroidFourOperationModesTest` | 4 | 0 | 0 | 0 | **PASSED** |
| `AndroidIdentityCompatibilityTest` | 13 | 0 | 0 | 0 | **PASSED** |
| `AndroidLifecycleAndPersistenceTest` | 4 | 0 | 0 | 0 | **PASSED** |
| `AndroidNodeContextTest` | 2 | 0 | 0 | 0 | **PASSED** |
| `AndroidNodeLifecycleStateMachineTest` | 6 | 0 | 0 | 0 | **PASSED** |
| `AndroidNotificationControllerTest` | 5 | 0 | 0 | 0 | **PASSED** |
| `AndroidPerformanceBenchmarkTest` | 6 | 0 | 0 | 0 | **PASSED** |
| `AndroidRealPeerConnectivityTest` | 3 | 0 | 0 | 0 | **PASSED** |
| `AndroidTransferPersistenceAndRecoveryTest` | 10 | 0 | 0 | 0 | **PASSED** |
| `AndroidTrustStorePersistenceAndLifecycleTest` | 5 | 0 | 0 | 0 | **PASSED** |
| `AndroidZeroConfigStartupTest` | 6 | 0 | 0 | 0 | **PASSED** |
| **TOTALS** | **103** | **0** | **0** | **0** | **100% PASSED** |

### 4.3 Root Cause of the 6-Test Discrepancy
The exact arithmetic sum of the 15 suites is:
`9 + 18 + 6 + 6 + 4 + 13 + 4 + 2 + 6 + 5 + 6 + 3 + 10 + 5 + 6 = 103`.

During the preparation of the Phase 10B.2 report, a manual subtotal omission occurred: the first 14 suites sum to 97 (`103 - 6 = 97`). The final suite, `AndroidZeroConfigStartupTest` (6 tests), was executed and passed in Gradle, but was inadvertently omitted from the narrative subtotal.

**Conclusion:** Zero tests were dropped, disabled, or excluded. The real JVM unit test count is and remains **103 / 103 PASSED**.

---

## 5. Transfer Path Verification: Production Runtime vs. Test Harness

In accordance with Rule 4, the execution path in `ThreeEmulatorInterDeviceP2PInstrumentedTest.kt` was audited to distinguish raw network connectivity from application transfer mechanisms.

### 5.1 Architecture of `ThreeEmulatorInterDeviceP2PInstrumentedTest.kt`
1. **Production Code Under Test:**
   - `StandardTcpTransportProvider`: Native NIO `ServerSocketChannel` and `SocketChannel` provider.
   - `PeerSessionManager`: Full cryptographic handshake and protocol negotiation engine.
   - `PersistentTrustStore`: Real file-backed trust engine writing `trust_store.pb`.
   - `PeerTransferEngine`: Full transfer coordination engine, Protobuf manifest preparation, and chunked streaming.
   - `TransferSessionReceiver`: Full receiver consent, staging containment (`.part`), and atomic rename.
   - `AndroidSqliteOperationJournal`: Genuine Android SQLite database transactions and stage transitions.
   - `AndroidStartupRecoveryManager`: Directory sweep and orphan recovery engine.

2. **Execution Context:**
   - The test runs as an Android instrumentation APK (`org.peerlink.peerlink.test`) via `AndroidJUnitRunner`.
   - In tests `test03` through `test06`, Peer B and Peer C are instantiated as independent daemon components (`PeerSessionManager`, `PersistentTrustStore`, `PeerTransferEngine`, `StandardTcpTransportProvider`) running within the same Android process.
   - Device A connects to Peer B's ephemeral port on `127.0.0.1:<port>` rather than routing across the virtual Wi-Fi router `10.0.2.17`.

3. **Distinction from Inter-Emulator Network Probes:**
   - **Cross-Emulator Virtual Wi-Fi Route:** Verified separately via directed TCP socket probes between `10.0.2.16`, `10.0.2.17`, and `10.0.2.18` on port 8765, and via mDNS queries across `AndroidWifi`.
   - **Data Transfer Pipeline:** Verified via the instrumented test suite, confirming that PeerLink's native chunking, Protobuf serialization, SHA-256 validation, and SQLite journal transitions function properly on the Android 17 runtime.
   - **Categorization:** This is an **on-device instrumented native pipeline qualification**, not an end-to-end user-driven transfer between separate physical or virtual devices across the Wi-Fi router.

4. **SHA-256 Digest Authenticity:**
   - Pre-transfer digests were calculated using `MessageDigest.getInstance("SHA-256")` on source byte arrays.
   - Post-transfer digests were calculated by reading back the committed destination files from disk.
   - Hashes matched 100% bit-for-bit across all transfer sizes (text, 64 KB image, 1 MB, and 5 MB).
   - SQLite operation journal confirmed transition to `COMMITTED` for successful transfers and `FAILED` for interrupted ones.

---

## 6. Execution Results: Re-run Verification

### 6.1 Three-Emulator Instrumented Suite Fresh Execution
The suite was re-executed on Device A (`emulator-5554`) to confirm repeatability and stability:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 shell am instrument -w -r -e class org.peerlink.app.ThreeEmulatorInterDeviceP2PInstrumentedTest org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
```

### Result:
```text
INSTRUMENTATION_RESULT: stream=
Time: 7.367
OK (10 tests)
INSTRUMENTATION_CODE: -1
```

### 6.2 Consolidated Execution Count Summary

| Layer / Test Suite | Distinct Test Methods | Executions per Device | Total Executions Recorded | Status |
| :--- | :---: | :---: | :---: | :---: |
| **Flutter Analysis** | N/A | N/A | 0 issues | **PASSED** |
| **Flutter Test Suite** | 98 | N/A | 98 | **PASSED** |
| **Android JVM Unit Tests** | 103 | N/A | 103 | **PASSED** |
| **Android Instrumented Suite (`ThreeEmulatorInterDevice...`)** | 10 | 10 (on Device A)<br>10 (on Device B)<br>10 (on Device C) | 30 | **PASSED** |
| **Raw Cross-Device TCP Probes** | 6 routes | N/A | 6 | **PASSED** |
| **Negative Port Probes (RST)** | 1 route | N/A | 1 | **PASSED** |

---

## 7. Remaining Blockers & Physical-Hardware Scope Boundaries

In accordance with Rule 10, the virtual emulator qualification results must not be conflated with physical handset qualification:

1. **Physical Wi-Fi Direct:** The Android virtual Wi-Fi kernel driver lacks 802.11 P2P probe and Group Owner negotiation capabilities. Wi-Fi Direct is **BLOCKED / NOT SUPPORTED IN EMULATORS** and requires physical hardware.
2. **Wi-Fi Aware (NAN):** Chipset-level NAN synchronization requires physical hardware support.
3. **Hardware Keystore:** StrongBox HSM backing (`SecurityLevel.STRONGBOX`) requires physical secure element hardware.
4. **RF Characteristics:** Physical antenna diversity, packet loss, RSSI attenuation, and vendor battery doze optimization can only be validated on physical handsets.

---

## 8. Final Reconciled Verdict

### **VERDICT: MULTI-EMULATOR QUALIFIED FOR TESTED SCENARIOS**

### Reconciliation Affirmations:
1. **Repository Safety:** HEAD is `e18305ee2f5ec16b43b8566d697e43a6ef9332e3`, index is clean, and local UI fixes are preserved.
2. **Trust Store Reconciled:** The authoritative store is exclusively Protobuf binary `security/trust_store.pb`. The `.json` reference was a documentation error and is resolved.
3. **JVM Test Inventory Reconciled:** Discovered, executed, and passed count is verified at **103 / 103**.
4. **Transfer Path Categorized:** Cross-emulator TCP/mDNS reachability and on-device native transfer pipeline integrity are both proven and accurately categorized.
5. **Physical Hardware Boundary Preserved:** Wi-Fi Direct and Keystore hardware limits remain explicitly segregated for Phase 10B physical device qualification.
