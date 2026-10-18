# PeerLink Android Studio Edition — Phase 03 Implementation Report: Real QR Invitations & Authenticated Pairing

**Document Version:** 1.0.0  
**Phase:** Phase 03  
**Status:** COMPLETE & VERIFIED  
**Date:** 2026-10-18  
**Author:** Lead Android / Flutter / P2P Systems Engineer  
**Target Project:** `peerlink-android-studio/`  
**Git Commit Baseline:** `e1362b2` (branch `master`)

---

## 1. Initial Defect & Simulated Behaviors

Prior to Phase 3:
1. **Decorative Simulated QR Code (`_SimulatedQrPainter`):** The QR modal displayed a hardcoded `CustomPainter` that drew static rectangles and fake finder patterns. It contained zero encoded data and could not be optically decoded by any standard QR reader.
2. **Fabricated Scan Action:** In the "Scan QR" tab, pressing the button executed `widget.onQrScanned?.call('peerlink://connect?peer=peer-scanned-01')`, simulating pairing with a non-existent demo peer (`peer-scanned-01`).
3. **Hardcoded Mock Hotspot Credentials:** The Wi-Fi Hotspot tab displayed static mock values:
   - SSID: `PeerLink-Direct-94A2`
   - WPA2 Password: `peerlink-direct-key`
   - Subnet: `192.168.49.1:52001`
4. **Vulnerability to Replay & Forgery:** There was no cryptographically bounded invitation payload, no session identifier, no expiration timestamp, no replay cache, and no visual Short Authentication String (SAS) out-of-band confirmation.

---

## 2. Root Cause Analysis

1. Lack of genuine QR generation and optical barcode scanning dependencies in `pubspec.yaml`.
2. Absence of an authoritative, versioned cryptographic model for short-lived pairing invitations.
3. Violation of Rule 6 (*"Never treat discovery as trust"*) by automatically assuming scanned text represented a trusted device without user identity review or out-of-band SAS code confirmation.

---

## 3. Design Decisions & Implementation Details

### A. Cryptographic Schema: `PairingInvitation` (`lib/core/pairing_invitation.dart`)
1. **Compact Versioned Payload Schema:**
   ```json
   {
     "v": 1,
     "peerId": "peer-sender-remote-77",
     "name": "Office ThinkPad",
     "fingerprint": "ed25519:senderfingerprint7777",
     "sessionId": "4b68e59276d1e434f4be2b012431cf98",
     "nonce": "e309cb6995ce5e82b3d88eb1a196fc98",
     "expiry": 1776512345678,
     "hints": ["192.168.1.80:8765"],
     "sec": "STRONGBOX"
   }
   ```
2. **Freshness & Nonces:**
   - Generated using `Random.secure()`, producing 128-bit random session identifiers and 128-bit nonces.
   - Default validity: 5 minutes (`Duration(minutes: 5)`).
3. **Strict Validation & Failure Paths:**
   - Throws `InvalidInvitationException` for malformed JSON, missing fields, or unsupported versions ($v \ne 1$).
   - Throws `InvitationExpiredException` if $\text{expiry} < \text{now}$.
   - Throws `ReplayDetectedException` if a consumed session ID is presented again.
4. **Short Authentication String (SAS):**
   - Derives a 4-digit numeric verification PIN:
     $$\text{PIN} = \Big|\text{Int32}\big(\text{SHA-256}(\text{fingerprint} + ":" + \text{sessionId} + ":" + \text{nonce})[0..3]\big)\Big| \pmod{10000}$$
   - Allows both parties to visually confirm the 4-digit code out-of-band before confirming trust.

### B. Real Optical QR Display & Camera Scanning (`lib/design_system/components/qr_pairing_sheet.dart`)
1. **Show QR View (`qr_flutter: 4.1.0`):**
   - Replaced `_SimulatedQrPainter` with `QrImageView` using error correction level `QrErrorCorrectLevel.M`, quiet zone padding, and high-contrast styling.
   - Displays real-time countdown timer ("Expires in mm:ss").
   - Displays bold visual SAS PIN chip.
   - Provides a "Generate Fresh QR" / "Refresh Invitation" action to cycle nonces and reset expiration.
2. **Scan QR View (`mobile_scanner: 7.4.2`):**
   - Implements live camera scanning with viewfinder reticle overlay and automatic torch/facing control.
   - Provides an accessible **Manual Code Entry / Paste** fallback with text input and "Verify & Pair" button for headless testing, emulators without virtual cameras, and camera permission-denied scenarios.
3. **Verified Candidate Confirmation Dialog:**
   - Scanning a code pauses the camera and presents an authoritative review dialog:
     - Remote Device Name & Peer ID
     - Full Ed25519 public key fingerprint
     - Out-of-band SAS Security Code
     - Keystore security level (`STRONGBOX`, `TEE`, etc.)
   - On "Trust & Pair":
     - Marks invitation consumed to prevent replay attacks.
     - Persists device into `DeviceTrustService.instance.pairDevice()`.
     - Invokes `AndroidNodeBridge.instance.confirmPairing()` to notify the native node.
     - Shows confirmation feedback and closes sheet.
4. **Dynamic Wi-Fi Direct Hotspot:**
   - Removed hardcoded credentials. Dynamically formats SSID `PeerLink-${peerId.take(6)}` and WPA2 passphrase.
   - Renders genuine standard Wi-Fi configuration QR code (`WIFI:T:WPA;S:...;P:...;;`) for instant camera join without manual typing.

---

## 4. Files Modified and Created

| File | Action | Purpose |
|------|--------|---------|
| `pubspec.yaml` | Modified | Added `qr_flutter: ^4.1.0` and `mobile_scanner: ^7.4.2`. |
| `lib/core/pairing_invitation.dart` | Created | Defined `PairingInvitation` model, validation exceptions, serialization, anti-replay cache, and SAS code derivation. |
| `lib/design_system/components/qr_pairing_sheet.dart` | Modified | Replaced `_SimulatedQrPainter` and fake scan button with real `QrImageView`, `MobileScanner`, manual fallback, and candidate confirmation modal. |
| `test/unit/pairing_invitation_test.dart` | Created | Comprehensive unit test suite for cryptographic schema, freshness, expiration, replay detection, and legacy fallback (6 tests). |
| `test/qr_pairing_authenticated_sheet_test.dart` | Created | Flutter widget test verifying optical QR rendering, SAS PIN, manual fallback pairing, and dynamic hotspot QR generation (3 tests). |

---

## 5. Verification Commands and Exact Results

### 1. Flutter Unit & Widget Tests
- **Command:** `flutter test`
- **Execution Time:** 8.0s
- **Results:** **All 66 tests passed!** (0 failures, 0 skipped).
- **Key Test Suites Verified:**
  - `test/unit/pairing_invitation_test.dart`: **6/6 passed**
  - `test/qr_pairing_authenticated_sheet_test.dart`: **3/3 passed**
  - `test/zero_config_startup_widget_test.dart`: **2/2 passed**
  - `test/home_ux_simplification_test.dart`: **2/2 passed**
  - `test/activity_journal_recovery_test.dart`: **3/3 passed**
  - `test/protocol_contract_compatibility_test.dart`: **6/6 passed**
  - `test/widget_test.dart`: **7/7 passed**

### 2. Android Native JVM Unit Tests
- **Command:** `powershell -Command "$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'; .\gradlew.bat :app:testDebugUnitTest"`
- **Execution Time:** 49.0s
- **Results:** **BUILD SUCCESSFUL**
- **Test Summary:** **38 / 38 passed** across 7 test suites:
  - `AndroidZeroConfigStartupTest`: 6/6 passed
  - `AndroidNodeLifecycleStateMachineTest`: 6/6 passed
  - `AndroidFourOperationModesTest`: 4/4 passed
  - `AndroidIdentityCompatibilityTest`: 11/11 passed
  - `AndroidLifecycleAndPersistenceTest`: 5/5 passed
  - `AndroidNodeContextTest`: 2/2 passed
  - `AndroidRealPeerConnectivityTest`: 4/4 passed

---

## 6. Acceptance Gate Evaluation

| Requirement | Acceptance Gate Standard | Status | Evidence |
|-------------|-------------------------|--------|----------|
| **Genuine QR Encoding** | Codes generated from actual session data with proper quiet zones | **MET** | `QrImageView` in `QrPairingSheet`, `testQrPairingSheet` |
| **No Fake Scan Callbacks** | Simulated callback replaced with real optical decoding / manual fallback | **MET** | `MobileScanner` integration; manual verification flow tested |
| **Cryptographic Invitations** | Short-lived payload with version, nonce, expiry, and SAS code | **MET** | `PairingInvitation` unit tests (6/6 passed) |
| **Anti-Replay Protection** | Prevent re-using consumed session identifiers | **MET** | `testAntiReplayProtection` verified |
| **Out-of-band SAS Verification** | Visual 4-digit code displayed for bilateral user verification | **MET** | Prominent SAS code chip in QR and confirmation dialog |
| **Trust Persistence** | Pairwise trust explicitly confirmed and persisted in `DeviceTrustService` | **MET** | Verified in `testManualFallbackValidatesInvitationAndPairsDevice` |

---

## 7. Next Phase Dependencies

- **Phase 04 (Automatic Nearby Discovery & Transport Selection):**
  - Deduplicate discovered peers across NSD/mDNS, Wi-Fi Direct, and Wi-Fi Aware adapters.
  - Expire stale peers automatically.
  - Abstract transport selection so UI remains agnostic to radio details.
