# PeerLink for Android — Self-Contained Platform Project

This directory contains the complete, self-contained implementation of PeerLink for Android, including the Flutter presentation layer, the native Android host project, hardware keystore integration, Storage Access Framework (SAF) scoped storage provider, foreground data sync services, and Android Studio workflow scripts.

---

## 1. Architecture & Android System Constraints

```
+-------------------------------------------------------------------------+
|                        PeerLink Android Client                          |
+-------------------------------------------------------------------------+
|  Flutter Presentation Layer (Dart)                                      |
|  - UI Presentation & State Management                                   |
|  - Communicates with native host via MethodChannel & EventChannel       |
|    - Channel: "org.peerlink/android_node_methods"                       |
|    - Channel: "org.peerlink/android_node_events"                        |
+-------------------------------------------------------------------------+
                                    |
          Pigeon / Platform Bridge  | AndroidPigeonBridge
                                    v
+-------------------------------------------------------------------------+
|  Authoritative Native Android Node Facade (Kotlin / Java 17)            |
|  - AndroidNodeStateMachine (Environmental Context & Power Evaluation)   |
|  - Hardware Keystore Identity (TEE / StrongBox via AndroidKeyStore)     |
|  - Storage Access Framework (SAF ContentResolver & Scoped Storage)      |
|  - Foreground Data Sync Service (FOREGROUND_SERVICE_TYPE_DATA_SYNC)    |
|  - NSD, Wi-Fi Direct, & Wi-Fi Aware Discovery Engine                    |
|  - Action Center Notification Channels & Pairing SAS Dialog             |
+-------------------------------------------------------------------------+
```

### Critical Mobile Invariants:
1. **Java Runtime Baseline**: Strictly compiled against **Java 17 LTS** (`JavaVersion.VERSION_17`, Kotlin JVM target `17`). Android never depends on the desktop Java 25 runtime.
2. **Lifecycle & Power Constraints**: Android is not treated like a desktop daemon. `AndroidNodeStateMachine` maps system state dynamically:
   - `ACTIVE`: App is in foreground, or `PeerLinkForegroundService` is active during long transfers.
   - `BACKGROUND_CAPABLE`: App backgrounded, battery healthy (> 15% or charging), unmetered Wi-Fi. Opportunistic WorkManager sync allowed.
   - `OS_RESTRICTED`: Doze mode, Power Saver mode, battery <= 15% without charging, or metered cellular with Data Saver active. Background network work is halted.
   - `UNAVAILABLE`: Device network is offline or critical storage permission is denied.
3. **No Battery Optimization Exemption Required**: Long-running transfers run under a declared `dataSync` Foreground Service (`PeerLinkForegroundService`) with user-visible ongoing notifications, conforming to Android 14+ requirements without requiring battery optimization whitelist exemptions.
4. **Hardware KeyStore**: Cryptographic device identities are generated and stored inside the Android hardware security module (`AndroidKeyStore`, TEE/StrongBox) using ECDSA `secp256r1`.
5. **Scoped Storage / SAF**: Files are accessed via `SafStorageProvider` and `AndroidStorageAbstraction`, preventing arbitrary Linux filesystem path assumptions and adhering to Android's Storage Access Framework.

---

## 2. Directory Structure

- `app/flutter/`: Flutter mobile application (Dart presentation, `lib/`, `pubspec.yaml`, `pubspec.lock`, `test/`).
- `app/flutter/android/`: Android host project directly openable in Android Studio.
  - `app/src/main/AndroidManifest.xml`: Android manifest declaring `dataSync` foreground service, SAF permissions, and Sharesheet targets.
  - `app/src/main/kotlin/org/peerlink/app/`: Native Kotlin implementation (`bridge`, `keystore`, `storage`, `service`, `notification`, `discovery`, `worker`, `ui`).
  - `app/src/main/res/`: Android drawables, mipmaps, and themes.
  - `key.properties.example`: Release signing template.
  - `local.properties.example`: SDK path configuration template.
  - `gradlew.bat`: Windows Gradle wrapper script.
- `src/main/java/org/peerlink/core/android/`: Authoritative portable Android core contracts (`AndroidNodeStateMachine`, `AndroidStorageAbstraction`, `AndroidKeystoreManager`, `AndroidNodeFacade`).
- `src/test/java/org/peerlink/core/android/`: Native Android unit and lifecycle tests (`AndroidLifecycleAndStateTest`, `AndroidSafStorageTest`, `AndroidIdentityPersistenceTest`, `AndroidForegroundTransferTest`).
- `scripts/`: Project-local developer workflow scripts.

---

## 3. Developer Workflow Scripts (`android/scripts/`)

All scripts compute paths relative to `$PSScriptRoot`, return non-zero exit codes on error, and never delete user data or secrets.

| Script | Purpose |
|--------|---------|
| `scripts\check-prerequisites.ps1` | Inspects host for Java JDK 17/21, Android SDK, Android Studio, `adb`, `emulator`, Flutter, and Gradle. |
| `scripts\open-android-studio.ps1` | Opens `android\app\flutter\android` directly in Android Studio (`studio64.exe`). Supports `-DryRun`. |
| `scripts\list-devices.ps1` | Lists connected physical devices and running emulators via ADB, and configured AVDs via emulator CLI. |
| `scripts\build-android.ps1` | Compiles debug or release APK (`-Release`) or App Bundle (`-Bundle`). |
| `scripts\run-android.ps1` | Launches application on a specified device or emulator (`-DeviceId <id>`). |
| `scripts\run-flutter-tests.ps1` | Executes Flutter unit, widget, and IPC tests in `android\app\flutter\test`. |
| `scripts\run-gradle-tests.ps1` | Executes native Android JUnit 4/5 unit tests via Gradle (`gradlew.bat testDebugUnitTest`). |
| `scripts\collect-diagnostics.ps1` | Collects full Android environment diagnostics (APIs, build-tools, ADB devices, AVDs). |

---

## 4. Opening in Android Studio

To open the project in Android Studio:
1. Run `powershell -File android\scripts\open-android-studio.ps1` or open Android Studio and choose "Open" -> select `android\app\flutter\android`.
2. Ensure Android Studio has the **Kotlin** and **Android** plugins enabled.
3. If running the Flutter Dart frontend directly from Android Studio, install the **Flutter** and **Dart** plugins.
