# PeerLink Android Studio Edition — Phase 02 Implementation Report: Zero-Configuration Startup & Permission Automation

**Document Version:** 1.0.0  
**Phase:** Phase 02  
**Status:** COMPLETE & VERIFIED  
**Date:** 2026-10-18  
**Author:** Lead Android / Flutter / P2P Systems Engineer  
**Target Project:** `peerlink-android-studio/`  
**Git Commit Baseline:** `e1362b2` (branch `master`)

---

## 1. Initial Defect & Usability Obstacles

Prior to Phase 2:
1. **Manual Networking Rituals:** When PeerLink launched, the Home screen displayed the desktop IPC card (`LocalNodeCard`), prompting users to manually inspect or configure IPC Auth Tokens, TCP ports (`50051`), and press manual "Connect" buttons. On native mobile devices, this created friction, technical confusion, and violated the core principle that routine sharing requires zero manual networking setup.
2. **Hardcoded Permission Assumptions:** Android runtime permissions in `PeerLinkApplication.kt` were unconditionally reported as `true` (`.storagePermissionGranted(true)`, `.notificationPermissionGranted(true)`, `.nearbyDevicesPermissionGranted(true)`), obscuring denied states and preventing accurate capability reporting.
3. **Missing Critical Manifest Declarations:** `CAMERA` permission was absent from `AndroidManifest.xml`, creating a blocker for real optical pairing in Phase 3.
4. **Fragile Transient Startup:** If the application opened while the device was momentarily offline, startup failed permanently without bounded retry or automatic recovery when network connectivity resumed.
5. **No Centralized Permission Bridge:** Flutter UI had no mechanism to request missing runtime permissions (`POST_NOTIFICATIONS`, `NEARBY_WIFI_DEVICES`, `ACCESS_LOCAL_NETWORK`, `CAMERA`) through native Android system dialogs.

---

## 2. Root Cause Analysis

1. **Desktop vs. Mobile Architectural Divergence:** The desktop Flutter client connects to an external local daemon over localhost IPC, whereas the native Android Studio Edition hosts the local node directly in-process via `AndroidNodeFacade` and `PeerLinkApplication`. The UI did not differentiate between desktop and mobile execution environments.
2. **Absence of Environmental Auto-Resumption:** Sockets and discovery were not tied to connectivity callbacks. When a prerequisite was restored, user intervention was incorrectly expected.
3. **Unimplemented Android Activity Permission Callbacks:** `MainActivity.kt` supported document picking via `startActivityForResult`, but lacked runtime `requestPermissions()` dispatch and `onRequestPermissionsResult()` handling.

---

## 3. Design Decisions & Implementation Details

### A. Zero-Configuration Startup Architecture
1. **Authoritative In-Process Lifecycle:**
   - In `LocalNodeCard.dart`, if running on Android (`PlatformCapabilities.isAndroid`), manual token/port text fields, "Connect" buttons, and desktop test harnesses are completely removed.
   - On widget initialization (`initState`), `LocalNodeCard` checks current `NodeLifecycleState`. If `stopped` or `unknown`, it automatically triggers `AndroidNodeBridge.instance.startNode()` without user interaction.
   - Real-time node capabilities (`NodeCapabilities`), local peer ID, hardware Keystore security tier, active listeners, and network interfaces are fetched asynchronously and kept in sync via `lifecycleStream` and `events`.
2. **Desktop Backward Compatibility:**
   - On Windows/Linux/macOS desktop environments (`!PlatformCapabilities.isAndroid`), the previous desktop IPC connection interface is fully preserved.

### B. Truthful Permission Evaluation & System Reconciler
1. **Runtime Manifest & Permission Audit:**
   - Added `<uses-permission android:name="android.permission.CAMERA" />` with optional hardware feature declaration (`android.hardware.camera`, `required="false"`).
   - In `AndroidNodeContext.java`, added `localNetworkPermissionGranted` (for API 37+ `ACCESS_LOCAL_NETWORK`) and `cameraPermissionGranted` with immutable getters and builder setters.
2. **Context-Aware Runtime Inspection in `PeerLinkApplication.kt`:**
   - Truthfully audits runtime permissions using `checkSelfPermission()`:
     - Android 13+ (API 33+): `POST_NOTIFICATIONS`, `NEARBY_WIFI_DEVICES`.
     - Android 12 and below: `ACCESS_FINE_LOCATION` for Wi-Fi Direct / NSD.
     - Android 17+ (API 37+): `ACCESS_LOCAL_NETWORK` for local socket listeners.
     - Android 6+ (API 23+): `CAMERA`.
     - Storage: Defaults to Storage Access Framework (SAF), eliminating invasive broad storage permission demands while remaining compliant with Google Play Scoped Storage policies.
3. **Native Bridge Permission Dispatch in `MainActivity.kt` & `AndroidPigeonBridge.kt`:**
   - Added `"checkPermissions"` and `"requestPermissions"` method channel handlers.
   - `MainActivity.kt` dispatches system permission dialogs via `requestPermissions()` and handles callbacks in `onRequestPermissionsResult()`, immediately refreshing `PeerLinkApplication.updateEnvironmentalState()` and emitting `"permissionsChanged"` events to Flutter.

### C. Bounded Retry & Environmental Auto-Recovery
1. **Transient Failure Exponential Backoff in `AndroidNodeFacade.java`:**
   - Added `retryScheduler` (`ScheduledExecutorService`) and `AtomicInteger retryCount`.
   - If `start()` is invoked while critical prerequisites are offline, the node transitions truthfully to `UNAVAILABLE` and schedules a retry with exponential backoff:
     $$\text{delay} = 2^{\text{attempt} - 1} \text{ seconds (1s, 2s, 4s)}$$
   - Bounded by `MAX_RETRY_BUDGET = 3`.
2. **Clean Cancellation & Environmental Auto-Resumption:**
   - Calling `stop()` immediately cancels any pending retry tasks (`pendingRetryTask.cancel(true)`) and resets `retryCount` to 0.
   - When network connectivity is restored (e.g. Wi-Fi reconnected), `updateContext()` detects the transition from `UNAVAILABLE` and automatically resumes node startup to `READY`.

---

## 4. Files Modified and Created

| File | Action | Purpose |
|------|--------|---------|
| `android/app/src/main/AndroidManifest.xml` | Modified | Added `CAMERA` permission and optional camera feature declaration. |
| `android/app/src/main/java/org/peerlink/core/android/AndroidNodeContext.java` | Modified | Added `localNetworkPermissionGranted` and `cameraPermissionGranted` with builder setters. |
| `android/app/src/main/java/org/peerlink/core/android/AndroidNodeFacade.java` | Modified | Implemented bounded exponential backoff retry, retry cancellation, environmental recovery, and full capability permission auditing. |
| `android/app/src/main/kotlin/org/peerlink/app/PeerLinkApplication.kt` | Modified | Updated `buildCurrentContext()` to evaluate real runtime permissions. |
| `android/app/src/main/kotlin/org/peerlink/app/bridge/AndroidPigeonBridge.kt` | Modified | Added `"checkPermissions"` and `"requestPermissions"` method channel handlers. |
| `android/app/src/main/kotlin/org/peerlink/peerlink/MainActivity.kt` | Modified | Implemented `requestRequiredPermissions()` and `onRequestPermissionsResult()`. |
| `lib/platform/android_node_bridge.dart` | Modified | Added `checkPermissions()` and `requestPermissions()` Dart bindings. |
| `lib/core/platform/android_node_bridge.dart` | Modified | Synchronized Dart platform bindings. |
| `lib/features/home/local_node_card.dart` | Modified | Rewritten with native Android zero-config UI, reactive lifecycle listeners, and permission warning banners. |
| `android/app/src/test/kotlin/org/peerlink/app/AndroidZeroConfigStartupTest.kt` | Created | Comprehensive JUnit/Kotlin unit test suite verifying zero-config startup, permissions, and retry policies (6 tests). |
| `test/zero_config_startup_widget_test.dart` | Created | Flutter widget test verifying zero-config UI behavior and desktop backward compatibility (2 tests). |

---

## 5. Verification Commands and Exact Results

### 1. Android Native JVM Unit Tests
- **Command:** `powershell -Command "$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'; .\gradlew.bat :app:testDebugUnitTest"`
- **Execution Time:** 24.0s
- **Results:** **BUILD SUCCESSFUL**
- **Test Summary:**
  - `AndroidZeroConfigStartupTest`: **6/6 passed** (0 failures, 0 errors, 0 skipped, 0.047s)
  - `AndroidNodeLifecycleStateMachineTest`: **6/6 passed**
  - `AndroidFourOperationModesTest`: **4/4 passed**
  - `AndroidIdentityCompatibilityTest`: **11/11 passed**
  - `AndroidLifecycleAndPersistenceTest`: **5/5 passed**
  - `AndroidNodeContextTest`: **2/2 passed**
  - `AndroidRealPeerConnectivityTest`: **4/4 passed**
  - **Total Android Tests:** **38 / 38 passed** (100% pass rate).

### 2. Flutter Unit & Widget Tests
- **Command:** `flutter test`
- **Execution Time:** 7.0s
- **Results:** **All 57 tests passed!** (0 failures).
- **Key Tests Verified:**
  - `test/zero_config_startup_widget_test.dart`:
    - `LocalNodeCard: Android Native Mode runs zero-config and hides desktop manual IPC controls`: PASSED.
    - `LocalNodeCard: Desktop Mode preserves desktop IPC parameters for backward compatibility`: PASSED.
  - `test/home_ux_simplification_test.dart`: PASSED.
  - `test/widget_test.dart`: PASSED.

---

## 6. Acceptance Gate Evaluation

| Requirement | Acceptance Gate Standard | Status | Evidence |
|-------------|-------------------------|--------|----------|
| **Zero-Config Startup** | Opening PeerLink initializes node without manual networking setup | **MET** | `testZeroConfigStartupInitializesToReady`, `zero_config_startup_widget_test.dart` |
| **Truthful Capabilities** | Readiness reflects real listeners, interfaces, and permissions | **MET** | Verified active TCP listener on 8765, Keystore tier, and interface reporting |
| **Permission Graceful Degradation** | Missing permissions report accurately without app crash | **MET** | `testPermissionDenialReportsMissingPermissionsGracefully` |
| **Bounded Retry & Backoff** | Transient failures retry with bounded exponential backoff | **MET** | `testTransientPrerequisiteFailureTriggersBoundedRetry` (budget: 3 attempts) |
| **Clean Cancellation** | Node stop cancels retries and cleans up background services | **MET** | `testStopCancelsRetriesAndCleansUp` |
| **Desktop Backward Compatibility** | Desktop mode retains manual IPC controls for harness testing | **MET** | `zero_config_startup_widget_test.dart` passes in desktop mode |

---

## 7. Next Phase Dependencies

- **Phase 03 (Real QR Invitations and Authenticated Pairing):**
  - Now unblocked with `CAMERA` permission in manifest and zero-config native node in `READY` state.
  - Replace `_SimulatedQrPainter` in `QrPairingSheet` with `qr_flutter`.
  - Replace simulated scan callback (`peer-scanned-01`) with real camera decoding via `mobile_scanner`.
  - Validate Ed25519 pairing invitations against versioned JSON schema with cryptographic nonces and expiry.
