# PeerLink — macOS Standalone Platform Project

Self-contained macOS platform implementation for PeerLink. This project physically owns its Java Local Node daemon, macOS-specific native integrations, Flutter desktop UI, native Xcode workspace, protocol bindings, test suites, and build scripts.

In accordance with PeerLink architecture governance, this directory contains **zero source dependencies or imports** from `windows/`, `android/`, `linux/`, or legacy root application modules.

---

## 1. Project Directory Layout

```
macos/
├── pom.xml                                  # macOS Local Node Maven build specification (Java 21)
├── README.md                                # Platform documentation, prerequisites & workflow guide
├── src/
│   ├── main/
│   │   ├── java/org/peerlink/
│   │   │   ├── core/                        # Portable core, transfer engine, identity, journal
│   │   │   │   └── platform/
│   │   │   │       ├── PlatformIntegrationService.java # Instantiates MacPlatformAdapter directly
│   │   │   │       └── macos/
│   │   │   │           └── MacPlatformAdapter.java     # Concrete macOS adapter
│   │   │   ├── desktop/runtime/             # Desktop Local Node daemon & gRPC IPC service
│   │   │   ├── macos/
│   │   │   │   ├── filesystem/
│   │   │   │   │   └── MacApfsFileProvider.java        # APFS Unicode NFC normalization & POSIX perms
│   │   │   │   └── os/
│   │   │   │       ├── keychain/
│   │   │   │       │   └── MacKeychainStore.java       # Apple Keychain Services & AES-256-GCM fallback
│   │   │   │       ├── power/
│   │   │   │       │   └── MacPowerManager.java        # caffeinate transfer sleep lock
│   │   │   │       ├── finder/
│   │   │   │       │   └── MacFinderIntegration.java   # Finder reveal, ~/Library paths
│   │   │   │       └── notifications/
│   │   │   │           └── MacNotificationManager.java # Desktop notification dispatcher (osascript)
│   │   │   └── protocol/                    # Generated Protobuf & gRPC stubs
│   │   └── resources/                       # Logging & daemon configuration
│   └── test/
│       └── java/org/peerlink/               # JUnit 5 unit and integration tests
├── app/
│   └── flutter/                             # Standalone Flutter macOS desktop project
│       ├── pubspec.yaml                     # Pinned Flutter dependencies
│       ├── pubspec.lock                     # Locked dependency tree
│       ├── lib/                             # Flutter UI widgets, state management, gRPC client
│       ├── macos/                           # Native Xcode Workspace & Runner project
│       │   ├── Runner.xcworkspace           # Primary Xcode workspace
│       │   ├── Runner.xcodeproj             # Xcode project file
│       │   ├── Runner/                      # AppDelegate.swift, MainFlutterWindow.swift, Info.plist
│       │   └── Flutter/                     # Flutter xcconfigs & GeneratedPluginRegistrant.swift
│       ├── assets/                          # Application icons and bundled assets
│       └── test/                            # Flutter widget and unit tests
└── scripts/
    ├── check-prerequisites.sh               # Inspects macOS Darwin, Xcode, CocoaPods, Java, and Flutter
    ├── check-prerequisites.ps1              # Cross-platform prerequisite inspector
    ├── open-xcode.sh                        # Opens native Runner.xcworkspace in Xcode
    ├── open-xcode.ps1                       # Cross-platform Xcode launcher/path resolver
    ├── build-macos.sh                       # Compiles Local Node jar and Flutter macOS .app bundle
    ├── build-macos.ps1                      # Cross-platform build script
    ├── run-macos.sh                         # Launches Local Node daemon and Flutter macOS desktop UI
    ├── run-macos.ps1                        # Cross-platform launcher
    ├── run-tests.sh                         # Executes Local Node JUnit tests and Flutter tests
    ├── run-tests.ps1                        # Cross-platform test runner
    ├── collect-diagnostics.sh               # Collects Darwin kernel, SIP, Gatekeeper, Xcode, Keychain, logs
    ├── collect-diagnostics.ps1              # Cross-platform diagnostics collector
    ├── package-macos.sh                     # Assembles relocatable PeerLink.app bundle archive (.tar.gz)
    └── package-macos.ps1                    # Cross-platform release packaging script
```

---

## 2. macOS-Specific Native Subsystems

### APFS Filesystem Handling (`MacApfsFileProvider`)
- **Unicode NFC Normalization**: Normalizes all incoming and local paths to Unicode Normalization Form C (`Normalizer.Form.NFC`), ensuring deterministic path matching on Apple File System (APFS).
- **Forbidden Character Rejection**: Explicitly rejects colons (`:`) in filenames—the historical Mac OS separator and invalid POSIX filename character—along with embedded NUL bytes (`\0`).
- **Path Traversal & Boundary Safety**: Enforces strict containment within designated root sandboxes, blocking any `..` traversal escapes.
- **Symlink Cycle Detection**: Traverses links with cycle detection (`FileSystemLoopException`), preventing denial-of-service recursion attacks.
- **Strict POSIX Permissions**: Restricts sensitive data directories to `0700` (`rwx------`) and sensitive files (credentials, keys, journals) to `0600` (`rw-------`).

### Apple Keychain Credential Storage (`MacKeychainStore`)
- **Apple Keychain Services Integration**: Direct interface to macOS Keychain Services via `/usr/bin/security` CLI (`add-generic-password`, `find-generic-password`, `delete-generic-password`).
- **Local Hardened Fallback**: When Keychain Services are unavailable (e.g. headless daemon or test runners without user session keychain), stores credentials in AES-256-GCM format salted with hardware/user seed and protected by `0600` file permissions.

### Power & Lifecycle Management (`MacPowerManager`)
- **Sleep Prevention via `caffeinate`**: Spawns `/usr/bin/caffeinate -i -s -m` to prevent system idle and disk sleep during active transfers.
- **Reference-Counted Lock Management**: Multiple concurrent transfers increment the lock counter; caffeinate is cleanly terminated only when all transfers finish or fail.

### Finder & Desktop Integration (`MacFinderIntegration`)
- **Standard Library Paths**:
  - Application Support: `~/Library/Application Support/PeerLink`
  - Caches: `~/Library/Caches/PeerLink`
  - Preferences: `~/Library/Preferences/com.peerlink.desktop.plist`
  - Logs: `~/Library/Logs/PeerLink`
- **Finder Reveal**: Highlights staged or completed files using `/usr/bin/open -R <path>`.
- **Default Application Opening**: Opens files securely using `/usr/bin/open <path>`.

### Desktop Notifications (`MacNotificationManager`)
- Dispatches user notifications via AppleScript (`/usr/bin/osascript -e 'display notification ... with title "PeerLink"'`).

---

## 3. Prerequisites & Toolchains

### Minimum Verified Baseline
| Toolchain / Library | Minimum Version | Purpose |
|---------------------|-----------------|---------|
| **macOS**           | 13.0+ (Ventura) | Modern Darwin kernel, APFS, and Swift concurrency |
| **Xcode**           | 14.0+           | Apple developer toolchain, compilers, and SDKs |
| **CocoaPods**       | 1.12+           | iOS/macOS plugin dependency manager (`pod`) |
| **Java JDK**        | 21 LTS or 25    | Compiles and runs the authoritative Local Node daemon |
| **Apache Maven**    | 3.9.0+          | Builds `macos/pom.xml` |
| **Flutter SDK**     | 3.24.0+ (stable)| Builds and runs the macOS Cocoa desktop UI |
| **Git**             | 2.30.0+         | Source control and Flutter dependencies |

### Installation via Homebrew (macOS)
```bash
# Install Homebrew if not present:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required toolchains:
brew install openjdk@21 maven cocoapods git
sudo xcode-select --install
```

---

## 4. Commands & Workflow

All commands should be executed from the `macos/` directory or project root.

### 1. Check Prerequisites
Inspects the environment for Darwin kernel, Xcode, CocoaPods, Java, Flutter, and Keychain:
```bash
# On macOS:
bash scripts/check-prerequisites.sh

# On Windows/Linux host:
.\scripts\check-prerequisites.ps1
```

### 2. Open Xcode Workspace
Opens the genuine native Xcode workspace for debugging native Swift code, signing, and entitlements:
```bash
# On macOS:
bash scripts/open-xcode.sh

# On Windows/Linux host (resolves paths and reports location):
.\scripts\open-xcode.ps1
```

### 3. Build Project
Compiles the Java Local Node daemon and Flutter macOS desktop application:
```bash
# On macOS:
bash scripts/build-macos.sh

# Compile Local Node only:
bash scripts/build-macos.sh --skip-ui

# On Windows/Linux host (compiles Local Node; marks native macOS UI BLOCKED):
.\scripts\build-macos.ps1
```

### 4. Run Application
Launches the Local Node daemon and Flutter desktop application:
```bash
# On macOS:
bash scripts/run-macos.sh

# Run daemon only:
bash scripts/run-macos.sh --node-only --port 50051

# On Windows/Linux host:
.\scripts\run-macos.ps1
```

### 5. Run Test Suite
Executes unit and integration test suites:
```bash
# On macOS:
bash scripts/run-tests.sh

# On Windows/Linux host:
.\scripts\run-tests.ps1
```

### 6. Collect Diagnostics
Collects Darwin kernel, SIP, Gatekeeper, Xcode tools, Keychain status, ports, and logs:
```bash
# On macOS:
bash scripts/collect-diagnostics.sh -o diagnostics.log

# On Windows/Linux host:
.\scripts\collect-diagnostics.ps1 -OutputFile diagnostics.log
```

### 7. Package Release
Packages a relocatable distribution archive (`peerlink-macos-<version>.tar.gz`) containing `PeerLink.app`, executable launchers, configuration, and SHA-256 signatures:
```bash
# On macOS:
bash scripts/package-macos.sh --version 1.0.0-rc1

# On Windows/Linux host:
.\scripts\package-macos.ps1 -Version 1.0.0-rc1
```

---

## 5. Security & Isolation Invariants

1. **Local Node Authority**: The Flutter UI acts purely as a presentation layer communicating over authenticated gRPC IPC on `127.0.0.1:50051`.
2. **Identity Persistence**: The device identity key is never stored in plain text configuration files. It is secured via `MacKeychainStore` in the macOS Keychain.
3. **Safe File Staging**: Incoming file transfers are staged in a dedicated quarantine directory before atomic move to destination upon SHA-256 verification.
4. **Zero Cross-Platform Bleed**: The macOS project physically owns all its code; it never links or imports code from other platform directories.
