# PeerLink Platform-Separated Architecture Specification

**Document**: `docs/architecture/PLATFORM-SEPARATED-REPOSITORY.md`  
**Version**: 1.0.0  
**Phase**: Repository Architecture Transformation  
**Author**: PeerLink Repository Architect  
**Status**: APPROVED & MANDATORY  

---

## 1. Architectural Vision & Core Mandate

PeerLink is transitioning from a traditional monorepo with cross-imported common libraries to a **fully separated, self-contained project structure for each operating system**.

### The Physical Duplication Mandate
To ensure that each platform project can be developed, tested, packaged, and maintained autonomously:
* **Windows** (`windows/`) contains its own complete, self-contained implementation.
* **Linux** (`linux/`) contains its own complete, self-contained implementation.
* **macOS** (`macos/`) contains its own complete, self-contained implementation.
* **Android** (`android/`) contains its own complete, self-contained implementation.

**CRITICAL INVARIANT**:
> **There is NO single runtime shared-code directory that every OS directly imports from.**  
> **Platform projects MUST NOT use symlinks, directory junctions, filesystem mounts, or runtime path redirection to reference external shared source.**  
> Common modules physically reside inside each platform directory.

---

## 2. Target Repository Topography

```
PeerLink/
│
├── windows/                         # Windows Self-Contained Project
│   ├── app/                         # Windows Flutter Desktop Application
│   │   └── flutter/                 # Duplicated Flutter source & Windows runner
│   ├── core/                        # Duplicated Core domain & portable logic
│   ├── protocol/                    # Duplicated Protobuf definitions & generated Java/Dart
│   ├── networking/                  # P2P QUIC, TCP/TLS, & Windows socket networking
│   ├── operations/                  # Causal operation journal & execution
│   ├── transfer/                    # Resilient chunk streaming & checkpointing
│   ├── sync/                        # Folder synchronization & vector clocks
│   ├── backup/                      # Archive creation & restoration engine
│   ├── access/                      # Remote access & access control
│   ├── sharing/                     # Direct link & collaborative sharing
│   ├── workspace/                   # Workspace boundaries & isolation
│   ├── clipboard/                   # Windows Win32 clipboard bridge
│   ├── compatibility/               # Windows MAX_PATH & filesystem rules
│   ├── security/                    # Authenticator & TLS manager
│   ├── recovery/                    # Crash recovery & session resumption
│   ├── diagnostics/                 # Telemetry & health probes
│   ├── filesystem/                  # Windows NTFS watcher & path validator
│   ├── os/                          # Windows Native Integrations:
│   │   ├── explorer/                # Shell context menu integration
│   │   ├── share/                   # Windows Share Contract
│   │   ├── notifications/           # Windows Action Center toasts
│   │   ├── credential-store/        # Windows Credential Manager / DPAPI
│   │   ├── firewall/                # Windows Firewall rule coordinator
│   │   └── power/                   # Windows power & sleep management
│   ├── supabase/                    # Supabase client adapter
│   ├── tests/                       # Windows standalone test suite
│   ├── scripts/                     # Windows build, run, and test scripts
│   └── README.md                    # Windows Developer Guide
│
├── linux/                           # Linux Self-Contained Project
│   ├── app/                         # Linux Flutter Desktop Application
│   │   └── flutter/                 # Duplicated Flutter source & Linux runner
│   ├── core/                        # Duplicated Core domain
│   ├── protocol/                    # Duplicated Protobuf definitions & generated code
│   ├── networking/                  # Linux epoll Netty transport & sockets
│   ├── operations/                  # Operations engine
│   ├── transfer/                    # Transfer engine
│   ├── sync/                        # Sync engine
│   ├── backup/                      # Backup engine
│   ├── access/                      # Access engine
│   ├── sharing/                     # Sharing engine
│   ├── workspace/                   # Workspace manager
│   ├── clipboard/                   # Linux X11/Wayland clipboard bridge
│   ├── compatibility/               # Linux POSIX filesystem rules
│   ├── security/                    # Security subsystem
│   ├── recovery/                    # Recovery subsystem
│   ├── diagnostics/                 # Diagnostics subsystem
│   ├── filesystem/                  # Linux inotify filesystem watcher
│   ├── os/                          # Linux Native Integrations:
│   │   ├── xdg/                     # XDG Base Directory & Desktop Entries
│   │   ├── dbus/                    # D-Bus IPC & system bus service
│   │   ├── notifications/           # Freedesktop notification daemon
│   │   ├── secret-store/            # Secret Service API / libsecret / KWallet
│   │   └── power/                   # systemd-logind power inhibition
│   ├── supabase/                    # Supabase client adapter
│   ├── tests/                       # Linux standalone test suite
│   ├── scripts/                     # Linux build, run, and test scripts
│   └── README.md                    # Linux Developer Guide
│
├── macos/                           # macOS Self-Contained Project
│   ├── app/                         # macOS Flutter Desktop Application
│   │   └── flutter/                 # Duplicated Flutter source & macOS runner
│   ├── core/                        # Duplicated Core domain
│   ├── protocol/                    # Duplicated Protobuf definitions & generated code
│   ├── networking/                  # macOS kqueue Netty transport
│   ├── operations/                  # Operations engine
│   ├── transfer/                    # Transfer engine
│   ├── sync/                        # Sync engine
│   ├── backup/                      # Backup engine
│   ├── access/                      # Access engine
│   ├── sharing/                     # Sharing engine
│   ├── workspace/                   # Workspace manager
│   ├── clipboard/                   # macOS NSPasteboard bridge
│   ├── compatibility/               # macOS APFS filesystem rules & normalization
│   ├── security/                    # Security subsystem
│   ├── recovery/                    # Recovery subsystem
│   ├── diagnostics/                 # Diagnostics subsystem
│   ├── filesystem/                  # macOS FSEvents filesystem watcher
│   ├── os/                          # macOS Native Integrations:
│   │   ├── finder/                  # Finder Sync Extension
│   │   ├── share/                   # macOS Share Sheet integration
│   │   ├── keychain/                # Apple Keychain Services wrapper
│   │   ├── file-provider/           # File Provider Extension
│   │   ├── notifications/           # NSUserNotificationCenter toasts
│   │   └── power/                   # IOKit IOPMAssertion power management
│   ├── supabase/                    # Supabase client adapter
│   ├── tests/                       # macOS standalone test suite
│   ├── scripts/                     # macOS build, run, and test scripts
│   └── README.md                    # macOS Developer Guide
│
├── android/                         # Android Self-Contained Project
│   ├── app/                         # Android Flutter Mobile Application
│   │   └── flutter/                 # Duplicated Flutter source & Android runner
│   ├── core/                        # Duplicated Core domain (Android API baseline)
│   ├── protocol/                    # Duplicated Protobuf definitions & generated code
│   ├── networking/                  # Android NetworkCallback & Wi-Fi Direct
│   ├── operations/                  # Operations engine
│   ├── transfer/                    # Transfer engine
│   ├── sync/                        # Sync engine
│   ├── backup/                      # Backup engine
│   ├── access/                      # Access engine
│   ├── sharing/                     # Sharing engine
│   ├── workspace/                   # Workspace manager
│   ├── clipboard/                   # Android ClipboardManager adapter
│   ├── compatibility/               # Android Scoped Storage filesystem rules
│   ├── security/                    # Security subsystem
│   ├── recovery/                    # Recovery subsystem
│   ├── diagnostics/                 # Diagnostics subsystem
│   ├── filesystem/                  # Storage Access Framework (SAF) abstraction
│   ├── os/                          # Android Native Integrations:
│   │   ├── storage-access-framework/# SAF DocumentFile tree coordinator
│   │   ├── media-store/             # Android MediaStore content resolver
│   │   ├── keystore/                # AndroidKeyStore hardware-backed RSA/EC
│   │   ├── notifications/           # Android NotificationChannels & Heads-up
│   │   ├── background/              # WorkManager & Doze mode handling
│   │   ├── foreground-transfer/     # ForegroundService (FOREGROUND_SERVICE_DATA_SYNC)
│   │   └── power/                   # PowerManager.WakeLock management
│   ├── supabase/                    # Supabase client adapter
│   ├── tests/                       # Android instrumented & unit tests
│   ├── scripts/                     # Android Gradle build & test scripts
│   └── README.md                    # Android Developer Guide
│
├── shared-source/                   # Canonical Source Maintenance Hub
│   └── canonical/                   # Source of truth for common modules ONLY
│       ├── core/                    # Canonical Core domain logic
│       ├── protocol/                # Canonical Protobuf definitions & generators
│       ├── operations/              # Canonical Operations engine
│       ├── transfer/                # Canonical Transfer engine
│       ├── sync/                    # Canonical Sync engine
│       ├── backup/                  # Canonical Backup engine
│       ├── access/                  # Canonical Access engine
│       ├── sharing/                 # Canonical Sharing engine
│       ├── workspace/               # Canonical Workspace manager
│       ├── clipboard/               # Canonical Clipboard models & sanitizer
│       ├── compatibility/           # Canonical Compatibility traits
│       ├── security/                # Canonical Cryptographic primitives
│       ├── recovery/                # Canonical Recovery engine
│       ├── diagnostics/             # Canonical Diagnostics interfaces
│       └── flutter/                 # Canonical Flutter shared UI & state
│
├── tools/
│   └── sync-platform-shared/        # Synchronization & Verification Tooling
│       ├── sync-shared              # Cross-platform CLI runner
│       ├── sync-shared.ps1          # PowerShell synchronization implementation
│       ├── sync-shared.sh           # POSIX bash synchronization implementation
│       ├── verify-shared            # Cross-platform verification CLI runner
│       ├── verify-shared.ps1        # PowerShell verification implementation
│       └── verify-shared.sh         # POSIX bash verification implementation
│
├── supabase/                        # Cloud control plane migrations & policies
├── relay/                           # coturn STUN/TURN configurations
├── docs/                            # Architecture & release documentation
├── AGENTS.md                        # Architecture instructions for agents
└── README.md                        # Master repository overview
```

---

## 3. Module Physical Duplication Mapping

Every OS project maintains its own physical copy of the 14 common modules:

| Common Module | Canonical Path in `shared-source/canonical/` | Platform Path inside `{windows,linux,macos,android}/` | Responsibility |
|---|---|---|---|
| **core** | `shared-source/canonical/core/` | `{os}/core/` | Fundamental entities (`ObjectId`, `PeerId`, `SyncObject`, `CausalVersion`) |
| **protocol** | `shared-source/canonical/protocol/` | `{os}/protocol/` | Protocol buffer contracts, descriptors, and message definitions |
| **operations**| `shared-source/canonical/operations/`| `{os}/operations/` | Operations journal, conflict detection, deterministic replay |
| **transfer** | `shared-source/canonical/transfer/` | `{os}/transfer/` | Chunk-based streaming, SHA-256 chunk verification, checkpoints |
| **sync** | `shared-source/canonical/sync/` | `{os}/sync/` | Bi-directional tree reconciliation, vector clocks, mass-change safety |
| **backup** | `shared-source/canonical/backup/` | `{os}/backup/` | Archive bundling, ZIP compression, restore validation |
| **access** | `shared-source/canonical/access/` | `{os}/access/` | Remote access policies, session authorization, token validation |
| **sharing** | `shared-source/canonical/sharing/` | `{os}/sharing/` | Direct share links, permissions, share invitations |
| **workspace** | `shared-source/canonical/workspace/` | `{os}/workspace/` | Local workspace scoping, storage isolation |
| **clipboard** | `shared-source/canonical/clipboard/` | `{os}/clipboard/` | Cross-device clipboard synchronization & security sanitization |
| **compatibility**|`shared-source/canonical/compatibility/`| `{os}/compatibility/`| Filename sanitization, path encoding, normalization rules |
| **security** | `shared-source/canonical/security/` | `{os}/security/` | TLS 1.3 certificate management, Ed25519 signing, TOFU pairing |
| **recovery** | `shared-source/canonical/recovery/` | `{os}/recovery/` | Startup recovery, interrupted session reconciliation |
| **diagnostics**|`shared-source/canonical/diagnostics/`| `{os}/diagnostics/` | Metrics collector, health probes, performance diagnostics |
| **flutter** | `shared-source/canonical/flutter/` | `{os}/app/flutter/` | Shared Flutter application UI screens, providers, widgets |

---

## 4. Platform-Specific Implementations

Platform-sensitive logic is implemented purely inside `{os}/os/`, `{os}/filesystem/`, and `{os}/networking/`. Platform projects never import native classes from other operating systems.

* **Windows**: Uses Win32 APIs, Windows Notification API, Credential Manager, DPAPI, and named pipes.
* **Linux**: Uses D-Bus, XDG specifications, Secret Service API, and POSIX epoll.
* **macOS**: Uses Apple Keychain Services, APFS Unicode normalization, NSPasteboard, and FSEvents.
* **Android**: Uses Android Keystore provider, Storage Access Framework, Foreground Services, and Android NotificationChannels.
