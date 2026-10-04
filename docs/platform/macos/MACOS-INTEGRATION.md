# macOS Native OS Integration

## Overview
PeerLink's macOS platform adapter (`MacPlatformAdapter`) bridges Apple-native services to the PeerLink capability interface while respecting App Sandbox boundaries and macOS security guidelines.

## Architecture & Integration Points

### 1. Finder Integration
- **Reveal**:
  - Executes `open -R "<path>"` to highlight received files or sync directories in Finder.
- **Finder Sync & Quick Actions**:
  - Supports Finder Sync App Extension or Automator/Shortcuts Quick Action for "Send with PeerLink".

### 2. Share Extension
- **Mechanism**:
  - Native macOS Share Extension (`NSSharingServicePicker`) accepts files or URLs from Safari, Preview, and Finder, forwarding them to PeerLink via App Group container.

### 3. Native Notifications
- **Mechanism**:
  - Interacts with `NSUserNotificationCenter` / `UNUserNotificationCenter` or `osascript` fallback.
  - Generates notifications with title, subtitle ("PeerLink"), sound, and action buttons.

### 4. Keychain Services
- **Mechanism**:
  - Implements `CredentialStorage` backed by macOS Keychain (`SecItemAdd`, `SecItemCopyMatching` or `security` CLI).
  - Isolates sensitive crypto materials with `kSecAttrAccessibleAfterFirstUnlock`.

### 5. App Sandbox Permissions & Security-Scoped Bookmarks
- **Entitlements**:
  - `com.apple.security.files.user-selected.read-write`
  - `com.apple.security.network.client` and `com.apple.security.network.server`
- **Security-Scoped Bookmarks**:
  - Retains persistent access across app launches to user-selected sync folders and backup repositories without requiring constant re-prompting.

### 6. File Provider (Optional Integration)
- **Status**: Optional integration flag (`OPTIONAL_FILE_PROVIDER`).
- **Design Rule**:
  - PeerLink core sync and storage engines do NOT depend on `NSFileProviderReplicatedExtension`.
  - File Provider is treated as an optional virtual filesystem provider when running on macOS 12+.
