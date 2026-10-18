# PeerLink Android Studio Edition — Feature Verification Matrix

**Document Version:** 1.0.0  
**Audit Date:** 2026-10-18  
**Project:** `peerlink-android-studio/`  
**Classification Baseline:** Verified against Flutter unit & widget tests (55/55 passed), Android JVM unit tests (26/26 passed), Flutter analysis (0 errors), and debug APK assembly (`build\app\outputs\flutter-apk\app-debug.apk`).

---

## 1. Classification Scheme

Every audited capability is strictly classified into exactly one of seven mutually exclusive statuses:
1. `IMPLEMENTED_AND_VERIFIED`: Implemented in production code and verified with passing automated tests.
2. `IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED`: Production code exists and passes unit tests, but requires full multi-device physical network verification.
3. `PARTIALLY_IMPLEMENTED`: Substantial production logic exists, but specific bridge adapters, callbacks, or workflow loops remain incomplete.
4. `SIMULATED_OR_PLACEHOLDER`: Hardcoded response, mock painter, or simulated scan callback present in production path.
5. `MISSING`: Capability is not yet implemented in the codebase.
6. `BLOCKED_BY_PLATFORM_OR_INFRASTRUCTURE`: Blocked due to operating system permission boundaries, hardware absence, or external relay infrastructure requirement.
7. `NOT_TESTED_IN_AVAILABLE_ENVIRONMENT`: Capability cannot be verified in the current single-workstation environment (e.g. requires 2 physical Wi-Fi Direct devices).

---

## 2. Feature Verification Matrix

| Area | Capability / Component | Status | Source Location | Verification Evidence & Audit Observations |
| :--- | :--- | :--- | :--- | :--- |
| **Core Identity** | Ed25519 Keypair Derivation & Keystore Storage | **IMPLEMENTED_AND_VERIFIED** | `AndroidKeystoreManager.java`, `AndroidKeyStoreProvider.kt` | Conformant to `DERIVATION_RULE_V1`. Private keys protected by hardware-backed AES-256-GCM. Corrupt keystore entry safely rejected without silent regeneration. Verified in `AndroidIdentityCompatibilityTest`. |
| **Core Identity** | Safety Numbers & Session Auth Codes | **IMPLEMENTED_AND_VERIFIED** | `PeerCryptoSigner.java`, `AndroidIdentityCompatibilityTest.kt` | 30-digit domain-separated safety numbers and 6-digit session codes verified symmetric and collision-resistant across independent keypairs. |
| **Lifecycle** | Authoritative Local Node State Machine | **IMPLEMENTED_AND_VERIFIED** | `AndroidNodeFacade.java`, `AndroidNodeBridge.dart` | Synchronized transitions across `STOPPED`, `STARTING`, `READY`, `TRANSFERRING`, `STOPPING`. Idempotent repeated start and stop verified. |
| **Lifecycle** | Persistent SQLite Operation Journal | **IMPLEMENTED_AND_VERIFIED** | `AndroidSqliteOperationJournal.java`, `operation_journal_service.dart` | SQLite WAL mode with foreign keys, schema versioning, and immutable state transitions. Verified in `AndroidLifecycleAndPersistenceTest`. |
| **Lifecycle** | Startup Crash Recovery (5-State Recovery) | **IMPLEMENTED_AND_VERIFIED** | `AndroidStartupRecoveryManager.java`, `PeerLinkApplication.kt` | Preserves valid incomplete transfers in `WAITING` without deleting valid chunks; quarantines corrupt chunks to `.corrupt`; flags uncertain final outcomes as `OUTCOME_UNKNOWN` per Rule 9. Verified in `activity_journal_recovery_test`. |
| **Discovery** | NSD / mDNS Local Network Discovery | **IMPLEMENTED_AND_VERIFIED** | `AndroidNsdAdapter.kt`, `AndroidDiscoveryEngine.java` | Advertises `_peerlink._tcp`, resolves host IPs/ports, extracts Protobuf `peerId` and `name` attributes. Evaluates API 37 `ACCESS_LOCAL_NETWORK` permission. Verified in `AndroidRealPeerConnectivityTest`. |
| **Discovery** | Wi-Fi Direct (P2P) Discovery Adapter | **IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED** | `AndroidWifiDirectAdapter.kt` | Code interfaces with `WifiP2pManager.discoverPeers`. Passes unit inspection, but requires two physical devices with Wi-Fi Direct radios for end-to-end multi-device testing. |
| **Discovery** | Wi-Fi Aware (NAN) Adapter | **IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED** | `AndroidWifiAwareAdapter.kt` | Interfaces with `WifiAwareManager`. Passes unit inspection; requires hardware Wi-Fi Aware chipsets. |
| **Discovery** | Cross-Adapter Peer Deduplication | **PARTIALLY_IMPLEMENTED** | `AndroidDiscoveryEngine.java` | Discovery mechanisms notify engine, but deduplication map across concurrent NSD and Wi-Fi Direct reporting identical `PeerId` requires consolidation. |
| **Pairing** | QR Code Visual Presentation | **SIMULATED_OR_PLACEHOLDER** | `lib/design_system/components/qr_pairing_sheet.dart` | Uses `_SimulatedQrPainter` rendering decorative placeholder squares. Scheduled for replacement with genuine `qr_flutter` in Phase 3. |
| **Pairing** | QR Camera Scanner | **SIMULATED_OR_PLACEHOLDER** | `lib/design_system/components/qr_pairing_sheet.dart:205` | "Simulate Instant Scan" button emits hardcoded URI `'peerlink://connect?peer=peer-scanned-01'`. Scheduled for replacement with real CameraX scanner in Phase 3. |
| **Pairing** | Direct Hotspot Configuration | **SIMULATED_OR_PLACEHOLDER** | `lib/design_system/components/qr_pairing_sheet.dart:278` | UI displays hardcoded SSID `'PeerLink-Direct-94A2'` and password `'peerlink-direct-key'`. Scheduled for genuine dynamic hotspot credentials in Phase 3. |
| **Transport** | TCP Sockets with 3-Way Cryptographic Handshake | **IMPLEMENTED_AND_VERIFIED** | `StandardTcpTransportProvider.java`, `PeerSessionImpl.java` | Real duplex TCP sockets, length-prefixed Protobuf framing, 3-way Ed25519 mutual authentication, and replay protection. Verified in `AndroidRealPeerConnectivityTest`. |
| **SEND Mode** | SAF File Streaming & Chunk Integrity Verification | **IMPLEMENTED_AND_VERIFIED** | `SafStorageProvider.kt`, `PeerTransferEngine.java` | Streams content URIs, computes SHA-256 chunk hashes, writes to `.part` staging, atomically commits upon final verification. Verified in `AndroidFourOperationModesTest`. |
| **SEND Mode** | Receiver Consent Interactivity | **PARTIALLY_IMPLEMENTED** | `FilesScreen.dart`, `AndroidNodeBridge.dart` | Trust service allows auto-accept for verified peers, but interactive bottom-sheet modal for unknown peer prompt requires end-to-end UI loop binding. |
| **ACCESS Mode** | Authoritative Scoping & Path Sandbox | **IMPLEMENTED_AND_VERIFIED** | `RemoteAccessCoordinator.java`, `ShareManager.java` | HMAC signed capability tokens, scope enforcement (`BROWSE`, `DOWNLOAD`), directory boundary enforcement rejecting `../` traversal. Verified in `AndroidFourOperationModesTest`. |
| **SYNC Mode** | Vector Clocks & Conflict Detection | **IMPLEMENTED_AND_VERIFIED** | `SyncManifest.java`, `ConflictDetector.java`, `CausalVersion.java` | Causal vector clocks track distributed modifications without treating timestamps as truth (Rule 7). Preserves both versions in `MODIFY_VS_MODIFY` conflict. Verified in `spaces_real_sync_backup_test`. |
| **SYNC Mode** | Continuous Background Space Sync | **PARTIALLY_IMPLEMENTED** | `PeerLinkSyncWorker.kt`, `SyncBackupService.dart` | WorkManager worker triggers sync on unmetered network/charging constraints; multi-peer live sync loop requires Phase 10 convergence verification. |
| **BACKUP Mode** | Snapshot Merkle Trees & Safe Restoration | **IMPLEMENTED_AND_VERIFIED** | `BackupEngine.java`, `SnapshotMerkleTree.java`, `FileBasedBackupTarget.java` | Full snapshot creation with SHA-256 chunk validation, retention pruning, and fail-on-conflict restore invariant. Verified in `AndroidFourOperationModesTest`. |
| **Remote WAN** | Direct-First NAT Traversal with Relay Fallback | **MISSING** | `docs/architecture/adr/` (To be designed in Phase 9) | Cross-network WAN sharing currently requires local LAN reachability. Direct-first signaling and relay fallback planned for Phase 9. |
| **Background** | Foreground Service & WorkManager Integration | **IMPLEMENTED_AND_VERIFIED** | `PeerLinkForegroundService.kt`, `PeerLinkSyncWorker.kt` | Android 14+ compliant `FOREGROUND_SERVICE_DATA_SYNC` with `onTimeout()` callback and safe transfer pause. Verified in Android test suite. |
| **Security** | Hardware Security Level Reporting | **IMPLEMENTED_AND_VERIFIED** | `AndroidKeystoreManager.java` | Truthfully inspects AndroidKeyStore whether master AES key is hardware-backed (TEE/StrongBox) or software, without fabricating false claims. |
| **Multi-Device** | Physical Multi-Device Wi-Fi Direct Transfer | **NOT_TESTED_IN_AVAILABLE_ENVIRONMENT** | Physical Hardware Required | Development workstation has 1 Android emulator (`Medium_Phone`) and local Windows/Chrome targets; multi-device over-the-air RF testing requires 2 physical Android devices. |

---

## 3. Prioritized Implementation Sequence

Based on the verified matrix:
1. **Phase 1: Core Lifecycle, Operation Contracts & Observability**
   Consolidate typed capability descriptors, enforce atomic lifecycle idempotency, and bridge real state to Flutter.
2. **Phase 2: Zero-Configuration Startup & Permission Automation**
   Automate node initialization upon app launch; auto-bind ephemeral TCP port and auto-start NSD discovery adapter.
3. **Phase 3: Real QR Invitations & Authenticated Pairing**
   Eliminate `_SimulatedQrPainter` and fake scan callback. Add `qr_flutter` and `mobile_scanner`, generate versioned invitation payloads with ephemeral nonces and connection hints, and enforce mutual public-key identity binding.
4. **Phase 4: Automatic Nearby Discovery & Transport Selection**
   Centralize discovery deduplication in `AndroidDiscoveryEngine`, add TTL-based peer expiration, and select optimal transport routes.
5. **Phase 5: Complete the Actual End-to-End SEND Path**
   Wire interactive receiver consent sheet, real-time chunk progress streaming, and atomic commit confirmation.

---
*End of Feature Verification Matrix.*
