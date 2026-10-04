# Phase 17 — Native OS Integration Verification

## 1. Executive Summary
Phase 17 delivers operating-system integration across all four target platforms (**Windows, macOS, Linux, and Android**) while rigorously maintaining the platform-independent integrity of the PeerLink core. All native features are implemented strictly as **adapters** behind a common capability-oriented interface (`NativePlatformAdapter`). The Flutter UI remains the shared client, and zero platform-specific assumptions or path models contaminate the domain logic.

---

## 2. Decoupled Architecture

```
                      +-----------------------------+
                      |     Shared Flutter UI       |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |   PlatformIntegrationService|
                      +--------------+--------------+
                                     |
                +--------------------+--------------------+
                |                                         |
                v                                         v
   +-------------------------+               +-------------------------+
   |   Portable JVM Core     |               |  NativePlatformAdapter  |
   | (Sync, Backup, Safety,  |               |  (Capability-Guarded)   |
   |  Smart Ops, Protocol)   |               +------------+------------+
   +-------------------------+                            |
                                      +-------------------+-------------------+
                                      |                   |                   |
                                      v                   v                   v
                               +--------------+    +--------------+    +--------------+
                               | WindowsAdapter|   |  MacAdapter  |    | LinuxAdapter |
                               +--------------+    +--------------+    +--------------+
                                      |
                                      v
                               +--------------+
                               |AndroidAdapter|
                               +--------------+
```

### Architectural Guarantees:
1. **Zero Core Contamination**: Core packages (`org.peerlink.core.sync`, `org.peerlink.core.backup`, `org.peerlink.core.safety`, `org.peerlink.core.operation`) have zero imports from `org.peerlink.core.platform.windows.*`, `macos.*`, `linux.*`, or `android.*`.
2. **Capability Guards**: No native method is called without prior verification via `supportsFeature(PlatformFeature)`.
3. **Graceful Degradation**: Headless or unsupported environments safely fall back to in-memory mock implementations without raising unhandled exceptions or disrupting transfers.

---

## 3. Platform Integrations Breakdown

### A. Windows (`WindowsPlatformAdapter`)
- **File Explorer Context Menu**: Generates context verbs (`HKCU\Software\Classes\*\shell\PeerLinkSend`).
- **Share Integration**: Windows Share Contract activation and shell execute handlers.
- **Toast Notifications**: WinRT / PowerShell `ToastNotificationManager` dispatch with priority and category routing.
- **File Associations**: Registers `.peerlink` (Pairing profiles) and `.plpkg` (Transfer packages).
- **File Reveal & Open**: Uses `explorer.exe /select,"<path>"` for safe highlight and default app execution.
- **OS Credentials**: Secure Windows Credential Manager / DPAPI encapsulation.
- **Firewall Diagnostics**: Safe `netsh advfirewall firewall show rule` inspection with recommended rule generation for TCP/UDP ports.

### B. macOS (`MacPlatformAdapter`)
- **Finder Integration**: Native `open -R "<path>"` reveal and Quick Action menus.
- **Share Extension**: Bridges to `NSSharingServicePicker` for cross-application sharing.
- **AppleScript & User Notifications**: `osascript -e 'display notification ...'` with title, subtitle, and action buttons.
- **Keychain Storage**: Secure credential management via macOS Keychain Services (`kSecClassGenericPassword`).
- **Sandbox Permissions**: Manages `com.apple.security.*` entitlements and security-scoped bookmark tracking.
- **File Provider**: Optional integration flag (`OPTIONAL_FILE_PROVIDER`) without coupling core storage to `NSFileProvider`.

### C. Linux (`LinuxPlatformAdapter`)
- **File Manager Actions**: Installs `.desktop` action specifications for Nautilus, Dolphin, Nemo, and Thunar.
- **XDG Standards**: Uses `xdg-open` and `xdg-mime` for default handlers and file associations.
- **Desktop Notifications**: D-Bus `org.freedesktop.Notifications` and `notify-send` with urgency levels.
- **Secret Service Storage**: FreeDesktop Secret Service (`secret-tool` / GNOME Keyring / KWallet) adapter.
- **DE Compatibility**: Dynamically inspects `$XDG_CURRENT_DESKTOP` to adapt behavior across GNOME, KDE, XFCE, and Wayland.

### D. Android (`AndroidPlatformAdapter`)
- **Android Sharesheet**: Bridges `Intent.ACTION_SEND` and `ACTION_SEND_MULTIPLE` via `FileProvider`.
- **System Notifications**: `NotificationManagerCompat` notification channels for transfers, security, and spaces.
- **SAF Document Picker**: `Intent.ACTION_OPEN_DOCUMENT_TREE` and persistent URI permissions.
- **MediaStore Integration**: Zero-permission import and media catalog scanning.
- **Runtime Permissions**: Asynchronous permission flows for `POST_NOTIFICATIONS`, `READ_MEDIA_IMAGES`, and `NEARBY_WIFI_DEVICES`.
- **Hardware Keystore**: Secure key and secret isolation in TEE/StrongBox.

---

## 4. Verification Suite & Results
The test suite `NativePlatformIntegrationTest` validates:
- `testPlatformTypeDetection`: Verified runtime OS detection across platforms.
- `testWindowsPlatformIntegration`: Verified Explorer context verbs, DPAPI credential store/retrieve/delete, toast notifications, file associations, and firewall rule diagnostics.
- `testMacPlatformIntegration`: Verified Finder reveal, Keychain storage, sandbox entitlements, and notification scripts.
- `testLinuxPlatformIntegration`: Verified XDG opener, Secret Service credential storage, desktop notification levels, and DE detection.
- `testAndroidPlatformIntegration`: Verified Sharesheet payload capture, SAF picker capability, notification routing, and Android Keystore secret storage.
- `testCapabilityNegotiationAndFallback`: Verified graceful fallback in headless environments.
- `testCoreDomainInvariance`: Confirmed zero core contamination and complete protocol/domain semantic preservation.
