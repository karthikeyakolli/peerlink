# PeerLink Platform-Separated Architecture Specification

**Document**: `docs/architecture/PLATFORM-SEPARATED-REPOSITORY.md`  
**Version**: 1.1.0 (Revised)  
**Phase**: Repository Architecture Transformation & Governance  
**Author**: PeerLink Principal Architect & Documentation Engineer  
**Status**: APPROVED & MANDATORY  

---

## 1. Architectural Vision & Core Mandate

PeerLink uses a **fully separated, self-contained project structure for each operating system** with physically duplicated common source code.

```
                              shared-source/canonical/
                    (Maintenance Source of Truth ONLY - Never Imported at Runtime)
                                          │
                  ┌───────────────────────┼───────────────────────┐
                  ▼                       ▼                       ▼
           tools/sync-shared       tools/sync-shared       tools/sync-shared
                  │                       │                       │
                  ▼                       ▼                       ▼
              windows/                  linux/                  macos/                  android/
        ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
        │ Common Modules   │    │ Common Modules   │    │ Common Modules   │    │ Common Modules   │
        │ (Physical Copy)  │    │ (Physical Copy)  │    │ (Physical Copy)  │    │ (Physical Copy)  │
        ├──────────────────┤    ├──────────────────┤    ├──────────────────┤    ├──────────────────┤
        │ Native Win32 OS  │    │ Native Linux OS  │    │ Native macOS OS  │    │ Native Android OS│
        │ & Filesystem     │    │ & Filesystem     │    │ & Filesystem     │    │ & Filesystem     │
        └──────────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
                  ▲                       ▲                       ▲                       ▲
                  └───────────────────────┴───────────────────────┴───────────────────────┘
                                          │
                                tools/verify-shared
                        (Zero-Drift Bit-Exact SHA-256 Audit)
```

### The Physical Duplication Mandate
To ensure that each platform project can be developed, tested, packaged, and maintained independently:
* **Windows** (`windows/`) contains its own complete, self-contained implementation.
* **Linux** (`linux/`) contains its own complete, self-contained implementation.
* **macOS** (`macos/`) contains its own complete, self-contained implementation.
* **Android** (`android/`) contains its own complete, self-contained implementation.

**CRITICAL ARCHITECTURAL INVARIANTS**:
> 1. **NO RUNTIME SHARED DIRECTORY**: There is no single runtime shared-code directory that operating systems import from directly.
> 2. **NO SYMLINKS OR JUNCTIONS**: Platform projects MUST NOT use symbolic links, NTFS directory junctions, bind mounts, or runtime path redirection to reference external shared source.
> 3. **CANONICAL HUB IS FOR MAINTENANCE ONLY**: `shared-source/canonical/` exists exclusively for centralized editing, maintenance, and synchronization. It is NEVER directly compiled or imported by platform runtimes.
> 4. **PHYSICAL DUPLICATION WITHOUT SEMANTIC DIVERGENCE**: Physical duplication does not mean divergence. Protocol formats, causal versioning, authorization invariants, and data integrity rules remain identical across all platforms.

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
│   ├── networking/                  # Windows Networking Implementation
│   │   ├── common/                  # Duplicated Transport & Session contracts
│   │   ├── quic/                    # Windows QUIC transport provider
│   │   ├── tcp/                     # Windows TCP/TLS fallback provider
│   │   └── platform/                # WinSock & Windows socket options
│   ├── operations/                  # Causal operation journal & execution
│   ├── transfer/                    # Resilient chunk streaming & checkpointing
│   ├── sync/                        # Folder synchronization & vector clocks
│   ├── backup/                      # Archive creation & restoration engine
│   ├── access/                      # Remote access & access control
│   ├── sharing/                     # Direct link & collaborative sharing
│   ├── workspace/                   # Workspace boundaries & isolation
│   ├── clipboard/                   # Windows Win32 clipboard bridge
│   ├── protocol-compatibility/      # Protocol version & feature negotiation
│   ├── file-compatibility/          # Windows path sanitization & filesystem rules
│   ├── security/                    # Authenticator & TLS manager
│   ├── recovery/                    # Journal-driven recovery & reconciliation
│   ├── diagnostics/                 # Telemetry & health probes
│   ├── filesystem/                  # Windows filesystem handling (handles, locks, staging)
│   ├── os/                          # Windows Native Integrations:
│   │   ├── explorer/                # Shell context menu integration
│   │   ├── share/                   # Windows Share Contract
│   │   ├── notifications/           # Windows Action Center toasts
│   │   ├── credential-store/        # Windows Credential Manager / DPAPI
│   │   ├── firewall/                # Windows Firewall rule coordinator
│   │   └── power/                   # Windows power & sleep management
│   ├── supabase/                    # Supabase REST/Realtime adapter
│   ├── tests/                       # Windows standalone test suite
│   ├── scripts/                     # Windows build, run, and test scripts
│   └── README.md                    # Windows Developer Guide
│
├── linux/                           # Linux Self-Contained Project
│   ├── app/                         # Linux Flutter Desktop Application
│   │   └── flutter/                 # Duplicated Flutter source & Linux runner
│   ├── core/                        # Duplicated Core domain
│   ├── protocol/                    # Duplicated Protobuf definitions & generated code
│   ├── networking/                  # Linux Networking Implementation
│   │   ├── common/                  # Duplicated Transport & Session contracts
│   │   ├── epoll/                   # Linux epoll transport provider
│   │   ├── tcp/                     # Linux TCP/TLS fallback provider
│   │   └── platform/                # Linux socket options & netlink
│   ├── operations/                  # Operations engine
│   ├── transfer/                    # Transfer engine
│   ├── sync/                        # Sync engine
│   ├── backup/                      # Backup engine
│   ├── access/                      # Access engine
│   ├── sharing/                     # Sharing engine
│   ├── workspace/                   # Workspace manager
│   ├── clipboard/                   # Linux X11/Wayland clipboard bridge
│   ├── protocol-compatibility/      # Protocol version & feature negotiation
│   ├── file-compatibility/          # POSIX file semantics & case rules
│   ├── security/                    # Security subsystem
│   ├── recovery/                    # Journal-driven recovery & reconciliation
│   ├── diagnostics/                 # Diagnostics subsystem
│   ├── filesystem/                  # Linux inotify filesystem watcher & staging
│   ├── os/                          # Linux Native Integrations:
│   │   ├── xdg/                     # XDG Base Directory & Desktop Entries
│   │   ├── dbus/                    # D-Bus IPC & system bus service
│   │   ├── notifications/           # Freedesktop notification daemon
│   │   ├── secret-store/            # Secret Service API / libsecret / KWallet
│   │   └── power/                   # systemd-logind power inhibition
│   ├── supabase/                    # Supabase REST/Realtime adapter
│   ├── tests/                       # Linux standalone test suite
│   ├── scripts/                     # Linux build, run, and test scripts
│   └── README.md                    # Linux Developer Guide
│
├── macos/                           # macOS Self-Contained Project
│   ├── app/                         # macOS Flutter Desktop Application
│   │   └── flutter/                 # Duplicated Flutter source & macOS runner
│   ├── core/                        # Duplicated Core domain
│   ├── protocol/                    # Duplicated Protobuf definitions & generated code
│   ├── networking/                  # macOS Networking Implementation
│   │   ├── common/                  # Duplicated Transport & Session contracts
│   │   ├── kqueue/                  # macOS kqueue transport provider
│   │   ├── tcp/                     # macOS TCP/TLS fallback provider
│   │   └── platform/                # BSD socket options & Darwin network APIs
│   ├── operations/                  # Operations engine
│   ├── transfer/                    # Transfer engine
│   ├── sync/                        # Sync engine
│   ├── backup/                      # Backup engine
│   ├── access/                      # Access engine
│   ├── sharing/                     # Sharing engine
│   ├── workspace/                   # Workspace manager
│   ├── clipboard/                   # macOS NSPasteboard bridge
│   ├── protocol-compatibility/      # Protocol version & feature negotiation
│   ├── file-compatibility/          # APFS Unicode normalization & case-folding
│   ├── security/                    # Security subsystem
│   ├── recovery/                    # Journal-driven recovery & reconciliation
│   ├── diagnostics/                 # Diagnostics subsystem
│   ├── filesystem/                  # macOS FSEvents filesystem watcher & staging
│   ├── os/                          # macOS Native Integrations:
│   │   ├── finder/                  # Finder Sync Extension
│   │   ├── share/                   # macOS Share Sheet integration
│   │   ├── keychain/                # Apple Keychain Services wrapper
│   │   ├── file-provider/           # File Provider Extension
│   │   ├── notifications/           # NSUserNotificationCenter toasts
│   │   └── power/                   # IOKit IOPMAssertion power management
│   ├── supabase/                    # Supabase REST/Realtime adapter
│   ├── tests/                       # macOS standalone test suite
│   ├── scripts/                     # macOS build, run, and test scripts
│   └── README.md                    # macOS Developer Guide
│
├── android/                         # Android Self-Contained Project
│   ├── app/                         # Android Flutter Mobile Application
│   │   └── flutter/                 # Duplicated Flutter source & Android runner
│   ├── core/                        # Duplicated Core domain (Android API baseline)
│   ├── protocol/                    # Duplicated Protobuf definitions & generated code
│   ├── networking/                  # Android Networking Implementation
│   │   ├── common/                  # Duplicated Transport & Session contracts
│   │   ├── platform/                # Android NetworkCallback & Wi-Fi Direct
│   │   └── transport/               # Android platform-appropriate transport
│   ├── operations/                  # Operations engine
│   ├── transfer/                    # Transfer engine
│   ├── sync/                        # Sync engine
│   ├── backup/                      # Backup engine
│   ├── access/                      # Access engine
│   ├── sharing/                     # Sharing engine
│   ├── workspace/                   # Workspace manager
│   ├── clipboard/                   # Android ClipboardManager adapter
│   ├── protocol-compatibility/      # Protocol version & feature negotiation
│   ├── file-compatibility/          # Android Scoped Storage & URI translation
│   ├── security/                    # Security subsystem
│   ├── recovery/                    # Journal-driven recovery & reconciliation
│   ├── diagnostics/                 # Diagnostics subsystem
│   ├── filesystem/                  # Storage Access Framework (SAF) abstraction
│   ├── os/                          # Android Native Integrations:
│   │   ├── storage-access-framework/# SAF DocumentFile tree coordinator
│   │   ├── media-store/             # Android MediaStore content resolver
│   │   ├── keystore/                # AndroidKeyStore hardware-backed RSA/EC
│   │   ├── notifications/           # Android NotificationChannels & Heads-up
│   │   ├── background/              # WorkManager scheduled tasks
│   │   ├── foreground-transfer/     # ForegroundService (FOREGROUND_SERVICE_DATA_SYNC)
│   │   └── power/                   # PowerManager.WakeLock & availability state
│   ├── supabase/                    # Supabase REST/Realtime adapter
│   ├── tests/                       # Android instrumented & unit tests
│   ├── scripts/                     # Android Gradle build & test scripts
│   └── README.md                    # Android Developer Guide
│
├── shared-source/                   # Canonical Source Maintenance Hub
│   └── canonical/                   # Source of truth for common modules ONLY
│       ├── core/                    # Canonical Core domain logic
│       ├── protocol/                # Canonical Protobuf definitions & generators
│       ├── networking/              # Canonical Common Transport & Session contracts
│       │   ├── transport-api/       # Transport interfaces & lifecycle listeners
│       │   ├── session-api/         # PeerSession & session state contracts
│       │   ├── connection-model/    # Connection state & frame abstractions
│       │   └── capability-model/    # Transport capability negotiation contracts
│       ├── operations/              # Canonical Operations engine & journal
│       ├── transfer/                # Canonical Transfer engine & chunking
│       ├── sync/                    # Canonical Sync engine & vector clocks
│       ├── backup/                  # Canonical Backup engine & archive format
│       ├── access/                  # Canonical Access engine & tokens
│       ├── sharing/                 # Canonical Sharing engine & capabilities
│       ├── workspace/               # Canonical Workspace manager & scoping
│       ├── clipboard/               # Canonical Clipboard models & sanitizer
│       ├── protocol-compatibility/  # Canonical Protocol version negotiation
│       ├── file-compatibility/      # Canonical File & filesystem compatibility
│       ├── security/                # Canonical Cryptographic & safety models
│       ├── recovery/                # Canonical Recovery & reconciliation engine
│       ├── diagnostics/             # Canonical Diagnostics & telemetry
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

## 3. Physical Duplication Mapping & Canonical Editing Rules

### 3.1 Module Duplication Mapping
Every OS project maintains its own complete physical copy of the common modules:

| Common Module | Canonical Path in `shared-source/canonical/` | Platform Path inside `{windows,linux,macos,android}/` | Responsibility |
|---|---|---|---|
| **core** | `shared-source/canonical/core/` | `{os}/core/` | Fundamental entities (`ObjectId`, `PeerId`, `SyncObject`, `CausalVersion`) |
| **protocol** | `shared-source/canonical/protocol/` | `{os}/protocol/` | Protobuf contracts, message descriptors, and generated code |
| **networking (common)**| `shared-source/canonical/networking/`| `{os}/networking/common/` | Common transport API, session contracts, and capability models |
| **operations** | `shared-source/canonical/operations/` | `{os}/operations/` | Operations journal, conflict detection, deterministic replay |
| **transfer** | `shared-source/canonical/transfer/` | `{os}/transfer/` | Chunk streaming, SHA-256 chunk verification, checkpoints |
| **sync** | `shared-source/canonical/sync/` | `{os}/sync/` | Bi-directional tree reconciliation, vector clocks, mass-change safety |
| **backup** | `shared-source/canonical/backup/` | `{os}/backup/` | Archive bundling, ZIP compression, restore validation |
| **access** | `shared-source/canonical/access/` | `{os}/access/` | Remote access policies, session authorization, token validation |
| **sharing** | `shared-source/canonical/sharing/` | `{os}/sharing/` | Direct share links, permissions, share invitations |
| **workspace** | `shared-source/canonical/workspace/` | `{os}/workspace/` | Local workspace scoping, storage isolation |
| **clipboard** | `shared-source/canonical/clipboard/` | `{os}/clipboard/` | Clipboard sync & security sanitization models |
| **protocol-compatibility**|`shared-source/canonical/protocol-compatibility/`|`{os}/protocol-compatibility/`| Protocol version, feature, and capability negotiation |
| **file-compatibility**|`shared-source/canonical/file-compatibility/`|`{os}/file-compatibility/`| File, storage, application, and metadata compatibility |
| **security** | `shared-source/canonical/security/` | `{os}/security/` | TLS 1.3 cert management, Ed25519 signing, safety policies |
| **recovery** | `shared-source/canonical/recovery/` | `{os}/recovery/` | Journal-based crash recovery, reconciliation, and resume |
| **diagnostics** | `shared-source/canonical/diagnostics/` | `{os}/diagnostics/` | Metrics collector, health probes, performance diagnostics |
| **flutter** | `shared-source/canonical/flutter/` | `{os}/app/flutter/` | Shared Flutter application UI screens, providers, widgets |

### 3.2 Canonical-Source Editing Rule
To eliminate accidental divergence and unauthorized code drift, the following editing governance is strictly enforced:

1. **COMMON SHARED SOURCE**:
   * Edit **ONLY** in `shared-source/canonical/`.
   * **NEVER** edit duplicated common files independently inside `windows/`, `linux/`, `macos/`, or `android/`.
   * A platform copy must never silently become the new canonical version.
2. **PLATFORM-SPECIFIC SOURCE**:
   * Edit only inside its corresponding OS project (`{os}/os/`, `{os}/filesystem/`, `{os}/networking/{quic,tcp,epoll,kqueue,platform}/`).
3. **ENGINEERING WORKFLOW**:
   ```
   shared-source/canonical/ (Author changes)
              │
              ▼
         sync-shared           (Propagate to all platform targets)
              │
              ▼
   windows / linux / macos / android
              │
              ▼
        verify-shared          (Verify 100% bit-exact parity)
              │
              ▼
          Run Tests            (Execute unit, integration, & regression tests)
   ```
4. **CROSS-PLATFORM BUG DISCOVERY**:
   If testing a specific platform reveals a bug in common logic:
   1. Fix the bug in `shared-source/canonical/`.
   2. Synchronize to all platforms using `sync-shared`.
   3. Run `verify-shared` to guarantee parity.
   4. Run affected test suites on all supported platforms.

---

## 4. Platform-Specific Implementations & Boundaries

Platform-sensitive logic is strictly isolated inside `{os}/os/`, `{os}/filesystem/`, and `{os}/networking/`. Platform projects never import native classes from other operating systems.

### 4.1 Windows Implementation
* **Filesystem Architecture**:
  * Uses standard Windows Win32 / Java NIO filesystem APIs.
  * Relies on native file handles and explicit shared read/write lock flags (`FILE_SHARE_READ`, `FILE_SHARE_WRITE`).
  * NTFS Alternate Data Streams (ADS) are used **strictly as optional metadata** (e.g., origin tracking), never for core transfer correctness.
  * Transfer safety utilizes staging files (`.part`), post-transfer SHA-256 verification, operation journal commit, and atomic move/rename (`ATOMIC_MOVE` via `MoveFileExW` / `REPLACE_EXISTING`).
  * Interrupted operations are reconciled during node startup via journal replay.
  * **No Transactional NTFS (TxF) Dependency**: PeerLink does not depend on deprecated or future-uncertain transactional filesystem technologies.
* **Native Integrations**:
  * Windows Explorer context menu handlers (`os/explorer/`).
  * Windows Notification Service / WinRT toast notifications (`os/notifications/`).
  * Windows Credential Manager and DPAPI for encrypted key storage (`os/credential-store/`).
  * Windows Defender Firewall automated port management (`os/firewall/`).
  * Windows Power Management suspend/sleep inhibition during active transfers (`os/power/`).
* **Networking**:
  * Common contracts implemented via Netty 4.2 / QUIC where supported, TCP/TLS fallback, and native WinSock options.

### 4.2 Linux Implementation
* **Filesystem Architecture**:
  * Uses POSIX filesystem calls, POSIX permissions (`chmod`/`chown`), and extended attributes (`xattr`) for optional metadata.
  * File change monitoring via `inotify`.
  * Atomic file replacement via POSIX `rename(2)` after staging and SHA-256 verification.
* **Native Integrations**:
  * XDG Base Directory specification compliance and `.desktop` entry registration (`os/xdg/`).
  * D-Bus IPC service for system bus integration (`os/dbus/`).
  * Freedesktop notification daemon (`org.freedesktop.Notifications`) (`os/notifications/`).
  * Secret Service API (`libsecret`/KWallet) for secure secret storage (`os/secret-store/`).
  * `systemd-logind` power inhibition locks during active transfers (`os/power/`).
* **Networking**:
  * Linux native `epoll` transport provider via Netty 4.2, TCP/TLS fallback, and POSIX socket tuning.

### 4.3 macOS Implementation
* **Filesystem Architecture**:
  * APFS copy-on-write cloning (`clonefile(2)`) where available for instant local snapshots.
  * APFS Unicode normalization (decomposed UTF-8 / NFC translation).
  * Extended attributes for quarantine tracking (`com.apple.quarantine`).
  * Staging and atomic exchange via `renamex_np` or POSIX rename.
  * File monitoring via Darwin `FSEvents`.
* **Native Integrations**:
  * Finder Sync Extension for status badge overlays and context menus (`os/finder/`).
  * macOS Share Sheet integration (`os/share/`).
  * Apple Keychain Services for secure credential storage (`os/keychain/`).
  * File Provider extension support (`os/file-provider/`).
  * `NSUserNotificationCenter` toast notifications (`os/notifications/`).
  * `IOPMAssertion` power management to inhibit system sleep during transfers (`os/power/`).
* **Networking**:
  * macOS native `kqueue` transport provider via Netty 4.2, TCP/TLS fallback, and Darwin socket options.

### 4.4 Android Implementation
* **Filesystem Architecture**:
  * Android Storage Access Framework (SAF) tree URIs and `DocumentFile` abstractions (`filesystem/`).
  * Android `MediaStore` ContentResolver integration for media indexing (`os/media-store/`).
  * App-scoped internal and external cache directories for temporary staging.
* **Native Integrations & Availability Model**:
  * Hardware-backed key generation via `AndroidKeyStore` (StrongBox / TEE) (`os/keystore/`).
  * Android Notification Channels and heads-up notifications (`os/notifications/`).
  * User-initiated long-running transfers execute via Foreground Services with persistent notification (`FOREGROUND_SERVICE_DATA_SYNC`) (`os/foreground-transfer/`).
  * Scheduled or opportunistic sync executes via `WorkManager` (`os/background/`).
  * PowerManager `WakeLock` held only for active user-visible transfers (`os/power/`).
  * **Availability States**: Android represents availability dynamically:
    * `ACTIVE`: App in foreground, high throughput, direct P2P capable.
    * `BACKGROUND_CAPABLE`: Foreground service active, background sync permitted.
    * `OS_RESTRICTED`: System resource constraints, Doze mode, or network throttled.
    * `UNAVAILABLE`: Process suspended or device offline.
  * **Battery Optimization Exemption**: Battery optimization whitelisting is **NOT** a required architectural dependency. PeerLink operates using standard platform-approved mechanisms (Foreground Services and WorkManager). Any request for battery optimization exemption is strictly **optional and user-controlled**.
* **Networking**:
  * Uses Android-appropriate transport mechanisms (Cronet/OkHttp/Java NIO), `ConnectivityManager.NetworkCallback` for dynamic network switching, and Wi-Fi Direct abstractions.

---

## 5. Language Runtimes & API Baselines

```
┌────────────────────────────────────────────────────────────────────────┐
│ Desktop Node (Windows, Linux, macOS)                                   │
│ Runtime: Java 25 Desktop Runtime                                       │
│ High-performance virtual threads, Netty 4.2, native OS bindings        │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Portable Shared Java Code (`shared-source/canonical/`)                 │
│ Runtime Baseline: Android-Compatible API Subset                        │
│ (Java 17 language level + Android desugaring / core library baseline)  │
│ Strict ban on desktop-only APIs (JNA, Desktop, AWT, internal JDK tools)│
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Android Node (`android/`)                                              │
│ Runtime: Android ART (Kotlin + Java Platform Layer)                    │
│ Uses Android SDK & Jetpack; does NOT require or assume Java 25         │
└────────────────────────────────────────────────────────────────────────┘
```

* **Desktop Platforms**: Windows, Linux, and macOS desktop projects target the **Java 25 runtime**, taking full advantage of modern JVM capabilities, virtual threads, and platform transport optimizations.
* **Portable Shared Java Code**: All common Java code in `shared-source/canonical/` (and duplicated in `{os}/core/`, `{os}/operations/`, etc.) must strictly adhere to the **Android-supported API baseline**. Desktop-only APIs (e.g. `java.awt.*`, desktop-specific NIO extensions, or JNA) are forbidden in shared modules.
* **Android Platform**: Written in Kotlin and Java using the standard Android SDK. It does not require or depend on a Java 25 runtime.

---

## 6. P2P Wire Protocol Architecture (Protobuf Only)

### 6.1 The Canonical Wire Protocol
* **Canonical P2P Protocol**: **Google Protocol Buffers (Protobuf v3)** is the **ONLY** PeerLink peer-to-peer wire protocol representation.
* **No Dual-Wire Ambiguity**: JSON is **NOT** an equivalent or alternative P2P wire protocol format.
* **Role of JSON**: JSON is strictly limited to:
  * External HTTP REST and control-plane APIs (Supabase).
  * Human-readable configuration, diagnostic logs, and state exports.
  * Local debugging tools.
* **Protocol Properties**:
  * **Versioned**: Package namespace `org.peerlink.protocol.v1`.
  * **Capability-Aware**: Protocol frames exchange explicit capability bitsets during handshake.
  * **Platform-Neutral**: Identical binary serialization across Java, Kotlin, Dart, C, and Rust.
  * **Backward/Forward Compatible**: Protobuf field rules guarantee schema evolution without breaking active nodes.

### 6.2 Protocol Schema Separation
The canonical protocol schemas are defined in `shared-source/canonical/protocol/proto/peerlink/v1/`:
* `common.proto`: Basic types, `ObjectId`, `PeerId`, timestamps.
* `session.proto`: Session handshake, transport frames, keepalives.
* `transfer.proto`: Chunk manifests, transfer requests, chunk offers, verification.
* `sync.proto`: Merkle tree snapshots, vector clocks, delta synchronization.
* `operation.proto`: Causal operation journal entries.
* `share.proto`: Capabilities, share metadata, invitation tokens.
* `trust.proto`: Identity certificates, pairing invitations, trust store records.
* `ipc.proto`: Local authenticated IPC contracts between Flutter UI and Local Node.

---

## 7. Data Integrity & Verification

### 7.1 Canonical Content Integrity Algorithm
* **V1 Content Integrity**: **SHA-256** is the frozen, canonical content integrity hashing algorithm for PeerLink V1.
* **Transfer Verification**:
  * Chunks are hashed with SHA-256 and checked against the manifest during streaming.
  * The assembled destination file is completely re-hashed with SHA-256 and verified against the source manifest before being committed from staging to destination.
* **Future Optimization Notice (BLAKE3)**:
  * BLAKE3 is **NOT** a V1 architectural requirement.
  * BLAKE3 is documented purely as an optional future performance optimization. Any adoption of BLAKE3 requires an approved Architecture Decision Record (ADR), backward compatibility negotiation, and explicit capability advertising.

### 7.2 Core Identity Invariants
* **Object ID ≠ Content Hash**: An `ObjectId` represents logical entity identity across causal edits, renames, and versions. A content hash represents immutable byte contents at an instant in time.
* **Object ID ≠ Filesystem Path**: Paths change due to user renames, directory reorganization, or OS conventions. The `ObjectId` remains immutable.

---

## 8. Three-Layer Security Architecture

PeerLink establishes a strict, decoupled three-layer security model:

```
┌────────────────────────────────────────────────────────────────────────┐
│ LAYER A: Transport Security                                            │
│ • TLS 1.3 for TCP-based transport streams                              │
│ • QUIC native TLS 1.3 encryption for datagram/stream connections       │
│ Invariant: Secures the transport channel against in-transit eavesdropping│
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ LAYER B: PeerLink Device Identity & Authentication                     │
│ • Ed25519 cryptographic keypairs per device                            │
│ • Stable Peer ID derived deterministically from public key             │
│ • Cryptographic mutual authentication during peer handshake            │
│ Invariants: Discovery ≠ Trust; TLS Certificate Identity ≠ Peer ID      │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ LAYER C: Application Payload Protection & Authorization               │
│ • End-to-end payload encryption (E2EE)                                 │
│ • Zero-knowledge relay: TURN/Coturn relays never receive plaintext     │
│ • Capability tokens and scoped access permissions                      │
│ Invariants: Trust ≠ Authorization; Relays have ZERO payload visibility │
└────────────────────────────────────────────────────────────────────────┘
```

### 8.1 Principles of Decoupling
1. **Discovery ≠ Trust**: Discovering a peer via mDNS, BLE, or Supabase signaling indicates presence only. It conveys zero trust.
2. **Trust ≠ Authorization**: A trusted paired device is not universally authorized to read, modify, or delete arbitrary files. Every operation requires explicit capability validation.
3. **Transport Security ≠ Device Identity**: TLS guarantees transport confidentiality, but PeerLink device identity is anchored strictly in Ed25519 cryptographic keys.
4. **Relay Isolation**: TURN servers are dumb packet forwarders. Relays cannot decrypt PeerLink application traffic.

---

## 9. Shared Networking Contracts & Transport Strategy

### 9.1 Shared Networking Contracts
Common transport contracts are defined canonically in `shared-source/canonical/networking/` and duplicated into `{os}/networking/common/`:
* `transport-api/`: `PeerLinkTransport`, `TransportConnection`, `ConnectionLifecycleListener`.
* `session-api/`: `PeerSession`, `SessionPayloadHandler`, `PeerSessionManager`.
* `connection-model/`: `ConnectionState`, `TransportFrame`, `TransportType`.
* `capability-model/`: `TransportCapabilityNegotiator`, protocol feature bitsets.

### 9.2 Transport Resolution Strategy
Transport selection follows a progressive fallback hierarchy:

```
               PeerLink Transport API Contract
                              │
                              ▼
                 Capability Negotiation
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     Supported & Preferred                 Fallback
   (QUIC / Platform Optimal)              (TCP / TLS 1.3)
              │                               │
              └───────────────┬───────────────┘
                              │ Direct Connection Fails
                              ▼
                      TURN Relay Path
               (End-to-End Encrypted Relay)
```

* **Desktop Implementations**: Desktop nodes (Windows, Linux, macOS) implement the transport contracts using Netty 4.2 with QUIC where supported, falling back to TCP/TLS.
* **Android Implementation**: Android implements the transport contracts using platform-appropriate network stacks (Cronet, OkHttp, or Java NIO).
* **No Universal Netty/QUIC Mandate**: Netty and QUIC are implementation details of specific platform engines. They are **NOT** mandatory on every platform.
* **Relay Invariant**: TURN relays provide NAT traversal only; they are never trust authorities.

---

## 10. Split Compatibility Model

PeerLink strictly separates **Protocol Compatibility** from **File Compatibility**:

```
                       COMPATIBILITY ARCHITECTURE
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
protocol-compatibility/                               file-compatibility/
• PeerLink protocol version negotiation              • Transfer compatibility
• Feature bitset negotiation                         • Storage capability compatibility
• Transport capability matching                      • Open / Application compatibility
• Message schema compatibility                       • Execution compatibility
• Backward / Forward compatibility rules             • Metadata & filesystem semantics
                                                     • Compatibility Verdicts
```

### 10.1 Protocol Compatibility (`protocol-compatibility/`)
* Negotiates wire protocol versions (e.g. `v1.0`).
* Matches capability flags (e.g., streaming compression, selective sync support).
* Ensures nodes refuse incompatible protocol frames gracefully without dropping connections abruptly.

### 10.2 File Compatibility (`file-compatibility/`)
* Evaluates cross-platform file exchange safety:
  * Path length limitations (Windows `MAX_PATH` vs. POSIX `PATH_MAX`).
  * Forbidden characters (`:`, `*`, `?`, `"`, `<`, `>`, `|` on Windows).
  * Case sensitivity conflicts (Linux case-sensitive vs. Windows/macOS case-insensitive).
  * Unicode normalization (macOS NFD vs. standard NFC).
  * Executable safety inspection (identifying `.exe`, `.bat`, `.sh`, `.apk` before writing).
* **Standardized Compatibility Verdicts**:
  * `COMPATIBLE`: Completely supported by the destination platform.
  * `PARTIALLY_COMPATIBLE`: Supported with sanitization (e.g., character replacement or NFD-to-NFC translation).
  * `INCOMPATIBLE`: Unsupported (e.g., exceeds storage quota or violates platform filesystem structure).
  * `UNKNOWN`: Unrecognized format or incomplete metadata.
  * `REQUIRES_USER_DECISION`: Potential risk or conflict requiring user confirmation (e.g., executable payload or overwrite).

---

## 11. Recovery & Reconciliation Architecture

PeerLink rejects the concept of "universal filesystem rollback." Operating systems do not guarantee atomic multi-file or directory rollback upon crash.

```
                           RECOVERY WORKFLOW
                                   │
                                   ▼
                           Operation Journal
                     (Persistent WAL / Record State)
                                   │
                                   ▼
                         Crash / Interruption
                                   │
                                   ▼
                           Startup Recovery
                                   │
                                   ▼
                    Filesystem / State Reconciliation
                                   │
                 ┌─────────────────┼─────────────────┐
                 ▼                 ▼                 ▼
          Resume Transfer     Retry Sync       Staging Cleanup
                 │                 │                 │
                 └─────────────────┼─────────────────┘
                                   │ Ambiguous State
                                   ▼
                         User Decision Required
```

### 11.1 Recovery Responsibilities
* **Operation Journal**: All state-modifying operations write intent to an append-only WAL before execution.
* **Filesystem & Database Reconciliation**: On startup, the recovery engine inspects local storage against the database and journal to reconcile incomplete states.
* **Interrupted Transfer Recovery**: Partial transfers are resumed from the last verified chunk checkpoint stored in the journal.
* **Interrupted Sync/Backup Recovery**: Incomplete sync operations detect missing causal events and re-trigger differential vector reconciliation.
* **Staging Directory Cleanup**: Abandoned temporary staging files (`.part`) older than the retention threshold are purged safely.
* **Unknown-Outcome Reconciliation**: If an external node disconnected during an operation with an unknown outcome, the local node marks the transaction `UNKNOWN` and requests status reconciliation rather than blindly repeating destructive actions.
* **Restricted Rollback**: Rollback is supported **ONLY** for operations that explicitly implement safe, idempotent compensatory actions.

---

## 12. Cloud Control Plane & Supabase Invariants

```
                                 SUPABASE CLOUD
                       (Control Plane & Signaling ONLY)
        ┌─────────────────────────────────────────────────────────────┐
        │ • GoTrue Auth (User Accounts)                              │
        │ • PostgreSQL (Device Registry, Ephemeral Presence)          │
        │ • Realtime WebSocket (Ephemeral Signaling & Notifications)  │
        │ • Edge Functions (Token validation, pairing coordination)   │
        └─────────────────────────────────────────────────────────────┘
                                  ▲         ▲
                      Signaling / │         │ Signaling /
                       Metadata   │         │  Metadata
                                  ▼         ▼
                         ┌──────────┐     ┌──────────┐
                         │ Node A   │◄───►│ Node B   │
                         └──────────┘     └──────────┘
                              Direct P2P Data Path
                      (Protobuf Wire Protocol over QUIC/TLS)
                     *** ZERO File Bytes In Supabase ***
```

* **Control Plane Role**: Supabase provides user authentication, device discovery registry, ephemeral online presence, and WebRTC/ICE signaling coordination.
* **Ephemeral Realtime**: Supabase Realtime is an **ephemeral coordination layer**, never a durable source of operation truth. Causal truth resides in peer operation journals.
* **No File Payloads in Supabase**: Normal file content is transferred strictly peer-to-peer (or via TURN relays). File bytes **NEVER** travel through or reside in Supabase Storage.
* **Account Identity ≠ Device Identity**: A Supabase user account may bind multiple devices, but each device retains its own independent Ed25519 identity key.
* **Client Architecture**: Desktop nodes communicate with Supabase via a **controlled HTTP/WebSocket adapter**, avoiding dependency on unverified or unstable community Java Supabase SDKs.

---

## 13. Local IPC Security Architecture

On desktop and mobile devices where the Flutter UI runs in a separate process from the PeerLink Node runtime:

* **Authenticated Local IPC**: Flutter ↔ Local Node IPC must be explicitly authenticated.
* **Localhost Is Not Inherently Trusted**: PeerLink rejects the assumption that `localhost` or local sockets are automatically safe. Untrusted local processes must not be able to issue transfer or configuration commands.
* **Authentication Mechanisms**:
  * Per-installation ephemeral shared secret or cryptographically generated auth token passed at process launch.
  * Strict protocol and API version handshake.
* **Interface Exposure Invariant**: The Local Node management interface is **NEVER** exposed as an unauthenticated or public network service.

---

## 14. Flutter Application Layer Duplication

* **Physical Duplication**: Common Flutter UI code is maintained canonically in `shared-source/canonical/flutter/` and duplicated into `{os}/app/flutter/`.
* **Synchronized Maintenance**: Common Flutter UI screens, state management providers, and widgets are updated in canonical source and synchronized across all four OS projects via `sync-shared`.
* **Zero Runtime Cross-Imports**: No operating system Flutter project imports code from another platform folder.
* **Platform-Specific Flutter Code**: Platform-specific Flutter plugins, native runners (Win32 runner, Linux GTK runner, macOS Cocoa runner, Android MainActivity/embedding), and OS-specific UI adaptations remain isolated in the respective platform project.
* **Verification**: Duplicated common Flutter files are tracked in the shared manifest and must pass `verify-shared` audits.

---

## 15. Synchronization & Verification Tooling

### 15.1 Synchronization Tooling (`sync-shared`)
* **Location**: `tools/sync-platform-shared/sync-shared` (`.ps1` for Windows PowerShell, `.sh` for Linux/macOS Bash).
* **Behavior**:
  * Copies **only** files from the declared shared modules in `shared-source/canonical/` to `windows/`, `linux/`, `macos/`, and `android/`.
  * Computes SHA-256 hashes to modify only files that have changed.
  * **Strictly preserves platform-specific directories** (`{os}/os/`, `{os}/filesystem/`, `{os}/networking/{quic,epoll,kqueue,platform,transport}/`, runners, scripts).
  * Supports `--dry-run` to preview file operations without touching disk.
  * Detects conflicting local modifications in platform copies before overwriting, requiring explicit manual confirmation.

### 15.2 Verification Tooling (`verify-shared`)
* **Location**: `tools/sync-platform-shared/verify-shared` (`.ps1`, `.sh`).
* **Behavior**:
  * Audits all required duplicated common source files against `shared-source/canonical/`.
  * Detects missing files, modified files, and unexpected shared files.
  * Computes SHA-256 hashes and verifies bit-exact identity.
  * Returns exit code `0` on complete synchronization; returns non-zero (`1`) on any drift.
* **Clarification of "Zero-Drift" Scope**:
  * Bit-exact zero-drift applies **strictly to files declared in the shared synchronized source manifest**.
  * Platform-specific code is intentionally different and isolated.
  * **Excluded from Duplication & Verification**:
    * Build output directories (`target/`, `build/`, `dist/`).
    * Flutter / Dart tool caches (`.dart_tool/`, `.packages`).
    * Temporary files, log files, SQLite local state (`*.db`, `*.db-wal`).
    * Environment-specific generated native binaries and wrappers.

---

## 16. Complete Architectural Invariants

The PeerLink architecture is governed by the following 24 non-negotiable invariants:

1. **Protobuf is Canonical P2P Protocol**: Google Protocol Buffers is the exclusive wire protocol for PeerLink peer-to-peer communication.
2. **JSON is for External/Control Systems**: JSON is strictly for HTTP REST/control plane APIs, configuration export, and debugging, not a second P2P wire protocol.
3. **SHA-256 is Canonical V1 Integrity**: SHA-256 is the frozen canonical algorithm for content-integrity hashing and chunk transfer verification in V1.
4. **Object ID ≠ Content Hash**: Object ID tracks logical entity identity across causal versions; content hash tracks immutable content bytes.
5. **Object ID ≠ Filesystem Path**: Paths are transient and platform-dependent; Object IDs are persistent and immutable.
6. **Watchers are Hints**: Filesystem watcher events (`inotify`, `FSEvents`, ReadDirectoryChangesW) are delivery hints; durable truth requires reconciliation.
7. **Timestamps are Not Conflict Authority**: Wall-clock timestamps are unreliable; causality is resolved via vector clocks and operation journals.
8. **Discovery Does Not Create Trust**: Finding a peer across the network indicates presence only, conveying zero security trust.
9. **Trust Does Not Grant Unlimited Authorization**: Trust establishes peer identity; individual operations still require explicit capability validation.
10. **UI is Never Authoritative**: The user interface is a presentation layer; the Local Node engine enforces all validation, permissions, and security.
11. **AI is Never Authoritative**: AI models and contextual recommendations are advisory; all destructive operations require explicit user approval.
12. **Supabase is Control Plane Only**: Supabase handles auth, presence, and signaling; file content bytes are never stored in Supabase.
13. **Realtime is Not Durable Truth**: Supabase Realtime is an ephemeral messaging bus; durable operation records reside in local peer journals.
14. **Local Node is Authoritative**: The Local Node runtime holds authority for all local storage, transfers, and cryptographic operations.
15. **Transport is Abstracted**: Netty and QUIC are platform implementations, not universal requirements on every operating system.
16. **Android is Full but Non-Continuous**: Android is a first-class node but is subject to OS process lifecycle and cannot be assumed an always-on daemon.
17. **Received Files are Never Auto-Executed**: Incoming files are quarantined and staged; executable files are never automatically launched.
18. **Destructive Unknown Outcomes Cannot Be Blindly Replayed**: Operations interrupted with unknown status require reconciliation or user decision before retry.
19. **Platform-Specific OS Semantics Must Be Exposed**: Filesystem differences (case sensitivity, path limits, permissions) must be handled transparently rather than silently corrupted.
20. **Common Source is Synchronized from Canonical**: Common code is authored solely in `shared-source/canonical/` and synchronized to platform targets.
21. **Platform Source Remains Isolated**: Platform-specific code resides strictly within its respective OS directory.
22. **Local IPC Must Be Authenticated**: Inter-process communication between UI and Node requires mutual authentication and cannot trust localhost blindly.
23. **Recovery is Reconciliation, Not Universal Rollback**: Recovery relies on journal reconciliation, resume, and retry; universal filesystem rollback is rejected.
24. **Security Scanning is Provider-Based**: PeerLink defines safety pipelines and external scanner integrations; it does not implement its own antivirus engine.
