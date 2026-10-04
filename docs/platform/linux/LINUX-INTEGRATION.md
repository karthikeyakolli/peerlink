# Linux Native OS Integration

## Overview
PeerLink's Linux platform adapter (`LinuxPlatformAdapter`) conforms to FreeDesktop.org standards (XDG, D-Bus, Secret Service) across diverse Linux desktop environments (GNOME, KDE Plasma, XFCE, Cinnamon, Sway/Wayland).

## Architecture & Integration Points

### 1. File Manager Actions
- **Desktop Actions**:
  - Installs `.desktop` action specifications under `~/.local/share/file-manager/actions/` and `~/.local/share/kio/servicemenus/`.
  - Integrates "Send via PeerLink" into Nautilus (GNOME Files), Dolphin (KDE), Nemo, and Thunar.

### 2. XDG Integration
- **Default Opener**:
  - Uses `xdg-open` for opening files and highlighting target folders.
- **MIME Associations**:
  - Registers `application/x-peerlink` and `application/x-peerlink-package` via `xdg-mime default peerlink.desktop application/x-peerlink`.

### 3. Desktop Notifications (D-Bus / notify-send)
- **Mechanism**:
  - Sends notifications via `org.freedesktop.Notifications` D-Bus interface or `notify-send`.
  - Supports standard urgency levels: `low`, `normal`, and `critical` (for security alerts or transfer failures).

### 4. Secret Storage (FreeDesktop Secret Service)
- **Mechanism**:
  - Communicates with `org.freedesktop.secrets` (GNOME Keyring, KWallet, KeePassXC) via `secret-tool` or native D-Bus bindings.
  - Safely stores master keys and space credentials in encrypted user keyrings.

### 5. Desktop Environment Compatibility
- **Detection**:
  - Inspects `$XDG_CURRENT_DESKTOP` and `$DESKTOP_SESSION`.
  - Adapts file reveal strategy, notifications, and tray icons based on active DE (GNOME libadwaita vs KDE Breeze vs generic X11/Wayland).
