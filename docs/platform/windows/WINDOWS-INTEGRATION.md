# Windows Native OS Integration

## Overview
PeerLink's Windows platform adapter (`WindowsPlatformAdapter`) integrates with modern Windows operating system facilities while maintaining clean separation from the portable PeerLink core. All interactions adhere to the adapter-only pattern and are guarded by runtime capability checks (`supportsFeature`).

## Architecture & Integration Points

### 1. File Explorer Context Menu
- **Integration**:
  - Contextual verbs registered under:
    - `HKCU\Software\Classes\*\shell\PeerLinkSend` ("Send with PeerLink")
    - `HKCU\Software\Classes\Directory\shell\PeerLinkSend`
  - Launches PeerLink UI or background dispatch passing target path.
- **Safety**:
  - User-level registry scope (`HKCU`) requires no elevation (UAC).
  - Clean unregistration provided on exit/uninstall.

### 2. Share Integration
- **Mechanism**:
  - Integrates with Windows Share Contract via WinRT DataTransferManager where available, or shell verbs.
  - Allows seamless routing of files into active PeerLink transfer sessions.

### 3. Toast Notifications
- **Mechanism**:
  - Employs Windows Runtime (`Windows.UI.Notifications.ToastNotificationManager`) via desktop bridge or PowerShell runner fallback.
  - Formatted notifications support titles, bodies, action buttons ("Open", "Dismiss"), and direct payload activation.

### 4. File Associations
- **Registered Extensions**:
  - `.peerlink` (Encrypted peer pairing profile or space ticket)
  - `.plpkg` (Self-contained offline peer transfer package)
- **ProgID**: `PeerLink.Package` / `PeerLink.Ticket`

### 5. File Reveal & Open
- **Reveal in Explorer**:
  - Executes `explorer.exe /select,"<path>"` highlighting the file without opening it.
- **Open Default App**:
  - Safely delegates to `cmd.exe /c start "" "<path>"` honoring system MIME handlers without executing suspicious binaries.

### 6. OS Credential Storage (DPAPI)
- **Mechanism**:
  - Encapsulated via `WindowsCredentialStorage`.
  - Secrets (device tokens, session keys, pairing passphrases) are encrypted with user-scope Windows Data Protection API (DPAPI) or Credential Manager.

### 7. Windows Defender Firewall Diagnostics
- **Diagnostics**:
  - Uses `netsh advfirewall firewall show rule` to determine whether PeerLink incoming listening ports (TCP/UDP) are open.
  - If a rule is missing, provides precise, non-elevated diagnostic feedback and safe PowerShell/netsh remediation commands for the administrator.
