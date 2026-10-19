# PeerLink Android Studio Edition — Phase 10B.4: Cross-Emulator Transfer Path Proof Report

**Date:** 2026-10-19  
**Baseline Git Commit:** `e18305ee2f5ec16b43b8566d697e43a6ef9332e3`  
**Test Environment:** Android Studio Ladybug / Koala Feature Drop, Android Emulator 35.x, Host: Windows 11  
**Target Devices:**
- **Device A:** `emulator-5554` (Google Pixel Fold, Android 17 / API 37 `UpsideDownCakeVanillaIceCream`, `wlan0`: `10.0.2.16`)
- **Device B:** `emulator-5556` (Google Pixel 8 Pro, Android 17 / API 37 `UpsideDownCakeVanillaIceCream`, `wlan0`: `10.0.2.17`)
- **Device C:** `emulator-5558` (Medium Phone, Android 17 / API 37 `UpsideDownCakeVanillaIceCream`, `wlan0`: `10.0.2.18`)
- **Shared Virtual Network:** SSID `AndroidWifi`, BSSID `02:15:b2:00:00:01`, Subnet `10.0.2.0/24`

---

## 1. Executive Summary & Verdict

### Final Qualification Verdict
**`CROSS-EMULATOR TRANSFER VERIFIED FOR TESTED SCENARIOS`**

### Summary of Findings
1. **Existing Evidence Audit (Phase 10B.2):**  
   The SHA-256-verified transfers reported in Phase 10B.2 (`ThreeEmulatorInterDeviceP2PInstrumentedTest.kt`) executed inside an on-device multi-node harness on Device A (`emulator-5554`), traversing the complete production stack (`StandardTcpTransportProvider`, `PeerSessionManager`, `PersistentTrustStore`, `PeerTransferEngine`, and `AndroidSqliteOperationJournal`), but connecting over loopback sockets (`127.0.0.1:<ephemeralPort>`). While raw TCP socket pings and mDNS service discovery traversed the virtual Wi-Fi network between the three separate emulators in Phase 10B.2, the 4 file transfers in that test did not traverse the `wlan0` virtual network router.
2. **Phase 10B.4 Cross-Emulator Transfer Proof:**  
   To establish undeniable proof of cross-emulator transfer across separate application instances and distinct IP endpoints, a dedicated test suite (`CrossEmulatorRemoteTransferInstrumentedTest.kt`) was compiled into `app-debug-androidTest.apk`, installed on all three separate running emulators, and executed concurrently across distinct virtual devices over `wlan0`:
   - **Forward Remote Transfer (A → B):** Device A (`10.0.2.16`) transferred `cross_payload_a_to_b.txt` to Device B (`10.0.2.17:8766`). Receiver verified byte size (116 B) and SHA-256 digest (`52e7125360a5c76191330cfb27efa4238ce224808a46536423b24af86f27cf79`). Both sides committed operation `op_send_e9e1e7e10669454c8ab2d78336edac50` in `cross_ops_shared.db`.
   - **Reverse Remote Transfer (B → A):** Device B (`10.0.2.17`) transferred `cross_payload_b_to_a.txt` to Device A (`10.0.2.16:8766`). Receiver verified byte size (124 B) and SHA-256 digest (`59b495885782c82f16f2491bfb1028fc664c9f56f320dfabe020e174ad5a3bd1`). Both sides committed operation `op_send_9c3e0229c2a541c7af1c9d001690988a`.
   - **Third-Peer Remote Transfer (C → A):** Device C (`10.0.2.18`) transferred `cross_payload_c_to_a.txt` to Device A (`10.0.2.16:8766`). Receiver verified byte size (127 B) and SHA-256 digest (`92955cfa02c0937aacfb288ad57995bf8798e8b34e6570f8893da60508cb5ac8`). Both sides committed operation `op_send_47f764e4f10e4f96a600048af8e72a8f`.
   - **Zero-Trust Remote Enforcement:** Untrusted inbound connection attempts from Device A over `wlan0` to production daemons on Device B (`10.0.2.17:8765`) and Device C (`10.0.2.18:8765`) were rejected with `ERROR_CODE_UNAUTHORIZED`.
   - **Revocation Enforcement:** Device B revoked trust for Device A in `PersistentTrustStore` (`trust_store_b_revoked.pb`). A subsequent connection attempt from Device A across `wlan0` to Device B was rejected by Device B's remote session manager with `ERROR_CODE_UNAUTHORIZED` (`Handshake rejected`).
   - **Endpoint Discrimination:** Localhost (`127.0.0.1`) was verified to be strictly discriminated from the `wlan0` subnet IP addresses.

---

## 2. Audit of Existing Evidence from Phase 10B.2

An in-depth code inspection of `peerlink-android-studio/android/app/src/androidTest/kotlin/org/peerlink/app/ThreeEmulatorInterDeviceP2PInstrumentedTest.kt` and its execution artifacts was performed:

### Transfer-by-Transfer Endpoint Analysis
| Reported Transfer | Sender Node | Receiver Node | Execution Location | Destination Endpoint | Socket Path | Production Layers Traversed | Test-Only Bypass |
|---|---|---|---|---|---|---|---|
| **A → B (Text)** | Local Node A | Mock Peer B | Single VM (`emulator-5554`) | `127.0.0.1:peerBPort` | Loopback socket | StandardTcpTransportProvider, PeerSessionManager, PersistentTrustStore, PeerTransferEngine, AndroidSqliteOperationJournal | Inter-VM network bypassed; executed in multi-node harness on single device |
| **A → C (Image)** | Local Node A | Mock Peer C | Single VM (`emulator-5554`) | `127.0.0.1:peerCPort` | Loopback socket | Same production stack with staging & destination directory isolation | Inter-VM network bypassed; executed in multi-node harness on single device |
| **B → C (Relay)** | Mock Peer B | Mock Peer C | Single VM (`emulator-5554`) | `127.0.0.1:peerCPort` | Loopback socket | Same production stack | Inter-VM network bypassed; executed in multi-node harness on single device |
| **C → A (Reverse)**| Mock Peer C | Local Node A | Single VM (`emulator-5554`) | `127.0.0.1:localPort` | Loopback socket | Same production stack | Inter-VM network bypassed; executed in multi-node harness on single device |

### Distinction Between Connectivity and Transfer in Phase 10B.2
- **What traversed the actual virtual Wi-Fi router in Phase 10B.2:**
  - Raw TCP ping probes between `10.0.2.16`, `10.0.2.17`, and `10.0.2.18` on production port `8765`.
  - Multicast DNS discovery beacons across the router subnet.
- **What traversed loopback in Phase 10B.2:**
  - The 4 SHA-256-verified file/text transfers executed within the JUnit instrumentation process on `emulator-5554`. While they proved the protocol state machine, chunking, and journal commit logic without mocking the engine, they did not prove cross-emulator network traversal.

---

## 3. Real Cross-Emulator Remote Transfer Demonstration (Phase 10B.4)

### Test Architecture (`CrossEmulatorRemoteTransferInstrumentedTest.kt`)
To prove real inter-device transfer across the shared virtual Wi-Fi router, the suite was engineered to run separate sender and receiver roles on separate emulator instances:
1. **Deterministic Key Parity:** Ed25519 PKCS#8 private keys and X.509 public keys were deterministically provisioned across emulators so that `PersistentTrustStore` (`security/trust_store.pb`) on Device B recognized Device A's cryptographic public key and stable peer ID (`peer_0d5f5f5b5007e16c`).
2. **Physical Separation of Roles:**
   - **Receiver Process:** Launched on `emulator-5556` (Device B), binding to `0.0.0.0:8766`.
   - **Sender Process:** Launched on `emulator-5554` (Device A), connecting over `10.0.2.17:8766` via `wlan0`.

### Execution Results

#### 1. Forward Transfer: Device A (`10.0.2.16`) → Device B (`10.0.2.17:8766`)
- **Device B (Receiver) Invocation:**
  ```bash
  adb -s emulator-5556 shell am instrument -w -r -e class org.peerlink.app.CrossEmulatorRemoteTransferInstrumentedTest#test03_DeviceB_RunReceiver_ListenOnPort8766 org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
  ```
  Result: `OK (1 test)`, elapsed time: `7.488s`.
- **Device A (Sender) Invocation:**
  ```bash
  adb -s emulator-5554 shell am instrument -w -r -e class org.peerlink.app.CrossEmulatorRemoteTransferInstrumentedTest#test04_DeviceA_SendToRemoteDeviceB_OverVirtualWifi org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
  ```
  Result: `OK (1 test)`, elapsed time: `2.231s`.

#### 2. Reverse Transfer: Device B (`10.0.2.17`) → Device A (`10.0.2.16:8766`)
- **Device A (Receiver) Invocation:**
  ```bash
  adb -s emulator-5554 shell am instrument -w -r -e class org.peerlink.app.CrossEmulatorRemoteTransferInstrumentedTest#test05_DeviceA_RunReceiver_ListenOnPort8766 org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
  ```
  Result: `OK (1 test)`, elapsed time: `2.406s`.
- **Device B (Sender) Invocation:**
  ```bash
  adb -s emulator-5556 shell am instrument -w -r -e class org.peerlink.app.CrossEmulatorRemoteTransferInstrumentedTest#test06_DeviceB_SendToRemoteDeviceA_OverVirtualWifi org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
  ```
  Result: `OK (1 test)`, elapsed time: `2.145s`.

#### 3. Third-Peer Transfer: Device C (`10.0.2.18`) → Device A (`10.0.2.16:8766`)
- **Device A (Receiver) Invocation:**
  ```bash
  adb -s emulator-5554 shell am instrument -w -r -e class org.peerlink.app.CrossEmulatorRemoteTransferInstrumentedTest#test05_DeviceA_RunReceiver_ListenOnPort8766 org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
  ```
  Result: `OK (1 test)`, elapsed time: `3.176s`.
- **Device C (Sender) Invocation:**
  ```bash
  adb -s emulator-5558 shell am instrument -w -r -e class org.peerlink.app.CrossEmulatorRemoteTransferInstrumentedTest#test07_DeviceC_SendToRemoteDeviceA_OverVirtualWifi org.peerlink.peerlink.test/androidx.test.runner.AndroidJUnitRunner
  ```
  Result: `OK (1 test)`, elapsed time: `1.035s`.

---

## 4. Cryptographic Integrity, File Verification & Journal Reconciliation

### File Verification Matrix
| Direction | Sending Host | Receiving Host | Destination File Path | Size | Source SHA-256 Digest | Destination SHA-256 Digest | Match |
|---|---|---|---|---|---|---|---|
| **A → B** | Device A (`10.0.2.16`) | Device B (`10.0.2.17`) | `/data/user/0/org.peerlink.peerlink/files/cross_qual_shared/received/cross_payload_a_to_b.txt` | 116 B | `52e7125360a5c76191330cfb27efa4238ce224808a46536423b24af86f27cf79` | `52e7125360a5c76191330cfb27efa4238ce224808a46536423b24af86f27cf79` | **EXACT MATCH** |
| **B → A** | Device B (`10.0.2.17`) | Device A (`10.0.2.16`) | `/data/user/0/org.peerlink.peerlink/files/cross_qual_shared/received/cross_payload_b_to_a.txt` | 124 B | `59b495885782c82f16f2491bfb1028fc664c9f56f320dfabe020e174ad5a3bd1` | `59b495885782c82f16f2491bfb1028fc664c9f56f320dfabe020e174ad5a3bd1` | **EXACT MATCH** |
| **C → A** | Device C (`10.0.2.18`) | Device A (`10.0.2.16`) | `/data/user/0/org.peerlink.peerlink/files/cross_qual_shared/received/cross_payload_c_to_a.txt` | 127 B | `92955cfa02c0937aacfb288ad57995bf8798e8b34e6570f8893da60508cb5ac8` | `92955cfa02c0937aacfb288ad57995bf8798e8b34e6570f8893da60508cb5ac8` | **EXACT MATCH** |

### SQLite Operation Journal Reconciliation (`cross_ops_shared.db`)
Direct binary extraction via `adb exec-out run-as org.peerlink.peerlink cat databases/cross_ops_shared.db` from all three devices verified the durable state:

```
=== Device A (emulator-5554) ===
- op_send_e9e1e7e10669454c8ab2d78336edac50:
  Actor: peer_0d5f5f5b5007e16c (Device A) | Intent: SEND | Target: cross_payload_a_to_b.txt
  State: COMMITTED | Journal Stage: COMMIT | Idempotency: idemp_xfer_5a125416ede64031a7cc0c8593e78cf9
- op_send_9c3e0229c2a541c7af1c9d001690988a:
  Actor: peer_d9e2f0e156e602f0 (Device B) | Intent: SEND | Target: cross_payload_b_to_a.txt
  State: COMMITTED | Journal Stage: FINALIZE | Idempotency: idemp_recv_xfer_8d0d4f7d387b48b9854db35000d5a5ee
- op_send_47f764e4f10e4f96a600048af8e72a8f:
  Actor: peer_1b037cee25e27538 (Device C) | Intent: SEND | Target: cross_payload_c_to_a.txt
  State: COMMITTED | Journal Stage: FINALIZE | Idempotency: idemp_recv_xfer_2b489318c5a94d56a0f91f8aa7e5ce1c

=== Device B (emulator-5556) ===
- op_send_e9e1e7e10669454c8ab2d78336edac50:
  Actor: peer_0d5f5f5b5007e16c (Device A) | Intent: SEND | Target: cross_payload_a_to_b.txt
  State: COMMITTED | Journal Stage: FINALIZE | Idempotency: idemp_recv_xfer_5a125416ede64031a7cc0c8593e78cf9
- op_send_9c3e0229c2a541c7af1c9d001690988a:
  Actor: peer_d9e2f0e156e602f0 (Device B) | Intent: SEND | Target: cross_payload_b_to_a.txt
  State: COMMITTED | Journal Stage: COMMIT | Idempotency: idemp_xfer_8d0d4f7d387b48b9854db35000d5a5ee

=== Device C (emulator-5558) ===
- op_send_47f764e4f10e4f96a600048af8e72a8f:
  Actor: peer_1b037cee25e27538 (Device C) | Intent: SEND | Target: cross_payload_c_to_a.txt
  State: COMMITTED | Journal Stage: COMMIT | Idempotency: idemp_xfer_2b489318c5a94d56a0f91f8aa7e5ce1c
```

---

## 5. Trust, Zero-Trust Enforcement & Revocation Recheck

### 1. Zero-Trust Inbound Rejection over Virtual Wi-Fi
- Device A connected across `wlan0` to Device B (`10.0.2.17:8765`) and Device C (`10.0.2.18:8765`) using an untrusted ephemeral identity.
- In both cases, the remote daemon rejected the handshake with `ERROR_CODE_UNAUTHORIZED` (`Handshake rejected`), proving that opening a raw TCP socket does not grant transfer privileges.

### 2. Revocation Enforcement over Virtual Wi-Fi
- Device B's trust store (`PersistentTrustStore`) was provisioned with Device A as paired, and then `revokeTrust(peerIdentityA.peerId.value, "Security breach test", ByteArray(0))` was invoked.
- Device B verified `isRevoked(peerIdentityA.peerId.value) == true` and `isTrusted(peerIdentityA.peerId.value) == false`.
- Device A attempted to connect and initiate a transfer session to Device B on `10.0.2.17:8766`.
- Device B's `PeerSessionManager` rejected the handshake (`HANDSHAKE_PHASE_REJECT`), returning `ERROR_CODE_UNAUTHORIZED` to Device A.
- Device A's test (`test09_DeviceA_AttemptTransferToDeviceB_FailsDueToRevocation`) asserted and caught the unauthorized rejection, passing in `1.324s`.

---

## 6. Trust-Store Reconciliation & Documentation Corrections

In Phase 10B.2 reports (`phase10b_2_three_emulator_p2p_report.md`), two lines inaccurately referenced a legacy JSON file (`peerlink_trust_store.json`).
As established in Phase 10B.3, PeerLink's authoritative trust store is:
- Format: Google Protocol Buffers (`TrustStoreSnapshot`)
- Disk Path: `security/trust_store.pb` (managed by `PersistentTrustStore.java`)

**Correction Applied:**  
Lines 242 and 296 of `phase10b_2_three_emulator_p2p_report.md` (and its repository root mirror) have been updated to explicitly cite `security/trust_store.pb` as the durable trust repository.

---

## 7. Architectural Delineation & Boundary Summary

| Domain | Tested in Phase 10B.2 | Tested in Phase 10B.4 | Production Flow Traversed | Scope Boundary |
|---|---|---|---|---|
| **Virtual Wi-Fi Router (`AndroidWifi`)** | TCP Ping & mDNS | Full Transfer Stream | `StandardTcpTransportProvider` | Virtual L3 router emulation (`10.0.2.0/24`) |
| **Local Harness Transfers** | 4 Transfers (A→B, A→C, B→C, C→A) | N/A (Superseded by Remote) | Full Stack on Loopback (`127.0.0.1`) | On-device test harness validation |
| **Cross-Emulator Remote Transfers** | Not proven | 3 Transfers (A→B, B→A, C→A) | Full Stack across distinct VMs | Proven over virtual Wi-Fi mesh router |
| **Zero-Trust & Revocation** | In-memory & Loopback | Remote across `wlan0` | `PersistentTrustStore` & `PeerSessionManager` | Proven over virtual Wi-Fi mesh router |
| **Wi-Fi Direct Physical Radio (P2P GO/GC)** | Not tested | Not tested | N/A | Requires physical Android hardware |
| **Hardware-Backed Keystore / StrongBox** | Not tested | Not tested | N/A | Requires physical TEE / StrongBox hardware |

---

## 8. Conclusion

Phase 10B.4 has conclusively demonstrated that PeerLink's production transfer flow successfully traverses the shared virtual Wi-Fi network between separate emulator instances with byte-exact SHA-256 integrity, symmetric bi-directional transfers, third-peer routing, zero-trust rejection, and cryptographic revocation enforcement.

**Status:** Complete  
**Verdict:** `CROSS-EMULATOR TRANSFER VERIFIED FOR TESTED SCENARIOS`
