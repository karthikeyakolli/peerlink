# PeerLink Android Studio Edition — Build Environment & Prerequisites

**Target:** `peerlink-android-studio`  
**Document Version:** 1.2.0 (Phase 25 Verified Baseline)

---

## 1. Verified Toolchain Matrix

| Tool / Runtime | Verified Version | Path / Location |
| :--- | :--- | :--- |
| **Flutter SDK** | 3.47.7 (Channel stable) | `c:\flutter` |
| **Dart SDK** | 3.13.5 | Bundled with Flutter SDK |
| **Android SDK** | 36.0.0 (API 36 / 37.0) | `C:\Users\OMEN\AppData\Local\Android\sdk` |
| **Build Tools** | 36.0.0 | `C:\Users\OMEN\AppData\Local\Android\sdk\build-tools\36.0.0` |
| **Gradle** | 9.3.1 | Via `gradlew.bat` (`gradle-9.3.1-all.zip`) |
| **Android Gradle Plugin** | 9.1.0 | Pinned in `settings.gradle.kts` |
| **Kotlin Gradle Plugin** | 2.4.0 | Pinned in `settings.gradle.kts` |
| **JDK (Gradle Runtime)** | OpenJDK 25.0.3 / JBR 21 | Android Studio Bundled JBR / OpenJDK |
| **Java Bytecode Target**| Java 17 (`VERSION_17`) | Configured in `build.gradle.kts` |
| **Minimum SDK** | API 26 (Android 8.0 Oreo) | Required for `java.time`, `java.util.Base64`, `java.nio.file` |
| **Compile / Target SDK**| API 36 / 37.0 | Android 14/15/16 modern runtime APIs |
| **Android Studio** | Android Studio Ladybug / Meerkat | `C:\Program Files\Android\Android Studio` |
| **Target Emulator** | Medium_Phone_API_37.0 (AVD) - 17 | Android 17 / API 37 system image |

---

## 2. Release Build & Artifact Metrics

### Release Compilation Commands:
```bash
# Split per-ABI APKs via Flutter CLI:
flutter build apk --release --split-per-abi

# Direct Gradle Release APK Assembly (ProGuard / R8 minified):
cd android && gradlew assembleRelease
```
**Exit Code:** `0` (Successful)

### Measured Artifact Sizes:
| Artifact Name | ABI Target | Size (Bytes) | Formatted Size | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `app-armeabi-v7a-release.apk` | 32-bit ARM | 17,472,989 | **16.66 MB** | Lean release binary for 32-bit legacy devices |
| `app-arm64-v8a-release.apk` | 64-bit ARM | 19,982,353 | **19.06 MB** | Standard modern mobile architecture |
| `app-x86_64-release.apk` | 64-bit x86 | 21,482,515 | **20.49 MB** | Emulator and Chromebook devices |
| `app-release.apk` (Gradle) | Universal Multi-ABI | 56,623,104 | **54.00 MB** | Full multi-ABI release APK with R8 minification & resource shrinking |
| `app-debug.apk` | Universal Multi-ABI | 153,777,774 | **146.65 MB** | Universal debug build bundling all 4 ABIs with JIT and symbols |

### Debug APK vs Release APK Size Analysis:
- The reported **146.65 MB** debug APK is an unstripped, universal fat binary containing JIT engine (`libflutter.so`) and debug symbols for all 4 architectures simultaneously, alongside developer service assets.
- In contrast, release mode splits ABIs, strips unneeded symbols, performs Dart AOT compilation, runs ProGuard/R8 dead code elimination, and tree-shakes fonts (reducing MaterialIcons by 99.1% from 1.64 MB to 14.76 KB).
- Per-ABI release APKs are approximately **87% to 89% smaller** than the universal debug APK.

---

## 3. Environment Variables

The project does **NOT** hardcode developer-specific absolute paths in any committed build files. It detects the standard Android and Java environment variables:

- `ANDROID_HOME` or `ANDROID_SDK_ROOT`: Points to your local Android SDK directory (e.g. `%LOCALAPPDATA%\Android\Sdk`).
- `JAVA_HOME`: Points to JDK 17+ (e.g. Android Studio JBR).
- `PATH`: Should include Flutter (`bin`) and Android SDK (`platform-tools`).

---

## 4. Verification Commands & Test Suites

1. **Physical Isolation Check (7/7 Checks):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\verify-isolation.ps1
   ```
2. **Flutter Static Analysis:**
   ```bash
   flutter analyze
   ```
3. **Flutter Contract & Widget Tests (12/12 Passing):**
   ```bash
   flutter test --reporter expanded
   ```
4. **Native Android JVM Unit Tests (23/23 Passing):**
   ```bash
   cd android && gradlew testDebugUnitTest
   ```
5. **Real Android OS Connected Instrumented Tests (15/15 Passing):**
   ```bash
   # Requires running emulator or connected device (e.g., Medium_Phone_API_37.0)
   cd android && gradlew connectedDebugAndroidTest
   ```
6. **Android Lint Report (0 Errors):**
   ```bash
   cd android && gradlew lintDebug
   ```
7. **Release APK Build:**
   ```bash
   cd android && gradlew assembleRelease
   ```

