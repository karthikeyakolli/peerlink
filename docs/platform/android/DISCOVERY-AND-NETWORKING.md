# Android Discovery & Networking Adapters

## 1. Zero Google Lock-In

PeerLink does **not** depend on proprietary Google Play Services (e.g. Nearby Connections). The discovery layer is completely modularized around the `DiscoveryAdapter` abstraction:

```
                      ┌───────────────────────────┐
                      │   AndroidDiscoveryEngine  │
                      └─────────────┬─────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          │                         │                         │
┌─────────▼───────────┐   ┌─────────▼───────────┐   ┌─────────▼───────────┐
│  NsdDiscoveryAdapter│   │WifiDirectDiscovery  │   │WifiAwareDiscovery   │
│  (DNS-SD / mDNS)    │   │Adapter (P2P Wi-Fi)  │   │Adapter (NAN)        │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
```

---

## 2. Adapter Matrix

| Discovery Technology | Android API | Use Case | Offline / Off-Grid Capable |
|---|---|---|---|
| **NSD / mDNS** | `android.net.nsd.NsdManager` (`_peerlink._tcp`) | Local Wi-Fi home/office networks | Requires local router/hotspot |
| **Wi-Fi Direct** | `android.net.wifi.p2p.WifiP2pManager` | High-bandwidth peer-to-peer without an AP | **Yes** (Completely off-grid) |
| **Wi-Fi Aware** | `android.net.wifi.aware.WifiAwareManager` | Low-power Neighbor Awareness Networking | **Yes** (Nan clusters) |
| **Nearby RF** | Bluetooth LE / Local RF custom | Ultra-low power discovery beaconing | **Yes** (Local radio beacon) |

---

## 3. Network Handoff & Cellular Throttling

When an Android device switches from Wi-Fi to a metered cellular connection:
1. `ConnectivityManager.NetworkCallback` detects network capability change.
2. `AndroidNodeStateMachine` updates environmental context.
3. `AndroidBackgroundPolicy.shouldThrottleTransfer()` returns `true`.
4. PeerLink transfer engine dynamically throttles block chunking and pauses non-essential background backups to prevent draining the user's mobile data quota.
