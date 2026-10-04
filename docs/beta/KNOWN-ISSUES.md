# PeerLink V1.0 - Known Limitations & Operational Guidance

**Document**: `docs/beta/KNOWN-ISSUES.md`  
**Target Release**: PeerLink 1.0.0 (`1.0.0-rc2` / GA)  
**Status**: Active Baseline  
**Audience**: Release Engineering, System Administrators, End Users  

---

## 1. Overview

PeerLink V1.0 is engineered for high-throughput, secure, local-first peer-to-peer data synchronization, file transfers, and shared capabilities across desktop and mobile devices. While all P0/P1 release-blocking defects have been resolved and verified with automated regression tests, certain operating system constraints, hardware boundaries, and network edge cases exist. 

This document cataloges known operational limitations and provides recommended user configurations and workarounds.

---

## 2. Platform-Specific Limitations & Workarounds

### 2.1 Android Operating System (Android 11 - 14)

* **Issue KI-AND-01: OEM Background Killing (Doze Mode & Battery Whitelisting)**
  * *Description*: Aggressive OEM battery managers (specifically Samsung OneUI, Xiaomi MIUI, and Huawei EMUI) may terminate background network sockets if the device enters deep sleep or the screen remains off for prolonged periods during passive sync.
  * *Impact*: Background synchronization may be delayed until the screen turns on or the user opens the application. Active foreground file transfers are protected by the persistent Foreground Notification Service and are not terminated.
  * *Workaround*: In Android System Settings, set PeerLink battery usage to **"Unrestricted"** and disable "Remove permissions if app is unused".
  
* **Issue KI-AND-02: Scoped Storage & File Access Permissions**
  * *Description*: On Android 11+ (API Level 30+), applications operate under Android Scoped Storage. Direct access to `/Android/data/` or root file systems is restricted by OS security policy.
  * *Impact*: PeerLink cannot synchronize folders inside protected private app directories of third-party apps.
  * *Workaround*: Synchronize shared directories located in standard media directories (`Documents/`, `Download/`, `DCIM/`, `Music/`) or use the Storage Access Framework (SAF) directory picker to explicitly grant tree access.

* **Issue KI-AND-03: Background Clipboard Listening on Android 10+**
  * *Description*: Android 10+ restricts background applications from reading the system clipboard unless the app has the default input method editor (IME) role or is currently in the active foreground window.
  * *Impact*: Automatic outbound clipboard synchronization requires PeerLink to be in the foreground or accessed via the PeerLink Quick Settings Tile / Notification action.
  * *Workaround*: Inbound clipboard pushes from trusted desktop peers are received and populated immediately via the local foreground service.

---

### 2.2 Desktop Operating Systems (Windows, macOS, Linux)

* **Issue KI-DSK-01: Windows Long File Path Limitations (MAX_PATH = 260)**
  * *Description*: On legacy Windows installations where Win32 Long Path support is not enabled in the system registry, file paths exceeding 260 characters will fail during filesystem sync.
  * *Impact*: Sync engine logs `SyncOutcome.failed("File path exceeds MAX_PATH")`.
  * *Workaround*: Enable Long Paths in Windows Group Policy (`Computer Configuration > Administrative Templates > System > Filesystem > Enable Win32 long paths`) or via registry key `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 1`.

* **Issue KI-DSK-02: macOS Local Network Permission Dialog (macOS 15 Sequoia)**
  * *Description*: macOS 15 requires explicit user consent for applications to discover devices on the local area network via mDNS (Bonjour).
  * *Impact*: If the user denies local network access upon initial application launch, peer discovery on the local subnet will be silenced.
  * *Workaround*: Navigate to `System Settings > Privacy & Security > Local Network` and ensure PeerLink is toggled ON.

* **Issue KI-DSK-03: Linux Headless / CLI Daemon Secret Storage**
  * *Description*: On headless Linux servers without an active X11/Wayland session or D-Bus Secret Service (GNOME Keyring / KWallet), native key storage falls back to file-based encrypted keystore protected by a local master passphrase.
  * *Impact*: Daemon startup requires environment variable `PEERLINK_KEYSTORE_PASSPHRASE` or an interactive prompt.
  * *Workaround*: Provide the passphrase via systemd credential store (`systemd-creds`) or standard environment configuration.

---

## 3. Network & Connectivity Limitations

### 3.1 Strict Symmetric NAT & UDP Filtering

* **Issue KI-NET-01: Enterprise Symmetric NAT to Symmetric NAT Direct P2P**
  * *Description*: When two peers are behind carrier-grade NAT (CGNAT) or restrictive corporate firewalls where port allocation is unpredictable (Symmetric NAT), direct UDP STUN hole punching fails in ~8-12% of configurations.
  * *Behavior*: PeerLink automatically and seamlessly falls back to authenticated, end-to-end encrypted TURN/Relay nodes. End-to-end TLS/Noise encryption keys remain exclusively between the two endpoints; relay servers observe only opaque ciphertext.
  * *Impact*: Transfer speeds through TURN relay may be governed by relay server bandwidth limits compared to local wire speeds.
  * *Workaround*: None required. Relays guarantee 100% reachability. Users may configure private custom TURN relay servers in `Settings > Network > Custom Relays`.

### 3.2 Captive Portals & Isolated Guest Wi-Fi

* **Issue KI-NET-02: Client Isolation on Public / Hotel Wi-Fi**
  * *Description*: Public hotspots often enforce AP Client Isolation, which blocks direct peer-to-peer multicast, broadcast, and unicast packets between devices connected to the same access point.
  * *Behavior*: Local mDNS discovery cannot traverse isolated APs.
  * *Workaround*: Use Out-of-Band pairing (Scan Peer QR code or manually paste Peer ID) and toggle "Route via Relay" or use Direct Wi-Fi / Hotspot tethering between devices.

---

## 4. Resource & Scale Boundaries

| Metric | Tested Limit (V1.0) | Recommended Guideline | Operational Behavior at Limit |
|---|---|---|---|
| **Maximum Single File Size** | 250 GB | 100 GB | Handled via streaming 1MB chunk hashes. Memory footprint remains static (< 64MB buffer). |
| **Max Tracked Sync Objects** | 100,000 files | 50,000 files | Manifest indexing SQLite database size ~45MB. Delta detection latency < 800ms. |
| **Concurrent Active Transfers**| 8 parallel sessions | 4 parallel sessions | Additional transfer requests are automatically queued in prioritized FIFO order. |
| **Simultaneous Paired Peers** | 50 devices | 25 devices | Discovery heartbeat thread uses randomized jitter to prevent multicast storms. |
| **Clipboard Sync Max Payload** | 10 MB text/image | 2 MB | Payloads > 10MB are rejected by safety filter to prevent clipboard memory flooding. |

---

## 5. Security & Safety Operational Policies

1. **Mass-Change Safety Protection**:
   * If more than 5 files (or > 50% of tracked repository files) are deleted in a single sync batch, PeerLink pauses synchronization to protect against accidental directory purge or ransomware behavior.
   * *Resolution*: The user is presented with a non-blocking confirmation dialog displaying the exact list of files pending deletion. Synchronization resumes immediately upon user confirmation.
2. **Untrusted Node Isolation**:
   * Nodes that fail mutual TLS handshake, present expired cryptographic certificates, or mismatch known trust-on-first-use (TOFU) keys are instantly terminated and quarantined.
