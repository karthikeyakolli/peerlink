# PeerLink Android Studio Edition — Android Studio Workflow Guide

This document describes how to open, build, run, and debug the PeerLink Android Studio Edition.

---

## 1. Two Distinct Development Entry Points

Depending on what you are developing, Android Studio provides two distinct entry points:

### Option A: Flutter Application Development (Recommended for Full App)
- **Directory to Open:** `peerlink-android-studio/`
- **What It Opens:** The complete Flutter cross-platform project with Dart source code, Material 3 UI widgets, platform channel bindings, and the Android host project.
- **Features in Android Studio:**
  - Full Flutter Hot Reload & Hot Restart (`r` / `R`).
  - Dart code completion, formatting, and analysis.
  - Flutter Widget Inspector and DevTools.
  - Execution via the pre-configured `.run/PeerLink_Android_Debug.run.xml` run configuration.
  - Setting breakpoints in Dart files (`lib/**/*.dart`).

### Option B: Native Android Development (Kotlin / Java / NDK / Gradle)
- **Directory to Open:** `peerlink-android-studio/android/`
- **What It Opens:** The pure native Android Gradle project (`settings.gradle.kts`, `app/build.gradle.kts`, `src/main/kotlin`, `src/main/java`).
- **Features in Android Studio:**
  - Gradle Project Sync and Dependency Tree inspection.
  - Native Kotlin / Java debugging with line breakpoints in Android Services, KeyStore manager, SAF provider, and discovery adapters.
  - Android Profiler (CPU, Memory, Network, Energy).
  - Native JUnit / Robolectric / Instrumentation tests.
  - Logcat filtering by package `org.peerlink.peerlink`.

---

## 2. Opening in Android Studio via Script

Run the helper script from PowerShell:
```powershell
.\scripts\open-android-studio.ps1
```
This script will locate your installed Android Studio (checking `C:\Program Files\Android\Android Studio\bin\studio64.exe` or PATH) and launch it targeting `peerlink-android-studio/`.

---

## 3. Run & Debug Configurations

The workspace includes pre-configured, portable shared run configurations in `.run/`:
- **`PeerLink Android Debug`**: Launches Flutter application on the selected connected device or emulator in debug mode.
- **`PeerLink Android Profile`**: Runs the app in profile mode with DevTools profiling enabled.
- **`Flutter Unit & Widget Tests`**: Executes `flutter test` across all unit and widget tests.
- **`Native Android Unit Tests`**: Runs Gradle `testDebugUnitTest` on native Kotlin/Java components.

---

## 4. Debugging Dual-Stack Code (Dart + Kotlin)

- **To debug Dart code:** Start the app via Flutter Run / Debug from `peerlink-android-studio/`. Breakpoints in Dart files will trigger the Dart VM debugger.
- **To debug Native Android code simultaneously:** While the Flutter app is running, click **Run > Attach Debugger to Android Process** in Android Studio, select `org.peerlink.peerlink`, and choose **Java / Dual**. Breakpoints in `MainActivity.kt`, `AndroidPigeonBridge.kt`, or `SafStorageProvider.kt` will now hit.
