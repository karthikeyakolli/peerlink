# PeerLink Release Engineering: Reproducible Build Guide

## 1. Overview & Architectural Principles

PeerLink produces reproducible, hardened, and installable release packages across supported platforms while preserving the strict architectural boundaries established in Phase 00–19:
- **Zero Unbundled Prerequisites:** The Java Local Node is packaged as a standalone shaded fat executable JAR (`peerlink-desktop-node.jar`) capable of executing alongside an embedded lightweight Java 17/21 JRE without assuming Java is installed on the target machine.
- **Strict Protocol Purity:** Wire interactions utilize `peerlink.v1` protocol buffers compiled with pinned protoc / gRPC generators.
- **Non-Authoritative Cloud:** Release configurations separate Supabase keys, enforcing that service-role keys and developer credentials are NEVER packaged into client binaries.

---

## 2. Toolchain & Pinned Versions

Every release build MUST be performed with the following verified baseline toolchain:

| Component | Pinned Version | Purpose / Scope |
| :--- | :--- | :--- |
| **JDK** | OpenJDK 17.0.10+ (or Eclipse Temurin 21.0.2+) | Compiles `protocol`, `core`, and `desktop-node` modules |
| **Maven** | 3.9.6 | Reproducible build orchestration and dependency resolution |
| **Kotlin** | 1.9.24 | Protocol and core language runtime |
| **Protobuf** | 4.29.3 (`protoc` 3.25.5 / gRPC 1.69.0) | Cross-platform binary wire serialization |
| **SQLite JDBC** | 3.47.2.0 | Bundled native binaries for Windows (`.dll`), Linux (`.so`), macOS (`.dylib`) |
| **Flutter SDK** | 3.24.x (Dart 3.5.x) | UI presentation layer across Desktop & Mobile |
| **Gradle** | 8.7 (AGP 8.4.x) | Android APK / AAB compilation |
| **Android SDK**| Compile API 34, Min API 26 (Android 8.0 Oreo) | Mobile platform baseline |

---

## 3. Monorepo Build Commands

### Clean & Compile JVM Monorepo
```bash
# Set Maven on PATH if required
export PATH="/path/to/maven/bin:$PATH"

# Run complete clean, test validation, and shading
mvn clean package -DskipTests=false
```
*Verification:*
- All 251 automated tests across `protocol` (15), `core` (204), and `desktop-node` (32) must pass.
- Shaded executable jar is generated at:
  `desktop-node/target/peerlink-desktop-node-0.1.0-SNAPSHOT-all.jar` (~39.2 MB).

### Build Flutter UI (Desktop & Mobile)
```bash
cd ui

# Verify Flutter environment
flutter doctor -v

# Clean and resolve pinned dependencies
flutter clean
flutter pub get

# Build Windows Release Desktop
flutter build windows --release

# Build Linux Release Desktop
flutter build linux --release

# Build macOS Release Desktop
flutter build macos --release

# Build Android Release Bundle / APK
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

---

## 4. Desktop Packaging Layout

PeerLink Desktop combines the compiled Flutter shell and the Java Local Node into a self-contained application tree:

```
peerlink-<version>/
├── bin/
│   ├── peerlink.exe (or peerlink binary on Linux/macOS)
│   ├── peerlink-node.bat (Windows daemon supervisor)
│   └── peerlink-node.sh (Unix daemon supervisor)
├── lib/
│   └── peerlink-desktop-node.jar (Shaded fat JAR including all runtime deps)
├── runtime/
│   └── bin/java[.exe] (Bundled JRE 17/21 created via jlink)
├── config/
│   └── application.properties (Production defaults: ports, log retention)
└── manifest.json (Release metadata & SHA-256 integrity hash)
```

### JRE Minification via `jlink`
To package the local runtime without bloated JDK overhead:
```bash
jlink \
  --add-modules java.base,java.sql,java.logging,java.desktop,java.management,java.naming,java.net.http,jdk.unsupported \
  --strip-debug \
  --no-man-pages \
  --no-header-files \
  --compress=2 \
  --output dist/windows/peerlink-1.0.0/runtime
```

---

## 5. Automated Packaging Scripts

PeerLink provides automated scripts to produce clean release bundles:

- **Windows:** `scripts/package-desktop.ps1 -TargetPlatform windows -Version 1.0.0`
- **Linux:** `bash scripts/package-desktop.sh --platform linux --version 1.0.0`
- **macOS:** `bash scripts/package-desktop.sh --platform macos --version 1.0.0`

Every packaging run automatically computes SHA-256 hashes of all runtime executables and writes a canonical `manifest.json`.
