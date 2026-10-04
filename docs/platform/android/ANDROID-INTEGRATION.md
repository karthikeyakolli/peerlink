# Android Native OS Integration

## Overview
PeerLink's Android platform adapter (`AndroidPlatformAdapter`) integrates with Android system capabilities (Sharesheet, NotificationManagerCompat, Storage Access Framework, MediaStore, and runtime permission flows) as established in Phase 16. It ensures all mobile-specific constraints are encapsulated without polluting the portable JVM/Kotlin core.

## Architecture & Integration Points

### 1. Android Sharesheet (`ACTION_SEND` & `ACTION_SEND_MULTIPLE`)
- **Integration**:
  - Implements `invokeSystemShare(List<Path> paths)`.
  - Dispatches `Intent.createChooser` with `ACTION_SEND` (single file) or `ACTION_SEND_MULTIPLE` (multiple files/directories).
  - Uses `FileProvider.getUriForFile()` to securely grant read permissions to receiving apps.

### 2. NotificationManagerCompat & Foreground Service
- **Mechanism**:
  - Encapsulates notification channels (`peerlink_transfers`, `peerlink_security`, `peerlink_general`).
  - Supports progress bars, cancellation intents, and interactive actions ("Accept", "Reject", "Open") directly from heads-up notifications.

### 3. Storage Access Framework (SAF) Document Picker
- **Mechanism**:
  - Implements `SAF_DOCUMENT_PICKER` capability.
  - Triggers `Intent.ACTION_OPEN_DOCUMENT_TREE` or `Intent.ACTION_OPEN_DOCUMENT` for secure, sandbox-compliant folder and file access.
  - Persists URI permissions across device reboots using `contentResolver.takePersistableUriPermission`.

### 4. MediaStore Integration
- **Mechanism**:
  - Interfaces with Android's MediaStore (`MediaStore.Images`, `MediaStore.Video`, `MediaStore.Downloads`) for smart photo sync and zero-permission import of captured media.

### 5. Runtime Permission Flows
- **Permissions Managed**:
  - `POST_NOTIFICATIONS` (Android 13+ / API 33+)
  - `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (Android 13+)
  - `NEARBY_WIFI_DEVICES` (Android 13+ for Wi-Fi Direct and Aware discovery)
  - `ACCESS_FINE_LOCATION` (Android 10-12 for legacy Wi-Fi scan)
- **Flow**:
  - Non-blocking permission request flow with graceful feature degradation when user denies optional permissions.

### 6. Android Keystore Integration
- **Mechanism**:
  - Implements `CredentialStorage` backed by hardware TEE or StrongBox Keymaster.
  - Secret keys generated with `KeyGenParameterSpec` are hardware-isolated and inaccessible outside the Secure World.
