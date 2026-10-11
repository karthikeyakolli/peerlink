# PeerLink — Linux Standalone Platform Project

Self-contained Linux platform implementation for PeerLink. This project physically owns its Java Local Node daemon, Linux-specific native integrations, Flutter desktop UI, protocol bindings, test suites, and build scripts.

In accordance with PeerLink architecture governance, this directory contains **zero source dependencies or imports** from `windows/`, `android/`, `macos/`, or legacy root application modules.

---

## 1. Project Directory Layout

```
linux/
├── pom.xml                                  # Linux Local Node Maven build specification (Java 21)
├── README.md                                # Platform documentation and workflow guide
├── src/
│   ├── main/
│   │   ├── java/org/peerlink/
│   │   │   ├── core/                        # Portable core, transfer engine, identity, journal
│   │   │   │   └── platform/
│   │   │   │       ├── PlatformIntegrationService.java # Instantiates LinuxPlatformAdapter directly
│   │   │   │       └── LinuxPlatformAdapter.java       # Concrete Linux adapter
│   │   │   ├── desktop/runtime/             # Desktop daemon entry points & gRPC IPC service
│   │   │   ├── linux/
│   │   │   │   ├── filesystem/
│   │   │   │   │   └── LinuxPosixFileProvider.java     # POSIX path validation & permission enforcement
│   │   │   │   └── os/
│   │   │   │       ├── secrets/
│   │   │   │       │   └── LinuxSecretStore.java       # Freedesktop Secret Service & AES-256-GCM fallback
│   │   │   │       ├── xdg/
│   │   │   │       │   └── XdgDesktopIntegration.java  # XDG Base Dirs, .desktop entry, D-Bus show items
│   │   │   │       ├── power/
│   │   │   │       │   └── LinuxPowerManager.java      # systemd-inhibit transfer sleep lock
│   │   │   │       └── notifications/
│   │   │   │           └── LinuxNotificationManager.java # Desktop notification dispatcher
│   │   │   └── protocol/                    # Generated Protobuf & gRPC stubs
│   │   └── resources/                       # Logging & daemon configuration
│   └── test/
│       └── java/org/peerlink/               # JUnit 5 unit and integration tests
├── app/
│   └── flutter/                             # Standalone Flutter Linux desktop project
│       ├── pubspec.yaml                     # Pinned Flutter dependencies
│       ├── pubspec.lock                     # Locked dependency tree
│       ├── lib/                             # Flutter UI widgets, state, and gRPC client
│       ├── linux/                           # Native C++ GTK+ runner (CMakeLists.txt, main.cc, my_application.cc)
│       ├── assets/                          # Application icons and bundled assets
│       └── test/                            # Flutter widget and unit tests
└── scripts/
    ├── check-prerequisites.sh               # Inspects Linux compiler, library, and runtime dependencies
    ├── check-prerequisites.ps1              # Cross-platform prerequisite inspector
    ├── build-linux.sh                       # Compiles Local Node jar and Flutter Linux desktop bundle
    ├── build-linux.ps1                      # Cross-platform build script
    ├── run-linux.sh                         # Launches Local Node daemon and Flutter Linux desktop UI
    ├── run-linux.ps1                        # Cross-platform launcher
    ├── run-tests.sh                         # Executes Local Node JUnit tests and Flutter tests
    ├── run-tests.ps1                        # Cross-platform test runner
    ├── collect-diagnostics.sh               # Collects kernel, glibc, D-Bus, secret store, ports, and logs
    ├── collect-diagnostics.ps1              # Cross-platform diagnostics collector
    ├── package-linux.sh                     # Assembles relocatable distribution tarball (.tar.gz)
    └── package-linux.ps1                    # Cross-platform release packaging script
```

---

## 2. Linux-Specific Native Subsystems

### POSIX Filesystem Handling (`LinuxPosixFileProvider`)
- **NUL-byte & Path Traversal Rejection**: Rejects any path component containing embedded NUL bytes (`\0`) or path traversal attempts (`..`).
- **Symlink Cycle Detection**: Traverses paths with cycle detection (`java.nio.file.FileSystemLoopException`), preventing denial-of-service from recursive link loops.
- **Strict POSIX Permissions**: Restricts sensitive data directories to `0700` (`rwx------`) and sensitive files (credentials, keys, journals) to `0600` (`rw-------`) via `PosixFilePermissions`. Falls back to read/write/executable attributes on non-POSIX filesystems.

### Credential Protection (`LinuxSecretStore`)
- **Freedesktop Secret Service API**: Interfaces with standard Linux keyring daemons (GNOME Keyring, KeePassXC, KWallet) via `secret-tool` CLI.
- **Local Hardened Fallback**: When Secret Service is absent, stores credentials in AES-256-GCM encrypted format with PBKDF2 key derivation salted with `/etc/machine-id` (or user salt fallback). Storage files are strictly permissioned `0600`.

### Desktop Integration (`XdgDesktopIntegration`)
- **XDG Base Directory Compliance**:
  - Configuration: `$XDG_CONFIG_HOME/peerlink` (default `~/.config/peerlink`)
  - Data & Identity: `$XDG_DATA_HOME/peerlink` (default `~/.local/share/peerlink`)
  - Cache: `$XDG_CACHE_HOME/peerlink` (default `~/.cache/peerlink`)
  - Runtime Sockets: `$XDG_RUNTIME_DIR/peerlink` (default `/run/user/<uid>/peerlink`)
- **Desktop Entry (`peerlink.desktop`)**: Automatic generation and installation to `$XDG_DATA_HOME/applications/peerlink.desktop`.
- **D-Bus File Manager Integration**: Reveals staged or received files using standard D-Bus interface `org.freedesktop.FileManager1.ShowItems`, falling back to `xdg-open`.

### Power & Lifecycle Management (`LinuxPowerManager`)
- **Sleep & Suspend Lock**: Uses `systemd-inhibit --what=sleep:shutdown:idle` to acquire a process lock during active file transfers.
- **Reference-Counted Lock Management**: Multiple concurrent transfers increment the lock counter; the systemd inhibition is cleanly released only when all active transfers complete or fail.

### Desktop Notifications (`LinuxNotificationManager`)
- Dispatches user notifications for transfer requests, completions, and security alerts via `notify-send` / Freedesktop notification specification.

---

## 3. Prerequisites & Toolchains

### Minimum Verified Baseline
| Toolchain / Library | Minimum Version | Purpose |
|---------------------|-----------------|---------|
| **Linux Kernel**    | 5.15+           | Required for modern epoll, inotify, and io_uring features |
| **Glibc**           | 2.31+           | C runtime baseline |
| **Java JDK**        | 21 LTS or 25    | Compiles and runs the authoritative Local Node daemon |
| **Apache Maven**    | 3.9.0+          | Builds `linux/pom.xml` |
| **Flutter SDK**     | 3.24.0+ (stable)| Builds and runs the Linux GTK+ desktop UI |
| **CMake**           | 3.20.0+         | Builds Flutter native Linux C++ runner |
| **Ninja**           | 1.10+           | Fast build tool for CMake |
| **GTK+ 3.0**        | 3.24+           | Linux desktop UI rendering toolkit (`libgtk-3-dev`) |
| **GLib 2.0**        | 2.64+           | Core application event loop (`libglib2.0-dev`) |
| **Secret Service**  | `libsecret-1`   | Hardware-backed secret and identity key storage |
| **pkg-config**      | 0.29+           | Library detection for CMake |

### Linux Package Installation Commands

**Ubuntu / Debian:**
```bash
sudo apt update
sudo apt install -y openjdk-21-jdk maven \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev libglib2.0-dev libsecret-1-dev libsecret-tools \
    libsystemd-dev dbus-x11
```

**Fedora:**
```bash
sudo dnf install -y java-21-openjdk-devel maven \
    clang cmake ninja-build pkgconf-pkg-config \
    gtk3-devel glib2-devel libsecret-devel \
    systemd-devel
```

**Arch Linux:**
```bash
sudo pacman -S jdk21-openjdk maven \
    clang cmake ninja pkgconf \
    gtk3 glib2 libsecret \
    systemd
```

---

## 4. Commands & Workflow

All commands should be executed from the `linux/` directory or project root.

### 1. Check Prerequisites
Inspects the environment for compilers, libraries, Java, Flutter, and D-Bus services:
```bash
# On Linux / WSL:
bash scripts/check-prerequisites.sh

# On Windows host:
.\scripts\check-prerequisites.ps1
```

### 2. Build Project
Compiles the Java Local Node daemon and Flutter Linux desktop bundle:
```bash
# On Linux / WSL:
bash scripts/build-linux.sh

# Compile Local Node only:
bash scripts/build-linux.sh --skip-ui

# On Windows host (compiles Local Node; delegates UI build to WSL if available):
.\scripts\build-linux.ps1
```

### 3. Run Application
Launches the Local Node daemon and Flutter desktop application:
```bash
# On Linux / WSL:
bash scripts/run-linux.sh

# Run daemon only:
bash scripts/run-linux.sh --node-only --port 50051

# On Windows host:
.\scripts\run-linux.ps1
```

### 4. Run Test Suite
Executes unit and integration test suites:
```bash
# On Linux / WSL:
bash scripts/run-tests.sh

# On Windows host:
.\scripts\run-tests.ps1
```

### 5. Collect Diagnostics
Collects system state, kernel release, glibc version, network ports, and Local Node logs:
```bash
# On Linux / WSL:
bash scripts/collect-diagnostics.sh -o diagnostics.log

# On Windows host:
.\scripts\collect-diagnostics.ps1 -OutputFile diagnostics.log
```

### 6. Package Release
Packages a relocatable distribution archive (`peerlink-linux-<version>.tar.gz`) with executable launchers, desktop entry, configuration, and SHA-256 signatures:
```bash
# On Linux / WSL:
bash scripts/package-linux.sh --version 1.0.0-rc1

# On Windows host:
.\scripts\package-linux.ps1 -Version 1.0.0-rc1
```

---

## 5. Security & Isolation Invariants

1. **Local Node Authority**: The Flutter UI acts purely as a presentation layer communicating over authenticated gRPC IPC on `127.0.0.1:50051`.
2. **Identity Persistence**: The device identity key is never stored in plain text configuration files. It is secured via `LinuxSecretStore` and keyed to the device's hardware identity.
3. **Safe File Staging**: Incoming file transfers are staged in a dedicated quarantine directory before atomic move to destination upon SHA-256 verification.
4. **Zero Cross-Platform Bleed**: The Linux project physically owns all its code; it never links or imports code from other platform directories.
