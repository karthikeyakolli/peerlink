# Android Storage Access Framework (SAF) & ContentResolver Architecture

## 1. Physical URIs vs. Logical Object Identities

On Android, application sandboxes and Scoped Storage prevent accessing arbitrary filesystem paths (`/sdcard`, `/storage/emulated/0/...`).

PeerLink core decouples logical object identity (`ObjectIdentity`) from physical storage locators:

- **Logical Object**: `ObjectIdentity("android-obj-7b9e...")`
- **Physical Handle**: `SafPeerFileHandle` wrapping `content://com.android.externalstorage.documents/tree/primary%3ADownloads/document/primary%3ADownloads%2Farchive.zip`

```
  Portable Core Layer                     Android SAF Layer
┌───────────────────────┐            ┌────────────────────────────┐
│   PeerFileProvider    │            │    SafStorageProvider      │
│     .resolve(id)      ├───────────►│   .openInputStream(uri)    │
│     .delete(handle)   │            │   .openOutputStream(uri)   │
└───────────────────────┘            └─────────────┬──────────────┘
                                                   │
                                     ┌─────────────▼──────────────┐
                                     │  Android ContentResolver   │
                                     │  & DocumentsContract API   │
                                     └────────────────────────────┘
```

---

## 2. Persistable Permissions Across Device Reboots

When a user selects a destination folder using `Intent.ACTION_OPEN_DOCUMENT_TREE`, temporary URI grants expire when the process terminates.

The `SafStorageProvider` invokes:

```kotlin
contentResolver.takePersistableUriPermission(
    treeUri,
    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
)
```

This guarantees PeerLink maintains access across device restarts, enabling automated background sync and backup into user-designated folders.

---

## 3. Storage Permission Denial Defense

If storage permissions are denied or revoked by the user at runtime:
1. `checkReadPermission()` or `checkWritePermission()` fails.
2. The storage abstraction raises an explicit `AccessDeniedException`.
3. The `AndroidNodeStateMachine` transitions immediately to `UNAVAILABLE` or `OS_RESTRICTED` rather than failing ungracefully.
4. The Flutter UI reflects the state and prompts the user to grant permissions.
