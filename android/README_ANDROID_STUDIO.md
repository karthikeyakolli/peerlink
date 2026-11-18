# PeerLink Android Studio Edition — Quick IDE Guide

---

## Opening the Project in Android Studio

You can open this project in Android Studio in two ways:

### 1. From PowerShell / Command Prompt:
```powershell
.\scripts\open-android-studio.ps1
```

### 2. From Android Studio GUI:
- Launch Android Studio.
- Click **Open** (or **File > Open**).
- **For Flutter & Full App Development:** Select `peerlink-android-studio/`.
- **For Native Kotlin & Gradle Development:** Select `peerlink-android-studio/android/`.

---

## Pre-configured Shared Run Configurations (`.run/`)

Once opened in Android Studio, the following configurations appear in the toolbar:

1. **`PeerLink Android Debug`**
   - Launches the Flutter application on your emulator or physical Android phone.
   - Supports Dart Hot Reload (`r`), Hot Restart (`R`), and breakpoints in Dart UI widgets.

2. **`PeerLink Android Profile`**
   - Runs the application with DevTools profiling active for performance and memory inspection.

3. **`Flutter Unit & Widget Tests`**
   - Runs all unit, contract, and widget tests within the IDE test runner.

4. **`Native Android Unit Tests`**
   - Runs Gradle `testDebugUnitTest` for native Kotlin/Java components.

---

## Verifying Physical Isolation

To ensure that your Android build is 100% self-contained and does not pull in any source from parent or sibling trees:
```powershell
.\scripts\verify-isolation.ps1
```
This script audits every build file, import statement, and source set, returning exit code 0 when isolation is verified.
