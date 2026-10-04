# PeerLink Android Node Architecture

## 1. Overview & Architectural Stack

Unlike desktop nodes that can operate continuously as resident daemons with persistent file paths, Android nodes run in a severely resource-constrained, battery-managed, sandbox-restricted operating system environment.

The PeerLink Android architecture is structured in strict layered decoupling:

```
┌────────────────────────────────────────────────────────┐
│                      Flutter UI                        │
│   (Dart widgets, reactive streams, user interaction)   │
└───────────────────────────┬────────────────────────────┘
                            │ Pigeon / Platform Channels
┌───────────────────────────▼────────────────────────────┐
│              Kotlin / Java Android Layer               │
│  (AndroidKeyStore, SAF DocumentFile, Notifications,    │
│   WorkManager, Foreground Service, Nsd/WifiDirect)     │
└───────────────────────────┬────────────────────────────┘
                            │ Portable APIs
┌───────────────────────────▼────────────────────────────┐
│                 Portable PeerLink Core                 │
│  (SessionManager, TransferEngine, SafetyPipeline,      │
│   SyncEngine, BackupEngine, Collaboration, KeyStore)   │
└───────────────────────────┬────────────────────────────┘
                            │ System Drivers / Hal
┌───────────────────────────▼────────────────────────────┐
│               Android Platform Services                │
│    (Linux Kernel, Wi-Fi Stack, Keymaster/StrongBox)    │
└────────────────────────────────────────────────────────┘
```

---

## 2. Fundamental Invariant: Mobile Node Realities

> **Core Invariant**: PeerLink must **never** assume an Android device can behave like an always-on desktop daemon.

1. **No Silent Background Sockets**: The Android OS freezes background network sockets when an app is not in the foreground unless explicitly promoted to a Foreground Service with an ongoing notification.
2. **Path vs. URI Separation**: Android storage uses ContentResolver URIs (`content://...`) and SAF Document IDs, never raw POSIX disk paths.
3. **Hardware Keystore Isolation**: Private identity keys are non-exportable from hardware StrongBox/TEE.
4. **Android 10+ Background Clipboard Lockdown**: Background apps are prohibited from accessing clipboard data.

---

## 3. The 4 Android Node States

```
                 App in Foreground / FGS Started
                 ┌─────────────────────────────┐
                 │                             │
                 ▼                             │ UI Backgrounded &
           ┌──────────┐                        │ FGS Stopped
           │  ACTIVE  │                        │
           └─────┬────┘                        ▼
                 │                      ┌────────────────────┐
                 │                      │ BACKGROUND_CAPABLE │
                 │                      └─────────┬──────────┘
      Airplane   │                                │
      or Offline │          Doze / PowerSaver     │
                 ▼          or Low Battery        ▼
         ┌─────────────┐                        ┌───────────────┐
         │ UNAVAILABLE │◄───────────────────────┤ OS_RESTRICTED │
         └─────────────┘   Storage Perm Denied  └───────────────┘
```

| State | Environmental Conditions | Allowed Operations |
|---|---|---|
| **`ACTIVE`** | App in foreground OR active Foreground Service (`FOREGROUND_SERVICE_TYPE_DATA_SYNC`). High-speed network connection. | Full line-rate P2P streaming, live mDNS discovery, interactive pairing, active clipboard broadcasting. |
| **`BACKGROUND_CAPABLE`** | App backgrounded, healthy battery or charging, unmetered network. Doze and power saver inactive. | Opportunistic WorkManager sync batches, scheduled backup participation, throttled keepalives. |
| **`OS_RESTRICTED`** | Doze mode (Device Idle), Battery Saver active, metered data saver, or battery <= 15% not charging. | Network sockets frozen, periodic sync paused, background clipboard access blocked. |
| **`UNAVAILABLE`** | Network offline, airplane mode, critical storage permission revoked, or process dying. | All operations halted; gracefully persists state for re-emergence. |
