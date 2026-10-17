# PeerLink — Android Studio Edition

**PeerLink** is a privacy-first, distributed personal data platform. It connects your devices directly over local Wi-Fi or end-to-end encrypted relays without cloud storage or third-party servers.

This directory (`peerlink-android-studio/`) is a **standalone, self-contained Android Studio project** engineered specifically for Android devices and emulators.

---

## Key Highlights

- **Physical Independence:** Contains physical copies of all required application source, contracts, adapters, and resources. Builds independently without importing source from external platform folders or parent trees.
- **Android Compatibility:** 100% free of desktop Java APIs (`java.net.http`, `java.lang.management`, `System.Logger`). Uses SLF4J / Android `Log`, Android KeyStore, and Scoped Storage (SAF).
- **Dual Development Entry Points:**
  - **Flutter Entry Point:** Open `peerlink-android-studio/` in Android Studio for Dart UI editing, Hot Reload, and cross-platform widget development.
  - **Native Android Entry Point:** Open `peerlink-android-studio/android/` in Android Studio for native Kotlin/Java editing, Gradle synchronization, and native profiling.
- **One-Click Windows PowerShell Workflows:**
  - `.\scripts\doctor.ps1` — Validates all toolchains (Flutter, Dart, JDK, Android SDK/NDK, Gradle, ADB).
  - `.\scripts\setup.ps1` — Resolves local dependencies and generates local configurations.
  - `.\scripts\analyze.ps1` — Runs formatting and static analysis checks.
  - `.\scripts\test.ps1` — Runs all Dart and native Android tests.
  - `.\scripts\build-debug-apk.ps1` — Assembles the standalone debug APK (`build/app/outputs/flutter-apk/app-debug.apk`).
  - `.\scripts\run-device.ps1` — Launches PeerLink on a connected device or emulator.
  - `.\scripts\open-android-studio.ps1` — Launches Android Studio targeting this workspace.
  - `.\scripts\verify-isolation.ps1` — Verifies zero source leakage outside this folder.

---

## Quick Start

```powershell
# 1. Check prerequisites
.\scripts\doctor.ps1

# 2. Resolve dependencies
.\scripts\setup.ps1

# 3. Verify static analysis and tests
.\scripts\analyze.ps1
.\scripts\test.ps1

# 4. Build Debug APK
.\scripts\build-debug-apk.ps1
```

For detailed IDE setup and debugging instructions, see [README_ANDROID_STUDIO.md](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/peerlink-android-studio/README_ANDROID_STUDIO.md) and [docs/ANDROID-STUDIO-WORKFLOW.md](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/peerlink-android-studio/docs/ANDROID-STUDIO-WORKFLOW.md).
