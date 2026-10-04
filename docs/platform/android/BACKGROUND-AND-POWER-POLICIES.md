# Android Background & Power Execution Policies

## 1. Foreground Service Elevation (`FOREGROUND_SERVICE_TYPE_DATA_SYNC`)

Android 14+ (API 34+) enforces strict rules on foreground services. PeerLink defines deterministic thresholds to decide when to elevate to a Foreground Service:

- **Size Threshold**: Transfers $\ge 5\text{ MB}$
- **Estimated Duration**: Transfers $\ge 5\text{ seconds}$

```kotlin
// Elevated with ongoing user-visible notification
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
    startForeground(
        NOTIFICATION_ID,
        notification,
        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
    )
}
```

This guarantees network sockets and CPU wake-locks remain alive if the user minimizes the app, locks their phone, or switches to another application.

---

## 2. WorkManager Periodic Sync & Backup Constraints

Background sync and backup are handled by `PeerLinkSyncWorker` under strict OS constraints:

- `setRequiredNetworkType(NetworkType.UNMETERED)`: Only run when connected to Wi-Fi/Ethernet.
- `setRequiresBatteryNotLow(true)`: Battery must not be in low threshold.
- **Backup Rule**: Automated full backups additionally require that the device is actively charging (`batteryCharging == true`) or has $\ge 60\%$ remaining charge.

---

## 3. Android 10+ Background Clipboard Lockdown & Android 13+ Sensitivity

- **Android 10+ (API 29+) Rule**: Apps running in the background cannot read the system clipboard.
  - `AndroidClipboardAdapter.syncLocalClipboardOutbound()` verifies `ctx.isAppInForeground()`. If false, clipboard reads are safely suppressed without crashing or logging security exceptions.
- **Android 13+ (API 33+) Sensitivity Flag**:
  - When copying sensitive content (e.g. passwords, crypto tokens), `ClipDescription.EXTRA_IS_SENSITIVE = true` is attached to prevent the system clipboard editor preview overlay from displaying the text.
- **Privacy Audit Guarantee**: Clipboard payloads exist ephemerally in volatile memory only and are never written to disk logs or diagnostic reports.
