# PeerLink — Privacy & Permissions UX Audit

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  

---

## 1. Principle of Minimal Privilege

PeerLink requests the least permission necessary to perform the user's explicit action:

| Permission | Platform | When Requested | Rationale Communicated to User | Fallback if Denied |
| :--- | :--- | :--- | :--- | :--- |
| **`READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`** | Android 13+ | When opening Media Gallery Space | "Browse and manage photos and videos stored on your device." | User can still select individual files via Android Photo Picker without broad storage permission. |
| **`MANAGE_EXTERNAL_STORAGE`** | Android 11+ | Only if user enables full device file browsing in File Manager | "Required to browse, copy, and organize files across all device folders." | Restricted mode: browse only the PeerLink app-specific vault and SAF-selected folders. |
| **`ACCESS_FINE_LOCATION` / `NEARBY_WIFI_DEVICES`** | Android 13+ | When starting Wi-Fi Direct or local hotspot pairing | "Required by Android OS to discover and negotiate direct local Wi-Fi connections with nearby devices." | Standard local network IP transfer over existing Wi-Fi router. |
| **`CAMERA`** | Android & Desktop | When scanning pairing QR code or using Document Scanner | "Required to scan device pairing QR invitations and capture physical documents for scanning." | Manual entry: paste 30-digit pairing code or import image files from storage. |
| **`POST_NOTIFICATIONS`** | Android 13+ | On first transfer start | "Displays live background transfer progress and completion alerts." | Transfers continue in background via foreground service, but system notification tray icon is hidden. |
| **`RECORD_AUDIO`** | Android & Desktop | When activating Push-to-Talk Walkie-Talkie | "Stream encrypted voice audio to connected peer while holding the talk button." | Walkie-talkie mode disabled; text snippets and file transfer remain active. |
